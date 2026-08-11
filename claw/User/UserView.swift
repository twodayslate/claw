import SwiftUI
import BetterSafariView

private struct UserAvatarSourcePreferenceKey: PreferenceKey {
    static var defaultValue: Anchor<CGRect>?

    static func reduce(
        value: inout Anchor<CGRect>?,
        nextValue: () -> Anchor<CGRect>?
    ) {
        value = nextValue() ?? value
    }
}

struct UserView: View {
    @State var user: NewestUser?
    @StateObject private var userFetcher: UserFetcher
    @StateObject private var stories: UserStoryFetcher
    var username: String?
    @Environment(\.didReselect) var didReselect
    @Environment(\.dismiss) private var dismiss
    @State private var error: Error?
    @State private var avatarScrollOffset: CGFloat = 0
    @State private var initialAvatarFrame: CGRect?
    @State private var titleAvatarFrame: CGRect?
    
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
                    HStack {
                        Spacer()
                        Color.clear
                            .frame(
                                width: Layout.profileAvatarSize,
                                height: Layout.profileAvatarSize
                            )
                            .onGeometryChange(for: CGRect.self) { geometry in
                                geometry.frame(in: .global)
                            } action: { frame in
                                guard avatarScrollOffset <= 0 else {
                                    return
                                }
                                initialAvatarFrame = frame
                            }
                            .anchorPreference(
                                key: UserAvatarSourcePreferenceKey.self,
                                value: .bounds
                            ) { $0 }
                            .accessibilityHidden(true)
                        Spacer()
                    }
                    .padding(.vertical)

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
            geometry.contentOffset.y + geometry.contentInsets.top
        }) { _, offset in
            avatarScrollOffset = offset
        }
        .navigationBarTitle(self.username ?? "")
        .toolbar {
            if self.user != nil {
                ToolbarItem(placement: .principal) {
                    HStack(
                        spacing: Layout.titleAvatarSpacing * avatarCollapseProgress
                    ) {
                        Color.clear
                            .frame(
                                width: Layout.titleAvatarSize,
                                height: Layout.titleAvatarSize
                            )
                            .onGeometryChange(for: CGRect.self) { geometry in
                                geometry.frame(in: .global)
                            } action: { frame in
                                titleAvatarFrame = frame
                            }
                            .frame(width: Layout.titleAvatarSize * avatarCollapseProgress)
                            .accessibilityHidden(true)

                        Text(self.username ?? "")
                            .font(style: .headline)
                    }
                }
            }
        }
        .overlayPreferenceValue(UserAvatarSourcePreferenceKey.self) { sourceAnchor in
            if let user = self.user {
                UserAvatarPortal(
                    user: user,
                    sourceAnchor: sourceAnchor,
                    destinationFrame: titleAvatarFrame,
                    progress: avatarCollapseProgress
                )
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

    private var avatarCollapseProgress: CGFloat {
        guard let initialAvatarFrame, let titleAvatarFrame else {
            return 0
        }

        let collapseDistance = max(
            initialAvatarFrame.midY - titleAvatarFrame.midY,
            1
        )
        return min(max(avatarScrollOffset / collapseDistance, 0), 1)
    }
}

private struct UserAvatarPortal: View {
    let user: NewestUser
    let sourceAnchor: Anchor<CGRect>?
    let destinationFrame: CGRect?
    let progress: CGFloat

    var body: some View {
        GeometryReader { geometry in
            if let frame = avatarFrame(in: geometry) {
                UserAvatarLoader(user: user, size: frame.width)
                    .position(x: frame.midX, y: frame.midY)
                    .accessibilityIdentifier("user-profile-avatar")
            }
        }
        .allowsHitTesting(false)
    }

    private func avatarFrame(in geometry: GeometryProxy) -> CGRect? {
        let source = sourceAnchor.map { geometry[$0] }
        let destination = destinationFrame.map { frame in
            let globalFrame = geometry.frame(in: .global)
            return frame.offsetBy(
                dx: -globalFrame.minX,
                dy: -globalFrame.minY
            )
        }

        if let source, let destination {
            return interpolatedFrame(
                from: source,
                to: destination,
                progress: progress
            )
        }

        // LazyVStack eventually removes the source marker. Once collapsed,
        // the toolbar destination must keep the shared avatar alive by itself.
        return source ?? destination
    }

    private func interpolatedFrame(
        from source: CGRect,
        to destination: CGRect,
        progress: CGFloat
    ) -> CGRect {
        let progress = min(max(progress, 0), 1)

        return CGRect(
            x: source.minX + ((destination.minX - source.minX) * progress),
            y: source.minY + ((destination.minY - source.minY) * progress),
            width: source.width + ((destination.width - source.width) * progress),
            height: source.height + ((destination.height - source.height) * progress)
        )
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
