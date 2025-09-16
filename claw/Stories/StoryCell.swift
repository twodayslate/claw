//
//  StoryCell.swift
//  claw
//
//  Created by Zachary Gorak on 9/11/20.
//

import SwiftUI
import SwiftData

struct StoryCell: View {
    @Environment(Settings.self) var settings
    
    var story: NewestStory
    
    @Query(ViewedItem.fetchAllDescriptor) var viewedItems: [ViewedItem]
    
    var body: some View {
        let contains = viewedItems.contains { element in
            element.short_id == story.short_id && element.isStory
        }
        ZStack(alignment: .trailing) {
            Spacer(minLength: 0)// ensure full width
            if !story.url.isEmpty {
                // make chevron bold like navigationlink
                Text("\(Image(systemName: "chevron.right"))").bold().foregroundColor(Color(UIColor.systemGray3))
            }
            HStack(alignment: .center, spacing: 16.0) {
                if settings.layout > .comfortable {
                    VStack(alignment: .center) {
                        Text("\(Image(systemName: "arrowtriangle.up.fill"))").foregroundColor(Color(UIColor.systemGray3))
                        Text("\(story.score)").foregroundColor(.gray)
                    }
                }
                
                VStack(alignment: .leading) {
                    Text(story.title)
                        .font(style: .headline)
                        .foregroundColor(Color.accentColor
                        .opacity(contains ? 0.69 : 1.0))
                    if settings.layout > .compact {
                        Text(URL(string: story.url)?.host ?? "")
                            .font(style: .callout)
                            .foregroundColor(Color.secondary)
                    }
                    if settings.layout > .compact {
                        TagList(tags: story.tags)
                    }
                    HStack {
                        SGNavigationLink(destination: UserView(story.submitter_user), withChevron: false) {
                            Text("via ").foregroundColor(Color.secondary) +
                            Text(story.submitter_user)
                                .foregroundColor(story.user_is_author == true ? .blue : .gray) +
                            Text(" " +
                                 story.time_ago).foregroundColor(Color.secondary)
                        }
                        .font(style: .subheadline)
                        Spacer()
                        SGNavigationLink(destination: StoryView(story), withChevron: false) {
                            if story.comment_count == 1 {
                                Text("1 comment").foregroundColor(Color.secondary)
                            } else {
                                Text("\(story.comment_count) comments").foregroundColor(Color.secondary)
                            }
                        }.fixedSize()
                            .font(style: .subheadline)
                    }
                }
            }
        }.opacity(contains ? 0.9 : 1.0)
    }
}

struct StoryCell_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            StoryCell(story: NewestStory(short_id: "", short_id_url: "", created_at: "2020-09-17T08:35:19.000-05:00", title: "A title here", url: "https://zac.gorak.us/story", score: 45, flags: 1, comment_count: 4, description: "A description", comments_url: "https://lobste.rs/c/asdf", submitter_user: "placeholder", user_is_author: false, tags: ["ios", "programming"]))
        }
        .previewLayout(.sizeThatFits)
        .modelContainer(PersistenceControllerV2.preview.container)
        .environment(SettingsV2())
        .environmentObject(ObservableURL())
    }
}
