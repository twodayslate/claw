//
//  newest.swift
//  claw
//
//  Created by Zachary Gorak on 9/11/20.
//

import Foundation
import SwiftUI

struct Story: GenericStory, Codable, Hashable, Identifiable {

    var id: String {
        return short_id
    }

    var short_id: String
    var short_id_url: String
    var created_at: String
    var title: String
    var url: String
    var score: Int
    var flags: Int
    var comment_count: Int
    var description: String
    var comments_url: String
    var submitter_user: String
    var user_is_author: Bool
    var tags: [String]
    var comments: [Comment]
    var user_upvoted: Bool = false
    var can_comment: Bool = false
    
    var sorted_comments: [CommentStructure] {
        var ans = [CommentStructure]()
        let rootComments = comments.filter { $0.parent_comment == nil }
        var subComments = comments.filter { $0.parent_comment != nil }

        func addComments(parent: CommentStructure) -> CommentStructure {
            var newParent = parent
            let children = subComments.filter { $0.parent_comment == parent.id }
            for child in children {
                let childStruct = addComments(parent: CommentStructure(comment: child))
                newParent = newParent.addChild(childStruct)
            }
            subComments.removeAll(where: { $0.parent_comment == parent.id })
            return newParent
        }

        for comment in rootComments {
            let parent = addComments(parent: CommentStructure(comment: comment))
            ans.append(parent)
        }

        return ans.sorted(by: { $0.comment.score > $1.comment.score })
    }
}

struct CommentStructure: Codable, Identifiable {
    var id: String {
        return comment.short_id
    }
    var comment: Comment
    var children: [CommentStructure] = []

    func addChild(_ child: Comment) -> Self {
        var newChildren = children
        newChildren.append(CommentStructure(comment: child))
        newChildren.sort(by: { $0.comment.score > $1.comment.score })
        return Self(comment: self.comment, children: newChildren)
    }

    func addChild(_ child: CommentStructure) -> Self {
        var newChildren = children
        newChildren.append(child)
        newChildren.sort(by: { $0.comment.score > $1.comment.score })
        return Self(comment: self.comment, children: newChildren)
    }
}

extension CommentStructure: Equatable {
    static func == (lhs: CommentStructure, rhs: CommentStructure) -> Bool {
        return lhs.id == rhs.id && rhs.children == lhs.children
    }
}

struct Comment: Codable, Hashable, Identifiable {
    var id: String {
        return short_id
    }
    var short_id: String
    var short_id_url: String
    var created_at: String
    var last_edited_at: String
    var is_deleted: Bool
    var is_moderated: Bool
    var score: Int
    var flags: Int
    var url: String
    var comment: String
    var parent_comment: String?
    var commenting_user: String
    var user_upvoted: Bool? = nil
    var can_edit: Bool? = nil
    var can_delete: Bool? = nil
    var can_reply: Bool? = nil
    var can_vote: Bool? = nil

    static var placeholder: Comment {
        Comment(short_id: "", short_id_url: "", created_at: "2020-09-17T08:35:19.000-05:00", last_edited_at: "2020-09-17T08:35:19.000-05:00", is_deleted: false, is_moderated: false, score: Int.random(in: 3..<25), flags: 0, url: "", comment: ["Hello World!", "To be, or not to be! That is the question!"].randomElement() ?? "", commenting_user: "user")
    }
}

@MainActor
class StoryFetcher: ObservableObject {
    private final class WeakReference {
        weak var value: StoryFetcher?

        init(_ value: StoryFetcher) {
            self.value = value
        }
    }

    @Published var story: Story? = nil

    public var short_id: String? = nil
    public var pageURL: URL? = nil
    private let webpageFetcher: WebpageFetcher
    private var contentGeneration: UInt = 0

    init(
        _ short_id: String? = nil,
        webpageFetcher: WebpageFetcher = .shared
    ) {
        self.short_id = short_id
        self.webpageFetcher = webpageFetcher
        Self.liveFetchers.append(WeakReference(self))
    }

    static var cachedStories = [Story]()
    static let fetchQueue = DispatchQueue(label: "StoryFetcher")
    private static var liveFetchers = [WeakReference]()

    static func reloadLiveFetchers() async {
        liveFetchers.removeAll { $0.value == nil }
        let fetchers = liveFetchers.compactMap(\.value)
        for fetcher in fetchers {
            try? await fetcher.loadSupersedingPendingLoads()
        }
    }

    private func supersedePendingLoads() {
        contentGeneration &+= 1
        isReloading = false
    }

    private func loadSupersedingPendingLoads() async throws {
        supersedePendingLoads()
        try await load()
    }

    private func isCurrentContentGeneration(_ generation: UInt) -> Bool {
        generation == contentGeneration
    }

    @Published var isReloading = false
    func reload() async throws {
        if isReloading {
            return
        }
        self.isReloading = true
        defer {
            isReloading = false
        }
        try await self.load()
    }
    
    func loadIfEmpty() async throws {
        if let _ = self.story {
            return
        }
        try await self.load()
    }

    func load() async throws {
        guard let short_id = self.short_id else {
            return
        }
        let generation = contentGeneration
        if let cachedStory = StoryFetcher.cachedStories.first(where: {$0.short_id == short_id}) {
            self.story = cachedStory
        }
        let configuredURL = APIConfiguration.shared.storyURL(shortId: short_id)
        let url: URL
        if let pageURL, APIConfiguration.shared.isLobstersURL(pageURL) {
            url = pageURL
        } else {
            url = configuredURL
        }

        var request = URLRequest(url: url)

        let isShortURL = url.pathComponents.count == 3
            && url.pathComponents[1] == "s"
            && url.pathComponents[2] == short_id
        let hasCookies = try !webpageFetcher.cookies(for: url).isEmpty
        if isShortURL, !hasCookies {
            request.setValue("claw_cache_bypass=1", forHTTPHeaderField: "Cookie")
        }

        let webpage: Webpage
        do {
            webpage = try await webpageFetcher.fetch(request)
        } catch {
            guard isCurrentContentGeneration(generation) else {
                return
            }
            throw error
        }

        let parsedStory: Story
        do {
            parsedStory = try await StoryHTMLParser.parseOffMain(
                webpage.html,
                pageURL: webpage.url
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
        self.story = parsedStory

        StoryFetcher.cachedStories.removeAll(where: {$0.short_id == short_id})
        StoryFetcher.cachedStories.append(parsedStory)
        if StoryFetcher.cachedStories.count > 10 {
            StoryFetcher.cachedStories.removeFirst()
        }
        
    }

}
