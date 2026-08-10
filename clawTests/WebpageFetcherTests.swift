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

    @MainActor
    func testReloadingLiveStoryFetchersRefreshesRetainedStory() async throws {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [WebpageURLProtocol.self]
        let session = URLSession(configuration: configuration)
        let webpageFetcher = WebpageFetcher(session: session)
        let storyURL = APIConfiguration.shared.storyURL(shortId: "test01")
        var title = "Anonymous story"

        WebpageURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(
                url: request.url ?? storyURL,
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Content-Type": "text/html; charset=utf-8"]
            )!
            let html = """
            <ol class="stories">
              <li data-shortid="test01" class="story">
                <div class="voters"><a class="upvoter" title="1">1</a></div>
                <div class="details">
                  <span class="link"><a class="u-url" href="/s/test01/story">\(title)</a></span>
                  <div class="byline"><a href="/~alice">alice</a></div>
                </div>
              </li>
            </ol>
            """
            return (response, Data(html.utf8))
        }
        defer {
            WebpageURLProtocol.requestHandler = nil
            session.invalidateAndCancel()
            StoryFetcher.cachedStories.removeAll()
        }

        let fetcher = StoryFetcher("test01", webpageFetcher: webpageFetcher)
        try await fetcher.load()
        try await assertEventually(
            "Anonymous story",
            isLoadedBy: fetcher
        )

        title = "Authenticated story"
        StoryFetcher.cachedStories.removeAll()
        await StoryFetcher.reloadLiveFetchers()

        try await assertEventually(
            "Authenticated story",
            isLoadedBy: fetcher
        )
    }

    @MainActor
    func testStoryFetcherRejectsPageURLFromDifferentOrigin() async throws {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [WebpageURLProtocol.self]
        let session = URLSession(configuration: configuration)
        let webpageFetcher = WebpageFetcher(
            session: session,
            storedCredentialPolicy: .never
        )
        let configuredURL = APIConfiguration.shared.storyURL(shortId: "test01")
        var otherOrigin = URLComponents(
            url: configuredURL,
            resolvingAgainstBaseURL: false
        )!
        otherOrigin.port = (configuredURL.port ?? 80) + 1
        let untrustedPageURL = try XCTUnwrap(otherOrigin.url)
        var requestedURL: URL?

        WebpageURLProtocol.requestHandler = { request in
            requestedURL = request.url
            let response = HTTPURLResponse(
                url: request.url ?? configuredURL,
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Content-Type": "text/html; charset=utf-8"]
            )!
            let html = """
            <ol class="stories">
              <li data-shortid="test01" class="story">
                <div class="voters"><a class="upvoter" title="1">1</a></div>
                <div class="details">
                  <span class="link"><a class="u-url" href="/s/test01/story">Story</a></span>
                  <div class="byline"><a href="/~alice">alice</a></div>
                </div>
              </li>
            </ol>
            """
            return (response, Data(html.utf8))
        }
        defer {
            WebpageURLProtocol.requestHandler = nil
            session.invalidateAndCancel()
            StoryFetcher.cachedStories.removeAll()
        }

        let fetcher = StoryFetcher("test01", webpageFetcher: webpageFetcher)
        fetcher.pageURL = untrustedPageURL
        try await fetcher.load()

        XCTAssertEqual(requestedURL, configuredURL)
        XCTAssertEqual(fetcher.story?.short_id, "test01")
    }

    @MainActor
    private func assertEventually(
        _ expectedTitle: String,
        isLoadedBy fetcher: StoryFetcher
    ) async throws {
        for _ in 0..<100 {
            if fetcher.story?.title == expectedTitle {
                return
            }
            try await Task.sleep(for: .milliseconds(10))
        }
        XCTFail(
            "Expected retained story title \(expectedTitle), got \(fetcher.story?.title ?? "nil")"
        )
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
