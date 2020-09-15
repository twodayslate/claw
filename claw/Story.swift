//
//  newest.swift
//  claw
//
//  Created by Zachary Gorak on 9/11/20.
//

import Foundation
import SwiftUI

struct Story: GenericStory, Codable, Identifiable {
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
    var submitter_user: NewestUser
    var tags: [String]
    var comments: [Comment]
    
    var sorted_comments: [CommentStructure] {
        func add_children(indentLevel: Int, comments: [Comment], stopWhenLess: Bool = true) -> [CommentStructure] {
            var ans = [CommentStructure]()
            for (i, comment) in comments.enumerated() {
                if comment.indent_level == indentLevel {
                    let slice = Array(comments.suffix(from: i+1))
                    let children = add_children(indentLevel: indentLevel+1, comments: slice)
                    if children.count > 0 {
                        ans.append(CommentStructure(comment: comment, children: children))
                    } else {
                        ans.append(CommentStructure(comment: comment, children: nil))
                    }
                } else if stopWhenLess {
                    break
                }
            }
            return ans
        }
        
        let children =  add_children(indentLevel: 1, comments: self.comments, stopWhenLess: false)
        return children
    }
}

struct CommentStructure: Codable, Identifiable {
    var id: String {
        return comment.short_id
    }
    var comment: Comment
    var children: [CommentStructure]?
}

struct Comment: Codable, Identifiable {
    var id: String {
        return short_id
    }
    var short_id: String
    var short_id_url: String
    var created_at: String
    var updated_at: String
    var is_deleted: Bool
    var is_moderated: Bool
    var score: Int
    var flags: Int
    var url: String
    var comment: String
    var indent_level: Int
    var commenting_user: NewestUser
}

class StoryFetcher: ObservableObject {
    @Published var story: Story? = nil
    
    var short_id: String
    
    init(_ short_id: String) {
        self.short_id = short_id
        load()
    }
    
    func load() {
        let url = URL(string: "https://lobste.rs/s/\(short_id).json")!
            
                URLSession.shared.dataTask(with: url) {(data,response,error) in
                    do {
                        if let d = data {
                            let decodedLists = try JSONDecoder().decode(Story.self, from: d)
                            DispatchQueue.main.async {
                                self.story = decodedLists
                            }
                        }else {
                            print("No Data")
                        }
                    } catch {
                        print ("Error \(error)")
                    }
                }.resume()
    }
}
