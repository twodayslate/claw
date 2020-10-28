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
                    Text(story.title).font(Font(.title2, sizeModifier: CGFloat(settings.textSizeModifier))).foregroundColor(.accentColor).fixedSize(horizontal: false, vertical: true).padding([.bottom], 1.0)
                    if let url = URL(string: story.url), let host = url.host, !(host.isEmpty) {
                        NavigationLink(
                            destination: WebView(webView: webViewStore.webView).navigationTitle(webViewStore.webView.title ?? story.title),
                            isActive: $navigationLinkActive,
                            label: {
                                Text(host).foregroundColor(Color.secondary).font(Font(.callout, sizeModifier: CGFloat(settings.textSizeModifier)))
                            }).padding([.bottom], 4.0).onAppear {
                            webViewStore.webView.load(URLRequest(url: url))
                        }
                    }
                    HStack(alignment: .center, spacing: 16.0) {
                        VStack(alignment: .center) {
                            Text("\(Image(systemName: "arrowtriangle.up.fill"))").foregroundColor(Color(UIColor.systemGray3))
                            Text("\(story.score)").foregroundColor(.gray)
                        }
                        
                        VStack(alignment: .leading) {
                            TagList(tags: story.tags)
                            SGNavigationLink(destination: UserView(story.submitter_user), withChevron: false) {
                                Text("via ").foregroundColor(Color.secondary) +
                                Text(story.submitter_user.username).font(Font(.callout, sizeModifier: CGFloat(settings.textSizeModifier))).foregroundColor(story.submitter_user.is_admin ? Color.red : (story.submitter_user.is_moderator ? Color.green : Color.gray)) +
                                    Text(" " + story.time_ago).foregroundColor(Color.secondary)
                            }.font(Font(.callout, sizeModifier: CGFloat(settings.textSizeModifier)))
                        }
                    }
                }
                Spacer(minLength: 0)// ensure full width
                if !story.url.isEmpty {
                    // make chevron bold like navigationlink
                    Text("\(Image(systemName: "chevron.right"))").bold().foregroundColor(Color(UIColor.systemGray3))
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
                            Button(action: {
                                activeSheet = .third
                            }, label: {
                                Label("Story Cache URL", systemImage: "archivebox")
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
                } else if item == .third {
                    ShareSheet(activityItems: [URL(string: "https://archive.md/\(story.url)")!])
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

#if DEBUG
struct StoryHeaderView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            StoryHeaderView(story: NewestStory(short_id: "", short_id_url: "", created_at: "2020-09-17T08:35:19.000-05:00", title: "A title here", url: "https://zac.gorak.us/story", score: 45, flags: 1, comment_count: 4, description: "A description", comments_url: "https://lobste.rs/c/asdf", submitter_user: NewestUser(username: "twodayslate", created_at: "2020-09-17T08:35:19.000-05:00", is_admin: false, about: "About me", is_moderator: false, karma: 20, avatar_url: "", invited_by_user: "woho", github_username: "github", twitter_username: "twodayslate", keybase_signatures: nil), tags: ["ios", "programming"]), webViewStore: WebViewStore(webView: WKWebView()))
        }.previewLayout(.sizeThatFits)
    }
}
#endif
