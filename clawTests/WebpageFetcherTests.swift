//
//  WebpageFetcherTests.swift
//  clawTests
//

import XCTest
import WebKit
@testable import claw

final class WebpageFetcherTests: XCTestCase {
    @MainActor
    func testExpiredCookiesRequireLoginOnForeground() async throws {
        let baseURL = APIConfiguration.shared.baseURL
        guard ["localhost", "127.0.0.1"].contains(baseURL.host ?? "") else {
            throw XCTSkip("Session tests only run against local Lobsters.")
        }
        let store = LobstersCredentialStore(service: "claw.tests.expiry.\(UUID())", accessGroup: nil)
        defer { try? store.deleteCookie(for: baseURL) }
        let cookie = try XCTUnwrap(HTTPCookie(properties: [
            .name: LobstersCredentialStore.cookieName, .value: "expiring-local-fixture",
            .domain: baseURL.host!, .path: "/", .expires: Date().addingTimeInterval(10)
        ]))
        try store.saveCookie(cookie, for: baseURL)
        let dataStore = WKWebsiteDataStore.nonPersistent()
        let feed = LobstersWebViewClient(dataStore: dataStore)
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [WebpageURLProtocol.self]
        let network = URLSession(configuration: config)
        defer { WebpageURLProtocol.requestHandler = nil; network.invalidateAndCancel() }
        WebpageURLProtocol.requestHandler = { request in
            (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!,
             Data("<html><body data-username='test'></body></html>".utf8))
        }
        let loader = LobstersPageLoader(session: network, credentialStore: store,
            storedCredentialPolicy: .always, throttle: LobstersRequestThrottle(minimumInterval: 0))
        let session = LobstersSession(credentialStore: store, pageLoader: loader,
            webClient: feed, storyWebClient: LobstersWebViewClient(dataStore: dataStore),
            avatarLoader: LobstersAvatarLoader(pageLoader: loader),
            // Session expiry must not refresh global feeds or fetchers owned by
            // the next test after this test's session has been released.
            contentRefresher: LobstersContentRefresher(refreshLiveContent: {}),
            coordinator: LobstersSessionCoordinator())
        session.setEntitlementAvailable(true)
        await session.start()
        XCTAssertTrue(session.isAuthenticated)
        // Exercise foreground validation after its 60-second freshness window
        // and the cookie expiry have both elapsed.
        try await Task.sleep(for: .seconds(61))
        XCTAssertNil(try store.loadCookie(for: baseURL))
        let remainingCookies = await feed.allCookies()
        XCTAssertFalse(remainingCookies.contains { cookie in
            guard let stored = StoredLobstersCookie(cookie, for: baseURL) else { return false }
            return !stored.isExpired
        })
        session.errorMessage = "An earlier temporary verification error"
        session.applicationDidBecomeActive()
        for _ in 0..<100 where session.isAuthenticated {
            try await Task.sleep(for: .milliseconds(20))
        }
        XCTAssertEqual(session.state, .signedOut, "Expired cookies must request login again")
        XCTAssertNil(session.errorMessage)
        XCTAssertNil(try store.loadCookie(for: baseURL))
    }

