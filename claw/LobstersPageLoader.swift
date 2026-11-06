//
//  LobstersPageLoader.swift
//  claw
//

import Foundation

private final class URLSessionTaskBox: @unchecked Sendable {
    private let lock = NSLock()
    private var task: URLSessionTask?
    private var isCancelled = false

    func setTask(_ task: URLSessionTask) {
        lock.lock()
        self.task = task
        let shouldCancel = isCancelled
        lock.unlock()
        if shouldCancel {
            task.cancel()
        }
    }

    func cancel() {
        lock.lock()
        isCancelled = true
        let task = task
        lock.unlock()
        task?.cancel()
    }
}

struct LoadedLobstersPage: Sendable {
    let html: String
    let response: HTTPURLResponse
}

enum LobstersPageLoaderError: LocalizedError {
    case invalidResponse
    case unsuccessfulStatusCode(Int)
    case cannotDecodeContent
    case rateLimited(retryAt: Date)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "The Lobsters webpage returned an invalid response."
        case .unsuccessfulStatusCode(let statusCode):
            return "The Lobsters webpage returned HTTP \(statusCode)."
        case .cannotDecodeContent:
            return "The Lobsters webpage could not be decoded."
        case .rateLimited(let retryAt):
            return "Lobsters is temporarily limiting requests. Please try again after \(retryAt.formatted(date: .omitted, time: .standard))."
        }
    }
}

/// Shared by native requests and WebKit document navigations. A throttled page
/// is not an anonymous session, and retrying it immediately only extends the burst.
final class LobstersRequestThrottle: @unchecked Sendable {
    static let shared = LobstersRequestThrottle()

    private let lock = NSLock()
    private let minimumInterval: TimeInterval
    private var nextRequest = [String: Date]()
    private var cooldowns = [String: Date]()

    init(minimumInterval: TimeInterval = 1) {
        self.minimumInterval = minimumInterval
    }

    private func origin(_ url: URL) -> String {
        "\(url.scheme?.lowercased() ?? "")://\(url.host?.lowercased() ?? ""):\(url.port ?? (url.scheme == "https" ? 443 : 80))"
    }

    func check(_ url: URL, now: Date = Date()) throws {
        lock.lock()
        defer { lock.unlock() }
        if let deadline = cooldowns[origin(url)], deadline > now {
            throw LobstersPageLoaderError.rateLimited(retryAt: deadline)
        }
    }

    func acquire(_ url: URL) async throws {
        while true {
            try Task.checkCancellation()
            let delay = try reserve(url)
            if delay <= 0 { return }
            try await Task.sleep(for: .seconds(delay))
        }
    }

    private func reserve(_ url: URL) throws -> TimeInterval {
        lock.lock()
        defer { lock.unlock() }
        let now = Date()
        let key = origin(url)
        if let deadline = cooldowns[key], deadline > now {
            throw LobstersPageLoaderError.rateLimited(retryAt: deadline)
        }
        if let next = nextRequest[key], next > now {
            return next.timeIntervalSince(now)
        }
        nextRequest[key] = now.addingTimeInterval(minimumInterval)
        return 0
    }

    @discardableResult
    func observe(_ response: HTTPURLResponse, now: Date = Date()) -> LobstersPageLoaderError? {
        guard response.statusCode == 429, let url = response.url else { return nil }
        let deadline = Self.retryDate(for: response, now: now)
        lock.lock()
        let key = origin(url)
        let retryAt = max(cooldowns[key] ?? deadline, deadline)
        cooldowns[key] = retryAt
        lock.unlock()
        return .rateLimited(retryAt: retryAt)
    }

    static func retryDate(for response: HTTPURLResponse, now: Date) -> Date {
        var deadlines = [Date]()
        if let value = response.value(forHTTPHeaderField: "Retry-After") {
            if let seconds = TimeInterval(value), seconds.isFinite, seconds >= 0 {
                deadlines.append(now.addingTimeInterval(seconds))
            } else {
                let formatter = DateFormatter()
                formatter.locale = Locale(identifier: "en_US_POSIX")
                formatter.timeZone = TimeZone(secondsFromGMT: 0)
                formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss zzz"
                if let date = formatter.date(from: value) { deadlines.append(date) }
            }
        }
        // Lobsters' Rack::Attack responder sends an absolute Unix timestamp.
        if let value = response.value(forHTTPHeaderField: "RateLimit-Reset"),
           let epoch = TimeInterval(value), epoch.isFinite {
            deadlines.append(Date(timeIntervalSince1970: epoch))
        }
        return deadlines.filter { $0 > now }.max() ?? now.addingTimeInterval(60)
    }
}

enum LobstersStoredCredentialPolicy: Sendable {
    /// Attach a stored cookie only while the last verified Pro entitlement is
    /// still active. This is the production policy used by the app and widget.
    case verifiedEntitlement
    /// Intended for isolated tests that establish authentication themselves.
    case always
    case never

