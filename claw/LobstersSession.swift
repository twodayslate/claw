//
//  LobstersSession.swift
//  claw
//

import Foundation
import OSLog
import UIKit
import WebKit

@MainActor
final class LobstersSession: ObservableObject {
    private static let logger = Logger(
        subsystem: "com.twodayslate.claw",
        category: "LobstersSession"
    )

    enum State: Equatable {
        case checking
        case signingIn
        case signedOut
        case signedIn(username: String)
        case signingOut(username: String)
        case unavailable(message: String)
    }

    enum Action: Equatable {
        case storyVote(String)
        case commentVote(String)
        case postComment
        case reply(String)
        case edit(String)
        case delete(String)
        case signOut
    }

    enum SessionError: LocalizedError {
        case signedOut
        case actionInProgress
        case emptyComment
        case storyPageUnavailable
        case commentActionFailed
        case voteDidNotChange
        case logoutPageUnavailable

        var errorDescription: String? {
            switch self {
            case .signedOut:
                return "Sign in to your Lobsters account to continue."
            case .actionInProgress:
                return "Another Lobsters action is still in progress."
            case .emptyComment:
                return "Enter a comment before posting."
            case .storyPageUnavailable:
                return "The Lobsters webpage did not contain this story."
            case .commentActionFailed:
                return "Lobsters did not confirm the comment action."
            case .voteDidNotChange:
                return "Lobsters did not confirm the vote change."
            case .logoutPageUnavailable:
                return "The Lobsters webpage did not contain its logout form."
            }
        }
    }

    @Published private(set) var state: State = .checking
    @Published private(set) var avatarURL: URL?
    @Published private(set) var avatarImage: UIImage?
    @Published private(set) var activeAction: Action?
    @Published var errorMessage: String?

    private let credentialStore: LobstersCredentialStore
    private let pageLoader: LobstersPageLoader
    // The primary client retains the selected feed and hosts the visible login/
    // submission pages. Story actions use a second retained client so opening a
    // story never evicts the feed page.
    private let webClient: LobstersWebViewClient
    private let storyWebClient: LobstersWebViewClient
    private let avatarLoader: LobstersAvatarLoader
    private let contentRefresher: LobstersContentRefresher
    private let coordinator: LobstersSessionCoordinator
    private var hasStarted = false
    private var isStarting = false
    private var isEntitled = false
    private var selectedTab: TabSelection = .Hottest
    private var restoreSelectedPageWhenPrimaryNavigationFinishes = false
    private var sessionGeneration: UInt = 0
    private var coordinatedAuthenticationUsername: String?
    private var signOutRequested = false
    private var signOutWaiters = [CheckedContinuation<Void, Never>]()

    init(
        credentialStore: LobstersCredentialStore = LobstersCredentialStore(),
        pageLoader: LobstersPageLoader = .shared,
        webClient: LobstersWebViewClient = LobstersWebViewClient(),
        storyWebClient: LobstersWebViewClient = LobstersWebViewClient(
            reloadsAfterWebContentProcessTermination: false
        ),
        avatarLoader: LobstersAvatarLoader = LobstersAvatarLoader(),
        contentRefresher: LobstersContentRefresher = LobstersContentRefresher(),
        coordinator: LobstersSessionCoordinator = .shared
    ) {
        self.credentialStore = credentialStore
        self.pageLoader = pageLoader
        self.webClient = webClient
        self.storyWebClient = storyWebClient
        self.avatarLoader = avatarLoader
        self.contentRefresher = contentRefresher
        self.coordinator = coordinator

        webClient.onPageLoaded = { [weak self] _ in
            Task { @MainActor in
                await self?.captureSessionFromWebView()
                self?.restoreSelectedPageIfRequested()
            }
        }
        webClient.onError = { [weak self] error in
            self?.errorMessage = error.localizedDescription
            self?.restoreSelectedPageIfRequested()
        }
        storyWebClient.onPageLoaded = { [weak self, weak storyWebClient] _ in
            guard let storyWebClient else {
                return
            }
            Task { @MainActor in
                await self?.captureSession(from: storyWebClient)
            }
        }
        storyWebClient.onError = { [weak self] error in
            self?.errorMessage = error.localizedDescription
        }
        coordinator.register(self)
    }

