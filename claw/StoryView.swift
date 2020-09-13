import SwiftUI

struct StoryView: View {
    var short_id: String
    var from_newest: NewestStory?
    @ObservedObject var story: StoryFetcher
    
    init(_ short_id: String) {
        self.short_id = short_id
        self.story = StoryFetcher(short_id)
    }
    
    init(_ story: NewestStory) {
        self.from_newest = story
        self.short_id = story.short_id
        self.story = StoryFetcher(short_id)
    }
    
    var title: String {
        if let story = story.story{
            if story.comment_count == 1 {
                return "1 comment"
            }
            return "\(story.comment_count) comments"
        }
        if let story = from_newest {
            if story.comment_count == 1 {
                return "1 comment"
            }
            return "\(story.comment_count) comments"
        }
        return short_id
    }
    
    var body: some View {
        List {
            if let newest = from_newest {
                StoryCell(story: newest)
            }
            Text(story.story?.title ?? from_newest?.title ?? short_id).font(.headline)
            if let my_story = story.story {
                if my_story.description.count > 0 {
                    Text(my_story.description)
                }
                ForEach(my_story.comments) { comment in
                    VStack(alignment: .leading, spacing: 8.0) {
                        HStack(alignment: .center) {
                            Text(comment.commenting_user.username).foregroundColor(.gray)
                            Spacer()
                            Text("\(Image(systemName: "arrow.up")) \(comment.score)").foregroundColor(.gray)
                        }
                        HTMLView(html: comment.comment)
                        ForEach(HTMLView(html: comment.comment).links, id: \.self) { link in
                            Text("\(link)").padding().font(.footnote).foregroundColor(Color.primary).background(Color.secondary).overlay(
                                RoundedRectangle(cornerRadius: 8.0)
                                    .stroke(Color.primary, lineWidth: 2.0)
                            ).clipShape(RoundedRectangle(cornerRadius: 8.0)).onTapGesture {
                                UIApplication.shared.open(URL(string: link)!)
                            }
                        }
                        
                    }.padding(EdgeInsets(top: 0.0, leading: CGFloat(comment.indent_level-1)*16.0, bottom: 0.0, trailing: 0.0))
                }
            }
        }.navigationBarTitle(self.title, displayMode: .inline)
    }
}
