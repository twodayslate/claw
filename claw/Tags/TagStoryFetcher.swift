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

    static var cachedStories = [[String]: [NewestStory]]()
    private static var liveFetchers = [WeakReference]()
    
    var tags: [String] {
        didSet {
            supersedePendingLoads()
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
        super.init()
        Self.liveFetchers.append(WeakReference(self))
    }

    static func reloadLiveFetchers() async {
        liveFetchers.removeAll { $0.value == nil }
        for fetcher in liveFetchers.compactMap(\.value) {
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
        let generation = captureContentGeneration()
        hasAttemptedLoad = true
        page = 1
        isLoading = true
        defer {
            if isCurrentContentGeneration(generation) {
                isLoading = false
            }
        }

        if let cachedStories = TagStoryFetcher.cachedStories[self.tags], self.items != cachedStories {
            self.items = cachedStories
        }

        let url = APIConfiguration.shared.tagStoryWebpageURL(tags: self.tags, page: self.page)
        let page: LoadedLobstersPage
        do {
            page = try await LobstersPageLoader.shared.load(url)
        } catch LobstersPageLoaderError.unsuccessfulStatusCode(404) {
            guard isCurrentContentGeneration(generation) else {
                return
            }
            // A saved tag can be absent when a Debug build switches to the local
            // test server. Treat that valid local state as an empty feed.
            TagStoryFetcher.cachedStories[self.tags] = []
            self.items = []
            return
        } catch {
            guard isCurrentContentGeneration(generation) else {
                return
            }
            throw error
        }
        let decodedLists: [NewestStory]
        do {
            decodedLists = try await StoryListHTMLParser.parseOffMain(
                page.html,
                pageURL: page.response.url ?? url
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
        let generation = captureContentGeneration()
        isLoadingMore = true
        defer {
            if isCurrentContentGeneration(generation) {
                isLoadingMore = false
            }
        }

        let url = APIConfiguration.shared.tagStoryWebpageURL(tags: self.tags, page: self.page)
        let stories: [NewestStory]
        do {
            let page = try await LobstersPageLoader.shared.load(url)
            stories = try await StoryListHTMLParser.parseOffMain(
                page.html,
                pageURL: page.response.url ?? url
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
        for story in stories {
            if !self.items.contains(story) {
                self.items.append(story)
            }
        }
        TagStoryFetcher.cachedStories[self.tags] = self.items
        self.page += 1
    }
}
