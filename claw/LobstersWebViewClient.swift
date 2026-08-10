//
//  LobstersWebViewClient.swift
//  claw
//

import Foundation
import OSLog
import UIKit
import WebKit

@MainActor
private enum LobstersWebsiteDataStore {
    static let shared = WKWebsiteDataStore.nonPersistent()
}

@MainActor
final class LobstersWebViewClient: NSObject {
    private static let logger = Logger(
        subsystem: "com.twodayslate.claw",
        category: "LobstersWebView"
    )

    enum ClientError: LocalizedError {
        case unsupportedURL
        case navigationFailed
        case navigationTimedOut
        case javaScriptTimedOut
        case pageUnavailable

        var errorDescription: String? {
            switch self {
            case .unsupportedURL:
                return "Claw blocked a webpage outside the configured Lobsters website."
            case .navigationFailed:
                return "The Lobsters webpage did not finish loading."
            case .navigationTimedOut:
                return "The Lobsters webpage took too long to load."
            case .javaScriptTimedOut:
                return "The Lobsters webpage stopped responding."
            case .pageUnavailable:
                return "The expected Lobsters webpage is not available."
            }
        }
    }

    var onPageLoaded: ((URL) -> Void)?
    var onError: ((Error) -> Void)?

    private let configurationProvider: APIConfiguration
    private let dataStore: WKWebsiteDataStore
    private let reloadsAfterWebContentProcessTermination: Bool
    private var targetURL: URL?
    private var activeNavigation: WKNavigation?
    private(set) var completedNavigationCount = 0
    private var waiters = [UUID: NavigationWaiter]()
    private var javaScriptWaiters = [UUID: JavaScriptWaiter]()

    private struct NavigationWaiter {
        let navigationID: ObjectIdentifier
        let continuation: CheckedContinuation<URL, Error>
        var timeoutTask: Task<Void, Never>?
    }

    private struct JavaScriptWaiter {
        let continuation: CheckedContinuation<Any?, Error>
        var timeoutTask: Task<Void, Never>?
    }

    static func shouldReportNavigationError(_ error: Error) -> Bool {
        let error = error as NSError
        return error.domain != NSURLErrorDomain || error.code != NSURLErrorCancelled
    }

    init(
        configurationProvider: APIConfiguration = .shared,
        dataStore: WKWebsiteDataStore? = nil,
        reloadsAfterWebContentProcessTermination: Bool = true
    ) {
        self.configurationProvider = configurationProvider
        self.dataStore = dataStore ?? LobstersWebsiteDataStore.shared
        self.reloadsAfterWebContentProcessTermination = reloadsAfterWebContentProcessTermination
        super.init()
    }

    private var retainedWebView: WKWebView?

    var webView: WKWebView {
        if let retainedWebView {
            return retainedWebView
        }
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = dataStore
        configuration.preferences.inactiveSchedulingPolicy = .throttle

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = self
        webView.allowsBackForwardNavigationGestures = true
        retainedWebView = webView
        return webView
    }

    var currentURL: URL? {
        retainedWebView?.url
    }

    var isLoading: Bool {
        retainedWebView?.isLoading ?? false
    }

    var hasCreatedWebView: Bool {
        retainedWebView != nil
    }

    func setBackgrounded(_ backgrounded: Bool) {
        guard let webView = retainedWebView else {
            return
        }
        webView.configuration.preferences.inactiveSchedulingPolicy = backgrounded
            ? .suspend
            : .throttle
    }

    func navigateIfNeeded(to url: URL) throws {
        guard configurationProvider.isLobstersURL(url) else {
            throw ClientError.unsupportedURL
        }
        guard shouldNavigate(to: url) else {
            return
        }
        _ = try startNavigation(to: url)
    }

    func reset(to url: URL) throws {
        guard configurationProvider.isLobstersURL(url) else {
            throw ClientError.unsupportedURL
        }

        webView.stopLoading()
        targetURL = url
        webView.configuration.preferences.inactiveSchedulingPolicy = .none
        let request = URLRequest(
            url: url,
            cachePolicy: .reloadIgnoringLocalCacheData
        )
        guard let navigation = webView.load(request) else {
            throw ClientError.navigationFailed
        }
        activeNavigation = navigation
    }

