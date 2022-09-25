import SwiftUI
import BetterSafariView

struct UserView: View {
    var user: NewestUser?
    @ObservedObject var userFetcher: UserFetcher
    var username: String?
    @Environment(\.didReselect) var didReselect
    @Environment(\.presentationMode) var presentationMode: Binding<PresentationMode>
    
    @EnvironmentObject var settings: Settings
    @EnvironmentObject var urlToOpen: ObservableURL
    
    init(_ user: NewestUser) {
        self.user = user
        self.username = self.user?.username
        self.userFetcher = UserFetcher(self.username ?? "")
    }
    
    init(_ username: String) {
        self.username = username
        self.userFetcher = UserFetcher(username)
    }
    
    var body: some View {
        List {
            if let user = self.user ?? self.userFetcher.user {
                HStack(alignment: .center) {
                    Spacer()
                    UserAvatarLoader(user: user).overlay(
                        Circle()                        .stroke(Color(UIColor.separator), lineWidth: 3.0)
                    ).clipShape(Circle()).shadow(radius: 5.0)
                    Spacer()
                }
                if let karma = user.karma {
                    HStack {
                        Text("Karma").bold()
                        Text("\(karma)")
                    }
                }
                if let username = user.github_username, let url = URL(string: "https://github.com/" + username) {
                    Button(action: {
                        if settings.browser == .inAppSafari {
                            urlToOpen.url = url
                        } else {
                            UIApplication.shared.open(url)
                        }
                    }, label: {
                        HStack {
                            Text("GitHub").bold()
                            Text(username).foregroundColor(.accentColor)
                        }
                    })
                }
                if let username = user.twitter_username, let url = URL(string: "https://twitter.com/\(username)") {
                    Button(action: {
                        if settings.browser == .inAppSafari {
                            urlToOpen.url = url
                        } else {
                            UIApplication.shared.open(url)
                        }
                    }, label: {
                        HStack {
                            Text("Twitter").bold()
                            Text("@" + username).foregroundColor(.accentColor)
                        }
                    })
                    
                }
                if let keybase = user.keybase_signatures {
                    HStack {
                        Text("Keybase").bold()
                        VStack(alignment: .leading) {
                            ForEach(keybase) { auth in
                                HStack {
                                    Text("@" + auth.kb_username).foregroundColor(.accentColor).onTapGesture(count: /*@START_MENU_TOKEN@*/1/*@END_MENU_TOKEN@*/, perform: {
                                        let keybase_url = URL(string: "https://keybase.io/" + auth.kb_username)!
                                        if settings.browser == .inAppSafari {
                                            urlToOpen.url = keybase_url
                                        } else {
                                            UIApplication.shared.open(keybase_url)
                                        }
                                    })
                                    Text("\(Image(systemName: "checkmark.shield.fill"))").foregroundColor(.accentColor).onTapGesture(count: /*@START_MENU_TOKEN@*/1/*@END_MENU_TOKEN@*/, perform: {
                                        if let keybase_url = URL(string: "https://keybase.io/" + auth.kb_username  + "/sigchain#" + auth.sig_hash) {
                                            if settings.browser == .inAppSafari {
                                                urlToOpen.url = keybase_url
                                            } else {
                                                UIApplication.shared.open(keybase_url)
                                            }
                                        }
                                    })
                                }
                            }
                        }
                    }
                }
                if !user.about.isEmpty {
                    VStack(alignment: .leading) {
                        Text("About").bold()
                        // BUG: https://github.com/lobsters/lobsters/issues/933
                        Text(.init(user.about))
                    }
                }
            }
        }.navigationBarTitle(self.username ?? "").onReceive(didReselect) { _ in
            DispatchQueue.main.async {
                self.presentationMode.wrappedValue.dismiss()
            }
        }.onAppear(perform: {
            self.userFetcher.load()
        })
        // this is necessary until multiple sheets can be displayed at one time. See #22
        .safariView(item: $urlToOpen.url, content: { url in
            SafariView(
                url: url,
                configuration: SafariView.Configuration(
                    entersReaderIfAvailable: settings.readerModeEnabled,
                    barCollapsingEnabled: true
                )
            ).preferredControlAccentColor(settings.accentColor).dismissButtonStyle(.close)
        })
    }
}

struct UserView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            UserView(NewestUser(username: "twodayslate", created_at: "2020-01-05T18:25:23.000-06:00", is_admin: false, about: "", is_moderator: false, karma: 64, avatar_url: "/avatars/twodayslate-100.png", invited_by_user: "kimjon", github_username: "twodayslate", twitter_username: "twodayslate", keybase_signatures: nil))
        }.previewLayout(.sizeThatFits)
        
    }
}
