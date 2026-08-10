//
//  APIConfiguration.swift
//  claw
//
//  Created by AI Assistant on 12/14/24.
//

import Foundation

/// Centralized Lobsters website configuration for the Claw app.
/// Handles the base URL for different build configurations.
/// 
/// Debug builds default to the local Docker test server and expose a server
/// switch in Settings. Release builds always use the production website.
final class APIConfiguration: Sendable {
    static let shared = APIConfiguration()

    #if DEBUG
    enum DebugServer: String, CaseIterable, Identifiable {
        case local
        case production

        var id: String { rawValue }

        var title: String {
            switch self {
            case .local: return "Local Test Server"
            case .production: return "Production"
            }
        }
    }

    private static let appGroupSuiteName = "group.com.twodayslate.claw"
    private static let debugServerDefaultsKey = "lobstersDebugServer"
    private static let uiTestBaseURLDefaultsKey = "clawUITestBaseURL"

    private static var debugDefaults: UserDefaults {
        UserDefaults(suiteName: appGroupSuiteName) ?? .standard
    }
    #endif
    
    private init() {}
    
    /// Base URL for the configured Lobsters website.
    var baseURL: URL {
        #if DEBUG
        if let uiTestBaseURL {
            return uiTestBaseURL
        }
        switch debugServer {
        case .local:
            return URL(string: "http://localhost:3000")!
        case .production:
            return URL(string: "https://lobste.rs")!
        }
        #else
        return URL(string: "https://lobste.rs")!
        #endif
    }

    #if DEBUG
    private var uiTestBaseURL: URL? {
        let processInfo = ProcessInfo.processInfo
        let value = processInfo.environment["CLAW_UI_TEST_BASE_URL"]
            ?? (processInfo.arguments.contains("--claw-ui-testing")
                ? UserDefaults.standard.string(
                    forKey: Self.uiTestBaseURLDefaultsKey
                )
                : nil)
        guard let value,
              let url = URL(string: value),
              url.scheme?.lowercased() == "http",
              ["localhost", "127.0.0.1"].contains(
                url.host?.lowercased() ?? ""
              ) else {
            return nil
        }
        return url
    }

    var debugServer: DebugServer {
        // Automated UI traffic must always stay on the disposable local
        // Lobsters instance, even if this Simulator previously selected prod.
        if ProcessInfo.processInfo.arguments.contains("--claw-ui-testing") {
            return .local
        }
        guard let value = Self.debugDefaults.string(
            forKey: Self.debugServerDefaultsKey
        ) else {
            return .local
        }
        return DebugServer(rawValue: value) ?? .local
    }

    func setDebugServer(_ server: DebugServer) {
        Self.debugDefaults.set(
            server.rawValue,
            forKey: Self.debugServerDefaultsKey
        )
    }
    #endif
    
    // MARK: - Website routes
    
    func userURL(username: String) -> URL {
        url(path: "/~\(username).json")
    }

    func userPageURL(username: String) -> URL {
        url(path: "/~\(username)")
    }

    func loginURL() -> URL {
        url(path: "/login")
    }

    func settingsURL() -> URL {
        url(path: "/settings")
    }

    func newStoryURL() -> URL {
        url(path: "/stories/new")
    }

    func hottestWebpageURL(page: Int = 1) -> URL {
        if page <= 1 {
            return baseURL
        }
        return url(path: "/page/\(page)")
    }

    func newestWebpageURL(page: Int = 1) -> URL {
        if page <= 1 {
            return url(path: "/newest")
        }
        return url(path: "/newest/page/\(page)")
    }

    func tagStoryWebpageURL(tags: [String], page: Int = 1) -> URL {
        let tagPath = tags.joined(separator: ",")
        if page <= 1 {
            return url(path: "/t/\(tagPath)")
        }
        return url(path: "/t/\(tagPath)/page/\(page)")
    }
    
    func storyURL(shortId: String) -> URL {
        url(path: "/s/\(shortId)")
    }
    
    func tagsURL() -> URL {
        url(path: "/tags.json")
    }
    
    func userAvatarURL(avatarPath: String) -> URL? {
        URL(string: avatarPath, relativeTo: baseURL)?.absoluteURL
    }
    
    func isLobstersHost(_ host: String?) -> Bool {
        host?.lowercased() == baseURL.host?.lowercased()
    }

    func isLobstersURL(_ url: URL?) -> Bool {
        guard let url else {
            return false
        }
        return url.scheme?.lowercased() == baseURL.scheme?.lowercased()
            && url.host?.lowercased() == baseURL.host?.lowercased()
            && effectivePort(for: url) == effectivePort(for: baseURL)
    }

    private func url(path: String) -> URL {
        var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)!
        components.path = path
        return components.url!
    }

    private func effectivePort(for url: URL) -> Int? {
        if let port = url.port {
            return port
        }
        switch url.scheme?.lowercased() {
        case "http": return 80
        case "https": return 443
        default: return nil
        }
    }
}
