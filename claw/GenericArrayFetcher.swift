import Foundation
import Combine
import SwiftUI

@MainActor
class GenericArrayFetcher<T: Hashable & Codable>: ObservableObject {
    @Published var items = [T]()

    @Published var isLoadingMore = false
    @Published var isReloading = false
    @Published var isLoading = false
    @Published var hasAttemptedLoad = false

    public internal(set) var page: Int = 1
    private var contentGeneration: UInt = 0

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
        page = 1
        hasAttemptedLoad = false
    }

    func loadSupersedingPendingLoads() async throws {
        supersedePendingLoads()
        try await load()
    }
    
    func loadIfEmpty() async throws {
        if self.items.isEmpty {
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
