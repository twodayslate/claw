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

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "The Lobsters webpage returned an invalid response."
        case .unsuccessfulStatusCode(let statusCode):
            return "The Lobsters webpage returned HTTP \(statusCode)."
        case .cannotDecodeContent:
            return "The Lobsters webpage could not be decoded."
        }
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

    init(
        session: URLSession? = nil,
        credentialStore: LobstersCredentialStore = LobstersCredentialStore(),
        storedCredentialPolicy: LobstersStoredCredentialPolicy = .verifiedEntitlement
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

        if storedCredentialPolicy.allowsStoredCredentials,
           request.value(forHTTPHeaderField: "Cookie") == nil,
           let url = request.url,
           let cookie = try credentialStore.loadCookie(for: url) {
            request.setValue(cookie.requestHeaderValue, forHTTPHeaderField: "Cookie")
        }

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
        let (data, response) = try await data(for: URLRequest(url: url))
        guard let response = response as? HTTPURLResponse else {
            throw LobstersPageLoaderError.invalidResponse
        }
        guard (200..<300).contains(response.statusCode) else {
            throw LobstersPageLoaderError.unsuccessfulStatusCode(response.statusCode)
        }
        return data
    }

    private func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        for attempt in 0..<3 {
            do {
                return try await performDataTask(for: request)
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
