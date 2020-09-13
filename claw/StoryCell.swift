//
//  StoryCell.swift
//  claw
//
//  Created by Zachary Gorak on 9/11/20.
//

import SwiftUI

struct StoryCell: View {
    var story: NewestStory
    
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
                        SGNavigationLink(destination: UserView(user: story.submitter_user), withChevron: false) {
                            Text("via ").font(.callout).foregroundColor(Color.secondary) +
                            Text(story.submitter_user.username).font(.callout).foregroundColor(story.submitter_user.is_admin ? Color.red : (story.submitter_user.is_moderator ? Color.green : Color.gray)) +
                                Text(" " +
                                        story.time_ago).font(.callout).foregroundColor(Color.secondary)
                            
                        }
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
