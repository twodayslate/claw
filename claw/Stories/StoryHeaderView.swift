import SwiftUI

struct StoryHeaderView<T: GenericStory>: View {
    var story: T
        
    @EnvironmentObject var settings: Settings
    
    @State var backgroundColorState = Color(UIColor.systemBackground)
    
    @EnvironmentObject var urlToOpen: ObservableURL
    @EnvironmentObject var observableSheet: ObservableActiveSheet
    
    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                VStack(alignment: .leading) {
                    Text(story.title).font(Font(.title2, sizeModifier: CGFloat(settings.textSizeModifier))).foregroundColor(.accentColor).fixedSize(horizontal: false, vertical: true).padding([.bottom], 1.0)
                    if let url = URL(string: story.url), let host = url.host, !(host.isEmpty) {
                        Button(action: {
                            guard let url = URL(string: story.url) else {
                                // show error
                                return
                            }
                            if settings.browser == .inAppSafari, (url.scheme == "http" || url.scheme == "https") {
                                urlToOpen.url = url
                            } else {
                                UIApplication.shared.open(url)
                            }
                        }, label: {
                            Text(host).foregroundColor(Color.secondary).font(Font(.callout, sizeModifier: CGFloat(settings.textSizeModifier)))
                            }).padding([.bottom], 4.0)
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
                                Text(story.submitter_user).font(Font(.callout, sizeModifier: CGFloat(settings.textSizeModifier))) +
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
                        observableSheet.sheet = .share(URL(string: story.short_id_url)!)
                    }, label: {
                        Label("Share", systemImage: "square.and.arrow.up")
                    })
                } else {
                    Menu(content: {
                        Button(action: {
                            observableSheet.sheet = .share(URL(string: story.short_id_url)!)
                        }, label: {
                            Label("Lobsters URL", systemImage: "book")
                        })
                        if !story.url.isEmpty {
                            Button(action: {
                                observableSheet.sheet = .share(URL(string: story.url)!)
                            }, label: {
                                Label("Story URL", systemImage: "link")
                            })
                            Button(action: {
                                observableSheet.sheet = .share(URL(string: "https://archive.md/\(story.url)")!)
                            }, label: {
                                Label("Story Cache URL", systemImage: "archivebox")
                            })
                        }
                    }, label: {
                        Label("Share", systemImage: "square.and.arrow.up.on.square")
                    })
                }
            })

            if story.description.count > 0 {
                Divider().padding([.leading, .trailing])
                VStack(alignment: .leading) {
                    let html = HTMLView(html: story.description.trimmingCharacters(in: .whitespacesAndNewlines))
                    html.fixedSize(horizontal: false, vertical: true)
                    ForEach(html.links, id: \.self) { link in
                        URLView(link: link).environmentObject(urlToOpen).environmentObject(settings)
                    }
                }.padding()
            }
        }.onTapGesture(count: /*@START_MENU_TOKEN@*/1/*@END_MENU_TOKEN@*/, perform: {
            if !story.url.isEmpty {
                guard let url = URL(string: story.url) else {
                    // show error
                    return
                }
                withAnimation(.easeIn) {
                    backgroundColorState = Color(UIColor.systemGray4)
                    withAnimation(.easeOut) {
                        backgroundColorState = Color(UIColor.systemBackground)
                    }
                    if settings.browser == .inAppSafari, (url.scheme == "https" || url.scheme == "http") {
                        urlToOpen.url = url
                    } else {
                        UIApplication.shared.open(url)
                    }
                }
            }
        })
    }
}

#if DEBUG
struct StoryHeaderView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            StoryHeaderView(story: NewestStory(short_id: "", short_id_url: "", created_at: "2020-09-17T08:35:19.000-05:00", title: "A title here", url: "https://zac.gorak.us/story", score: 45, flags: 1, comment_count: 4, description: "A description", comments_url: "https://lobste.rs/c/asdf", submitter_user: "placeholder", tags: ["ios", "programming"]))
        }.previewLayout(.sizeThatFits)
    }
}
#endif
