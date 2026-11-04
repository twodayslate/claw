import Foundation
import SwiftUI

@MainActor
class HottestFetcher: GenericArrayFetcher<NewestStory> {

    // we need a shared object as a not singleton will be deinitialized after about 2
    // navigation views deep
    static var shared = HottestFetcher()
    
    private let pageLoader: LobstersPageLoader

    init(pageLoader: LobstersPageLoader = .shared) {
        self.pageLoader = pageLoader
        super.init()
    }

    override func load() async throws {
        if isLoading {
            return
        }
        let generation = captureContentGeneration()
        hasAttemptedLoad = true
        isLoading = true
        defer {
            if isCurrentContentGeneration(generation) {
                isLoading = false
            }
        }
        let decodedLists: ParsedStoryList
        do {
            let url = APIConfiguration.shared.hottestWebpageURL(page: 1)
            let loadedPage = try await pageLoader.load(url)
            decodedLists = try await StoryListHTMLParser.parseOffMain(
                loadedPage.html,
                pageURL: loadedPage.response.url ?? url
            )
        } catch {
            guard isCurrentContentGeneration(generation) else {
                return
            }
            loadFailed = true
            throw error
        }
        guard isCurrentContentGeneration(generation) else {
            return
        }
        
        self.items = decodedLists.stories
        self.skippedStoryCount = decodedLists.skippedStoryCount
        self.loadFailed = false
        self.page = 2
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

        let decodedLists: ParsedStoryList
        do {
            let loadedPage = try await pageLoader.load(url)
            decodedLists = try await StoryListHTMLParser.parseOffMain(
                loadedPage.html,
                pageURL: loadedPage.response.url ?? url
            )
        } catch {
            guard isCurrentContentGeneration(generation) else {
                return
            }
            loadFailed = true
            throw error
        }
        guard isCurrentContentGeneration(generation) else {
            return
        }

        let stories = decodedLists
        for story in stories.stories {
            if !self.items.contains(story) {
                self.items.append(story)
            }
        }
        self.skippedStoryCount += stories.skippedStoryCount
        self.loadFailed = false
        self.page += 1

    }
}
