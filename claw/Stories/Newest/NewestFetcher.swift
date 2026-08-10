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
            let url = APIConfiguration.shared.newestWebpageURL(page: self.page)
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
        guard self.items.last == story, !isLoadingMore else {
            return
        }
        let generation = captureContentGeneration()
        self.isLoadingMore = true
        defer {
            if isCurrentContentGeneration(generation) {
                isLoadingMore = false
            }
        }
        let url = APIConfiguration.shared.newestWebpageURL(page: self.page)
        let stories: [NewestStory]
        do {
            let loadedPage = try await LobstersPageLoader.shared.load(url)
            stories = try await StoryListHTMLParser.parseOffMain(
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

        for story in stories {
            if !self.items.contains(story) {
                self.items.append(story)
            }
        }
        self.page += 1

    }
}