    func clearSensitivePageContents() async {
        webView.stopLoading()
        targetURL = nil
        guard configurationProvider.isLobstersURL(currentURL) else {
            return
        }

        // Remove the form from the already-loaded document before relying on a
        // network navigation to replace it. This keeps cancelled credentials out
        // of the retained WebView even when the login-page reload fails.
        _ = try? await waitForJavaScript(timeout: .seconds(1)) { [webView] completion in
            webView.evaluateJavaScript(
                """
                (() => {
                    for (const field of document.querySelectorAll('input, textarea')) {
                        field.value = '';
                    }
                    document.documentElement.replaceChildren();
                })();
                """
            ) { value, error in
                if let error {
                    completion(.failure(error))
                } else {
                    completion(.success(value))
                }
            }
        }
    }

    @discardableResult
    func load(_ url: URL, timeout: Duration = .seconds(15)) async throws -> URL {
        guard configurationProvider.isLobstersURL(url) else {
            throw ClientError.unsupportedURL
        }

        if currentURL == url,
           Self.hasLoadedPage(
               targetURL: targetURL,
               currentURL: currentURL,
               isLoading: webView.isLoading
           ) {
            return url
        }

        let navigation: WKNavigation
        if targetURL == url, webView.isLoading, let activeNavigation {
            navigation = activeNavigation
        } else {
            navigation = try startNavigation(to: url)
        }
        return try await wait(for: navigation, timeout: timeout)
    }

    func reloadIfNeeded() {
        guard let webView = retainedWebView else {
            return
        }
        guard Self.hasLoadedPage(
            targetURL: targetURL,
            currentURL: currentURL,
            isLoading: webView.isLoading
        ) else {
            return
        }
        webView.configuration.preferences.inactiveSchedulingPolicy = .none
        activeNavigation = webView.reload()
    }

    @discardableResult
    func reload(timeout: Duration = .seconds(15)) async throws -> URL {
        try requireConfiguredPage()
        guard let navigation = webView.reload() else {
            throw ClientError.pageUnavailable
        }
        activeNavigation = navigation
        return try await wait(for: navigation, timeout: timeout)
    }

    func callAsyncJavaScript(
        _ script: String,
        arguments: [String: Any] = [:],
        timeout: Duration = .seconds(15)
    ) async throws -> Any? {
        try requireConfiguredPage()
        let callID = String(UUID().uuidString.prefix(8))
        Self.logger.debug(
            "JavaScript call \(callID, privacy: .public) started page=\(Self.logDescription(for: self.currentURL), privacy: .public) arguments=\(arguments.keys.sorted().joined(separator: ","), privacy: .public)"
        )
        do {
            let result = try await waitForJavaScript(timeout: timeout) { [webView] completion in
                webView.callAsyncJavaScript(
                    script,
                    arguments: arguments,
                    in: nil,
                    in: .page
                ) { result in
                    completion(result.map(Optional.some))
                }
            }
            Self.logger.debug(
                "JavaScript call \(callID, privacy: .public) completed"
            )
            return result
        } catch {
            Self.log(error, message: "JavaScript call \(callID) failed")
            throw error
        }
    }

    @discardableResult
    func callAsyncJavaScriptWaitingForNavigation(
        _ script: String,
        arguments: [String: Any] = [:],
        timeout: Duration = .seconds(15)
    ) async throws -> Any? {
        // Capture this before running the script. A form submission can navigate and
        // finish before callAsyncJavaScript returns, especially on a fast local server.
        let startingNavigationCount = completedNavigationCount
        let result = try await callAsyncJavaScript(
            script,
            arguments: arguments,
            timeout: timeout
        )
        try await waitForNavigation(
            after: startingNavigationCount,
            timeout: timeout
        )
        return result
    }

    func evaluateJavaScript(
        _ script: String,
        timeout: Duration = .seconds(15)
    ) async throws -> Any? {
        try requireConfiguredPage()
        return try await waitForJavaScript(timeout: timeout) { [webView] completion in
            webView.evaluateJavaScript(script) { value, error in
                if let error {
                    completion(.failure(error))
                } else {
                    completion(.success(value))
                }
            }
        }
    }

