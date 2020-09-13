//
//  StoryCell.swift
//  claw
//
//  Created by Zachary Gorak on 9/11/20.
//

import SwiftUI

struct StoryCell: View {
    var story: NewestStory
    
    var time_ago: String {
        let isoDate = story.created_at

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSSZ"
    
        if let date = dateFormatter.date(from:isoDate) {
            let minutes = abs(date.timeIntervalSinceNow/60)
            if minutes < 60 {
                return "\(Int(minutes)) minutes ago"
            }
            let hours = Int(minutes/60)
            return "\(hours) hours ago"
        }
        
        return "unknown time ago"
    }
    
    var body: some View {
        HStack(alignment: .center, spacing: 16.0) {
            Text("\(story.score)")
            VStack(alignment: .leading) {
                HStack(alignment: .top) {
                    Text(story.title).font(.headline).foregroundColor(Color.accentColor)
                    Text(URL(string: story.url)?.host ?? "").foregroundColor(Color.secondary).font(.callout)
                }
                TagList(tags: story.tags)
                HStack {
                    HStack {
                
                        Text("via ").font(.callout).foregroundColor(Color.secondary) +
                        Text(story.submitter_user.username).font(.callout).foregroundColor(story.submitter_user.is_admin ? Color.red : (story.submitter_user.is_moderator ? Color.green : Color.gray)) +
                        Text(" " + time_ago).font(.callout).foregroundColor(Color.secondary)
                    }
                    if story.comment_count == 1 {
                        Text("1 comment").font(.callout).foregroundColor(Color.secondary)
                    } else {
                        Text("\(story.comment_count) comments").font(.callout).foregroundColor(Color.secondary)
                    }
                }
            }
        }
    }
}

//struct StoryCell_Previews: PreviewProvider {
//    static var previews: some View {
//        StoryCell()
//    }
//}
