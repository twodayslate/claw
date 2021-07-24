//
//  GenericUser.swift
//  claw
//
//  Created by Zachary Gorak on 9/14/20.
//

import Foundation

protocol GenericStory: Codable, Hashable, Identifiable {
    var id: String { get }
    var short_id: String { get }
    var short_id_url: String { get }
    var created_at: String { get }
    var title: String { get }
    var url: String { get }
    var score: Int { get }
    var flags: Int { get }
    var comment_count: Int { get }
    var description: String { get }
    var comments_url: String { get }
    var submitter_user: NewestUser { get }
    var tags: [String] { get }
}

extension GenericStory {
    var id: String {
        return short_id
    }
    
    var time_ago: String {
        let isoDate = self.created_at

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSSZ"
    
        if let date = dateFormatter.date(from:isoDate) {
            let minutes = abs(date.timeIntervalSinceNow/60)
            if minutes < 60 {
                if minutes == 1 {
                    return "1 minute ago"
                }
                return "\(Int(minutes)) minutes ago"
            }
            let hours = Int(minutes/60)
            if hours < 24 {
                if hours == 1 {
                    return "1 hour ago"
                }
                return "\(hours) hours ago"
            }
            let days = Int(hours/24)
            if days == 1 {
                return "1 day ago"
            }
            return "\(days) days ago"
        }
        
        return "unknown time ago"
    }
}