    func setCookie(_ cookie: HTTPCookie) async {
        await withCheckedContinuation { continuation in
            dataStore.httpCookieStore.setCookie(cookie) {
                continuation.resume()
            }
        }
    }

    func allCookies() async -> [HTTPCookie] {
        await withCheckedContinuation { continuation in
            dataStore.httpCookieStore.getAllCookies { cookies in
                continuation.resume(returning: cookies)
            }
        }
    }

    func deleteCookie(_ cookie: HTTPCookie) async {
        await withCheckedContinuation { continuation in
            dataStore.httpCookieStore.delete(cookie) {
                continuation.resume()
            }
        }
    }

    static func shouldNavigate(
        to requestedURL: URL,
        targetURL: URL?,
        currentURL: URL?,
        isLoading: Bool
    ) -> Bool {
        guard targetURL == requestedURL else {
            return true
        }
        return !isLoading && currentURL != requestedURL
    }

    static func hasLoadedPage(
        targetURL: URL?,
        currentURL: URL?,
        isLoading: Bool
    ) -> Bool {
        !isLoading && targetURL != nil && targetURL == currentURL
    }

    private func shouldNavigate(to url: URL) -> Bool {
        Self.shouldNavigate(
            to: url,
            targetURL: targetURL,
            currentURL: currentURL,
            isLoading: webView.isLoading
        )
    }

    @discardableResult
    private func startNavigation(to url: URL) throws -> WKNavigation {
        targetURL = url
        webView.configuration.preferences.inactiveSchedulingPolicy = .none
        guard let navigation = webView.load(URLRequest(url: url)) else {
            throw ClientError.navigationFailed
        }
        activeNavigation = navigation
        return navigation
    }

    private func wait(
        for navigation: WKNavigation,
        timeout: Duration
    ) async throws -> URL {
        let waiterID = UUID()
        let navigationID = ObjectIdentifier(navigation)

        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                waiters[waiterID] = NavigationWaiter(
                    navigationID: navigationID,
                    continuation: continuation,
                    timeoutTask: nil
                )
                waiters[waiterID]?.timeoutTask = Task { [weak self] in
                    try? await Task.sleep(for: timeout)
                    guard !Task.isCancelled else {
                        return
                    }
                    self?.completeWaiter(
                        waiterID,
                        with: .failure(ClientError.navigationTimedOut)
                    )
                }
            }
        } onCancel: {
            Task { @MainActor [weak self] in
                self?.completeWaiter(waiterID, with: .failure(CancellationError()))
            }
        }
    }

    private func waitForNavigation(
        after navigationCount: Int,
        timeout: Duration
    ) async throws {
        let clock = ContinuousClock()
        let deadline = clock.now.advanced(by: timeout)

        while clock.now < deadline {
            if completedNavigationCount > navigationCount, !webView.isLoading {
                return
            }
            try await Task.sleep(for: .milliseconds(25))
        }

        throw ClientError.navigationTimedOut
    }

    private func completeWaiters(
        for navigation: WKNavigation?,
        result: Result<URL, Error>
    ) {
        guard let navigation else {
            return
        }
        let navigationID = ObjectIdentifier(navigation)
        let waiterIDs = waiters.compactMap { id, waiter in
            waiter.navigationID == navigationID ? id : nil
        }
        for waiterID in waiterIDs {
            completeWaiter(waiterID, with: result)
        }
    }

    private func completeWaiter(_ id: UUID, with result: Result<URL, Error>) {
        guard let waiter = waiters.removeValue(forKey: id) else {
            return
        }
        waiter.timeoutTask?.cancel()
        waiter.continuation.resume(with: result)
    }

    private func waitForJavaScript(
        timeout: Duration,
        operation: @escaping @MainActor (
            @escaping @MainActor @Sendable (Result<Any?, Error>) -> Void
        ) -> Void
    ) async throws -> Any? {
        let waiterID = UUID()

        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                javaScriptWaiters[waiterID] = JavaScriptWaiter(
                    continuation: continuation,
                    timeoutTask: nil
                )
                operation { [weak self] result in
                    self?.completeJavaScriptWaiter(
                        waiterID,
                        with: result
                    )
                }
                javaScriptWaiters[waiterID]?.timeoutTask = Task { [weak self] in
                    try? await Task.sleep(for: timeout)
                    guard !Task.isCancelled else {
                        return
                    }
                    Self.logger.error(
                        "JavaScript call timed out after \(String(describing: timeout), privacy: .public)"
                    )
                    self?.completeJavaScriptWaiter(
                        waiterID,
                        with: .failure(ClientError.javaScriptTimedOut)
                    )
                }
            }
        } onCancel: {
            Task { @MainActor [weak self] in
                self?.completeJavaScriptWaiter(
                    waiterID,
                    with: .failure(CancellationError())
                )
            }
        }
    }

    private func completeJavaScriptWaiter(
        _ id: UUID,
        with result: Result<Any?, Error>
    ) {
        guard let waiter = javaScriptWaiters.removeValue(forKey: id) else {
            return
        }
        waiter.timeoutTask?.cancel()
        waiter.continuation.resume(with: result)
    }

    private func requireConfiguredPage() throws {
        guard configurationProvider.isLobstersURL(currentURL),
              Self.hasLoadedPage(
                  targetURL: targetURL,
                  currentURL: currentURL,
                  isLoading: webView.isLoading
              ) else {
            throw ClientError.pageUnavailable
        }
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

    private func completeNavigation(_ navigation: WKNavigation?) {
        if navigation === activeNavigation {
            activeNavigation = nil
        }
    }

    private func failNavigation(_ navigation: WKNavigation?) {
        if navigation === activeNavigation {
            activeNavigation = nil
            // The committed URL may still match a page whose replacement failed.
            // Clear the target so the next request retries instead of deduplicating.
            targetURL = nil
        }
    }
}

