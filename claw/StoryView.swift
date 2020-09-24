import SwiftUI
import WebView
import WebKit


struct StoryHeaderView<T: GenericStory>: View {
    var story: T
    
    @ObservedObject var webViewStore: WebViewStore
    
    @State var activeSheet: ActiveSheet?
    
    @EnvironmentObject var settings: Settings
    
    @State var navigationLinkActive = false
    
    @State var backgroundColorState = Color(UIColor.systemBackground)
    
    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                VStack(alignment: .leading) {
                    Text(story.title).font(.title2).foregroundColor(.accentColor).fixedSize(horizontal: false, vertical: true).padding([.bottom], 1.0)
                    if let url = URL(string: story.url), let host = url.host, !(host.isEmpty) {
                        NavigationLink(
                            destination: WebView(webView: webViewStore.webView).navigationTitle(webViewStore.webView.title ?? story.title),
                            isActive: $navigationLinkActive,
                            label: {
                                Text(host).foregroundColor(Color.secondary).font(.callout)
                            }).padding([.bottom], 4.0).onAppear {
                            webViewStore.webView.load(URLRequest(url: url))
                        }
                    }
                    HStack(alignment: .center, spacing: 16.0) {
                        VStack(alignment: .leading) {
                            Text("\(Image(systemName: "arrowtriangle.up.fill"))").foregroundColor(Color(UIColor.systemGray3))
                            Text("\(story.score)").foregroundColor(.gray)
                        }
                        
                        VStack(alignment: .leading) {
                            TagList(tags: story.tags)
                            SGNavigationLink(destination: UserView(user: story.submitter_user), withChevron: false) {
                                Text("via ").font(.callout).foregroundColor(Color.secondary) +
                                Text(story.submitter_user.username).font(.callout).foregroundColor(story.submitter_user.is_admin ? Color.red : (story.submitter_user.is_moderator ? Color.green : Color.gray)) +
                                    Text(" " + story.time_ago).font(.callout).foregroundColor(Color.secondary)
                            }
                        }
                    }
                }
                Spacer(minLength: 0)// ensure full width
                if !story.url.isEmpty {
                    Image(systemName: "chevron.right").foregroundColor(Color.gray)
                }
            }.padding().background(backgroundColorState.ignoresSafeArea()).contextMenu(menuItems: {
                if story.url.isEmpty {
                    Button(action: {
                        activeSheet = .second
                    }, label: {
                        Label("Share", systemImage: "square.and.arrow.up")
                    })
                } else {
                    Menu(content: {
                        Button(action: {
                            activeSheet = .second
                        }, label: {
                            Label("Lobsters URL", systemImage: "book")
                        })
                        if !story.url.isEmpty {
                            Button(action: {
                                activeSheet = .first
                            }, label: {
                                Label("Story URL", systemImage: "link")
                            })
                        }
                    }, label: {
                        Label("Share", systemImage: "square.and.arrow.up.on.square")
                    })
                }
            }).sheet(item: self.$activeSheet) {
                item in
                if item == .first {
                    ShareSheet(activityItems: [URL(string: story.url)!])
                } else if item == .second {
                    ShareSheet(activityItems: [URL(string: story.short_id_url)!])
                } else {
                    Text("\(activeSheet.debugDescription)")
                }
            }

            if story.description.count > 0 {
                Divider().padding([.leading, .trailing])
                VStack(alignment: .leading) {
                    let html = HTMLView(html: story.description)
                    html.fixedSize(horizontal: false, vertical: true)
                    ForEach(html.links, id: \.self) { link in
                        URLView(link: link)
                    }
                }.padding()
            }
        }.onTapGesture(count: /*@START_MENU_TOKEN@*/1/*@END_MENU_TOKEN@*/, perform: {
            withAnimation(.easeIn) {
                backgroundColorState = Color(UIColor.systemGray4)
                withAnimation(.easeOut) {
                    backgroundColorState = Color(UIColor.systemBackground)
                }
                navigationLinkActive = true
            }
        })
    }
}


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
    
    // https://stackoverflow.com/questions/58093295/swiftui-avoid-recreating-rerendering-view-in-tabview-with-mkmapviewuiviewrepre
    // this webview is recreated everytime a settings changes and is slow af
    static var webView = WKWebView()
    
    @ObservedObject var webViewStore = WebViewStore(webView: StoryView.webView)
    
    @State var activeSheet: ActiveSheet?
    
    @EnvironmentObject var settings: Settings
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                if let story = story.story {
                    StoryHeaderView<Story>(story: story, webViewStore: webViewStore).environmentObject(settings)
                }
                else if let story = from_newest  {
                    StoryHeaderView<NewestStory>(story: story, webViewStore: webViewStore).environmentObject(settings)
                } else {
                    StoryHeaderView<NewestStory>(story: NewestStory.placeholder, webViewStore: webViewStore).environmentObject(settings).redacted(reason: .placeholder).allowsHitTesting(false)
                }
                Divider()
                if let my_story = story.story {
                    if  my_story.comments.count > 0 {
                        HierarchyList(data: my_story.sorted_comments, header: { comment in
                            HStack(alignment: .center) {
                                SGNavigationLink(destination: UserView(user: comment.comment.commenting_user), withChevron: false) {
                                    Text(comment.comment.commenting_user.username).foregroundColor(.gray)
                                }
                                Spacer()
                                Text("\(Image(systemName: "arrow.up")) \(comment.comment.score)").foregroundColor(.gray)
                            }
                        }, rowContent: { comment in
                            VStack(alignment: .leading, spacing: 8.0) {
                                HStack {
                                    HTMLView(html: comment.comment.comment)
                                    Spacer(minLength: 0)
                                }
                                ForEach(HTMLView(html: comment.comment.comment).links, id: \.self) { link in
                                        URLView(link: link)
                                }
                            }
                        }).padding([.bottom])
                    } else {
                        HStack {
                            Spacer()
                            Text("No comments").foregroundColor(.gray)
                            Spacer()
                        }.padding()
                    }
                }
            }
        }.navigationBarTitle(self.title, displayMode: .inline)
    }
}
