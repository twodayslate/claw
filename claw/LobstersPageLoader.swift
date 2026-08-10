//
//  LobstersPageLoader.swift
//  claw
//

import Foundation

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

        let (data, response) = try await session.data(for: request)
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
        let (data, response) = try await session.data(from: url)
        guard let response = response as? HTTPURLResponse else {
            throw LobstersPageLoaderError.invalidResponse
        }
        guard (200..<300).contains(response.statusCode) else {
            throw LobstersPageLoaderError.unsuccessfulStatusCode(response.statusCode)
        }
        return data
    }
}
