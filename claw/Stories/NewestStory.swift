//
//  NewestStory.swift
//  claw
//
//  Created by Zachary Gorak on 9/14/20.
//

import Foundation

struct NewestStory: GenericStory, Codable, Identifiable, Hashable {
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
    
    static var placeholder: NewestStory {
        return NewestStory(short_id: "bmqi6l", short_id_url: "https://lobste.rs/s/bmqi6l", created_at: "2020-09-17T08:35:19.000-05:00", title: "Story title", url: "https://lobste.rs", score: 6, flags: 0, comment_count: 9, description: "Description", comments_url: "", submitter_user: NewestUser.placeholder, tags: ["programming", "apple"])
    }
}

extension NewestStory: Equatable {
    static func == (lhs: NewestStory, rhs: NewestStory) -> Bool {
        return lhs.id == rhs.id
    }
}
