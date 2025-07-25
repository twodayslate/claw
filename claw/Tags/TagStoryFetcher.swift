import Foundation
import SwiftUI
import Combine

@MainActor
class TagStoryFetcher: GenericArrayFetcher<NewestStory> {
    
    static var cachedStories = [[String]: [NewestStory]]()
    
    var tags: [String] {
        didSet {
            self.page = 1
            if let cachedStories = TagStoryFetcher.cachedStories[self.tags] {
                self.items = cachedStories
            } else {
                self.items = []
            }
        }
    }

    init(tags: [String] = []) {
        self.tags = tags
    }

    override func load() async throws {
        if isLoading {
            return
        }
        page = 1
        isLoading = true
        defer {
            isLoading = false
        }

        if let cachedStories = TagStoryFetcher.cachedStories[self.tags], self.items != cachedStories {
            self.items = cachedStories
        }

        let url = APIConfiguration.shared.tagStoryURL(tags: self.tags, page: self.page)
        
        let (data, _) = try await URLSession.shared.data(from: url)
        let decodedLists = try JSONDecoder().decode([NewestStory].self, from: data)
        
        if TagStoryFetcher.cachedStories.count > 10 {
            // xxx: I'd like to remove the last used cache but this will do for now
            TagStoryFetcher.cachedStories.removeAll()
        }
        TagStoryFetcher.cachedStories[self.tags] = decodedLists
        self.items = decodedLists
        self.page += 1
    }

    override func more(_ story: NewestStory? = nil) async throws {
        guard self.items.last == story, !isLoadingMore else {
            return
        }
        isLoadingMore = true
        defer {
            isLoadingMore = false
        }

        let url = APIConfiguration.shared.tagStoryURL(tags: self.tags, page: self.page)

        let (data, _) = try await URLSession.shared.data(from: url)
        let stories = try JSONDecoder().decode([NewestStory].self, from: data)
        for story in stories {
            if !self.items.contains(story) {
                self.items.append(story)
            }
        }
        TagStoryFetcher.cachedStories[self.tags] = self.items
        self.page += 1
    }
}