    var allowsStoredCredentials: Bool {
        switch self {
        case .verifiedEntitlement:
            #if DEBUG
            // The UI-test process receives its Pro bypass in memory and is
            // constrained to loopback by APIConfiguration. Do not persist that
            // bypass into the app group where it could affect a later launch.
            if ProcessInfo.processInfo.arguments.contains("--claw-ui-testing") {
                return true
            }
            #endif
            return LobstersEntitlementStore.allowsAuthenticatedRequests
        case .always:
            return true
        case .never:
            return false
        }
    }
}

final class LobstersPageLoader: @unchecked Sendable {
    static let shared = LobstersPageLoader()

    static func shouldRetryReadOnlyRequest(after error: Error) -> Bool {
        if error is CancellationError || error is LobstersPageLoaderError {
            return false
        }
        let error = error as NSError
        return error.domain != NSURLErrorDomain || error.code != NSURLErrorCancelled
    }

    private let session: URLSession
    private let credentialStore: LobstersCredentialStore
    private let storedCredentialPolicy: LobstersStoredCredentialPolicy
    private let throttle: LobstersRequestThrottle

    init(
        session: URLSession? = nil,
        credentialStore: LobstersCredentialStore = LobstersCredentialStore(),
        storedCredentialPolicy: LobstersStoredCredentialPolicy = .verifiedEntitlement,
        throttle: LobstersRequestThrottle = .shared
    ) {
        if let session {
            self.session = session
        } else {
            let configuration = URLSessionConfiguration.ephemeral
            configuration.httpCookieStorage = nil
            configuration.httpShouldSetCookies = false
            self.session = URLSession(configuration: configuration)
        }
        self.credentialStore = credentialStore
        self.storedCredentialPolicy = storedCredentialPolicy
        self.throttle = throttle
    }

    func load(_ url: URL) async throws -> LoadedLobstersPage {
        try await load(URLRequest(url: url))
    }

    func load(_ originalRequest: URLRequest) async throws -> LoadedLobstersPage {
        var request = originalRequest
        if request.value(forHTTPHeaderField: "Accept") == nil {
            request.setValue(
                "text/html,application/xhtml+xml",
                forHTTPHeaderField: "Accept"
            )
        }
        await request.setUserAgent()

        try attachStoredCookie(to: &request)

        let (data, response) = try await data(for: request)
        guard let response = response as? HTTPURLResponse else {
            throw LobstersPageLoaderError.invalidResponse
        }
        guard (200..<300).contains(response.statusCode) else {
            throw LobstersPageLoaderError.unsuccessfulStatusCode(response.statusCode)
        }

        guard let html = String(data: data, encoding: .utf8) else {
            throw LobstersPageLoaderError.cannotDecodeContent
        }
        return LoadedLobstersPage(html: html, response: response)
    }

    func data(from url: URL) async throws -> Data {
        var request = URLRequest(url: url)
        await request.setUserAgent()
        try attachStoredCookie(to: &request)
        let (data, response) = try await data(for: request)
        guard let response = response as? HTTPURLResponse else {
            throw LobstersPageLoaderError.invalidResponse
        }
        guard (200..<300).contains(response.statusCode) else {
            throw LobstersPageLoaderError.unsuccessfulStatusCode(response.statusCode)
        }
        return data
    }

    private func attachStoredCookie(to request: inout URLRequest) throws {
        guard storedCredentialPolicy.allowsStoredCredentials,
              request.value(forHTTPHeaderField: "Cookie") == nil,
              let url = request.url,
              APIConfiguration.shared.isLobstersURL(url),
              let cookie = try credentialStore.loadCookie(for: url),
              !cookie.isSecure || url.scheme == "https" else { return }
        request.setValue(cookie.requestHeaderValue, forHTTPHeaderField: "Cookie")
    }

    private func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        for attempt in 0..<3 {
            do {
                if let url = request.url { try await throttle.acquire(url) }
                let result = try await performDataTask(for: request)
                if let response = result.1 as? HTTPURLResponse,
                   let error = throttle.observe(response) {
                    throw error
                }
                return result
            } catch {
                let method = request.httpMethod?.uppercased() ?? "GET"
                guard attempt < 2,
                      method == "GET" || method == "HEAD",
                      Self.shouldRetryReadOnlyRequest(after: error) else {
                    throw error
                }
                try await Task.sleep(for: .milliseconds(100))
            }
        }
        throw LobstersPageLoaderError.invalidResponse
    }

    private func performDataTask(for request: URLRequest) async throws -> (Data, URLResponse) {
        // Avoid Foundation's async URLSession overlay so transient networking
        // process teardown arrives as a retryable request error.
        let taskBox = URLSessionTaskBox()
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                let task = session.dataTask(with: request) { data, response, error in
                    if let error {
                        continuation.resume(throwing: error)
                    } else if let data, let response {
                        continuation.resume(returning: (data, response))
                    } else {
                        continuation.resume(
                            throwing: LobstersPageLoaderError.invalidResponse
                        )
                    }
                }
                taskBox.setTask(task)
                task.resume()
            }
        } onCancel: {
            taskBox.cancel()
        }
    }
}
