import Foundation
import SwiftUI

@MainActor
class HottestFetcher: GenericArrayFetcher<NewestStory> {

    // we need a shared object as a not singleton will be deinitialized after about 2
    // navigation views deep
    static var shared = HottestFetcher()
    
    override func load() async throws {
        if isLoading {
            return
        }
        page = 1
        isLoading = true
        defer {
            isLoading = false
        }
        let url = APIConfiguration.shared.hottestURL(page: self.page)
        let (data, _) = try await URLSession.shared.data(from: url)
        let decodedLists = try JSONDecoder().decode([NewestStory].self, from: data)
        
        self.items = decodedLists
        self.page += 1
    }

    override func more(_ story: NewestStory? = nil) async throws {
        guard self.items.last == story && !isLoadingMore else {
            return
        }
        let url = APIConfiguration.shared.hottestPageURL(page: self.page)
        isLoadingMore = true
        defer { isLoadingMore = false }

        let (data, _) = try await URLSession.shared.data(from: url)
        let decodedLists = try JSONDecoder().decode([NewestStory].self, from: data)

        let stories = decodedLists
        for story in stories {
            if !self.items.contains(story) {
                self.items.append(story)
            }
        }
        self.page += 1

    }
}
