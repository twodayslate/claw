import Foundation
import Combine
import SwiftUI

@MainActor
class GenericArrayFetcher<T: Hashable & Codable>: ObservableObject {
    @Published var items = [T]()

    @Published var isLoadingMore = false
    @Published var isReloading = false
    @Published var isLoading = false

    public internal(set) var page: Int = 1
    
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
