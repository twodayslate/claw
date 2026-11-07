//
//  clawUITests.swift
//  clawUITests
//
//  Created by Zachary Gorak on 9/11/20.
//

import XCTest

class clawUITests: XCTestCase {

    private let storyVotePrefix = "story-vote-"
    private let voteFixtureTitle = "Claw UI Vote Fixture"
    private let profileFixtureTitle = "Claw UI Profile Story Fixture"

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.

        // In UI tests it is usually best to stop immediately when a failure occurs.
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait

        // In UI tests it’s important to set the initial state - such as interface orientation - required for your tests before they run. The setUp method is a good place to do this.
    }

    override func tearDownWithError() throws {
        XCUIDevice.shared.orientation = .portrait
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    private func configuredApplication() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments.append("--claw-ui-testing")
        if let baseURL = ProcessInfo.processInfo.environment[
            "CLAW_UI_TEST_BASE_URL"
        ] {
            app.launchEnvironment["CLAW_UI_TEST_BASE_URL"] = baseURL
        }
        return app
    }

    func testStoryPullToRefreshDisplaysUpdatedContent() throws {
        try setRefreshFixture(updated: false)
        let app = configuredApplication()
        try openLocalStory("rfrsh1", in: app)
        let title = app.descendants(matching: .any)["story-title-rfrsh1"]
        XCTAssertTrue(title.waitForExistence(timeout: 20))
        waitForLabel("Initial refresh fixture", on: title)
        // Exercise refreshing an already-open story after navigation settles;
        // pulling immediately can miss SwiftUI's refresh-cancellation behavior.
        sleep(3)

        try setRefreshFixture(updated: true)
        let scroll = app.scrollViews.containing(.any, identifier: "story-title-rfrsh1").firstMatch
        XCTAssertTrue(scroll.exists)
        scroll.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.15)).press(
            forDuration: 0.1,
            thenDragTo: scroll.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.9))
        )

        // A disappearing spinner does not prove the request completed: a
        // cancelled refresh can leave the cached story visible without an alert.
        waitForLabel("Updated refresh fixture", on: title)
        XCTAssertFalse(app.alerts["Error!"].exists)
    }

    private func setRefreshFixture(updated: Bool) throws {
        let url = try XCTUnwrap(URL(string: "/_claw_test/story_refresh", relativeTo: localBaseURL()))
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = Data("updated=\(updated)".utf8)
        let completed = expectation(description: "Update the local refresh fixture")
        URLSession.shared.dataTask(with: request) { _, response, error in
            XCTAssertNil(error)
            XCTAssertEqual((response as? HTTPURLResponse)?.statusCode, 204)
            completed.fulfill()
        }.resume()
        wait(for: [completed], timeout: 10)
    }

    func testStoryCanBeUpvotedThenUnvoted() throws {
        let app = configuredApplication()
        app.launch()

        signInToLocalLobstersIfNeeded(app)
        app.terminate()

        let storyID = try localStoryID()
        try openLocalStory(storyID, in: app)
        let storyTitle = app.descendants(matching: .any)[
            "story-title-\(storyID)"
        ]
        XCTAssertTrue(
            storyTitle.waitForExistence(timeout: 20),
            "Opening the local vote fixture did not present its story."
        )
        XCTAssertEqual(storyTitle.label, voteFixtureTitle)

        let voteButton = app.buttons[storyVotePrefix + storyID]
        XCTAssertTrue(
            voteButton.waitForExistence(timeout: 20),
            "The story vote control did not load."
        )

        // A reused local test user may already have voted for this fixture.
        // Normalize it before testing the requested upvote -> unvote sequence.
        if voteButton.label == "Remove upvote" {
            voteButton.tap()
            waitForLabel("Upvote", on: voteButton)
        }

        XCTAssertEqual(voteButton.label, "Upvote")
        voteButton.tap()
        waitForLabel("Remove upvote", on: voteButton)

        voteButton.tap()
        waitForLabel("Upvote", on: voteButton)
    }

    func testStoryCanBeOpenedFromWidgetURL() throws {
        let app = configuredApplication()
        let storyID = try localStoryID()

        // open(_:) launches the target with its configured arguments and
        // environment while delivering the URL, matching a widget launch.
        try openLocalStory(storyID, in: app)

        // A linked story title is exposed as a button, while a text-only story
        // is exposed as static text, so match either accessibility element.
        let storyTitle = app.descendants(matching: .any)[
            "story-title-\(storyID)"
        ]
        XCTAssertTrue(
            storyTitle.waitForExistence(timeout: 20),
            "Opening the widget URL did not present the requested story."
        )
        XCTAssertEqual(storyTitle.label, voteFixtureTitle)
    }

    func testSignedInProfileShowsSubmittedStoryAndOpensIt() throws {
        let app = configuredApplication()
        app.launch()

        signInToLocalLobstersIfNeeded(app)

        let profileLink = app.buttons["lobsters-account-profile"]
        XCTAssertTrue(
            profileLink.waitForExistence(timeout: 5),
            "The signed-in username was not available as a profile link."
        )
        profileLink.tap()

        XCTAssertTrue(
            app.navigationBars["test"].waitForExistence(timeout: 10),
            "Tapping the signed-in username did not open its profile."
        )

        let storyID = try localProfileStoryID()
        let storyIdentifier = "story-row-\(storyID)"
        let profileStory = app.staticTexts
            .matching(identifier: storyIdentifier)
            .matching(NSPredicate(format: "label == %@", profileFixtureTitle))
            .firstMatch

        let profileScrollView = app.scrollViews.firstMatch
        XCTAssertTrue(profileScrollView.waitForExistence(timeout: 5))
        let profileAvatar = app.descendants(matching: .any)[
            "user-profile-avatar"
        ]
        XCTAssertTrue(
            profileAvatar.waitForExistence(timeout: 5),
            "The user's profile avatar was not visible."
        )
        let expandedAvatarWidth = profileAvatar.frame.width
        let dragStart = profileScrollView.coordinate(
            withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)
        )
        dragStart.press(
            forDuration: 0.1,
            thenDragTo: dragStart.withOffset(CGVector(dx: 0, dy: -30)),
            withVelocity: .slow,
            thenHoldForDuration: 1
        )

        XCTAssertLessThan(
            profileAvatar.frame.width,
            expandedAvatarWidth,
            "The profile avatar did not begin shrinking after a short scroll."
        )
        XCTAssertGreaterThan(
            profileAvatar.frame.width,
            50,
            "The profile avatar reached its title size too early."
        )
        profileScrollView.swipeUp()
        profileScrollView.swipeUp()

        XCTAssertTrue(
            profileAvatar.waitForExistence(timeout: 5),
            "The user's avatar did not move into the title after scrolling."
        )
        XCTAssertLessThan(
            profileAvatar.frame.width,
            50,
            "The profile avatar did not shrink to its title size."
        )
        XCTAssertLessThan(
            profileAvatar.frame.midY,
            120,
            "The same profile avatar did not move into the navigation title."
        )

        scroll(profileScrollView, untilHittable: profileStory)
        XCTAssertTrue(
            profileStory.isHittable,
            "The signed-in user's submitted story was not visible."
        )
        XCTAssertTrue(
            profileAvatar.waitForExistence(timeout: 5),
            "The title avatar disappeared after its profile row was recycled."
        )
        XCTAssertLessThan(
            profileAvatar.frame.midY,
            120,
            "The title avatar left the navigation title after prolonged scrolling."
        )
        profileStory.tap()

        let loadedStory = app.descendants(matching: .any)[
            "story-title-\(storyID)"
        ]
        XCTAssertTrue(
            loadedStory.waitForExistence(timeout: 20),
            "Tapping the profile story did not load its local story page."
        )
        XCTAssertEqual(loadedStory.label, profileFixtureTitle)
        let profileBackButton = app.navigationBars.buttons["test"]
        let backButton = profileBackButton.exists
            ? profileBackButton
            : app.buttons["BackButton"]
        XCTAssertTrue(backButton.waitForExistence(timeout: 5))
        backButton.tap()
        XCTAssertTrue(app.navigationBars["test"].waitForExistence(timeout: 5))
    }

    func testLatestLobstersStoryDisplaysCommentsAndReplies() throws {
        _ = try localBaseURL()
        let app = configuredApplication()
        app.launch()
        signInToLocalLobstersIfNeeded(app)
        selectTab("Newest", in: app)

        let fixture = app.staticTexts.matching(NSPredicate(
            format: "identifier BEGINSWITH 'story-row-' AND label == %@",
            "Claw Parser Compatibility Fixture"
        )).firstMatch
        let feed = app.scrollViews.firstMatch
        XCTAssertTrue(feed.waitForExistence(timeout: 10))
        _ = fixture.waitForExistence(timeout: 15)
        scroll(feed, untilHittable: fixture)
        XCTAssertTrue(fixture.isHittable, "Seed the local server with .ci/seed-parser-fixture.rb")
        fixture.tap()

        // A successfully loaded header alone does not prove comments loaded.
        // Exercise the actual fetcher and native comment rendering for #73.
        for body in ["Parser parent body.", "Parser child body.", "Parser second root body."] {
            let comment = app.staticTexts[body]
            if !comment.waitForExistence(timeout: 15) {
                scroll(app.scrollViews.firstMatch, untilHittable: comment)
            }
            XCTAssertTrue(comment.exists, "Missing rendered comment: \(body)")
        }
        XCTAssertFalse(app.descendants(matching: .any)["story-comments-unavailable"].exists)
    }

    func testStoryRateLimitOffersCopyableReportAndRetryTime() throws {
        let app = configuredApplication()
        app.launch()
        selectTab("Hottest", in: app)
        try openLocalStory("err429", in: app)
        let alert = app.alerts["Error!"]
        XCTAssertTrue(alert.waitForExistence(timeout: 20))
        let message = alert.staticTexts.allElementsBoundByIndex.map(\.label).joined(separator: "\n")
        XCTAssertTrue(message.contains("Lobsters Is Limiting Requests"))
        XCTAssertTrue(message.contains("Try again after"))
        assertCopyableStoryAlert(in: app)
    }

    func testStoryMarkupErrorOffersCopyableReport() throws {
        let app = configuredApplication()
        app.launch()
        selectTab("Hottest", in: app)
        try openLocalStory("errhtm", in: app)
        let alert = app.alerts["Error!"]
        XCTAssertTrue(alert.waitForExistence(timeout: 20))
        XCTAssertTrue(alert.staticTexts.containing(NSPredicate(
            format: "label CONTAINS %@", "Story Could Not Be Read")).firstMatch.exists)
        assertCopyableStoryAlert(in: app)
        XCTAssertTrue(app.staticTexts["Story Unavailable"].exists)
    }

    func testCommentMarkupErrorKeepsStoryAndOffersCopyableReport() throws {
        let app = configuredApplication()
        app.launch()
        selectTab("Hottest", in: app)
        try openLocalStory("errcmt", in: app)
        let alert = app.alerts["Error!"]
        XCTAssertTrue(alert.waitForExistence(timeout: 20))
        XCTAssertTrue(alert.staticTexts.containing(NSPredicate(
            format: "label CONTAINS %@", "Comments Could Not Be Read")).firstMatch.exists)
        alert.buttons["Okay"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["story-title-errcmt"].exists)
        XCTAssertTrue(app.staticTexts["story-comments-unavailable"].exists)
        XCTAssertFalse(app.buttons["copy-story-error-details"].exists)
    }

    private func assertCopyableStoryAlert(in app: XCUIApplication) {
        let alert = app.alerts["Error!"]
        XCTAssertTrue(alert.buttons["Okay"].exists)
        alert.buttons["Copy Error Details"].tap()
        let dismissed = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: alert)
        XCTAssertEqual(XCTWaiter.wait(for: [dismissed], timeout: 5), .completed)
        XCTAssertFalse(app.buttons["copy-story-error-details"].exists)
    }

    private func commentFixtureApplication() -> XCUIApplication {
        let app = configuredApplication()
        app.launchEnvironment["CLAW_UI_TEST_BASE_URL"] =
            ProcessInfo.processInfo.environment["CLAW_UI_TEST_BASE_URL"] ?? "http://localhost:3006"
        return app
    }

    func testCommentDepthContinuation() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["RUN_COMMENT_DEPTH_UI_TEST"] == "1",
                          "Seed the local Lobsters instance with scripts/seed_comment_depth.rb first.")
        let app = commentFixtureApplication()
        app.launch()
        app.buttons["Newest"].firstMatch.tap()
        let story = app.staticTexts["Claw comment depth regression fixture"]
        XCTAssertTrue(story.waitForExistence(timeout: 10))
        story.tap()
        XCTAssertTrue(app.staticTexts["Depth 0 comment"].waitForExistence(timeout: 15))

        func reveal(_ element: XCUIElement) {
            for _ in 0..<12 {
                if element.exists && element.isHittable { return }
                app.scrollViews.firstMatch.swipeUp()
            }
            XCTFail("Could not reveal \(element)")
        }

        let firstContinuation = app.buttons["continue-thread-depth3"]
        reveal(firstContinuation)
        XCTAssertFalse(app.staticTexts["Depth 4 comment"].exists)
        XCTAssertFalse(app.buttons["continue-thread-leaf3"].exists)
        let originalIndent = app.staticTexts["Depth 3 comment"].frame.minX
        firstContinuation.tap()

        XCTAssertTrue(app.navigationBars["Thread"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Depth 3 comment"].exists)
        XCTAssertLessThan(app.staticTexts["Depth 3 comment"].frame.minX, originalIndent)
        XCTAssertTrue(app.staticTexts["Depth 4 comment"].exists)
        XCTAssertFalse(app.staticTexts["Depth 7 comment"].exists)

        let secondContinuation = app.buttons["continue-thread-depth6"]
        reveal(secondContinuation)
        secondContinuation.tap()
        XCTAssertTrue(app.staticTexts["Depth 6 comment"].waitForExistence(timeout: 5))
        app.staticTexts["Depth 6 comment"].tap()
        XCTAssertFalse(app.staticTexts["Depth 7 comment"].exists)
        // The context comment remains available through its header when collapsed.
        app.buttons["toggle-comment-depth6"].tap()
        XCTAssertTrue(app.staticTexts["Depth 7 comment"].waitForExistence(timeout: 5))
        reveal(app.staticTexts["Depth 9 comment"])
        XCTAssertFalse(app.buttons["continue-thread-depth9"].exists)

        app.navigationBars.buttons.firstMatch.tap()
        reveal(app.staticTexts["Sibling reply at depth 4"])
        app.navigationBars.buttons.firstMatch.tap()
        reveal(app.staticTexts["Independent root comment"])
        reveal(app.staticTexts["Short branch depth 3"])
        XCTAssertFalse(app.buttons["continue-thread-leaf3"].exists)
    }

    private func requireCommentFixture() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["RUN_COMMENT_DEPTH_UI_TEST"] == "1",
                          "Seed the disposable local Lobsters instance first.")
    }

    private func reveal(_ element: XCUIElement, in app: XCUIApplication) {
        for _ in 0..<16 {
            if element.exists && element.isHittable { return }
            app.scrollViews.firstMatch.swipeUp()
        }
        XCTFail("Could not reveal \(element)")
    }

    func testCommentDepthAdaptsToWidth() throws {
        try requireCommentFixture()
        XCUIDevice.shared.orientation = .portrait
        defer { XCUIDevice.shared.orientation = .portrait }
        let app = commentFixtureApplication()
        app.launch()
        app.buttons["Newest"].firstMatch.tap()
        let story = app.staticTexts["Claw comment depth regression fixture"]
        XCTAssertTrue(story.waitForExistence(timeout: 10))
        story.tap()
        XCTAssertTrue(app.staticTexts["Depth 0 comment"].waitForExistence(timeout: 15))
        if app.frame.width < 700 {
            reveal(app.buttons["continue-thread-depth3"], in: app)
            XCTAssertFalse(app.staticTexts["Depth 4 comment"].exists)
            XCUIDevice.shared.orientation = .landscapeLeft
            reveal(app.staticTexts["Depth 4 comment"], in: app)
            XCTAssertFalse(app.buttons["continue-thread-depth3"].exists)
            XCUIDevice.shared.orientation = .portrait
            reveal(app.buttons["continue-thread-depth3"], in: app)
            XCTAssertFalse(app.staticTexts["Depth 4 comment"].exists)
        } else {
            reveal(app.staticTexts["Depth 9 comment"], in: app)
            XCTAssertFalse(app.buttons["continue-thread-depth3"].exists)
        }
    }

    @MainActor
    func testCommentLinksOpenHiddenReplies() async throws {
        try requireCommentFixture()
        let base = try XCTUnwrap(URL(string: ProcessInfo.processInfo.environment["CLAW_UI_TEST_BASE_URL"]
                                     ?? "http://localhost:3006"))
        XCTAssertTrue(["localhost", "127.0.0.1", "::1"].contains(base.host ?? ""))
        guard ["localhost", "127.0.0.1", "::1"].contains(base.host ?? "") else { return }
        let (data, _) = try await URLSession.shared.data(from: base.appendingPathComponent("newest.json"))
        let feed = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [[String: Any]])
        let fixture = try XCTUnwrap(feed.first { ($0["title"] as? String) == "Claw comment depth regression fixture" })
        let storyURL = try XCTUnwrap(fixture["comments_url"] as? String)

        func wrapped(_ url: URL) -> URL {
            var components = URLComponents(string: "claw://open")!
            components.queryItems = [URLQueryItem(name: "url", value: url.absoluteString)]
            return components.url!
        }

        let app = commentFixtureApplication()
        app.launch()
        app.buttons["Newest"].firstMatch.tap()
        let story = app.staticTexts["Claw comment depth regression fixture"]
        XCTAssertTrue(story.waitForExistence(timeout: 10))
        story.tap()
        XCTAssertTrue(app.staticTexts["Depth 0 comment"].waitForExistence(timeout: 15))
        let internalLink = app.staticTexts["/c/depth4"]
        reveal(internalLink, in: app)
        internalLink.tap()
        XCTAssertTrue(app.staticTexts["Linked comment"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["Depth 4 comment"].isHittable)
        XCTAssertFalse(app.staticTexts["Depth 0 comment"].exists)
        if app.frame.width < 700 {
            reveal(app.buttons["continue-thread-depth7"], in: app)
            app.buttons["continue-thread-depth7"].tap()
            reveal(app.staticTexts["Depth 9 comment"], in: app)
        }

        // Replace an already-open thread with another comment in the same story.
        app.open(wrapped(try XCTUnwrap(URL(string: storyURL + "#c_depth9"))))
        XCTAssertTrue(app.staticTexts["Depth 9 comment"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["Linked comment"].exists)
        XCTAssertFalse(app.staticTexts["Depth 4 comment"].exists)
        app.buttons["View all comments"].tap()
        XCTAssertTrue(app.staticTexts["Claw comment depth regression fixture"].waitForExistence(timeout: 5))

        app.open(wrapped(base.appendingPathComponent("c/depth7")))
        XCTAssertTrue(app.staticTexts["Depth 7 comment"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["Linked comment"].exists)
        XCTAssertFalse(app.staticTexts["Depth 0 comment"].exists)

        app.open(wrapped(try XCTUnwrap(URL(string: storyURL + "#c_missing"))))
        XCTAssertTrue(app.staticTexts["Comment unavailable"].waitForExistence(timeout: 10))
        app.open(wrapped(base.appendingPathComponent("c/missing")))
        XCTAssertTrue(app.alerts.firstMatch.waitForExistence(timeout: 10))
        app.alerts.buttons["Okay"].tap()
        XCTAssertTrue(app.staticTexts["Story Unavailable"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Retry"].exists)
    }

    func testCommentLinkRefocusesAfterViewAll() throws {
        try requireCommentFixture()
        let app = commentFixtureApplication()
        let base = ProcessInfo.processInfo.environment["CLAW_UI_TEST_BASE_URL"] ?? "http://localhost:3006"
        var wrapper = URLComponents(string: "claw://open")!
        wrapper.queryItems = [URLQueryItem(name: "url", value: base + "/c/depth4")]
        app.open(try XCTUnwrap(wrapper.url))
        XCTAssertTrue(app.staticTexts["Linked comment"].waitForExistence(timeout: 15))
        app.buttons["View all comments"].tap()
        let link = app.staticTexts["/c/depth4"]
        reveal(link, in: app)
        link.tap()
        XCTAssertTrue(app.staticTexts["Linked comment"].waitForExistence(timeout: 5),
                      "The same comment link no longer focuses its target after View all comments")
        XCTAssertTrue(app.staticTexts["Depth 4 comment"].isHittable)
    }

    func testLaunchPerformance() throws {
        if #available(macOS 10.15, iOS 13.0, tvOS 13.0, *) {
            // This measures how long it takes to launch your application.
            measure(metrics: [XCTApplicationLaunchMetric()]) {
                configuredApplication().launch()
            }
        }
    }

    private func signInToLocalLobstersIfNeeded(_ app: XCUIApplication) {
        selectTab("Settings", in: app)

        let signedInControl = app.buttons["Submit a Story"]
        let signInButton = app.buttons["Sign In to Lobsters"]
        let settingsList = app.collectionViews.firstMatch
        XCTAssertTrue(settingsList.waitForExistence(timeout: 5))
        for _ in 0..<4 where !signedInControl.exists && !signInButton.exists {
            settingsList.swipeUp()
        }

        if signedInControl.exists {
            return
        }

        XCTAssertTrue(
            signInButton.waitForExistence(timeout: 5),
            "The local Lobsters login control did not become available."
        )
        signInButton.tap()

        let webView = app.webViews.firstMatch
        XCTAssertTrue(webView.waitForExistence(timeout: 15))

        let usernameField = webView.descendants(matching: .textField)
            .matching(
                NSPredicate(
                    format: "identifier == 'email' OR label CONTAINS[c] 'Username'"
                )
            )
            .firstMatch
        XCTAssertTrue(usernameField.waitForExistence(timeout: 15))
        usernameField.tap()
        usernameField.typeText("test")

        let passwordField = webView.secureTextFields.firstMatch
        XCTAssertTrue(passwordField.waitForExistence(timeout: 5))
        passwordField.tap()
        passwordField.typeText("test")

        let loginButton = webView.buttons["Login"]
        XCTAssertTrue(loginButton.waitForExistence(timeout: 5))
        loginButton.tap()

        XCTAssertTrue(
            signedInControl.waitForExistence(timeout: 20),
            "The local test account did not finish signing in."
        )
    }

    private func selectTab(_ label: String, in app: XCUIApplication) {
        // The iPhone Duo's side tab rail lives outside the tab bar.
        let tabBarDestination = app.tabBars.buttons[label]
        let destination = tabBarDestination.exists
            ? tabBarDestination
            : app.buttons[label]
        if !destination.exists {
            // iOS 26 collapses the tab bar after the Settings form scrolls.
            // Pressing the selected compact tab expands the other choices.
            let selectedTab = app.tabBars.buttons.matching(
                NSPredicate(format: "isSelected == true")
            ).firstMatch
            if selectedTab.exists {
                selectedTab.tap()
            }
        }
        XCTAssertTrue(
            destination.waitForExistence(timeout: 5),
            "Missing tab \(label): \(app.debugDescription)"
        )
        destination.tap()
    }

    private func openLocalStory(
        _ storyID: String,
        in app: XCUIApplication
    ) throws {
        let baseURL = try localBaseURL()
        let storyURL = try XCTUnwrap(
            URL(string: "/s/\(storyID)", relativeTo: baseURL)?.absoluteURL
        )
        // This is the same custom URL shape emitted by the widget's Link and
        // widgetURL modifiers.
        let appURL = try XCTUnwrap(
            URL(string: "claw://open?url=\(storyURL.absoluteString)")
        )
        app.open(appURL)
    }

    private func localBaseURL() throws -> URL {
        let value = try XCTUnwrap(
            ProcessInfo.processInfo.environment["CLAW_UI_TEST_BASE_URL"]
        )
        let url = try XCTUnwrap(URL(string: value))
        XCTAssertTrue(
            ["localhost", "127.0.0.1"].contains(url.host?.lowercased() ?? ""),
            "Widget UI tests must use the local Lobsters server."
        )
        return url
    }

    private func localStoryID() throws -> String {
        let storyID = try XCTUnwrap(
            ProcessInfo.processInfo.environment["CLAW_UI_TEST_STORY_ID"]
        )
        XCTAssertFalse(storyID.isEmpty)
        XCTAssertFalse(
            storyID.contains("/"),
            "The local story fixture must be a Lobsters short ID."
        )
        return storyID
    }

    private func localProfileStoryID() throws -> String {
        let storyID = try XCTUnwrap(
            ProcessInfo.processInfo.environment[
                "CLAW_UI_TEST_PROFILE_STORY_ID"
            ]
        )
        XCTAssertFalse(storyID.isEmpty)
        XCTAssertFalse(
            storyID.contains("/"),
            "The profile story fixture must be a Lobsters short ID."
        )
        return storyID
    }

    private func waitForLabel(
        _ label: String,
        on element: XCUIElement,
        timeout: TimeInterval = 20
    ) {
        // For vote controls, also wait for server confirmation to re-enable
        // the control before attempting the opposite vote.
        let expectation = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "label == %@ AND enabled == true", label),
            object: element
        )
        XCTAssertEqual(
            XCTWaiter.wait(for: [expectation], timeout: timeout),
            .completed,
            "Expected \(element.identifier) to become “\(label)” and be enabled."
        )
    }

    private func scroll(
        _ container: XCUIElement,
        untilHittable element: XCUIElement
    ) {
        for _ in 0..<8 where !element.isHittable {
            container.swipeUp()
        }
    }
}