    var webView: WKWebView {
        webClient.webView
    }

    var username: String? {
        switch state {
        case .signedIn(let username), .signingOut(let username):
            return username
        default:
            return nil
        }
    }

    var isAuthenticated: Bool {
        if case .signedIn = state {
            return true
        }
        return false
    }

    var isBusy: Bool {
        activeAction != nil || state == .checking || state == .signingIn
    }

    func start(force: Bool = false) async {
        guard isEntitled else {
            state = .signedOut
            return
        }
        guard !isStarting else {
            return
        }
        if hasStarted && !force {
            guard case .unavailable = state else {
                return
            }
        }

        isStarting = true
        hasStarted = true
        state = .checking
        defer { isStarting = false }
        let generation = sessionGeneration

        do {
            guard let storedCookie = try credentialStore.loadCookie(for: baseURL),
                  let cookie = storedCookie.makeCookie() else {
                if isCurrentSession(generation) {
                    state = .signedOut
                }
                return
            }

            await webClient.setCookie(cookie)
            await storyWebClient.setCookie(cookie)
            guard isCurrentSession(generation) else {
                return
            }
            try await validateSession(generation: generation)
            guard isCurrentSession(generation) else {
                return
            }
            webClient.reloadIfNeeded()
            storyWebClient.reloadIfNeeded()
        } catch {
            guard isCurrentSession(generation) else {
                return
            }
            state = .unavailable(message: error.localizedDescription)
            errorMessage = error.localizedDescription
        }
    }

    func markEntitlementUnavailable(_ error: Error) {
        guard state == .checking else {
            return
        }
        state = .unavailable(message: error.localizedDescription)
    }

    func setEntitlementAvailable(_ available: Bool) {
        guard isEntitled != available else {
            return
        }
        isEntitled = available
        if !available {
            sessionGeneration &+= 1
        }
    }

    func beginLogin() {
        guard isEntitled else {
            state = .signedOut
            return
        }
        sessionGeneration &+= 1
        restoreSelectedPageWhenPrimaryNavigationFinishes = false
        errorMessage = nil
        state = .signingIn
        do {
            try webClient.navigateIfNeeded(to: APIConfiguration.shared.loginURL())
        } catch {
            state = .signedOut
            errorMessage = error.localizedDescription
        }
    }

    func cancelLogin() {
        if state == .signingIn {
            sessionGeneration &+= 1
            restoreSelectedPageWhenPrimaryNavigationFinishes = false
            let cancellationGeneration = sessionGeneration
            state = .signedOut
            Task {
                await discardCancelledLogin(generation: cancellationGeneration)
            }
        }
    }

    func endLoginPresentation() {
        if state == .signingIn {
            cancelLogin()
        } else {
            restoreSelectedPageAfterPrimaryFlow()
        }
    }

    func beginStorySubmission() throws {
        guard isEntitled, isAuthenticated else {
            throw SessionError.signedOut
        }
        restoreSelectedPageWhenPrimaryNavigationFinishes = false
        try webClient.navigateIfNeeded(to: APIConfiguration.shared.newStoryURL())
    }

    func endStorySubmissionPresentation() {
        restoreSelectedPageAfterPrimaryFlow()
    }

