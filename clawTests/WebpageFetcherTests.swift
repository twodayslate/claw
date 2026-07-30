//
//  WebpageFetcherTests.swift
//  clawTests
//

import XCTest
@testable import claw

final class WebpageFetcherTests: XCTestCase {
    @MainActor
    func testFetchBuildsHTMLRequest() async throws {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [WebpageURLProtocol.self]
        let session = URLSession(configuration: configuration)
        let fetcher = WebpageFetcher(session: session)
        let url = URL(string: "https://lobste.rs/s/test/a_story")!

        WebpageURLProtocol.requestHandler = { request in
            XCTAssertEqual(
                request.value(forHTTPHeaderField: "Accept"),
                "text/html,application/xhtml+xml"
            )
            XCTAssertFalse(
                try XCTUnwrap(request.value(forHTTPHeaderField: "User-Agent")).isEmpty
            )

            let response = HTTPURLResponse(
                url: url,
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Content-Type": "text/html; charset=utf-8"]
            )!
            return (response, Data("<html><body>Claw</body></html>".utf8))
        }
        defer {
            WebpageURLProtocol.requestHandler = nil
            session.invalidateAndCancel()
        }

        let webpage = try await fetcher.fetch(url)

        XCTAssertEqual(webpage.url, url)
        XCTAssertEqual(webpage.html, "<html><body>Claw</body></html>")
        XCTAssertEqual(webpage.response.statusCode, 200)
    }
}

private final class WebpageURLProtocol: URLProtocol {
    static var requestHandler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let requestHandler = Self.requestHandler else {
            client?.urlProtocol(
                self,
                didFailWithError: URLError(.resourceUnavailable)
            )
            return
        }

        do {
            let (response, data) = try requestHandler(request)
            client?.urlProtocol(
                self,
                didReceive: response,
                cacheStoragePolicy: .notAllowed
            )
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}
