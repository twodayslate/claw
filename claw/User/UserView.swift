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
    @State private var avatarCollapseProgress: CGFloat = 0
    
    @Environment(Settings.self) var settings
    @EnvironmentObject var urlToOpen: ObservableURL

    private enum Layout {
        static let profileAvatarSize: CGFloat = 100
        static let titleAvatarSize: CGFloat = 28
        static let titleAvatarSpacing: CGFloat = 8
    }
    
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
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                if let user = self.user {
                    UserAvatarLoader(
                        user: user,
                        size: Layout.profileAvatarSize
                    )
                        .frame(maxWidth: .infinity)
                        .padding(.vertical)
                        .opacity(1 - avatarCollapseProgress)
                        .scaleEffect(1 - (0.15 * avatarCollapseProgress))
                        .accessibilityIdentifier("user-profile-avatar")

                    if let karma = user.karma {
                        HStack {
                            Text("Karma").bold()
                            Text("\(karma)")
                        }
                        .padding()
                        Divider().padding(.leading)
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
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                        })
                        .buttonStyle(.plain)
                        .padding()
                        Divider().padding(.leading)
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
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                        })
                        .buttonStyle(.plain)
                        .padding()
                        Divider().padding(.leading)
                    }
                    if let keybase = user.keybase_signatures {
                        HStack(alignment: .top) {
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
                        .padding()
                        Divider().padding(.leading)
                    }
                    if !user.about.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("About").bold()
                            HTMLView(html: user.about.trimmingCharacters(in: .whitespacesAndNewlines))
                        }
                        .padding()
                    }
                }

                Text("Stories")
                    .font(style: .title2)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)
                    .padding(.top, 24)
                    .padding(.bottom, 8)
                Divider().padding(.leading)

                if stories.items.isEmpty && (!stories.hasAttemptedLoad || stories.isLoading) {
                    ForEach(0..<3) { _ in
                        StoryListCellView(story: NewestStory.placeholder)
                            .redacted(reason: .placeholder)
                            .allowsHitTesting(false)
                        Divider().padding(.leading)
                    }
                } else if stories.items.isEmpty {
                    Label("No submitted stories", systemImage: "newspaper")
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding()
                } else {
                    ForEach(stories.items) { story in
                        StoryListCellView(story: story)
                            .id(story)
                            .task {
                                do {
                                    try await stories.more(story)
                                } catch is CancellationError {
                                    return
                                } catch {
                                    self.error = error
                                }
                            }
                        Divider().padding(.leading)
                    }
                }

                if stories.isLoadingMore {
                    HStack {
                        Spacer()
                        ProgressView()
                        Spacer()
                    }
                    .padding()
                }
            }
        }
        .onScrollGeometryChange(for: CGFloat.self, of: { geometry in
            let offset = geometry.contentOffset.y + geometry.contentInsets.top
            let collapseDistance = Layout.profileAvatarSize
                - (2 * Layout.titleAvatarSize)
            return min(max(offset / collapseDistance, 0), 1)
        }) { _, progress in
            avatarCollapseProgress = progress
        }
        .navigationBarTitle(self.username ?? "")
        .toolbar {
            if let user = self.user, avatarCollapseProgress > 0 {
                ToolbarItem(placement: .principal) {
                    HStack(
                        spacing: Layout.titleAvatarSpacing * avatarCollapseProgress
                    ) {
                        UserAvatarLoader(
                            user: user,
                            size: Layout.titleAvatarSize
                        )
                        .frame(
                            width: Layout.titleAvatarSize * avatarCollapseProgress,
                            height: Layout.titleAvatarSize
                        )
                        .scaleEffect(avatarCollapseProgress)
                        .opacity(avatarCollapseProgress)
                        .accessibilityIdentifier("user-title-avatar")
                        .accessibilityHidden(avatarCollapseProgress < 0.9)

                        Text(self.username ?? "")
                            .font(style: .headline)
                    }
                }
            }
        }
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
