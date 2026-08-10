//
//  WebpageFetcher.swift
//  claw
//

import Foundation

struct Webpage {
    let html: String
    let url: URL
    let response: HTTPURLResponse
}

enum WebpageFetcherError: LocalizedError {
    case invalidResponse
    case unsuccessfulStatusCode(Int)
    case cannotDecodeContent

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "The server returned an invalid response."
        case .unsuccessfulStatusCode(let statusCode):
            return "The server returned HTTP \(statusCode)."
        case .cannotDecodeContent:
            return "The webpage could not be decoded."
        }
    }
}

@MainActor
final class WebpageFetcher {
    static let shared = WebpageFetcher()

    private let pageLoader: LobstersPageLoader
    private let cookieStorage: HTTPCookieStorage?
    private let credentialStore: LobstersCredentialStore
    private let storedCredentialPolicy: LobstersStoredCredentialPolicy

    init(
        cookieStorage: HTTPCookieStorage? = nil,
        storedCredentialPolicy: LobstersStoredCredentialPolicy = .verifiedEntitlement
    ) {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.httpCookieStorage = cookieStorage
        configuration.httpShouldSetCookies = cookieStorage != nil

        self.cookieStorage = cookieStorage
        let credentialStore = LobstersCredentialStore()
        self.credentialStore = credentialStore
        self.storedCredentialPolicy = storedCredentialPolicy
        self.pageLoader = LobstersPageLoader(
            session: URLSession(configuration: configuration),
            credentialStore: credentialStore,
            storedCredentialPolicy: storedCredentialPolicy
        )
    }

    init(
        session: URLSession,
        cookieStorage: HTTPCookieStorage? = nil,
        storedCredentialPolicy: LobstersStoredCredentialPolicy = .verifiedEntitlement
    ) {
        self.cookieStorage = cookieStorage
        let credentialStore = LobstersCredentialStore()
        self.credentialStore = credentialStore
        self.storedCredentialPolicy = storedCredentialPolicy
        self.pageLoader = LobstersPageLoader(
            session: session,
            credentialStore: credentialStore,
            storedCredentialPolicy: storedCredentialPolicy
        )
    }

    func fetch(_ url: URL) async throws -> Webpage {
        try await fetch(URLRequest(url: url))
    }

    func fetch(_ originalRequest: URLRequest) async throws -> Webpage {
        let page = try await pageLoader.load(originalRequest)
        guard let responseURL = page.response.url ?? originalRequest.url else {
            throw WebpageFetcherError.invalidResponse
        }

        return Webpage(html: page.html, url: responseURL, response: page.response)
    }

    func cookies(for url: URL) throws -> [HTTPCookie] {
        if let cookieStorage {
            return cookieStorage.cookies(for: url) ?? []
        }
        guard storedCredentialPolicy.allowsStoredCredentials,
              let storedCookie = try credentialStore.loadCookie(for: url),
              let cookie = storedCookie.makeCookie() else {
            return []
        }
        return [cookie]
    }
}
