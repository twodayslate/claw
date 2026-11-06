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
            let url = APIConfiguration.shared.newestWebpageURL(page: 1)
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
        let stories: ParsedStoryList
        do {
            let loadedPage = try await pageLoader.load(url)
            stories = try await StoryListHTMLParser.parseOffMain(
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

        appendStoryPage(stories)

    }
}
