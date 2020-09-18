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
            VStack {
                Text("\(Image(systemName: "arrowtriangle.up.fill"))").foregroundColor(Color(UIColor.systemGray3))
                Text("\(story.score)").foregroundColor(.gray)
            }
            VStack(alignment: .leading) {
                Text(story.title).font(.headline).foregroundColor(Color.accentColor)
                Text(URL(string: story.url)?.host ?? "").foregroundColor(Color.secondary).font(.callout)
                TagList(tags: story.tags)
                HStack {
                    SGNavigationLink(destination: UserView(user: story.submitter_user), withChevron: false) {
                        Text("via ").font(.callout).foregroundColor(Color.secondary) +
                        Text(story.submitter_user.username).font(.callout).foregroundColor(story.submitter_user.is_admin ? Color.red : (story.submitter_user.is_moderator ? Color.green : Color.gray)) +
                            Text(" " +
                                    story.time_ago).font(.callout).foregroundColor(Color.secondary)
                    }
                    Spacer()
                    SGNavigationLink(destination: StoryView(story), withChevron: false) {
                        if story.comment_count == 1 {
                            Text("1 comment").font(.callout).foregroundColor(Color.secondary)
                        } else {
                            Text("\(story.comment_count) comments").font(.callout).foregroundColor(Color.secondary)
                        }
                    }.fixedSize()
                }
            }
        }
    }
}

struct StoryCell_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            StoryCell(story: NewestStory(short_id: "", short_id_url: "", created_at: "2020-09-17T08:35:19.000-05:00", title: "A title here", url: "https://zac.gorak.us/story", score: 45, flags: 1, comment_count: 4, description: "A description", comments_url: "https://lobste.rs/c/asdf", submitter_user: NewestUser(username: "twodayslate", created_at: "2020-09-17T08:35:19.000-05:00", is_admin: false, about: "About me", is_moderator: false, karma: 20, avatar_url: "", invited_by_user: "woho", github_username: "github", twitter_username: "twodayslate", keybase_signatures: nil), tags: ["apple", "programming"]))
        }.previewLayout(.sizeThatFits)
    }
}
