import SwiftUI
import BetterSafariView

struct UserView: View {
    @State var user: NewestUser?
    @StateObject private var userFetcher: UserFetcher
    @StateObject private var stories: UserStoryFetcher
    var username: String?
    @Environment(\.didReselect) var didReselect
    @Environment(\.dismiss) private var dismiss
    @State private var error: Error?
    
    @Environment(Settings.self) var settings
    @EnvironmentObject var urlToOpen: ObservableURL
    
    init(_ user: NewestUser) {
        self._userFetcher = StateObject(wrappedValue: UserFetcher(user.username))
        self._stories = StateObject(wrappedValue: UserStoryFetcher(username: user.username))
        self.user = user
        self.username = user.username
    }
    
    init(_ username: String) {
        self.username = username
        self._userFetcher = StateObject(wrappedValue: UserFetcher(username))
        self._stories = StateObject(wrappedValue: UserStoryFetcher(username: username))
    }
    
    var body: some View {
        List {
            if let user = self.user {
                HStack(alignment: .center) {
                    Spacer()
                    UserAvatarLoader(user: user)
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
                                    Text("@" + auth.kb_username).foregroundColor(.accentColor).onTapGesture(count: 1, perform: {
                                        let keybase_url = URL(string: "https://keybase.io/" + auth.kb_username)!
                                        if settings.browser == .inAppSafari {
                                            urlToOpen.url = keybase_url
                                        } else {
                                            UIApplication.shared.open(keybase_url)
                                        }
                                    })
                                    Text("\(Image(systemName: "checkmark.shield.fill"))").foregroundColor(.accentColor).onTapGesture(count: 1, perform: {
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
                        HTMLView(html: user.about.trimmingCharacters(in: .whitespacesAndNewlines))
                    }
                }
            }
            Section("Stories") {
                if stories.items.isEmpty && (!stories.hasAttemptedLoad || stories.isLoading) {
                    ForEach(0..<3) { _ in
                        StoryListCellView(story: NewestStory.placeholder)
                            .redacted(reason: .placeholder)
                            .allowsHitTesting(false)
                    }
                } else if stories.items.isEmpty {
                    Label("No submitted stories", systemImage: "newspaper")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(stories.items) { story in
                        StoryListCellView(story: story)
                            .task {
                                do {
                                    try await stories.more(story)
                                } catch is CancellationError {
                                    return
                                } catch {
                                    self.error = error
                                }
                            }
                    }
                }

                if stories.isLoadingMore {
                    HStack {
                        Spacer()
                        ProgressView()
                        Spacer()
                    }
                }
            }
        }
        .navigationBarTitle(self.username ?? "")
        .onReceive(didReselect) { _ in
            DispatchQueue.main.async {
                dismiss()
            }
        }
        .task {
            do {
                guard self.user == nil else {
                    return
                }
                self.user = try await self.userFetcher.load()
            } catch is CancellationError {
                return
            } catch {
                self.error = error
            }
        }
        .task {
            do {
                try await stories.loadIfEmpty()
            } catch is CancellationError {
                return
            } catch {
                self.error = error
            }
        }
        .refreshable {
            do {
                try await stories.reload()
            } catch is CancellationError {
                return
            } catch {
                self.error = error
            }
        }
        .errorAlert(error: $error)
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
            UserView(.placeholder)
        }
        .previewLayout(.sizeThatFits)
        .modelContainer(PersistenceControllerV2.preview.container)
        .environment(SettingsV2())
        .environmentObject(ObservableURL())
    }
}
