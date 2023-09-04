import Foundation
import Combine
import SwiftUI

@MainActor
class GenericArrayFetcher<T: Hashable & Codable>: ObservableObject {
    @Published var items = [T]()
    
    @Published var isLoadingMore = false
    @Published var isReloading = false
    
    public internal(set) var page: Int = 1
    internal var session: URLSessionTask? = nil
    internal var moreSession: URLSessionTask? = nil
        
    deinit {
        self.session?.cancel()
        self.moreSession?.cancel()
    }
    
    func loadIfEmpty() {
        if self.items.count <= 0 {
            self.load()
        }
    }
    
    func reload() {
        self.session?.cancel()
        self.moreSession?.cancel()
        self.isReloading = true
        self.load()
    }
    
    func load() {
        self.page = 1
        self.session?.cancel()
        self.moreSession?.cancel()
    }

    func more(_ item: T? = nil) {
        if self.items.last == item && !isLoadingMore {
            self.isLoadingMore = true
            
            self.moreSession?.cancel()
        }
    }
}
