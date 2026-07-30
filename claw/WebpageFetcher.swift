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

    private let session: URLSession
    private let cookieStorage: HTTPCookieStorage

    init(cookieStorage: HTTPCookieStorage = .shared) {
        let configuration = URLSessionConfiguration.default
        configuration.httpCookieStorage = cookieStorage
        configuration.httpShouldSetCookies = true

        self.cookieStorage = cookieStorage
        self.session = URLSession(configuration: configuration)
    }

    init(session: URLSession, cookieStorage: HTTPCookieStorage = .shared) {
        self.session = session
        self.cookieStorage = cookieStorage
    }

    func fetch(_ url: URL) async throws -> Webpage {
        try await fetch(URLRequest(url: url))
    }

    func fetch(_ originalRequest: URLRequest) async throws -> Webpage {
        var request = originalRequest
        if request.value(forHTTPHeaderField: "Accept") == nil {
            request.setValue(
                "text/html,application/xhtml+xml",
                forHTTPHeaderField: "Accept"
            )
        }
        request.setUserAgent()

        let (data, response) = try await session.data(for: request)
        guard let response = response as? HTTPURLResponse else {
            throw WebpageFetcherError.invalidResponse
        }
        guard (200..<300).contains(response.statusCode) else {
            throw WebpageFetcherError.unsuccessfulStatusCode(response.statusCode)
        }
        guard let html = String(data: data, encoding: .utf8) else {
            throw WebpageFetcherError.cannotDecodeContent
        }
        guard let responseURL = response.url ?? request.url else {
            throw WebpageFetcherError.invalidResponse
        }

        return Webpage(html: html, url: responseURL, response: response)
    }

    func cookies(for url: URL) -> [HTTPCookie] {
        cookieStorage.cookies(for: url) ?? []
    }

    /// Copies cookies captured by another web client, such as WKWebView, into
    /// the cookie store used for app requests.
    func storeCookies(_ cookies: [HTTPCookie], for url: URL) {
        guard let host = url.host?.lowercased() else {
            return
        }

        let matchingCookies = cookies.filter { cookie in
            let domain = cookie.domain
                .trimmingCharacters(in: CharacterSet(charactersIn: "."))
                .lowercased()
            return host == domain || host.hasSuffix(".\(domain)")
        }
        cookieStorage.setCookies(
            matchingCookies,
            for: url,
            mainDocumentURL: url
        )
    }

    func removeCookies(named names: Set<String>? = nil, for url: URL) {
        for cookie in cookies(for: url)
        where names == nil || names?.contains(cookie.name) == true {
            cookieStorage.deleteCookie(cookie)
        }
    }
}
