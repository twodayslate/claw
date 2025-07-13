import Foundation
import SwiftUI

@MainActor
class TagFetcher: ObservableObject {
    @Published var tags = TagFetcher.cachedTags
    
    static var userDefaults = UserDefaults.standard
    static private var userDefaultCacheKey = "TagFetcher.cachedTags"

    /// Tag's don't change that often so we can cache them on the device
    static var cachedTags: [Tag] = {
        if let data = userDefaults.object(forKey: userDefaultCacheKey) as? Data, let saved = try? PropertyListDecoder().decode([Tag].self, from: data) {
            return saved
        }
        return [Tag]()
    }() {
        didSet {
            if let encodedTags = try? PropertyListEncoder().encode(cachedTags) {
                userDefaults.set(encodedTags, forKey: userDefaultCacheKey)
            }
        }
    }
        
    static var shared = TagFetcher()
    
    init() {
        Task {
            // refresh our tag list once per app instance. Since we really only use this as .shared this is once per app load
            do {
                try await self.load()
            } catch {
                print("Unable to fetch tags", error)
            }
        }
    }
    
    @Published var isLoading = false
    
    func loadIfEmpty() async throws {
        if self.tags.isEmpty {
            try await load()
        }
    }
    
    func load() async throws {
        if isLoading {
            return
        }
        
        isLoading = true
        defer {
            isLoading = false
        }
        let url = APIConfiguration.shared.tagsURL()
        
        var request = URLRequest(url: url)
        request.setUserAgent()
        
        let (data, _) = try await URLSession.shared.data(for: request)
        
        let decodedLists = try JSONDecoder().decode([Tag].self, from: data)
        
        let sorted = decodedLists.sorted(by: {$0.tag < $1.tag})
        TagFetcher.cachedTags = sorted
        self.tags = sorted
    }
}
