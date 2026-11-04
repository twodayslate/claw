//
//  WebpageFetcherTests.swift
//  clawTests
//

import XCTest
@testable import claw

final class WebpageFetcherTests: XCTestCase {
    func testRateLimitRetryHeadersAndExpiry() throws {
        let url = URL(string: "http://localhost:3000/")!
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let cases: [([String: String], TimeInterval)] = [
            (["Retry-After": "12"], 12),
            (["Retry-After": "Tue, 14 Nov 2023 22:14:20 GMT"], 60),
            (["RateLimit-Reset": "1700000030"], 30),
            (["Retry-After": "5", "RateLimit-Reset": "1700000030"], 30),
            (["Retry-After": "invalid"], 60),
            (["RateLimit-Reset": "1699999999"], 60)
        ]
        for (headers, expected) in cases {
            let response = HTTPURLResponse(url: url, statusCode: 429, httpVersion: nil, headerFields: headers)!
            let throttle = LobstersRequestThrottle(minimumInterval: 0)
            XCTAssertNotNil(throttle.observe(response, now: now))
            XCTAssertThrowsError(try throttle.check(url, now: now))
            XCTAssertNoThrow(try throttle.check(url, now: now.addingTimeInterval(expected)))
            XCTAssertEqual(LobstersRequestThrottle.retryDate(for: response, now: now), now.addingTimeInterval(expected))
            XCTAssertNoThrow(try throttle.check(URL(string: "http://localhost:3001/")!, now: now))
        }
    }

    @MainActor
    func testRateLimitStopsQueuedRequestsAcrossLoaders() async throws {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [WebpageURLProtocol.self]
        let session = URLSession(configuration: configuration)
        let throttle = LobstersRequestThrottle(minimumInterval: 0.1)
        let first = LobstersPageLoader(session: session, storedCredentialPolicy: .never, throttle: throttle)
        let second = LobstersPageLoader(session: session, storedCredentialPolicy: .never, throttle: throttle)
        let url = URL(string: "http://localhost:3000/")!
        var requestCount = 0
        WebpageURLProtocol.requestHandler = { request in
            requestCount += 1
            return (HTTPURLResponse(url: request.url!, statusCode: 429, httpVersion: nil, headerFields: ["Retry-After": "60"])!, Data())
        }
        defer {
            WebpageURLProtocol.requestHandler = nil
            session.invalidateAndCancel()
        }
        let requests = [
            Task { try await first.data(from: url) },
            Task { try await second.data(from: url.appendingPathComponent("avatar")) },
            Task { Data(try await first.load(url).html.utf8) }
        ]
        for request in requests {
            do {
                _ = try await request.value
                XCTFail("Expected a rate-limit error")
            } catch LobstersPageLoaderError.rateLimited {
                // One server response must stop the rest of the queued burst.
            }
        }
        XCTAssertEqual(requestCount, 1)
    }

    @MainActor
    func testRequestPacingAndCancellation() async throws {
        let throttle = LobstersRequestThrottle(minimumInterval: 0.1)
        let url = URL(string: "http://localhost:3000/")!
        try await throttle.acquire(url)
        let cancelled = Task { try await throttle.acquire(url) }
        cancelled.cancel()
        do {
            try await cancelled.value
            XCTFail("A cancelled request must not run")
        } catch is CancellationError {}
        let start = ContinuousClock.now
        try await throttle.acquire(url)
        XCTAssertGreaterThanOrEqual(start.duration(to: .now), .milliseconds(80))
    }

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