    func preparePage(for tab: TabSelection) {
        if tab == .Settings {
            // Keep the most recent feed warm while Settings is visible. On a
            // fresh launch there is no previous page, so prime Hottest.
            if webClient.currentURL == nil {
                do {
                    try webClient.navigateIfNeeded(
                        to: APIConfiguration.shared.hottestWebpageURL()
                    )
                } catch {
                    errorMessage = error.localizedDescription
                }
            }
            return
        }

        selectedTab = tab
        let url: URL?
        switch tab {
        case .Hottest:
            url = APIConfiguration.shared.hottestWebpageURL()
        case .Newest:
            url = APIConfiguration.shared.newestWebpageURL()
        case .Tags:
            let tags = UserDefaults.standard.stringArray(forKey: "selectedTags") ?? ["programming"]
            url = APIConfiguration.shared.tagStoryWebpageURL(tags: tags)
        case .Settings:
            url = nil
        }

        if let url {
            do {
                try webClient.navigateIfNeeded(to: url)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    func prepareStory(shortID: String, commentsURL: URL?) {
        do {
            try storyWebClient.navigateIfNeeded(
                to: storyURL(shortID: shortID, commentsURL: commentsURL)
            )
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    #if DEBUG
    func switchDebugServer(to server: APIConfiguration.DebugServer) async {
        guard server != APIConfiguration.shared.debugServer else {
            return
        }

        // Sign out while the old origin is still configured so its Keychain and
        // WebKit cookies are removed from the correct host.
        await signOut()
        APIConfiguration.shared.setDebugServer(server)

        sessionGeneration &+= 1
        hasStarted = false
        isStarting = false
        restoreSelectedPageWhenPrimaryNavigationFinishes = false
        errorMessage = nil
        avatarURL = nil
        avatarImage = nil
        state = isEntitled ? .checking : .signedOut

        do {
            try webClient.reset(to: APIConfiguration.shared.hottestWebpageURL())
            try storyWebClient.reset(to: APIConfiguration.shared.hottestWebpageURL())
        } catch {
            errorMessage = error.localizedDescription
        }
        contentRefresher.invalidate()

        if isEntitled {
            await start(force: true)
        }
    }
    #endif

    func setStoryUpvoted(
        _ upvoted: Bool,
        shortID: String,
        commentsURL: URL?
    ) async throws {
        Self.logger.info(
            "Story vote requested shortID=\(shortID, privacy: .public) desired=\(upvoted) page=\(Self.logDescription(for: self.storyWebClient.currentURL), privacy: .public)"
        )
        try await perform(.storyVote(shortID), reloadOnFailure: false) {
            let generation = try authenticatedGeneration()
            try await ensureStoryPage(
                shortID: shortID,
                commentsURL: commentsURL
            )
            guard isCurrentSession(generation) else {
                throw SessionError.signedOut
            }

            try await performVoteAction(
                script: LobstersWebActions.storyVote,
                shortID: shortID,
                desiredState: upvoted,
                selector: "#story_\(shortID)",
                generation: generation
            )
            contentRefresher.invalidate()
            Self.logger.info(
                "Story vote confirmed shortID=\(shortID, privacy: .public) desired=\(upvoted)"
            )
        }
    }

    func setCommentUpvoted(
        _ upvoted: Bool,
        commentID: String,
        storyID: String,
        commentsURL: URL?
    ) async throws {
        try await perform(.commentVote(commentID), reloadOnFailure: false) {
            let generation = try authenticatedGeneration()
            try await ensureStoryPage(
                shortID: storyID,
                commentsURL: commentsURL
            )
            guard isCurrentSession(generation) else {
                throw SessionError.signedOut
            }

            try await performVoteAction(
                script: LobstersWebActions.commentVote,
                shortID: commentID,
                desiredState: upvoted,
                selector: "#c_\(commentID)",
                generation: generation
            )
            contentRefresher.invalidate()
        }
    }

    func commentDraft(
        commentID: String,
        storyID: String,
        commentsURL: URL?
    ) async throws -> String {
        try await perform(.edit(commentID)) {
            let generation = try authenticatedGeneration()
            try await ensureStoryPage(shortID: storyID, commentsURL: commentsURL)
            guard isCurrentSession(generation) else {
                throw SessionError.signedOut
            }
            let result = try await storyWebClient.callAsyncJavaScript(
                LobstersWebActions.commentDraft,
                arguments: ["shortID": commentID]
            )
            guard let draft = result as? String else {
                throw SessionError.commentActionFailed
            }
            return draft
        }
    }

    func submitComment(
        _ text: String,
        storyID: String,
        parentCommentID: String? = nil,
        editingCommentID: String? = nil,
        commentsURL: URL?
    ) async throws {
        let text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else {
            throw SessionError.emptyComment
        }

        let action: Action
        let mode: String
        let targetID: String
        if let editingCommentID {
            action = .edit(editingCommentID)
            mode = "edit"
            targetID = editingCommentID
        } else if let parentCommentID {
            action = .reply(parentCommentID)
            mode = "reply"
            targetID = parentCommentID
        } else {
            action = .postComment
            mode = "new"
            targetID = ""
        }

        try await perform(action) {
            let generation = try authenticatedGeneration()
            try await ensureStoryPage(shortID: storyID, commentsURL: commentsURL)
            guard isCurrentSession(generation) else {
                throw SessionError.signedOut
            }
            let result = try await storyWebClient.callAsyncJavaScript(
                LobstersWebActions.submitComment,
                arguments: [
                    "mode": mode,
                    "targetID": targetID,
                    "storyID": storyID,
                    "text": text
                ]
            )
            guard result as? Bool == true else {
                throw SessionError.commentActionFailed
            }
            contentRefresher.invalidate()
        }
    }

    func deleteComment(
        commentID: String,
        storyID: String,
        commentsURL: URL?
    ) async throws {
        try await perform(.delete(commentID)) {
            let generation = try authenticatedGeneration()
            try await ensureStoryPage(shortID: storyID, commentsURL: commentsURL)
            guard isCurrentSession(generation) else {
                throw SessionError.signedOut
            }
            let result = try await storyWebClient.callAsyncJavaScript(
                LobstersWebActions.deleteComment,
                arguments: ["shortID": commentID]
            )
            guard result as? Bool == true else {
                throw SessionError.commentActionFailed
            }
            contentRefresher.invalidate()
        }
    }

    func applicationDidEnterBackground() {
        webClient.setBackgrounded(true)
        storyWebClient.setBackgrounded(true)
    }

    func applicationDidBecomeActive() {
        webClient.setBackgrounded(false)
        storyWebClient.setBackgrounded(false)
        guard isAuthenticated else {
            if case .unavailable = state {
                Task { await start(force: true) }
            }
            return
        }

        let generation = sessionGeneration
        Task {
            do {
                try await validateSession(generation: generation)
            } catch {
                if isCurrentSession(generation) {
                    errorMessage = error.localizedDescription
                }
            }
        }
    }

    func signOut() async {
        if activeAction == .signOut {
            await waitForSignOut()
            return
        }
        signOutRequested = true
        guard activeAction == nil else {
            await waitForSignOut()
            return
        }
        await performPendingSignOut()
    }

    private func performPendingSignOut() async {
        guard signOutRequested, activeAction == nil else {
            return
        }
        signOutRequested = false
        activeAction = .signOut
        let signedInUsername = username
        if let signedInUsername {
            state = .signingOut(username: signedInUsername)
        }
        sessionGeneration &+= 1

        var websiteLogoutError: Error?
        if signedInUsername != nil {
            do {
                try await logoutThroughWebpage()
            } catch {
                websiteLogoutError = error
            }
        }

        do {
            try await clearSession(reloadWidgets: true)
        } catch {
            errorMessage = error.localizedDescription
        }
        activeAction = nil
        resumeSignOutWaiters()
        if let websiteLogoutError {
            errorMessage = "You were signed out of Claw, but Lobsters could not confirm its webpage logout: \(websiteLogoutError.localizedDescription)"
        }
    }

    private func waitForSignOut() async {
        await withCheckedContinuation { continuation in
            signOutWaiters.append(continuation)
        }
    }

    private func resumeSignOutWaiters() {
        let waiters = signOutWaiters
        signOutWaiters.removeAll()
        waiters.forEach { $0.resume() }
    }

    private var baseURL: URL {
        APIConfiguration.shared.baseURL
    }

    private static func log(_ error: Error, message: String) {
        let error = error as NSError
        logger.error(
            "\(message, privacy: .public) domain=\(error.domain, privacy: .public) code=\(error.code) description=\(error.localizedDescription, privacy: .public)"
        )
    }

    private static func logDescription(for url: URL?) -> String {
        guard let url else {
            return "none"
        }
        var components = URLComponents()
        components.scheme = url.scheme
        components.host = url.host
        components.port = url.port
        components.path = url.path
        return components.string ?? url.path
    }

    private func authenticatedGeneration() throws -> UInt {
        guard isEntitled, isAuthenticated else {
            throw SessionError.signedOut
        }
        return sessionGeneration
    }

    private func performVoteAction(
        script: String,
        shortID: String,
        desiredState: Bool,
        selector: String,
        generation: UInt
    ) async throws {
        var actionError: Error?
        do {
            let result = try await storyWebClient.callAsyncJavaScript(
                script,
                arguments: [
                    "shortID": shortID,
                    "desiredState": desiredState
                ]
            )
            let values = result as? [String: Any]
            let reportedState = values?["upvoted"] as? Bool
            let stage = values?["stage"] as? String ?? "missing"
            let pageError = values?["error"] as? String
            let pagePath = values?["pagePath"] as? String ?? "missing"
            let documentState = values?["documentState"] as? String ?? "missing"
            let online = (values?["online"] as? NSNumber)?.boolValue
            let requestPath = values?["requestPath"] as? String ?? "none"
            let requestMethod = values?["requestMethod"] as? String ?? "none"
            let responseStatus = (values?["responseStatus"] as? NSNumber)?.stringValue ?? "none"
            Self.logger.info(
                "Vote webpage result shortID=\(shortID, privacy: .public) desired=\(desiredState) reported=\(String(describing: reportedState), privacy: .public) stage=\(stage, privacy: .public) page=\(pagePath, privacy: .public) document=\(documentState, privacy: .public) online=\(String(describing: online), privacy: .public) request=\(requestMethod, privacy: .public) \(requestPath, privacy: .public) status=\(responseStatus, privacy: .public)"
            )
            if let pageError {
                Self.logger.error(
                    "Vote webpage error shortID=\(shortID, privacy: .public) stage=\(stage, privacy: .public) message=\(pageError, privacy: .public)"
                )
            }
            guard reportedState == desiredState, pageError == nil else {
                throw SessionError.voteDidNotChange
            }
            // The Lobsters handler completed its request and updated the DOM.
            // The native model is updated optimistically by StoryView, so a full
            // document reload is unnecessary on the successful path.
            return
        } catch {
            // The webpage action can finish before WebKit reports a JavaScript
            // bridge error. Verify the persisted page before surfacing failure.
            actionError = error
            Self.log(
                error,
                message: "Vote webpage action failed shortID=\(shortID) desired=\(desiredState)"
            )
        }

        guard isCurrentSession(generation) else {
            throw SessionError.signedOut
        }

        do {
            _ = try await storyWebClient.reload()
            guard isCurrentSession(generation) else {
                throw SessionError.signedOut
            }
            let result = try await storyWebClient.callAsyncJavaScript(
                "return document.querySelector(selector)?.classList.contains('upvoted') ?? null;",
                arguments: ["selector": selector]
            )
            let persistedState = result as? Bool
            Self.logger.info(
                "Vote reload verification shortID=\(shortID, privacy: .public) desired=\(desiredState) persisted=\(String(describing: persistedState), privacy: .public)"
            )
            if persistedState == desiredState {
                return
            }
        } catch {
            Self.log(
                error,
                message: "Vote reload verification failed shortID=\(shortID) desired=\(desiredState)"
            )
            if actionError == nil {
                throw error
            }
        }

        // WKWebView discards the underlying JavaScript exception message. Once
        // the reloaded webpage confirms no change, show the actionable vote error.
        throw SessionError.voteDidNotChange
    }

    private func perform<T>(
        _ action: Action,
        reloadOnFailure: Bool = true,
        operation: () async throws -> T
    ) async throws -> T {
        guard activeAction == nil, !signOutRequested else {
            throw SessionError.actionInProgress
        }
        activeAction = action
        do {
            let value = try await operation()
            activeAction = nil
            await performPendingSignOut()
            return value
        } catch {
            activeAction = nil
            Self.log(
                error,
                message: "Lobsters action failed action=\(String(describing: action))"
            )
            if reloadOnFailure, !signOutRequested {
                _ = try? await storyWebClient.reload()
            }
            await performPendingSignOut()
            throw error
        }
    }

    private func storyURL(shortID: String, commentsURL: URL?) -> URL {
        if APIConfiguration.shared.isLobstersURL(commentsURL) {
            return commentsURL!
        }
        return APIConfiguration.shared.storyURL(shortId: shortID)
    }

    private func ensureStoryPage(
        shortID: String,
        commentsURL: URL?
    ) async throws {
        if !storyWebClient.isLoading,
           APIConfiguration.shared.isLobstersURL(storyWebClient.currentURL),
           (try? await pageContainsStory(shortID)) == true {
            return
        }

        _ = try await storyWebClient.load(
            storyURL(shortID: shortID, commentsURL: commentsURL)
        )
        guard try await pageContainsStory(shortID) else {
            throw SessionError.storyPageUnavailable
        }
    }

    private func pageContainsStory(_ shortID: String) async throws -> Bool {
        let result = try await storyWebClient.callAsyncJavaScript(
            "return document.getElementById('story_' + shortID) !== null;",
            arguments: ["shortID": shortID]
        )
        return result as? Bool ?? false
    }

    private func logoutThroughWebpage() async throws {
        guard let storedCookie = try credentialStore.loadCookie(for: baseURL),
              let cookie = storedCookie.makeCookie() else {
            return
        }

        await webClient.setCookie(cookie)
        _ = try await webClient.load(APIConfiguration.shared.settingsURL())
        let submitted = try await webClient.callAsyncJavaScript(LobstersWebActions.logout) as? Bool ?? false
        guard submitted else {
            throw SessionError.logoutPageUnavailable
        }
        try await webClient.waitForCurrentNavigation()
    }

    private func discardCancelledLogin(generation: UInt) async {
        guard isCancelledLogin(generation: generation) else {
            return
        }
        await webClient.clearSensitivePageContents()
        guard isCancelledLogin(generation: generation) else {
            return
        }
        let cookies = await webClient.allCookies()
        guard isCancelledLogin(generation: generation) else {
            return
        }
        for cookie in cookies
        where StoredLobstersCookie(cookie, for: baseURL) != nil {
            await webClient.deleteCookie(cookie)
        }
        guard isCancelledLogin(generation: generation) else {
            return
        }
        try? credentialStore.deleteCookie(for: baseURL)

        do {
            try webClient.reset(to: selectedPageURL())
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func restoreSelectedPageAfterPrimaryFlow() {
        guard isEntitled else {
            restoreSelectedPageWhenPrimaryNavigationFinishes = false
            return
        }
        if webClient.isLoading {
            restoreSelectedPageWhenPrimaryNavigationFinishes = true
            return
        }
        restoreSelectedPageWhenPrimaryNavigationFinishes = false
        preparePage(for: selectedTab)
    }

    private func restoreSelectedPageIfRequested() {
        guard restoreSelectedPageWhenPrimaryNavigationFinishes else {
            return
        }
        restoreSelectedPageWhenPrimaryNavigationFinishes = false
        restoreSelectedPageAfterPrimaryFlow()
    }

    private func selectedPageURL() -> URL {
        switch selectedTab {
        case .Hottest:
            return APIConfiguration.shared.hottestWebpageURL()
        case .Newest:
            return APIConfiguration.shared.newestWebpageURL()
        case .Tags:
            let tags = UserDefaults.standard.stringArray(
                forKey: "selectedTags"
            ) ?? ["programming"]
            return APIConfiguration.shared.tagStoryWebpageURL(tags: tags)
        case .Settings:
            // Settings never replaces the last selected content tab.
            return APIConfiguration.shared.hottestWebpageURL()
        }
    }

    private func isCancelledLogin(generation: UInt) -> Bool {
        isCurrentSession(generation) && state == .signedOut
    }

    private func validateSession(generation: UInt) async throws {
        let page = try await pageLoader.load(baseURL)
        guard isEntitled, isCurrentSession(generation) else {
            return
        }
        let username = try await Task.detached(priority: .userInitiated, operation: {
            try LobstersHTMLParser.username(from: page.html)
        }).value
        guard isEntitled, isCurrentSession(generation) else {
            return
        }
        guard let username else {
            try await clearSession(reloadWidgets: true)
            return
        }

        let previousUsername = self.username
        coordinatedAuthenticationUsername = nil
        if previousUsername != username {
            contentRefresher.invalidate()
            // Install authenticated controls before exposing signed-in actions.
            // This retains the story WebView and refreshes its existing document.
            storyWebClient.reloadIfNeeded()
        }
        state = .signedIn(username: username)
        if let cookie = await sessionCookie() {
            await coordinator.didAuthenticate(
                username: username,
                cookie: cookie,
                source: self
            )
        }
        guard isCurrentSession(generation) else {
            return
        }
        await loadAvatarIfNeeded(for: username, generation: generation)
    }

    private func captureSessionFromWebView() async {
        await captureSession(from: webClient)
    }

    private func captureSession(from client: LobstersWebViewClient) async {
        guard isEntitled,
              activeAction != .signOut,
              Self.shouldCaptureSession(
                state: state,
                coordinatedAuthenticationUsername: coordinatedAuthenticationUsername
              ) else {
            return
        }
        let generation = sessionGeneration
        guard isCurrentSession(generation) else {
            return
        }

        do {
            let value = try await client.evaluateJavaScript(
                "document.body?.dataset?.username || ''"
            )
            guard isCurrentSession(generation) else {
                return
            }
            guard let username = value as? String, !username.isEmpty else {
                if coordinatedAuthenticationUsername != nil {
                    coordinatedAuthenticationUsername = nil
                    webClient.reloadIfNeeded()
                    return
                }
                if isAuthenticated {
                    try await clearSession(reloadWidgets: true)
                }
                return
            }

            let cookies = await client.allCookies()
            guard isCurrentSession(generation) else {
                return
            }
            guard let sessionCookie = cookies.first(where: {
                StoredLobstersCookie($0, for: baseURL) != nil
            }) else {
                if isAuthenticated {
                    try await clearSession(reloadWidgets: true)
                }
                return
            }

            try credentialStore.saveCookie(sessionCookie, for: baseURL)
            let previousUsername = self.username
            coordinatedAuthenticationUsername = nil
            if previousUsername != username {
                contentRefresher.invalidate()
                // The shared data store now has the authenticated cookie, but a
                // retained story document may still contain anonymous controls.
                storyWebClient.reloadIfNeeded()
            }
            state = .signedIn(username: username)
            await coordinator.didAuthenticate(
                username: username,
                cookie: sessionCookie,
                source: self
            )
            guard isCurrentSession(generation) else {
                return
            }
            await loadAvatarIfNeeded(for: username, generation: generation)
        } catch is CancellationError {
            return
        } catch {
            if isCurrentSession(generation) {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func loadAvatarIfNeeded(for username: String, generation: UInt) async {
        if self.username == username, avatarImage != nil {
            return
        }

        do {
            guard let avatar = try await avatarLoader.avatar(for: username) else {
                self.avatarURL = nil
                self.avatarImage = nil
                return
            }
            guard isCurrentSession(generation) else {
                return
            }
            self.avatarURL = avatar.url
            self.avatarImage = avatar.image
        } catch {
            if isCurrentSession(generation) {
                avatarURL = nil
                avatarImage = nil
            }
        }
    }

    private func clearSession(reloadWidgets: Bool) async throws {
        var credentialError: Error?
        do {
            try credentialStore.deleteCookie(for: baseURL)
        } catch {
            credentialError = error
        }

        await coordinator.didSignOut(source: self)
        contentRefresher.invalidate(reloadWidgets: reloadWidgets)
        if let credentialError {
            throw credentialError
        }
    }

    private func isCurrentSession(_ generation: UInt) -> Bool {
        generation == sessionGeneration
    }

    static func shouldCaptureSession(
        state: State,
        coordinatedAuthenticationUsername: String?
    ) -> Bool {
        if coordinatedAuthenticationUsername != nil {
            return true
        }
        switch state {
        case .signingIn, .signedIn:
            return true
        case .checking, .signedOut, .signingOut, .unavailable:
            return false
        }
    }

    fileprivate func applyCoordinatedAuthentication(
        username: String,
        cookie: HTTPCookie
    ) async {
        guard isEntitled, activeAction != .signOut else {
            return
        }
        await webClient.setCookie(cookie)
        await storyWebClient.setCookie(cookie)
        guard isEntitled, activeAction != .signOut else {
            return
        }
        if self.username == username, isAuthenticated {
            return
        }

        sessionGeneration &+= 1
        let generation = sessionGeneration
        coordinatedAuthenticationUsername = username
        webClient.reloadIfNeeded()
        storyWebClient.reloadIfNeeded()
        state = .signedIn(username: username)
        await loadAvatarIfNeeded(for: username, generation: generation)
    }

    fileprivate func applyCoordinatedSignOut(completeWaiters: Bool) async {
        sessionGeneration &+= 1
        restoreSelectedPageWhenPrimaryNavigationFinishes = false
        for cookie in await webClient.allCookies()
        where StoredLobstersCookie(cookie, for: baseURL) != nil {
            await webClient.deleteCookie(cookie)
        }

        state = .signedOut
        avatarURL = nil
        avatarImage = nil
        coordinatedAuthenticationUsername = nil
        signOutRequested = false
        if completeWaiters {
            resumeSignOutWaiters()
        }
        webClient.reloadIfNeeded()
        storyWebClient.reloadIfNeeded()
    }

    private func sessionCookie() async -> HTTPCookie? {
        let cookies = await webClient.allCookies()
        return cookies.first(where: {
            StoredLobstersCookie($0, for: baseURL) != nil
        })
    }

}

@MainActor
final class LobstersSessionCoordinator {
    static let shared = LobstersSessionCoordinator()

    private final class WeakSession {
        weak var value: LobstersSession?

        init(_ value: LobstersSession) {
            self.value = value
        }
    }

    private var sessions = [WeakSession]()

    func register(_ session: LobstersSession) {
        compactSessions()
        guard !sessions.contains(where: { $0.value === session }) else {
            return
        }
        sessions.append(WeakSession(session))
    }

    func didAuthenticate(
        username: String,
        cookie: HTTPCookie,
        source: LobstersSession
    ) async {
        compactSessions()
        for session in sessions.compactMap(\.value) where session !== source {
            await session.applyCoordinatedAuthentication(
                username: username,
                cookie: cookie
            )
        }
    }

    func didSignOut(source: LobstersSession) async {
        compactSessions()
        for session in sessions.compactMap(\.value) {
            await session.applyCoordinatedSignOut(
                completeWaiters: session !== source
            )
        }
    }

    private func compactSessions() {
        sessions.removeAll(where: { $0.value == nil })
    }
}