    @MainActor
    func testUnverifiedPagesAndErrorsKeepBrowserCookiesAndSavedLogin() async throws {
        let baseURL = APIConfiguration.shared.baseURL
        let store = LobstersCredentialStore(service: "claw.tests.preserve.\(UUID())", accessGroup: nil)
        defer { try? store.deleteCookie(for: baseURL) }
        let cookie = try XCTUnwrap(HTTPCookie(properties: [
            .name: LobstersCredentialStore.cookieName, .value: "saved-local-session",
            .domain: baseURL.host!, .path: "/", .expires: Date().addingTimeInterval(3600)
        ]))
        let preference = try XCTUnwrap(HTTPCookie(properties: [
            .name: "test_preference", .value: "keep-me", .domain: baseURL.host!, .path: "/"
        ]))
        let dataStore = WKWebsiteDataStore.nonPersistent()
        let feed = LobstersWebViewClient(dataStore: dataStore)
        let story = LobstersWebViewClient(dataStore: dataStore)
        await feed.setCookie(cookie)
        await feed.setCookie(preference)
        // Keychain may still contain an older cookie after WebKit rotates it.
        let olderCookie = try XCTUnwrap(HTTPCookie(properties: [
            .name: LobstersCredentialStore.cookieName, .value: "older-copy",
            .domain: baseURL.host!, .path: "/"
        ]))
        try store.saveCookie(olderCookie, for: baseURL)
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [WebpageURLProtocol.self]
        let network = URLSession(configuration: config)
        defer {
            WebpageURLProtocol.requestHandler = nil
            network.invalidateAndCancel()
        }
        var html = "<html><body data-username='test'></body></html>"
        var status = 200
        var networkError: Error?
        WebpageURLProtocol.requestHandler = { request in
            if request.value(forHTTPHeaderField: "Cookie") == "lobster_trap=anonymous-replacement" {
                let loginForm = "<form action='/login' method='post'><input name='email'><input name='password' type='password'></form>"
                return (HTTPURLResponse(url: APIConfiguration.shared.loginURL(), statusCode: 200,
                                        httpVersion: nil, headerFields: nil)!, Data(loginForm.utf8))
            }
            if request.url?.path == "/settings" {
                XCTAssertEqual(request.value(forHTTPHeaderField: "Cookie"), "lobster_trap=saved-local-session")
            }
            if let networkError { throw networkError }
            return (HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!, Data(html.utf8))
        }
        let loader = LobstersPageLoader(session: network, credentialStore: store,
                                       storedCredentialPolicy: .never,
                                       throttle: LobstersRequestThrottle(minimumInterval: 0))
        let session = LobstersSession(credentialStore: store, pageLoader: loader,
                                     webClient: feed, storyWebClient: story,
                                     avatarLoader: LobstersAvatarLoader(pageLoader: loader),
                                     contentRefresher: LobstersContentRefresher(refreshLiveContent: {}),
                                     coordinator: LobstersSessionCoordinator())
        session.setEntitlementAvailable(true)
        await session.start()
        XCTAssertTrue(session.isAuthenticated)
        XCTAssertEqual(try store.loadCookie(for: baseURL)?.value, cookie.value)

        let anonymousReplacement = try XCTUnwrap(HTTPCookie(properties: [
            .name: cookie.name, .value: "anonymous-replacement", .domain: baseURL.host!, .path: "/"
        ]))
        await feed.setCookie(anonymousReplacement)
        await session.start(force: true)
        XCTAssertTrue(session.isAuthenticated, "Rejecting the browser cookie must still try the valid recovery copy")
        XCTAssertEqual(try store.loadCookie(for: baseURL)?.value, cookie.value)
        let recovered = await feed.allCookies()
        XCTAssertTrue(recovered.contains { $0.name == cookie.name && $0.value == cookie.value })

        html = "<html><body>Unexpected maintenance page</body></html>"
        for code in [200, 403, 500] {
            status = code
            await session.start(force: true)
            XCTAssertTrue(session.isAuthenticated, "HTTP \(code) must not clear a confirmed login")
            XCTAssertEqual(try store.loadCookie(for: baseURL)?.value, cookie.value)
            let cookies = await feed.allCookies()
            XCTAssertTrue(cookies.contains { $0.name == cookie.name && $0.value == cookie.value })
            XCTAssertTrue(cookies.contains { $0.name == preference.name && $0.value == preference.value })
        }
        networkError = URLError(.notConnectedToInternet)
        await session.start(force: true)
        XCTAssertTrue(session.isAuthenticated)
        XCTAssertNotNil(try store.loadCookie(for: baseURL))
        networkError = nil
        status = 429
        await session.start(force: true)
        XCTAssertTrue(session.isAuthenticated)
        XCTAssertNotNil(try store.loadCookie(for: baseURL))

        session.setEntitlementAvailable(false)
        XCTAssertNotNil(try store.loadCookie(for: baseURL), "Entitlement changes are not sign-out")
        let retainedCookies = await feed.allCookies()
        XCTAssertTrue(retainedCookies.contains { $0.name == cookie.name })
    }

