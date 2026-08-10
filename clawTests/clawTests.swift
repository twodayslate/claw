//
//  clawTests.swift
//  clawTests
//
//  Created by Zachary Gorak on 9/11/20.
//

import XCTest
import WebKit
import SwiftSoup
import Security
@testable import claw

class clawTests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testExample() throws {
        let scheme = CommentColorScheme.custom(.blue, .link, .black, .black, .black.withAlphaComponent(0.7), .black, .red)
        let data = try JSONEncoder().encode(scheme)
        let converted = try JSONDecoder().decode(CommentColorScheme.self, from: data)
        XCTAssertEqual(scheme, converted)
    }

    func testTabBarMinimizePreferences() {
        XCTAssertEqual(
            TabBarMinimizePreference.allCases,
            [.automatic, .never, .onScroll]
        )
        XCTAssertEqual(TabBarMinimizePreference.automatic.title, "Automatic")
        XCTAssertEqual(TabBarMinimizePreference.never.title, "Never")
        XCTAssertEqual(TabBarMinimizePreference.onScroll.title, "On Scroll")
        XCTAssertEqual(TabBarMinimizePreference.automatic.behavior, .automatic)
        XCTAssertEqual(TabBarMinimizePreference.never.behavior, .never)
        XCTAssertEqual(TabBarMinimizePreference.onScroll.behavior, .onScrollDown)
    }

    func testStoryHTMLParserParsesNestedComments() throws {
        let html = """
        <html>
          <body>
            <ol class="stories">
              <li id="story_abc123" data-shortid="abc123" class="story upvoted">
                <div class="story_liner h-entry">
                  <div class="voters"><a class="upvoter" title="42">42</a></div>
                  <div class="details">
                    <span class="link"><a class="u-url" href="https://example.com/article">An article</a></span>
                    <ul class="tags"><li><a>swift</a></li><li><a>ios</a></li></ul>
                    <div class="byline">
                      <span>authored by</span>
                      <a href="/~alice">alice</a>
                      <time datetime="2026-07-29T12:00:00Z" data-at-unix="1785326400"></time>
                    </div>
                  </div>
                </div>
              </li>
            </ol>
            <div class="story_content"><div class="story_text"><p>Story body</p></div></div>
            <div class="comment_form_container">
              <form><input name="story_id" value="abc123"></form>
            </div>
            <ol class="comments">
              <li class="comments_subtree">
                <div id="c_parent1" data-shortid="parent1" class="comment upvoted">
                  <div class="voters"><button class="upvoter" title="8">8</button></div>
                  <div class="details">
                    <div class="byline">
                      <a aria-hidden="true" href="/~bob"></a><a href="/~bob">bob</a>
                      <a href="/c/parent1"><time data-at-unix="1785326460"></time></a>
                      <a class="comment_editor">edit</a>
                      <a class="comment_deletor">delete</a>
                      <a class="comment_replier">reply</a>
                    </div>
                    <div class="comment_text"><p>Parent <strong>comment</strong></p></div>
                  </div>
                </div>
                <ol class="comments">
                  <li class="comments_subtree">
                    <div id="c_child1" data-shortid="child1" class="comment flagged">
                      <div class="voters"><button class="upvoter" title="3">3</button></div>
                      <div class="details">
                        <div class="byline">
                          <a href="/~carol">carol</a>
                          <a href="/c/child1"><time data-at-unix="1785326520"></time></a>
                          <a class="comment_replier">reply</a>
                        </div>
                        <div class="comment_text"><p>Child comment</p></div>
                      </div>
                    </div>
                  </li>
                </ol>
              </li>
              <li class="comments_subtree">
                <div id="c_deleted1" data-shortid="deleted1" class="comment">
                  <div class="details">
                    <div class="byline"><a href="/~dave">dave</a><a href="/c/deleted1"><time data-at-unix="1785326580"></time></a></div>
                    <div class="comment_text"><span class="na">[deleted by moderator]</span></div>
                  </div>
                </div>
              </li>
            </ol>
          </body>
        </html>
        """

        let story = try StoryHTMLParser.parse(
            html,
            pageURL: URL(string: "https://lobste.rs/s/abc123/an_article?source=test#comments")!
        )

        XCTAssertEqual(story.short_id, "abc123")
        XCTAssertEqual(story.title, "An article")
        XCTAssertEqual(story.url, "https://example.com/article")
        XCTAssertEqual(story.score, 42)
        XCTAssertEqual(story.comment_count, 3)
        XCTAssertEqual(story.comments_url, "https://lobste.rs/s/abc123/an_article")
        XCTAssertEqual(story.submitter_user, "alice")
        XCTAssertTrue(story.user_is_author)
        XCTAssertTrue(story.user_upvoted)
        XCTAssertTrue(story.can_comment)
        XCTAssertEqual(story.tags, ["swift", "ios"])
        XCTAssertEqual(story.description, "<p>Story body</p>")

        let parent = try XCTUnwrap(story.comments.first { $0.short_id == "parent1" })
        XCTAssertNil(parent.parent_comment)
        XCTAssertEqual(parent.commenting_user, "bob")
        XCTAssertEqual(parent.score, 8)
        XCTAssertEqual(parent.user_upvoted, true)
        XCTAssertEqual(parent.can_edit, true)
        XCTAssertEqual(parent.can_delete, true)
        XCTAssertEqual(parent.can_reply, true)
        XCTAssertEqual(parent.can_vote, true)
        XCTAssertTrue(parent.comment.contains("<strong>comment</strong>"))

        let child = try XCTUnwrap(story.comments.first { $0.short_id == "child1" })
        XCTAssertEqual(child.parent_comment, "parent1")
        XCTAssertEqual(child.flags, 1)
        XCTAssertEqual(child.can_reply, false)
        XCTAssertEqual(child.can_vote, true)

        let deleted = try XCTUnwrap(story.comments.first { $0.short_id == "deleted1" })
        XCTAssertTrue(deleted.is_deleted)
        XCTAssertTrue(deleted.is_moderated)
        XCTAssertEqual(deleted.can_vote, false)
    }

    func testStoryHTMLParserRecognizesSelfPost() throws {
        let html = """
        <ol class="stories">
          <li data-shortid="self01" class="story">
            <div class="voters"><a class="upvoter" title="1">1</a></div>
            <div class="details">
              <span class="link"><a class="u-url" href="/s/self01/a_self_post">A self post</a></span>
              <div class="byline"><span>via</span><a href="/~alice">alice</a><time data-at-unix="1785326400"></time></div>
            </div>
          </li>
        </ol>
        """

        let story = try StoryHTMLParser.parse(
            html,
            pageURL: URL(string: "https://lobste.rs/s/self01/a_self_post")!
        )

        XCTAssertEqual(story.url, "")
        XCTAssertFalse(story.user_is_author)
        XCTAssertFalse(story.user_upvoted)
        XCTAssertFalse(story.can_comment)
        XCTAssertEqual(story.comment_count, 0)
    }

    func testStoryListHTMLParserParsesRenderedWebpage() throws {
        let html = """
        <html>
          <body data-username="alice">
            <ol class="stories list">
              <li id="story_abc123" data-shortid="abc123" class="story upvoted">
                <div class="story_liner">
                  <div class="voters"><a class="upvoter" title="42">42</a></div>
                  <div class="details">
                    <span class="link"><a class="u-url" href="https://example.com/article">An article</a></span>
                    <ul class="tags"><li><a>swift</a></li><li><a>ios</a></li></ul>
                    <details class="story_content"><summary>Preview text</summary></details>
                    <div class="byline">
                      <span>authored by</span>
                      <a tabindex="-1" aria-hidden="true" href="/~alice"><img class="avatar" alt=""></a>
                      <a class="u-author" href="/~alice">alice</a>
                      <time data-at-unix="1785326400"></time>
                      <span class="comments_label"><a href="/s/abc123/an_article">12 comments</a></span>
                    </div>
                  </div>
                </div>
              </li>
            </ol>
          </body>
        </html>
        """

        let stories = try StoryListHTMLParser.parse(
            html,
            pageURL: URL(string: "https://lobste.rs/")!
        )
        let story = try XCTUnwrap(stories.first)

        XCTAssertEqual(story.short_id, "abc123")
        XCTAssertEqual(story.title, "An article")
        XCTAssertEqual(story.url, "https://example.com/article")
        XCTAssertEqual(story.score, 42)
        XCTAssertEqual(story.comment_count, 12)
        XCTAssertEqual(story.submitter_user, "alice")
        XCTAssertTrue(story.user_is_author)
        XCTAssertEqual(story.tags, ["swift", "ios"])
        XCTAssertEqual(story.description, "Preview text")
    }

    func testStoryListHTMLParserAllowsEmptyFeed() throws {
        let stories = try StoryListHTMLParser.parse(
            "<html><body><ol class='stories list'></ol></body></html>",
            pageURL: URL(string: "http://localhost:3000/")!
        )
        XCTAssertTrue(stories.isEmpty)
    }

    func testStoryListHTMLParserRejectsUnknownNonemptyMarkup() throws {
        let html = """
        <ol class="stories">
          <li class="story" data-shortid="changed"><a class="new-title">Changed</a></li>
        </ol>
        """

        XCTAssertThrowsError(
            try StoryListHTMLParser.parse(
                html,
                pageURL: URL(string: "http://localhost:3000/")!
            )
        ) { error in
            XCTAssertEqual(error as? StoryListHTMLParserError, .incompatibleStoryMarkup)
        }
    }

    func testStoryListHTMLParserRejectsPartiallyIncompatibleMarkup() throws {
        let html = """
        <ol class="stories">
          <li class="story" data-shortid="valid">
            <div class="voters"><a class="upvoter" title="1">1</a></div>
            <span class="link"><a class="u-url" href="/s/valid/story">Story</a></span>
            <div class="byline"><a href="/~alice">alice</a></div>
          </li>
          <li class="story" data-shortid="changed"><a class="new-title">Changed</a></li>
        </ol>
        """

        XCTAssertThrowsError(
            try StoryListHTMLParser.parse(
                html,
                pageURL: URL(string: "http://localhost:3000/")!
            )
        ) { error in
            XCTAssertEqual(error as? StoryListHTMLParserError, .incompatibleStoryMarkup)
        }
    }

    func testStoryListHTMLParserRejectsStoryMissingShortID() throws {
        let html = """
        <ol class="stories">
          <li class="story" data-shortid="valid">
            <div class="voters"><a class="upvoter" title="1">1</a></div>
            <span class="link"><a class="u-url" href="/s/valid/story">Story</a></span>
            <div class="byline"><a href="/~alice">alice</a></div>
          </li>
          <li class="story">
            <div class="voters"><a class="upvoter" title="2">2</a></div>
            <span class="link"><a class="u-url" href="/s/changed/story">Changed story</a></span>
            <div class="byline"><a href="/~bob">bob</a></div>
          </li>
        </ol>
        """

        XCTAssertThrowsError(
            try StoryListHTMLParser.parse(
                html,
                pageURL: URL(string: "http://localhost:3000/")!
            )
        ) { error in
            XCTAssertEqual(error as? StoryListHTMLParserError, .incompatibleStoryMarkup)
        }
    }

    func testStoryListHTMLParserRejectsStoryMissingDestination() throws {
        let html = """
        <ol class="stories">
          <li class="story" data-shortid="missing-href">
            <div class="voters"><a class="upvoter" title="1">1</a></div>
            <span class="link"><a class="u-url">Story</a></span>
            <div class="byline"><a href="/~alice">alice</a></div>
          </li>
        </ol>
        """

        XCTAssertThrowsError(
            try StoryListHTMLParser.parse(
                html,
                pageURL: URL(string: "http://localhost:3000/")!
            )
        ) { error in
            XCTAssertEqual(
                error as? StoryListHTMLParserError,
                .incompatibleStoryMarkup
            )
        }
    }

    func testLobstersHTMLParserReadsAuthenticatedIdentityAndAvatar() throws {
        let html = """
        <html><body data-username="alice">
          <div id="gravatar"><img class="avatar" src="/avatars/alice-100.png"></div>
        </body></html>
        """
        let pageURL = URL(string: "https://lobste.rs/~alice")!

        XCTAssertEqual(try LobstersHTMLParser.username(from: html), "alice")
        XCTAssertEqual(
            try LobstersHTMLParser.avatarURL(from: html, pageURL: pageURL),
            URL(string: "https://lobste.rs/avatars/alice-100.png")
        )
        XCTAssertNil(try LobstersHTMLParser.username(from: "<body data-username=''></body>"))
    }

    func testStoredLobstersCookieRequiresExactHostAndRoundTrips() throws {
        let url = URL(string: "https://lobste.rs/")!
        let cookie = try XCTUnwrap(HTTPCookie(properties: [
            .name: LobstersCredentialStore.cookieName,
            .value: "encrypted-session",
            .domain: "lobste.rs",
            .path: "/",
            .secure: "TRUE",
            .expires: Date().addingTimeInterval(3600)
        ]))

        let stored = try XCTUnwrap(StoredLobstersCookie(cookie, for: url))
        XCTAssertEqual(stored.requestHeaderValue, "lobster_trap=encrypted-session")
        XCTAssertFalse(stored.isExpired)
        XCTAssertEqual(stored.makeCookie()?.value, cookie.value)

        let wrongHost = URL(string: "https://example.com/")!
        XCTAssertNil(StoredLobstersCookie(cookie, for: wrongHost))
    }

    func testCredentialStorePersistsAndDeletesCookie() throws {
        let service = "com.twodayslate.claw.tests.\(UUID().uuidString)"
        let store = LobstersCredentialStore(service: service, accessGroup: nil)
        let url = URL(string: "http://localhost:3000/")!
        let cookie = try XCTUnwrap(HTTPCookie(properties: [
            .name: LobstersCredentialStore.cookieName,
            .value: "local-test-session",
            .domain: "localhost",
            .path: "/",
            .expires: Date().addingTimeInterval(3600)
        ]))
        defer { try? store.deleteCookie(for: url) }

        try store.saveCookie(cookie, for: url)
        XCTAssertEqual(try store.loadCookie(for: url)?.value, "local-test-session")
        try store.deleteCookie(for: url)
        XCTAssertNil(try store.loadCookie(for: url))
    }

    func testCredentialStoreDeletesUnreadableCookie() throws {
        let service = "com.twodayslate.claw.tests.\(UUID().uuidString)"
        let store = LobstersCredentialStore(service: service, accessGroup: nil)
        let url = URL(string: "http://localhost:3000/")!
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: "localhost:3000",
            kSecValueData as String: Data("not-json".utf8),
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]
        defer { try? store.deleteCookie(for: url) }

        XCTAssertEqual(SecItemAdd(query as CFDictionary, nil), errSecSuccess)
        XCTAssertNil(try store.loadCookie(for: url))
        XCTAssertNil(try store.loadCookie(for: url))
    }

    func testConfiguredLobstersOriginIncludesSchemeAndPort() {
        let configuration = APIConfiguration.shared
        XCTAssertTrue(configuration.isLobstersURL(configuration.baseURL))
        XCTAssertFalse(configuration.isLobstersURL(URL(string: "https://localhost:3000/")))
        var otherOrigin = URLComponents(
            url: configuration.baseURL,
            resolvingAgainstBaseURL: false
        )!
        otherOrigin.port = (configuration.baseURL.port ?? 80) + 1
        XCTAssertFalse(configuration.isLobstersURL(otherOrigin.url))
        XCTAssertFalse(configuration.isLobstersURL(URL(string: "http://example.com:3000/")))
    }

    @MainActor
    func testRetainedWebViewNavigationDeduplication() throws {
        let loginURL = try XCTUnwrap(URL(string: "http://localhost:3000/login"))
        let redirectedURL = try XCTUnwrap(URL(string: "http://localhost:3000/"))

        XCTAssertFalse(
            LobstersWebViewClient.shouldNavigate(
                to: loginURL,
                targetURL: loginURL,
                currentURL: loginURL,
                isLoading: false
            )
        )
        XCTAssertFalse(
            LobstersWebViewClient.shouldNavigate(
                to: loginURL,
                targetURL: loginURL,
                currentURL: redirectedURL,
                isLoading: true
            )
        )
        XCTAssertTrue(
            LobstersWebViewClient.shouldNavigate(
                to: loginURL,
                targetURL: loginURL,
                currentURL: redirectedURL,
                isLoading: false
            )
        )

        XCTAssertTrue(
            LobstersWebViewClient.hasLoadedPage(
                targetURL: loginURL,
                currentURL: loginURL,
                isLoading: false
            )
        )
        XCTAssertFalse(
            LobstersWebViewClient.hasLoadedPage(
                targetURL: nil,
                currentURL: loginURL,
                isLoading: false
            )
        )
        XCTAssertFalse(
            LobstersWebViewClient.hasLoadedPage(
                targetURL: loginURL,
                currentURL: loginURL,
                isLoading: true
            )
        )
    }

    @MainActor
    func testRetainedWebViewIgnoresSupersededNavigationErrors() {
        XCTAssertFalse(
            LobstersWebViewClient.shouldReportNavigationError(
                URLError(.cancelled)
            )
        )
        XCTAssertTrue(
            LobstersWebViewClient.shouldReportNavigationError(
                URLError(.timedOut)
            )
        )
    }

    @MainActor
    func testFeedAndStoryClientsUseDistinctLazyWebViewsWithSharedCookies() {
        let feedClient = LobstersWebViewClient()
        let storyClient = LobstersWebViewClient(
            reloadsAfterWebContentProcessTermination: false
        )

        XCTAssertFalse(feedClient.hasCreatedWebView)
        XCTAssertFalse(storyClient.hasCreatedWebView)

        feedClient.setBackgrounded(true)
        storyClient.reloadIfNeeded()

        XCTAssertFalse(feedClient.hasCreatedWebView)
        XCTAssertFalse(storyClient.hasCreatedWebView)

        let feedWebView = feedClient.webView
        let storyWebView = storyClient.webView

        XCTAssertFalse(feedWebView === storyWebView)
        XCTAssertTrue(
            feedWebView.configuration.websiteDataStore
                === storyWebView.configuration.websiteDataStore
        )
    }

    @MainActor
    func testSupersedingLoadsInvalidatePriorGeneration() {
        let fetcher = GenericArrayFetcher<Int>()
        let priorGeneration = fetcher.captureContentGeneration()
        fetcher.isLoading = true
        fetcher.isLoadingMore = true

        fetcher.supersedePendingLoads()

        XCTAssertFalse(fetcher.isCurrentContentGeneration(priorGeneration))
        XCTAssertFalse(fetcher.isLoading)
        XCTAssertFalse(fetcher.isLoadingMore)
    }

    @MainActor
    func testCancelledLoginCannotCaptureACompletedNavigation() {
        XCTAssertTrue(
            LobstersSession.shouldCaptureSession(
                state: .signingIn,
                coordinatedAuthenticationUsername: nil
            )
        )
        XCTAssertFalse(
            LobstersSession.shouldCaptureSession(
                state: .signedOut,
                coordinatedAuthenticationUsername: nil
            )
        )
    }

    func testStoredCredentialsRequireAnActiveEntitlement() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)

        XCTAssertFalse(
            LobstersEntitlementSnapshot(
                isEntitled: false,
                validUntil: nil
            ).allowsAuthenticatedRequests(at: now)
        )
        XCTAssertFalse(
            LobstersEntitlementSnapshot(
                isEntitled: true,
                validUntil: now.addingTimeInterval(-1)
            ).allowsAuthenticatedRequests(at: now)
        )
        XCTAssertTrue(
            LobstersEntitlementSnapshot(
                isEntitled: true,
                validUntil: now.addingTimeInterval(1)
            ).allowsAuthenticatedRequests(at: now)
        )
        XCTAssertTrue(
            LobstersEntitlementSnapshot(
                isEntitled: true,
                validUntil: nil
            ).allowsAuthenticatedRequests(at: now)
        )
    }

    func testLocalLobstersMainHTMLMatchesCurrentParsers() async throws {
        let baseURL = APIConfiguration.shared.baseURL
        guard baseURL.host == "localhost" || baseURL.host == "127.0.0.1" else {
            throw XCTSkip("Integration tests only run against the configured local Lobsters server.")
        }

        let store = LobstersCredentialStore(
            service: "com.twodayslate.claw.tests.local-public",
            accessGroup: nil
        )
        let sessionConfiguration = URLSessionConfiguration.ephemeral
        // A cold Simulator can take several seconds to launch its networking
        // process on CI even after the host-side readiness check succeeds.
        sessionConfiguration.timeoutIntervalForRequest = 15
        let loader = LobstersPageLoader(
            session: URLSession(configuration: sessionConfiguration),
            credentialStore: store
        )
        let page: LoadedLobstersPage
        do {
            page = try await loader.load(baseURL)
        } catch let error as URLError where error.code == .cannotConnectToHost {
            throw XCTSkip("The disposable local Lobsters server is not running.")
        }
        let stories = try await StoryListHTMLParser.parseOffMain(
            page.html,
            pageURL: page.response.url ?? baseURL
        )

        if let first = stories.first {
            let detailURL = APIConfiguration.shared.storyURL(shortId: first.short_id)
            let detail = try await loader.load(detailURL)
            let story = try await StoryHTMLParser.parseOffMain(
                detail.html,
                pageURL: detail.response.url ?? detailURL
            )
            XCTAssertEqual(story.short_id, first.short_id)
        }
    }

    @MainActor
    func testLocalWebViewClearsCancelledLoginForm() async throws {
        let configuration = APIConfiguration.shared
        guard configuration.baseURL.host == "localhost"
                || configuration.baseURL.host == "127.0.0.1" else {
            throw XCTSkip("WebView integration tests only run against local Lobsters.")
        }

        let client = LobstersWebViewClient(dataStore: .nonPersistent())
        do {
            _ = try await client.load(configuration.loginURL())
        } catch let error as URLError where error.code == .cannotConnectToHost {
            throw XCTSkip("The disposable local Lobsters server is not running.")
        }
        _ = try await client.callAsyncJavaScript(
            """
            const email = document.getElementById('email');
            const password = document.getElementById('password');
            if (!email || !password) return false;
            email.value = 'cancelled-user';
            password.value = 'cancelled-password';
            return true;
            """
        )

        await client.clearSensitivePageContents()

        let fieldCount = try await client.webView.evaluateJavaScript(
            "document.querySelectorAll('input, textarea').length"
        ) as? Int
        XCTAssertEqual(fieldCount, 0)

        try client.reset(to: configuration.loginURL())
        _ = try await client.load(configuration.loginURL())
        let restoredPassword = try await client.evaluateJavaScript(
            "document.getElementById('password')?.value || ''"
        ) as? String
        XCTAssertEqual(restoredPassword, "")
    }

    @MainActor
    func testLocalWebViewJavaScriptTimeoutDoesNotHang() async throws {
        let configuration = APIConfiguration.shared
        guard configuration.baseURL.host == "localhost"
                || configuration.baseURL.host == "127.0.0.1" else {
            throw XCTSkip("WebView integration tests only run against local Lobsters.")
        }

        let client = LobstersWebViewClient(dataStore: .nonPersistent())
        do {
            _ = try await client.load(configuration.loginURL())
        } catch let error as URLError where error.code == .cannotConnectToHost {
            throw XCTSkip("The disposable local Lobsters server is not running.")
        }

        do {
            _ = try await client.callAsyncJavaScript(
                "await new Promise(() => {})",
                timeout: .milliseconds(100)
            )
            XCTFail("Expected JavaScript execution to time out.")
        } catch LobstersWebViewClient.ClientError.javaScriptTimedOut {
            // Expected: this must complete even when page JavaScript cannot.
        }
    }

    @MainActor
    func testLocalSessionReloadsRetainedAnonymousStoryAfterLogin() async throws {
        let configuration = APIConfiguration.shared
        let baseURL = configuration.baseURL
        guard baseURL.host == "localhost" || baseURL.host == "127.0.0.1" else {
            throw XCTSkip("Authenticated integration tests only run against local Lobsters.")
        }

        let credentialStore = LobstersCredentialStore(
            service: "com.twodayslate.claw.tests.login-story-reload.\(UUID().uuidString)",
            accessGroup: nil
        )
        defer { try? credentialStore.deleteCookie(for: baseURL) }

        let dataStore = WKWebsiteDataStore.nonPersistent()
        let feedClient = LobstersWebViewClient(dataStore: dataStore)
        let storyClient = LobstersWebViewClient(
            dataStore: dataStore,
            reloadsAfterWebContentProcessTermination: false
        )
        let sessionConfiguration = URLSessionConfiguration.ephemeral
        sessionConfiguration.httpCookieStorage = nil
        sessionConfiguration.httpShouldSetCookies = false
        let pageLoader = LobstersPageLoader(
            session: URLSession(configuration: sessionConfiguration),
            credentialStore: credentialStore,
            storedCredentialPolicy: .always
        )
        let session = LobstersSession(
            credentialStore: credentialStore,
            pageLoader: pageLoader,
            webClient: feedClient,
            storyWebClient: storyClient,
            coordinator: LobstersSessionCoordinator()
        )
        session.setEntitlementAvailable(true)
        await session.start()
        XCTAssertFalse(session.isAuthenticated)

        do {
            _ = try await storyClient.load(configuration.hottestWebpageURL())
        } catch let error as URLError where error.code == .cannotConnectToHost {
            throw XCTSkip("The disposable local Lobsters server is not running.")
        }
        let loadedShortID = try await storyClient.evaluateJavaScript(
            "document.querySelector('li.story[data-shortid]')?.dataset.shortid || ''"
        ) as? String
        let shortID = try XCTUnwrap(loadedShortID)
        guard !shortID.isEmpty else {
            throw XCTSkip("The disposable local Lobsters server has no stories.")
        }

        let storyURL = configuration.storyURL(shortId: shortID)
        _ = try await storyClient.load(storyURL)
        let anonymousUsername = try await storyClient.evaluateJavaScript(
            "document.body?.dataset?.username || ''"
        ) as? String
        XCTAssertEqual(anonymousUsername, "")
        let anonymousNavigationCount = storyClient.completedNavigationCount

        session.beginLogin()
        _ = try await feedClient.load(configuration.loginURL())
        let submitted = try await feedClient.callAsyncJavaScriptWaitingForNavigation(
            """
            const email = document.getElementById('email');
            const password = document.getElementById('password');
            const form = email?.form;
            if (!email || !password || !form) return false;
            email.value = username;
            password.value = passphrase;
            setTimeout(() => form.requestSubmit(), 0);
            return true;
            """,
            arguments: ["username": "test", "passphrase": "test"]
        )
        XCTAssertEqual(submitted as? Bool, true)

        for _ in 0..<200 {
            if session.isAuthenticated,
               storyClient.completedNavigationCount > anonymousNavigationCount {
                break
            }
            try await Task.sleep(for: .milliseconds(50))
        }

        XCTAssertTrue(session.isAuthenticated)
        XCTAssertGreaterThan(
            storyClient.completedNavigationCount,
            anonymousNavigationCount
        )
        let authenticatedUsername = try await storyClient.evaluateJavaScript(
            "document.body?.dataset?.username || ''"
        ) as? String
        XCTAssertEqual(authenticatedUsername, "test")

        await session.signOut()
    }

    @MainActor
    func testLocalAuthenticatedWebpageActionsRoundTrip() async throws {
        let configuration = APIConfiguration.shared
        let baseURL = configuration.baseURL
        guard baseURL.host == "localhost" || baseURL.host == "127.0.0.1" else {
            throw XCTSkip("Authenticated integration tests only run against local Lobsters.")
        }

        let probeConfiguration = URLSessionConfiguration.ephemeral
        // A cold Simulator can take several seconds to launch its networking
        // process on CI even after the host-side readiness check succeeds.
        probeConfiguration.timeoutIntervalForRequest = 15
        let probe = LobstersPageLoader(
            session: URLSession(configuration: probeConfiguration),
            credentialStore: LobstersCredentialStore(
                service: "com.twodayslate.claw.tests.web-actions-probe",
                accessGroup: nil
            )
        )
        do {
            _ = try await probe.load(baseURL)
        } catch let error as URLError where error.code == .cannotConnectToHost {
            throw XCTSkip("The disposable local Lobsters server is not running.")
        }

        let client = LobstersWebViewClient(dataStore: .nonPersistent())
        _ = try await client.load(configuration.loginURL())
        let submitted = try await client.callAsyncJavaScriptWaitingForNavigation(
            """
            const email = document.getElementById('email');
            const password = document.getElementById('password');
            const form = email?.form;
            if (!email || !password || !form) return false;
            email.value = username;
            password.value = passphrase;
            setTimeout(() => form.requestSubmit(), 0);
            return true;
            """,
            arguments: ["username": "test", "passphrase": "test"]
        )
        XCTAssertEqual(submitted as? Bool, true)
        let signedInUsername = try await client.evaluateJavaScript(
            "document.body?.dataset?.username || ''"
        ) as? String
        XCTAssertEqual(signedInUsername, "test")

        let fixtureID = try await createFixtureStory(in: client, configuration: configuration)
        do {
            try await assertAuthenticatedActions(
                in: client,
                storyID: fixtureID,
                configuration: configuration
            )
            try await deleteFixtureStory(
                fixtureID,
                in: client,
                configuration: configuration
            )
            try await logOut(client, configuration: configuration)
        } catch {
            try? await deleteFixtureStory(
                fixtureID,
                in: client,
                configuration: configuration
            )
            try? await logOut(client, configuration: configuration)
            throw error
        }
    }

    @MainActor
    func testLocalSessionKeepsFeedLoadedAndDoesNotReloadAfterSuccessfulVote() async throws {
        let configuration = APIConfiguration.shared
        let baseURL = configuration.baseURL
        guard baseURL.host == "localhost" || baseURL.host == "127.0.0.1" else {
            throw XCTSkip("Authenticated integration tests only run against local Lobsters.")
        }

        let credentialStore = LobstersCredentialStore(
            service: "com.twodayslate.claw.tests.two-webviews.\(UUID().uuidString)",
            accessGroup: nil
        )
        defer { try? credentialStore.deleteCookie(for: baseURL) }

        let dataStore = WKWebsiteDataStore.nonPersistent()
        let feedClient = LobstersWebViewClient(dataStore: dataStore)
        let storyClient = LobstersWebViewClient(
            dataStore: dataStore,
            reloadsAfterWebContentProcessTermination: false
        )
        do {
            _ = try await feedClient.load(configuration.loginURL())
        } catch let error as URLError where error.code == .cannotConnectToHost {
            throw XCTSkip("The disposable local Lobsters server is not running.")
        }
        let submitted = try await feedClient.callAsyncJavaScriptWaitingForNavigation(
            """
            const email = document.getElementById('email');
            const password = document.getElementById('password');
            const form = email?.form;
            if (!email || !password || !form) return false;
            email.value = username;
            password.value = passphrase;
            setTimeout(() => form.requestSubmit(), 0);
            return true;
            """,
            arguments: ["username": "test", "passphrase": "test"]
        )
        XCTAssertEqual(submitted as? Bool, true)

        let cookies = await feedClient.allCookies()
        let cookie = try XCTUnwrap(cookies.first(where: {
            StoredLobstersCookie($0, for: baseURL) != nil
        }))
        try credentialStore.saveCookie(cookie, for: baseURL)

        let sessionConfiguration = URLSessionConfiguration.ephemeral
        sessionConfiguration.httpCookieStorage = nil
        sessionConfiguration.httpShouldSetCookies = false
        let pageLoader = LobstersPageLoader(
            session: URLSession(configuration: sessionConfiguration),
            credentialStore: credentialStore,
            storedCredentialPolicy: .always
        )
        let session = LobstersSession(
            credentialStore: credentialStore,
            pageLoader: pageLoader,
            webClient: feedClient,
            storyWebClient: storyClient,
            coordinator: LobstersSessionCoordinator()
        )
        session.setEntitlementAvailable(true)
        await session.start()
        XCTAssertTrue(session.isAuthenticated)

        let fixtureID = try await createFixtureStory(
            in: feedClient,
            configuration: configuration
        )
        do {
            let feedURL = configuration.hottestWebpageURL()
            session.preparePage(for: .Hottest)
            _ = try await feedClient.load(feedURL)
            let loadedFeedURL = try XCTUnwrap(feedClient.currentURL)

            let storyURL = configuration.storyURL(shortId: fixtureID)
            session.prepareStory(shortID: fixtureID, commentsURL: storyURL)
            _ = try await storyClient.load(storyURL)
            let loadedStoryURL = try XCTUnwrap(storyClient.currentURL)
            let initialState = try await voteState(
                in: storyClient,
                selector: "#story_\(fixtureID)"
            )
            let completedNavigations = storyClient.completedNavigationCount

            try await session.setStoryUpvoted(
                !initialState,
                shortID: fixtureID,
                commentsURL: storyURL
            )

            XCTAssertEqual(feedClient.currentURL, loadedFeedURL)
            XCTAssertEqual(storyClient.currentURL, loadedStoryURL)
            XCTAssertEqual(storyClient.completedNavigationCount, completedNavigations)
            let updatedState = try await voteState(
                in: storyClient,
                selector: "#story_\(fixtureID)"
            )
            XCTAssertEqual(updatedState, !initialState)

            try await deleteFixtureStory(
                fixtureID,
                in: feedClient,
                configuration: configuration
            )
            try await logOut(feedClient, configuration: configuration)
        } catch {
            try? await deleteFixtureStory(
                fixtureID,
                in: feedClient,
                configuration: configuration
            )
            try? await logOut(feedClient, configuration: configuration)
            throw error
        }
    }

    @MainActor
    func testLocalStoryVoteRetriesUntilWebpageHandlerIsReady() async throws {
        let configuration = APIConfiguration.shared
        let baseURL = configuration.baseURL
        guard baseURL.host == "localhost" || baseURL.host == "127.0.0.1" else {
            throw XCTSkip("Authenticated integration tests only run against local Lobsters.")
        }

        let client = LobstersWebViewClient(dataStore: .nonPersistent())
        do {
            _ = try await client.load(configuration.loginURL())
        } catch let error as URLError where error.code == .cannotConnectToHost {
            throw XCTSkip("The disposable local Lobsters server is not running.")
        }
        let submitted = try await client.callAsyncJavaScriptWaitingForNavigation(
            """
            const email = document.getElementById('email');
            const password = document.getElementById('password');
            const form = email?.form;
            if (!email || !password || !form) return false;
            email.value = username;
            password.value = passphrase;
            setTimeout(() => form.requestSubmit(), 0);
            return true;
            """,
            arguments: ["username": "test", "passphrase": "test"]
        )
        XCTAssertEqual(submitted as? Bool, true)

        let fixtureID = try await createFixtureStory(
            in: client,
            configuration: configuration
        )
        do {
            let initialState = try await voteState(
                in: client,
                selector: "#story_\(fixtureID)"
            )
            try await assertStoryVoteRoundTripAfterIgnoredFirstClick(
                client: client,
                storyID: fixtureID,
                initialState: initialState
            )
            try await deleteFixtureStory(
                fixtureID,
                in: client,
                configuration: configuration
            )
            try await logOut(client, configuration: configuration)
        } catch {
            try? await deleteFixtureStory(
                fixtureID,
                in: client,
                configuration: configuration
            )
            try? await logOut(client, configuration: configuration)
            throw error
        }
    }

    @MainActor
    private func createFixtureStory(
        in client: LobstersWebViewClient,
        configuration: APIConfiguration
    ) async throws -> String {
        let marker = UUID().uuidString
        _ = try await client.load(configuration.newStoryURL())
        let submitted = try await client.callAsyncJavaScriptWaitingForNavigation(
            """
            const form = document.querySelector('#story_holder form');
            const title = document.getElementById('story_title');
            const tags = document.getElementById('story_tags');
            const description = document.getElementById('story_description');
            const submit = form?.querySelector('input[type="submit"][value="Submit"]');
            if (!form || !title || !tags || !description || !submit) return false;
            title.value = storyTitle;
            description.value = storyDescription;
            for (const option of tags.options) option.selected = option.value === 'test';
            setTimeout(() => form.requestSubmit(submit), 0);
            return true;
            """,
            arguments: [
                "storyTitle": "Claw webpage integration fixture \(marker)",
                "storyDescription": "Disposable local-only Claw integration fixture \(marker)."
            ]
        )
        XCTAssertEqual(submitted as? Bool, true)
        let shortID = try await client.evaluateJavaScript(
            "document.querySelector('li.story[data-shortid]')?.dataset.shortid || ''"
        ) as? String
        return try XCTUnwrap(shortID.flatMap { $0.isEmpty ? nil : $0 })
    }

    @MainActor
    private func assertAuthenticatedActions(
        in client: LobstersWebViewClient,
        storyID: String,
        configuration: APIConfiguration
    ) async throws {
        let storyURL = configuration.storyURL(shortId: storyID)
        _ = try await client.load(storyURL)
        let initialStoryVote = try await voteState(
            in: client,
            selector: "#story_\(storyID)"
        )
        try await assertVoteRoundTrip(
            client: client,
            script: LobstersWebActions.storyVote,
            id: storyID,
            initialState: initialStoryVote
        )
        try await assertStoryVoteRoundTripWithURLInput(
            client: client,
            storyID: storyID,
            initialState: initialStoryVote
        )

        let marker = "Claw webpage action \(UUID().uuidString)"
        let parentResult = try await client.callAsyncJavaScript(
            LobstersWebActions.submitComment,
            arguments: [
                "mode": "new",
                "targetID": "",
                "storyID": storyID,
                "text": marker + " parent"
            ]
        )
        let parentCommentID = try XCTUnwrap(parentResult as? String)
        var parsedStory = try await waitForStory(
            in: client,
            pageURL: storyURL
        ) { story in
            story.comments.contains { $0.short_id == parentCommentID }
        }
        let parentComment = try XCTUnwrap(parsedStory.comments.first(where: {
            $0.short_id == parentCommentID
        }))
        XCTAssertTrue(parentComment.comment.contains(marker + " parent"))
        XCTAssertEqual(parentComment.can_vote, true)
        let initialCommentVote = try await voteState(
            in: client,
            selector: "#c_\(parentComment.short_id)"
        )
        try await assertVoteRoundTrip(
            client: client,
            script: LobstersWebActions.commentVote,
            id: parentComment.short_id,
            initialState: initialCommentVote
        )

        let edited = try await client.callAsyncJavaScript(
            LobstersWebActions.submitComment,
            arguments: [
                "mode": "edit",
                "targetID": parentComment.short_id,
                "storyID": storyID,
                "text": marker + " edited"
            ]
        )
        XCTAssertEqual(edited as? String, parentComment.short_id)
        parsedStory = try await waitForStory(
            in: client,
            pageURL: storyURL
        ) { story in
            story.comments.contains {
                $0.short_id == parentComment.short_id
                    && $0.comment.contains(marker + " edited")
            }
        }
        XCTAssertTrue(parsedStory.comments.contains(where: {
            $0.short_id == parentComment.short_id && $0.comment.contains(marker + " edited")
        }))

        let replyResult = try await client.callAsyncJavaScript(
            LobstersWebActions.submitComment,
            arguments: [
                "mode": "reply",
                "targetID": parentComment.short_id,
                "storyID": storyID,
                "text": marker + " reply"
            ]
        )
        let replyCommentID = try XCTUnwrap(replyResult as? String)
        parsedStory = try await waitForStory(
            in: client,
            pageURL: storyURL
        ) { story in
            story.comments.contains { $0.short_id == replyCommentID }
        }
        let reply = try XCTUnwrap(parsedStory.comments.first(where: {
            $0.short_id == replyCommentID
        }))
        XCTAssertTrue(reply.comment.contains(marker + " reply"))
        XCTAssertEqual(reply.parent_comment, parentComment.short_id)

        var rejectedInvalidComment = false
        do {
            _ = try await client.callAsyncJavaScript(
                LobstersWebActions.submitComment,
                arguments: [
                    "mode": "reply",
                    "targetID": parentComment.short_id,
                    "storyID": storyID,
                    "text": "+1"
                ]
            )
        } catch {
            rejectedInvalidComment = true
        }
        XCTAssertTrue(rejectedInvalidComment)
        parsedStory = try StoryHTMLParser.parse(
            try await pageHTML(from: client),
            pageURL: storyURL
        )
        XCTAssertFalse(parsedStory.comments.contains(where: {
            (try? SwiftSoup.parseBodyFragment($0.comment).text()) == "+1"
        }))

        for commentID in [reply.short_id, parentComment.short_id] {
            let deleted = try await client.callAsyncJavaScript(
                LobstersWebActions.deleteComment,
                arguments: ["shortID": commentID]
            )
            XCTAssertEqual(deleted as? Bool, true)
        }
    }

    @MainActor
    private func deleteFixtureStory(
        _ storyID: String,
        in client: LobstersWebViewClient,
        configuration: APIConfiguration
    ) async throws {
        let editURL = URL(
            string: "/stories/\(storyID)/edit",
            relativeTo: configuration.baseURL
        )!.absoluteURL
        _ = try await client.load(editURL)
        let submitted = try await client.callAsyncJavaScriptWaitingForNavigation(
            """
            const form = document.getElementById('edit_story');
            const button = [...(form?.querySelectorAll('input[type="submit"]') || [])]
              .find(input => input.value === 'Delete');
            if (!form || !button) return false;
            button.removeAttribute('data-confirm');
            setTimeout(() => form.requestSubmit(button), 0);
            return true;
            """
        )
        XCTAssertEqual(submitted as? Bool, true)
    }

    @MainActor
    private func logOut(
        _ client: LobstersWebViewClient,
        configuration: APIConfiguration
    ) async throws {
        _ = try await client.load(configuration.settingsURL())
        let loggedOut = try await client.callAsyncJavaScriptWaitingForNavigation(
            LobstersWebActions.logout
        )
        XCTAssertEqual(loggedOut as? Bool, true)
        let signedOutUsername = try await client.evaluateJavaScript(
            "document.body?.dataset?.username || ''"
        ) as? String
        XCTAssertEqual(signedOutUsername, "")
    }

    @MainActor
    private func pageHTML(from client: LobstersWebViewClient) async throws -> String {
        let value = try await client.evaluateJavaScript("document.documentElement.outerHTML")
        return try XCTUnwrap(value as? String)
    }

    @MainActor
    private func waitForStory(
        in client: LobstersWebViewClient,
        pageURL: URL,
        until expectedState: (Story) -> Bool
    ) async throws -> Story {
        var latestStory: Story?
        let clock = ContinuousClock()
        let deadline = clock.now.advanced(by: .seconds(10))

        repeat {
            let html = try await pageHTML(from: client)
            let story = try StoryHTMLParser.parse(
                html,
                pageURL: pageURL
            )
            latestStory = story
            if expectedState(story) {
                return story
            }
            try await Task.sleep(for: .milliseconds(50))
        } while clock.now < deadline

        XCTFail("The Lobsters webpage did not reflect the expected comment state.")
        return try XCTUnwrap(latestStory)
    }

    @MainActor
    private func voteState(
        in client: LobstersWebViewClient,
        selector: String
    ) async throws -> Bool {
        let value = try await client.callAsyncJavaScript(
            "return document.querySelector(selector)?.classList.contains('upvoted') ?? null;",
            arguments: ["selector": selector]
        )
        return try XCTUnwrap(value as? Bool)
    }

    @MainActor
    private func assertVoteRoundTrip(
        client: LobstersWebViewClient,
        script: String,
        id: String,
        initialState: Bool
    ) async throws {
        for desiredState in [!initialState, initialState] {
            let result = try await client.callAsyncJavaScript(
                script,
                arguments: ["shortID": id, "desiredState": desiredState]
            ) as? [String: Any]
            XCTAssertEqual(result?["upvoted"] as? Bool, desiredState)
        }
    }

    @MainActor
    private func assertStoryVoteRoundTripWithURLInput(
        client: LobstersWebViewClient,
        storyID: String,
        initialState: Bool
    ) async throws {
        for desiredState in [!initialState, initialState] {
            let installed = try await client.callAsyncJavaScript(
                """
                document.addEventListener('click', event => {
                  const voter = event.target.closest('a.upvoter');
                  const story = voter?.closest('li.story');
                  if (story?.dataset.shortid !== shortID) return;

                  event.preventDefault();
                  event.stopImmediatePropagation();
                  story.classList.toggle('upvoted', desiredState);

                  const headers = new Headers();
                  headers.append(
                    'X-CSRF-Token',
                    document.querySelector('meta[name="csrf-token"]')?.content || ''
                  );
                  headers.append('X-Requested-With', 'XMLHttpRequest');
                  const action = desiredState ? 'upvote' : 'unvote';
                  fetch(
                    new URL('/stories/' + shortID + '/' + action, document.baseURI),
                    { method: 'post', headers: headers, body: new FormData() }
                  );
                }, { capture: true, once: true });
                return true;
                """,
                arguments: [
                    "shortID": storyID,
                    "desiredState": desiredState
                ]
            )
            XCTAssertEqual(installed as? Bool, true)

            let result = try await client.callAsyncJavaScript(
                LobstersWebActions.storyVote,
                arguments: [
                    "shortID": storyID,
                    "desiredState": desiredState
                ]
            ) as? [String: Any]
            XCTAssertEqual(result?["upvoted"] as? Bool, desiredState)
        }
    }

    @MainActor
    private func assertStoryVoteRoundTripAfterIgnoredFirstClick(
        client: LobstersWebViewClient,
        storyID: String,
        initialState: Bool
    ) async throws {
        for desiredState in [!initialState, initialState] {
            let installed = try await client.callAsyncJavaScript(
                """
                document.addEventListener('click', event => {
                  const voter = event.target.closest('a.upvoter');
                  const story = voter?.closest('li.story');
                  if (story?.dataset.shortid !== shortID) return;
                  event.preventDefault();
                  event.stopImmediatePropagation();
                }, { capture: true, once: true });
                return true;
                """,
                arguments: ["shortID": storyID]
            )
            XCTAssertEqual(installed as? Bool, true)

            let result = try await client.callAsyncJavaScript(
                LobstersWebActions.storyVote,
                arguments: [
                    "shortID": storyID,
                    "desiredState": desiredState
                ]
            ) as? [String: Any]
            XCTAssertEqual(result?["upvoted"] as? Bool, desiredState)

            _ = try await client.reload()
            let persistedState = try await voteState(
                in: client,
                selector: "#story_\(storyID)"
            )
            XCTAssertEqual(persistedState, desiredState)
        }
    }

    func testPerformanceExample() throws {
        // This is an example of a performance test case.
        self.measure {
            // Put the code you want to measure the time of here.
        }
    }

}
