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
        let generation = captureContentGeneration()
        hasAttemptedLoad = true
        page = 1
        isLoading = true
        defer {
            if isCurrentContentGeneration(generation) {
                isLoading = false
            }
        }
        let decodedLists: [NewestStory]
        do {
            let url = APIConfiguration.shared.hottestWebpageURL(page: self.page)
            let loadedPage = try await LobstersPageLoader.shared.load(url)
            decodedLists = try await StoryListHTMLParser.parseOffMain(
                loadedPage.html,
                pageURL: loadedPage.response.url ?? url
            )
        } catch {
            guard isCurrentContentGeneration(generation) else {
                return
            }
            throw error
        }
        guard isCurrentContentGeneration(generation) else {
            return
        }
        
        self.items = decodedLists
        self.page += 1
    }

    override func more(_ story: NewestStory? = nil) async throws {
        guard self.items.last == story && !isLoadingMore else {
            return
        }
        let generation = captureContentGeneration()
        let url = APIConfiguration.shared.hottestWebpageURL(page: self.page)
        isLoadingMore = true
        defer {
            if isCurrentContentGeneration(generation) {
                isLoadingMore = false
            }
        }

        let decodedLists: [NewestStory]
        do {
            let loadedPage = try await LobstersPageLoader.shared.load(url)
            decodedLists = try await StoryListHTMLParser.parseOffMain(
                loadedPage.html,
                pageURL: loadedPage.response.url ?? url
            )
        } catch {
            guard isCurrentContentGeneration(generation) else {
                return
            }
            throw error
        }
        guard isCurrentContentGeneration(generation) else {
            return
        }

        let stories = decodedLists
        for story in stories {
            if !self.items.contains(story) {
                self.items.append(story)
            }
        }
        self.page += 1

    }
}