    @MainActor
    func testNativeHTMLAndDataRequestsReuseLoginOnlyOnConfiguredOrigin() async throws {
        let baseURL = APIConfiguration.shared.baseURL
        let store = LobstersCredentialStore(service: "claw.tests.native-cookie.\(UUID())", accessGroup: nil)
        defer { try? store.deleteCookie(for: baseURL) }
        let cookie = try XCTUnwrap(HTTPCookie(properties: [
            .name: LobstersCredentialStore.cookieName, .value: "native-cookie",
            .domain: baseURL.host!, .path: "/"
        ]))
        try store.saveCookie(cookie, for: baseURL)
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [WebpageURLProtocol.self]
        let network = URLSession(configuration: config)
        let loader = LobstersPageLoader(session: network, credentialStore: store,
                                       storedCredentialPolicy: .always,
                                       throttle: LobstersRequestThrottle(minimumInterval: 0))
        WebpageURLProtocol.requestHandler = { request in
            let expected = APIConfiguration.shared.isLobstersURL(request.url) ? "lobster_trap=native-cookie" : nil
            XCTAssertEqual(request.value(forHTTPHeaderField: "Cookie"), expected)
            return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, Data("{}".utf8))
        }
        defer {
            WebpageURLProtocol.requestHandler = nil
            network.invalidateAndCancel()
        }
        _ = try await loader.load(baseURL)
        _ = try await loader.data(from: APIConfiguration.shared.userStoriesURL(username: "test", page: 1))
        var other = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)!
        other.port = (other.port ?? 80) + 1
        _ = try await loader.data(from: try XCTUnwrap(other.url))
    }

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

extension WebpageFetcherTests {
    @MainActor
    func testFailedTagRefreshPreservesContentAndWarningAcrossViews() async throws {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [WebpageURLProtocol.self]
        let session = URLSession(configuration: config)
        let loader = LobstersPageLoader(session: session, storedCredentialPolicy: .never)
        let first = TagStoryFetcher(tags: ["shared-cache"], pageLoader: loader)
        let second = TagStoryFetcher(tags: ["shared-cache"], pageLoader: loader)
        func row(_ id: String) -> String {
            "<li class='story' data-shortid='\(id)'><h2 class='link'><a class='u-url' href='/s/\(id)'>\(id)</a></h2></li>"
        }
        var responseHTML = "<ol class='stories'>\(row("a"))</ol>"
        var paths: [String] = []
        WebpageURLProtocol.requestHandler = { request in
            let url = try XCTUnwrap(request.url)
            XCTAssertTrue(["localhost", "127.0.0.1"].contains(url.host ?? ""))
            paths.append(url.path)
            return (HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!, Data(responseHTML.utf8))
        }
        defer {
            WebpageURLProtocol.requestHandler = nil
            TagStoryFetcher.cachedStories.removeAll()
            session.invalidateAndCancel()
        }
        TagStoryFetcher.cachedStories.removeAll()
        try await first.load()
        responseHTML = "<ol class='stories'>\(row("b"))<li class='story' data-shortid='bad'>Missing title</li></ol>"
        try await first.more(first.items.last)
        XCTAssertEqual(first.items.map(\.short_id), ["a", "b"])
        XCTAssertEqual(first.skippedStoryCount, 1)
        XCTAssertEqual(first.page, 3)
        // A second view refreshes the same tag, replacing the shared cache
        // with page 1 while the first view still displays two pages.
        responseHTML = "<ol class='stories'>\(row("a"))</ol>"
        try await second.load()
        responseHTML = "<html>Temporary error</html>"
        do {
            try await first.reload()
            XCTFail("Expected the malformed refresh response to fail")
        } catch {}
        XCTAssertTrue(first.loadFailed)
        XCTAssertEqual(first.page, 3)
        XCTAssertEqual(first.items.map(\.short_id), ["a", "b"], "Failed refresh must retain this view's loaded pages")
        XCTAssertEqual(first.skippedStoryCount, 1, "Failed refresh must retain this view's warning")
        responseHTML = "<ol class='stories'>\(row("c"))</ol>"
        try await first.more(first.items.last)
        XCTAssertTrue(paths.last?.hasSuffix("/page/3") == true)
        XCTAssertEqual(first.items.map(\.short_id), ["a", "b", "c"], "Pagination must not skip the discarded page")
        XCTAssertEqual(first.skippedStoryCount, 1)
        XCTAssertFalse(first.loadFailed)

        // Only a successful refresh should replace the loaded pages and clear
        // the warning about the previously skipped row.
        responseHTML = "<ol class='stories'>\(row("fresh"))</ol>"
        try await first.reload()
        XCTAssertEqual(first.items.map(\.short_id), ["fresh"])
        XCTAssertEqual(first.skippedStoryCount, 0)
        XCTAssertEqual(first.page, 2)
    }
}
