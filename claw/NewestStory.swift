//
//  NewestStory.swift
//  claw
//
//  Created by Zachary Gorak on 9/14/20.
//

import Foundation

struct NewestStory: GenericStory, Codable, Identifiable {
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
}
