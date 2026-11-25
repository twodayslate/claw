import Foundation
import Combine
import SwiftUI

@MainActor
class GenericArrayFetcher<T: Hashable & Codable>: ObservableObject {
    @Published var items = [T]()

    @Published var isLoadingMore = false
    @Published var isReloading = false
    @Published var isLoading = false
    @Published var hasAttemptedLoad = false {
        didSet { if hasAttemptedLoad { hasRequestedContent = true } }
    }
    // Survives origin invalidation so an already-open screen can be refreshed.
    private(set) var hasRequestedContent = false
    @Published var skippedStoryCount = 0
    @Published var loadFailed = false

    public internal(set) var page: Int = 1
    private var contentGeneration: UInt = 0
    var hasLoadedContent = false
    var hasMorePages = true

    /// Captures the generation associated with a network load. Subclasses must
    /// verify it before publishing results from an asynchronous request.
    func captureContentGeneration() -> UInt {
        contentGeneration
    }

    func isCurrentContentGeneration(_ generation: UInt) -> Bool {
        generation == contentGeneration
    }

    /// Starts a fresh load while making any in-flight load ineligible to
    /// publish. This is used when authentication changes the rendered webpage.
    func supersedePendingLoads() {
        contentGeneration &+= 1
        isLoading = false
        isLoadingMore = false
    }

    /// Removes content associated with a server origin while preventing its
    /// in-flight loads from publishing after the origin changes.
    func invalidateContent() {
        supersedePendingLoads()
        items.removeAll()
        skippedStoryCount = 0
        loadFailed = false
        page = 1
        hasAttemptedLoad = false
        hasLoadedContent = false
        hasMorePages = true
    }

    func loadSupersedingPendingLoads() async throws {
        supersedePendingLoads()
        try await load()
    }
    
    func loadIfEmpty() async throws {
        if !hasLoadedContent && self.items.isEmpty {
            try await self.load()
        }
    }
    
    func reload() async throws {
        if isReloading {
            return
        }
        isReloading = true
        defer {
            isReloading = false
        }
        do {
            try await self.load()
        } catch {
            throw error
        }
    }
    
    func load() async throws {
        assert(true, "override this")
    }

    func more(_ item: T? = nil) async throws {
        assert(true, "should not call this. use the below as an example for the beginning of your function")
        guard self.items.last == item, !isLoadingMore else {
            return
        }
        isLoadingMore = true
        defer {
            isLoadingMore = false
        }
        // no-op
    }
}

// Keep successful feed publication consistent across Hottest, Newest, and Tags.
// Callers validate their request generation before applying a page.
extension GenericArrayFetcher where T == NewestStory {
    func replaceStoryPage(_ result: ParsedStoryList) {
        hasLoadedContent = true
        hasMorePages = !result.stories.isEmpty
        items = result.stories
        skippedStoryCount = result.skippedStoryCount
        loadFailed = false
        page = 2
    }

    func appendStoryPage(_ result: ParsedStoryList) {
        // An empty terminal page must not be requested again when the last
        // visible row reappears. Deduplicate by identity, not mutable scores.
        hasMorePages = !result.stories.isEmpty
        let existingIDs = Set(items.map(\.id))
        for story in result.stories where !existingIDs.contains(story.id) {
            items.append(story)
        }
        skippedStoryCount += result.skippedStoryCount
        loadFailed = false
        page += 1
    }
}
