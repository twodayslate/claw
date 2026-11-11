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
        // A refresh replaces the pagination cursor and supersedes its result.
        if isLoadingMore { supersedePendingLoads() }
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
        
        replaceStoryPage(decodedLists)
    }

    override func more(_ story: NewestStory? = nil) async throws {
        guard let story, self.items.last?.id == story.id, hasMorePages, !isLoading, !isLoadingMore else {
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

        appendStoryPage(decodedLists)

    }
}
