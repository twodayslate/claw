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

    static var placeholder: Comment {
        Comment(short_id: "", short_id_url: "", created_at: "2020-09-17T08:35:19.000-05:00", last_edited_at: "2020-09-17T08:35:19.000-05:00", is_deleted: false, is_moderated: false, score: Int.random(in: 3..<25), flags: 0, url: "", comment: ["Hello World!", "To be, or not to be! That is the question!"].randomElement() ?? "", commenting_user: "user")
    }
}

@MainActor
class StoryFetcher: ObservableObject {
    @Published var story: Story? = nil

    public var short_id: String? = nil

    init(_ short_id: String? = nil) {
        self.short_id = short_id
    }

    deinit {
        self.session?.cancel()
    }

    static var cachedStories = [Story]()
    static let fetchQueue = DispatchQueue(label: "StoryFetcher")
    
    private var session: URLSessionTask? = nil
    
    @Published var isReloading = false
    func reload() {
        self.session?.cancel()
        self.isReloading = true
        self.load()
    }
    
    func loadIfEmpty() {
        if let _ = self.story {
            return
        }
        self.load()
    }

    func awaitLoad() async throws {
        guard let short_id = self.short_id else {
            return
        }
        if let cachedStory = StoryFetcher.cachedStories.first(where: {$0.short_id == short_id}) {
            self.story = cachedStory
        }
        let url = APIConfiguration.shared.storyURL(shortId: short_id)
        
        let (data, _) = try await URLSession.shared.data(from: url)
        
        isReloading = false

        let decodedLists = try JSONDecoder().decode(Story.self, from: data)
        self.story = decodedLists

        StoryFetcher.cachedStories.removeAll(where: {$0.short_id == short_id})
        StoryFetcher.cachedStories.append(decodedLists)
        if StoryFetcher.cachedStories.count > 10 {
            StoryFetcher.cachedStories.removeFirst()
        }
        
    }
    
    func load() {
        guard let short_id = self.short_id else {
            return
        }
        if let cachedStory = StoryFetcher.cachedStories.first(where: {$0.short_id == short_id}) {
            DispatchQueue.main.async {
                self.story = cachedStory
            }
        }
        let url = APIConfiguration.shared.storyURL(shortId: short_id)

        self.session?.cancel()

        self.session = URLSession.shared.dataTask(with: url) {(data,response,error) in
            DispatchQueue.main.async {
                self.isReloading = false
            }
            do {
                if let d = data {
                    let decodedLists = try JSONDecoder().decode(Story.self, from: d)
                    DispatchQueue.main.async {
                        self.story = decodedLists
                    }
                    Self.fetchQueue.async {
                        Task { @MainActor in
                            StoryFetcher.cachedStories.removeAll(where: {$0.short_id == short_id})
                            StoryFetcher.cachedStories.append(decodedLists)
                            if StoryFetcher.cachedStories.count > 10 {
                                StoryFetcher.cachedStories.removeFirst()
                            }
                        }
                    }
                } else {
                    print("No Data for story")
                }
            } catch {
                print ("Error fetching story \(error)")
            }
        }
        self.session?.resume()
    }
}
