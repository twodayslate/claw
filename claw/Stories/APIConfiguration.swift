//
//  APIConfiguration.swift
//  claw
//
//  Created by AI Assistant on 12/14/24.
//

import Foundation

/// Centralized API configuration for the Claw app
/// Handles base URL configuration for different build configurations
/// 
/// ## Usage for Local Development:
/// To use your local docker-lobsters instance, change the DEBUG baseURL:
/// ```swift
/// #if DEBUG
/// return "http://localhost:3000"  // Your local server
/// #else
/// return "https://lobste.rs"      // Production server
/// #endif
/// ```
///
/// This ensures:
/// - Debug builds use your local development server
/// - Release builds always use the production lobste.rs server
/// - All API calls are centralized in one location
class APIConfiguration {
    static let shared = APIConfiguration()
    
    private init() {}
    
    /// Base URL for the Lobsters API
    /// Debug builds can be easily changed to point to local development server
    /// Release builds always use production server
    var baseURL: String {
        #if DEBUG
        // For development, change this to your local docker-lobsters instance
        // Example: "http://localhost:3000"
        return "http://localhost:3000"
        #else
        // Production always uses lobste.rs
        return "https://lobste.rs"
        #endif
    }
    
    // MARK: - API Endpoints
    
    func userURL(username: String) -> URL {
        return URL(string: "\(baseURL)/~\(username).json")!
    }
    
    func storyURL(shortId: String) -> URL {
        return URL(string: "\(baseURL)/s/\(shortId).json")!
    }
    
    func hottestURL(page: Int) -> URL {
        return URL(string: "\(baseURL)/hottest.json?page=\(page)")!
    }
    
    func hottestPageURL(page: Int) -> URL {
        return URL(string: "\(baseURL)/page/\(page).json")!
    }
    
    func newestURL(page: Int) -> URL {
        return URL(string: "\(baseURL)/newest.json?page=\(page)")!
    }
    
    func newestPageURL(page: Int) -> URL {
        return URL(string: "\(baseURL)/newest/page/\(page).json")!
    }
    
    func tagsURL() -> URL {
        return URL(string: "\(baseURL)/tags.json")!
    }
    
    func tagStoryURL(tags: [String], page: Int) -> URL {
        return URL(string: "\(baseURL)/t/\(tags.joined(separator: ",")).json?page=\(page)")!
    }
    
    func tagStoryURL(tags: [String]) -> URL {
        return URL(string: "\(baseURL)/t/\(tags.joined(separator: ",")).json")!
    }
    
    func userAvatarURL(avatarPath: String) -> URL? {
        return URL(string: "\(baseURL)/\(avatarPath)")
    }
    
    func isLobstersHost(_ host: String?) -> Bool {
        guard let host = host else { return false }
        guard let url = URL(string: baseURL) else { return false }
        return url.host == host
    }
}
