import Foundation
import SwiftUI
import Combine

@MainActor
class TagStoryFetcher: GenericArrayFetcher<NewestStory> {

    private final class WeakReference {
        weak var value: TagStoryFetcher?

        init(_ value: TagStoryFetcher) {
            self.value = value
        }
    }

    static var cachedStories = [[String]: ParsedStoryList]()
    private static var liveFetchers = [WeakReference]()
    
    var tags: [String] {
        didSet {
            guard tags != oldValue else { return }
            supersedePendingLoads()
            hasLoadedContent = false
            hasMorePages = true
            hasAttemptedLoad = false
            loadFailed = false
            self.page = 1
            self.items = []
            self.skippedStoryCount = 0
        }
    }

    private let pageLoader: LobstersPageLoader

    init(tags: [String] = [], pageLoader: LobstersPageLoader = .shared) {
        self.pageLoader = pageLoader
        self.tags = tags
        super.init()
        Self.liveFetchers.append(WeakReference(self))
    }

    static func reloadLiveFetchers() async {
        liveFetchers.removeAll { $0.value == nil }
        for fetcher in liveFetchers.compactMap(\.value) where fetcher.hasRequestedContent {
            try? await fetcher.loadSupersedingPendingLoads()
        }
    }

    static func invalidateLiveContent() {
        cachedStories.removeAll()
        liveFetchers.removeAll { $0.value == nil }
        for fetcher in liveFetchers.compactMap(\.value) {
            fetcher.invalidateContent()
        }
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

        // Another view may have replaced the shared cache with fewer pages.
        // Keep this view's content and warning paired with its page cursor
        // until the refresh succeeds.
        if self.items.isEmpty, let cachedStories = TagStoryFetcher.cachedStories[self.tags] {
            self.items = cachedStories.stories
            self.skippedStoryCount = cachedStories.skippedStoryCount
            // This cache can contain several pages but has no cursor. Do not
            // paginate it unless a successful first-page refresh resets us.
            self.hasMorePages = false
        }

        let url = APIConfiguration.shared.tagStoryWebpageURL(tags: self.tags, page: 1)
        let page: LoadedLobstersPage
        do {
            page = try await pageLoader.load(url)
        } catch LobstersPageLoaderError.unsuccessfulStatusCode(404) {
            guard isCurrentContentGeneration(generation) else {
                return
            }
            hasLoadedContent = true
            hasMorePages = false
            // A saved tag can be absent when a Debug build switches to the local
            // test server. Treat that valid local state as an empty feed.
            TagStoryFetcher.cachedStories[self.tags] = ParsedStoryList(stories: [], skippedStoryCount: 0)
            self.items = []
            self.skippedStoryCount = 0
            self.loadFailed = false
            return
        } catch {
            guard isCurrentContentGeneration(generation) else {
                return
            }
            loadFailed = true
            throw error
        }
        let decodedLists: ParsedStoryList
        do {
            decodedLists = try await StoryListHTMLParser.parseOffMain(
                page.html,
                pageURL: page.response.url ?? url
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
        
        if TagStoryFetcher.cachedStories.count > 10 {
            // xxx: I'd like to remove the last used cache but this will do for now
            TagStoryFetcher.cachedStories.removeAll()
        }
        TagStoryFetcher.cachedStories[self.tags] = decodedLists
        replaceStoryPage(decodedLists)
    }

    override func more(_ story: NewestStory? = nil) async throws {
        guard let story, self.items.last?.id == story.id, hasMorePages, !isLoading, !isLoadingMore else {
            return
        }
        let generation = captureContentGeneration()
        isLoadingMore = true
        defer {
            if isCurrentContentGeneration(generation) {
                isLoadingMore = false
            }
        }

        let url = APIConfiguration.shared.tagStoryWebpageURL(tags: self.tags, page: self.page)
        let stories: ParsedStoryList
        do {
            let page = try await pageLoader.load(url)
            stories = try await StoryListHTMLParser.parseOffMain(
                page.html,
                pageURL: page.response.url ?? url
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
        appendStoryPage(stories)
        TagStoryFetcher.cachedStories[self.tags] = ParsedStoryList(
            stories: self.items, skippedStoryCount: self.skippedStoryCount
        )
    }
}
