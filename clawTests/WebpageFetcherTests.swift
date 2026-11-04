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

extension WebpageFetcherTests {
    @MainActor
    func testFeedPartialResultsPaginationAndRecovery() async throws {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [WebpageURLProtocol.self]
        let session = URLSession(configuration: config)
        let loader = LobstersPageLoader(session: session, storedCredentialPolicy: .never)
        let fetchers: [GenericArrayFetcher<NewestStory>] = [
            HottestFetcher(pageLoader: loader), NewestFetcher(pageLoader: loader),
            TagStoryFetcher(tags: ["resilience"], pageLoader: loader)
        ]
        defer {
            WebpageURLProtocol.requestHandler = nil
            session.invalidateAndCancel()
            TagStoryFetcher.cachedStories.removeAll()
        }
        for fetcher in fetchers {
            var responseHTML = """
            <ol class='stories'>
              <li class='story' data-shortid='good'><h2 class='link'><a class='u-url' href='/s/good'>Good</a></h2></li>
              <li class='story' data-shortid='broken'>Changed title markup</li>
            </ol>
            """
            var requestedPaths: [String] = []
            WebpageURLProtocol.requestHandler = { request in
                let url = try XCTUnwrap(request.url)
                XCTAssertTrue(["localhost", "127.0.0.1"].contains(url.host ?? ""))
                requestedPaths.append(url.path)
                return (HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: ["Content-Type": "text/html"])!, Data(responseHTML.utf8))
            }
            try await fetcher.load()
            XCTAssertEqual(fetcher.items.map(\.short_id), ["good"])
            XCTAssertEqual(fetcher.skippedStoryCount, 1)
            XCTAssertEqual(fetcher.page, 2)
            responseHTML = "<html><h1>Temporary server error</h1></html>"
            do {
                try await fetcher.load()
                XCTFail("An unexpected page must fail, even with HTTP 200")
            } catch {}
            XCTAssertTrue(fetcher.loadFailed)
            XCTAssertEqual(fetcher.items.map(\.short_id), ["good"])
            XCTAssertEqual(fetcher.skippedStoryCount, 1)
            XCTAssertEqual(fetcher.page, 2, "A failed refresh must preserve the pagination cursor")
            responseHTML = "<ol class='stories'><li class='story' data-shortid='next'><h2 class='link'><a class='u-url' href='/s/next'>Next</a></h2></li></ol>"
            try await fetcher.more(fetcher.items.last)
            XCTAssertTrue(requestedPaths.last?.hasSuffix("/page/2") == true)
            XCTAssertEqual(fetcher.items.map(\.short_id), ["good", "next"])
            XCTAssertEqual(fetcher.skippedStoryCount, 1, "A successful next page must retain the earlier warning")
            XCTAssertFalse(fetcher.loadFailed)
            try await fetcher.load()
            XCTAssertEqual(fetcher.items.map(\.short_id), ["next"])
            XCTAssertEqual(fetcher.skippedStoryCount, 0)
            fetcher.invalidateContent()
            XCTAssertTrue(fetcher.items.isEmpty)
            XCTAssertFalse(fetcher.loadFailed)
            XCTAssertEqual(fetcher.skippedStoryCount, 0)
        }
    }

    @MainActor
    func testStoryFetcherPublishesReadableStoryWhenCommentsBreakAndRecovers() async throws {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [WebpageURLProtocol.self]
        let session = URLSession(configuration: config)
        let fetcher = StoryFetcher("test01", webpageFetcher: WebpageFetcher(session: session, storedCredentialPolicy: .never))
        var comments = "<ol class='comments'><li>Unrecognized comments</li></ol>"
        var responseOverride: String?
        WebpageURLProtocol.requestHandler = { request in
            let url = try XCTUnwrap(request.url)
            let html = responseOverride ?? ("<ol class='stories'><li class='story' data-shortid='test01'><h2 class='link'><a class='u-url' href='/s/test01'>Readable story</a></h2></li></ol>" + comments)
            return (HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!, Data(html.utf8))
        }
        defer {
            WebpageURLProtocol.requestHandler = nil
            session.invalidateAndCancel()
            StoryFetcher.cachedStories.removeAll()
        }
        try await fetcher.load()
        XCTAssertEqual(fetcher.story?.title, "Readable story")
        XCTAssertEqual(fetcher.story?.comments_unavailable, true)
        XCTAssertEqual(StoryFetcher.cachedStories.first?.comments_unavailable, true)
        comments = "<ol class='comments'></ol>"
        try await fetcher.reload()
        XCTAssertEqual(fetcher.story?.comments_unavailable, false)
        XCTAssertEqual(fetcher.story?.comment_count, 0)
        responseOverride = "<html><form action='/login'>Sign in</form></html>"
        do {
            try await fetcher.reload()
            XCTFail("An HTTP 200 login page is not a story")
        } catch {}
        XCTAssertTrue(fetcher.loadFailed)
        XCTAssertEqual(fetcher.story?.title, "Readable story")
        responseOverride = nil
        try await fetcher.reload()
        XCTAssertFalse(fetcher.loadFailed)
    }
}
