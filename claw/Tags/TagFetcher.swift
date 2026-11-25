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
    
    private let pageLoader: LobstersPageLoader

    init(pageLoader: LobstersPageLoader = .shared) {
        self.pageLoader = pageLoader
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
        
        let data = try await pageLoader.data(from: url)
        
        let decodedLists = try JSONDecoder().decode([Tag].self, from: data)
        
        let sorted = decodedLists.sorted(by: {$0.tag < $1.tag})
        TagFetcher.cachedTags = sorted
        self.tags = sorted
    }
}