extension LobstersWebViewClient: WKNavigationDelegate {
    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        activeNavigation = navigation
    }

    func webView(
        _ webView: WKWebView,
        decidePolicyFor navigationAction: WKNavigationAction,
        decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
    ) {
        guard let url = navigationAction.request.url else {
            decisionHandler(.cancel)
            return
        }

        guard configurationProvider.isLobstersURL(url) else {
            if navigationAction.navigationType == .linkActivated,
               (url.scheme == "http" || url.scheme == "https") {
                UIApplication.shared.open(url)
            }
            decisionHandler(.cancel)
            return
        }

        targetURL = url
        decisionHandler(.allow)
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        completedNavigationCount += 1
        webView.configuration.preferences.inactiveSchedulingPolicy = .throttle
        let url = webView.url ?? targetURL ?? configurationProvider.baseURL
        targetURL = url
        Self.logger.debug(
            "Navigation finished page=\(Self.logDescription(for: url), privacy: .public)"
        )
        completeWaiters(for: navigation, result: .success(url))
        completeNavigation(navigation)
        onPageLoaded?(url)
    }

    func webView(
        _ webView: WKWebView,
        didFail navigation: WKNavigation!,
        withError error: Error
    ) {
        webView.configuration.preferences.inactiveSchedulingPolicy = .throttle
        completeWaiters(for: navigation, result: .failure(error))
        failNavigation(navigation)
        Self.log(error, message: "Navigation failed")
        if Self.shouldReportNavigationError(error) {
            onError?(error)
        }
    }

    func webView(
        _ webView: WKWebView,
        didFailProvisionalNavigation navigation: WKNavigation!,
        withError error: Error
    ) {
        webView.configuration.preferences.inactiveSchedulingPolicy = .throttle
        completeWaiters(for: navigation, result: .failure(error))
        failNavigation(navigation)
        Self.log(error, message: "Provisional navigation failed")
        if Self.shouldReportNavigationError(error) {
            onError?(error)
        }
    }

    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        Self.logger.error(
            "Web content process terminated page=\(Self.logDescription(for: self.currentURL), privacy: .public)"
        )
        if reloadsAfterWebContentProcessTermination {
            reloadIfNeeded()
        } else {
            // An offscreen story page is recoverable. Let the system reclaim its
            // process and reload lazily the next time that story is needed.
            let terminatedNavigation = activeNavigation
            completeWaiters(
                for: terminatedNavigation,
                result: .failure(ClientError.pageUnavailable)
            )
            failNavigation(terminatedNavigation)
        }
    }
}
