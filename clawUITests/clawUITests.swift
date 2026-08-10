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

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.

        // In UI tests it is usually best to stop immediately when a failure occurs.
        continueAfterFailure = false

        // In UI tests it’s important to set the initial state - such as interface orientation - required for your tests before they run. The setUp method is a good place to do this.
    }

    override func tearDownWithError() throws {
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

    func testSignedInUsernameOpensProfile() throws {
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
        let destination = app.tabBars.buttons[label]
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
        XCTAssertTrue(destination.waitForExistence(timeout: 5))
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

    private func waitForLabel(
        _ label: String,
        on element: XCUIElement,
        timeout: TimeInterval = 20
    ) {
        let expectation = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "label == %@", label),
            object: element
        )
        XCTAssertEqual(
            XCTWaiter.wait(for: [expectation], timeout: timeout),
            .completed,
            "Expected \(element.identifier) to become “\(label)”."
        )
    }
}
