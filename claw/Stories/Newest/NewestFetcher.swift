//
//  newest.swift
//  claw
//
//  Created by Zachary Gorak on 9/11/20.
//

import Foundation
import SwiftUI

@MainActor
class NewestFetcher: GenericArrayFetcher<NewestStory> {
    static var shared = NewestFetcher()
    
    override func load() async throws {
        if isLoading {
            return
        }
        page = 1
        isLoading = true
        defer {
            isLoading = false
        }
        let url = APIConfiguration.shared.newestURL(page: self.page)
        let (data, _) = try await URLSession.shared.data(from: url)
        let decodedLists = try JSONDecoder().decode([NewestStory].self, from: data)
        
        self.items = decodedLists
        self.page += 1
    }
    
    override func more(_ story: NewestStory? = nil) async throws {
        guard self.items.last == story, !isLoadingMore else {
            return
        }
        self.isLoadingMore = true
        defer {
            isLoadingMore = false
        }
        let url = APIConfiguration.shared.newestPageURL(page: self.page)

        let (data, _) = try await URLSession.shared.data(from: url)
        let stories = try JSONDecoder().decode([NewestStory].self, from: data)

        for story in stories {
            if !self.items.contains(story) {
                self.items.append(story)
            }
        }
        self.page += 1

    }
}
