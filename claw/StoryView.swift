import SwiftUI
import WebView
import WebKit

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
    
    @ObservedObject var webViewStore = WebViewStore(webView: WKWebView())
    
    var body: some View {
        List {
            if let generic: GenericStory = story.story ?? from_newest {
                VStack(alignment: .leading) {
                    Text(generic.title).font(.title2).foregroundColor(.accentColor)
                    if let url = URL(string: generic.url), let host = url.host, !(host.isEmpty) {
                        SGNavigationLink(destination: WebView(webView: webViewStore.webView).navigationTitle(webViewStore.webView.title ?? generic.title)) {
                            Text(host).foregroundColor(Color.secondary).font(.callout)
                        }.onAppear {
                            webViewStore.webView.load(URLRequest(url: url))
                        }
                    }
                    HStack(alignment: .center, spacing: 16.0) {
                        Text("\(generic.score)")
                        VStack(alignment: .leading) {
                            TagList(tags: generic.tags)
                            SGNavigationLink(destination: UserView(user: generic.submitter_user), withChevron: false) {
                                Text("via ").font(.callout).foregroundColor(Color.secondary) +
                                Text(generic.submitter_user.username).font(.callout).foregroundColor(generic.submitter_user.is_admin ? Color.red : (generic.submitter_user.is_moderator ? Color.green : Color.gray)) +
                                    Text(" " + generic.time_ago).font(.callout).foregroundColor(Color.secondary)
                            }
                        }
                    }
                    if generic.description.count > 0 {
                        VStack(alignment: .leading) {
                            HTMLView(html: generic.description)
                            ForEach(HTMLView(html: generic.description).links, id: \.self) { link in
                                URLView(link: link)
                            }
                        }
                    }
                }
            }
            if let my_story = story.story {
                ForEach(my_story.comments) { comment in
                    VStack(alignment: .leading, spacing: 8.0) {
                        HStack(alignment: .center) {
                            NavigationLink(destination: UserView(user: comment.commenting_user)) {
                                Text(comment.commenting_user.username).foregroundColor(.gray)
                            }
                            Spacer()
                            Text("\(Image(systemName: "arrow.up")) \(comment.score)").foregroundColor(.gray)
                        }
                        HTMLView(html: comment.comment)
                        ForEach(HTMLView(html: comment.comment).links, id: \.self) { link in
                            URLView(link: link)
                        }
                        
                    }.padding(EdgeInsets(top: 0.0, leading: CGFloat(comment.indent_level-1)*16.0, bottom: 0.0, trailing: 0.0))
                }
            }
        }.navigationBarTitle(self.title, displayMode: .inline)
    }
}
