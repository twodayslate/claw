import SwiftUI
import SwiftData
import Combine

import BetterSafariView
import SimpleCommon

struct DidReselectKey: EnvironmentKey {
    static let defaultValue = PassthroughSubject<TabSelection, Never>().eraseToAnyPublisher()
}

extension EnvironmentValues {
    var didReselect: AnyPublisher<TabSelection, Never> {
        get {
            return self[DidReselectKey.self]
        }
        set {
            self[DidReselectKey.self] = newValue
        }
    }
}


enum TabSelection: String {
    case Hottest, Newest, Settings, Tags
}
/** https://stackoverflow.com/a/64019877/193772 */
struct NavigableTabViewItem<Content: View, TabItem: View>: View {
    @Environment(\.didReselect) var didReselect
    @Environment(Settings.self) var settings
    @Environment(\.dismiss) private var dismiss
    
    let tabSelection: TabSelection
    let content: Content
    let tabItem: TabItem
    
    init(tabSelection: TabSelection, @ViewBuilder content: () -> Content, @ViewBuilder tabItem: () -> TabItem) {
        self.tabSelection = tabSelection
        self.content = content()
        self.tabItem = tabItem()
    }

    var body: some View {
        let didReselectThis = didReselect.filter( {
            $0 == tabSelection
        }).eraseToAnyPublisher()

        NavigationView {
                self.content.onReceive(didReselect) { _ in
                    DispatchQueue.main.async {
                        dismiss()
                    }
                }
        }.tabItem {
            self.tabItem
        }
        .tag(tabSelection)
        .navigationViewStyle(StackNavigationViewStyle())
        .environment(\.didReselect, didReselectThis)
    }
}

struct ContentView: View {
    @EnvironmentObject private var storeModel: StoreKitModel
    @EnvironmentObject private var sceneDelegate: ClawSceneDelegate
    @StateObject private var lobstersSession = LobstersSession()
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.modelContext) private var modelContext
    @Query(Settings.fetchLatestDescriptor) var allSettings: [Settings]
            
    var settings: Settings {
        if let first = self.allSettings.first {
            if UIApplication.shared.alternateIconName != first.alternateIconName {
                UIApplication.shared.setAlternateIconName(first.alternateIconName, completionHandler: {error in
                    if let _ = error {
                        first.alternateIconName = nil
                        return
                    }
                })
            }
            return first
        }

        let newSettings = Settings()
        modelContext.insert(newSettings)
        return newSettings
    }

    @AppStorage("contentViewSelection") private var _selection: TabSelection = .Hottest
    @AppStorage(TabBarMinimizePreference.defaultsKey)
    private var tabBarMinimizePreference: TabBarMinimizePreference = .onScroll

    @State private var didReselect = PassthroughSubject<TabSelection, Never>()

    @Environment(\.sizeCategory) var sizeCategory
        
    @StateObject var observableSheet = ObservableActiveSheet()
    @StateObject var urlToOpen = ObservableURL()
    
    var body: some View {
        let selection = Binding(get: { self._selection },
                                        set: {
                                            if self._selection == $0 {
                                                didReselect.send($0)
                                            }
                                            self._selection = $0
                                            if storeModel.owned {
                                                lobstersSession.preparePage(for: $0)
                                            }
                                        })
        withEnvironment {
            TabView(selection: selection) {
                NavigableTabViewItem(tabSelection: TabSelection.Hottest, content: {
                    HottestView()
                }, tabItem: {
                    _selection == .Hottest ? Image(systemName: "flame.fill") : Image(systemName: "flame")
                    Text("Hottest")
                })

                NavigableTabViewItem(tabSelection: TabSelection.Newest, content: {
                    NewestView()
                }, tabItem: {
                    _selection == .Newest ? Image(systemName: "burst.fill") : Image(systemName: "burst")
                    Text("Newest")
                })

                NavigableTabViewItem(tabSelection: TabSelection.Tags, content: {
                    SelectedTagsView()
                }, tabItem: {
                    _selection == .Tags ? Image(systemName: "tag.fill") : Image(systemName: "tag")
                    Text("Tags")
                })

                NavigableTabViewItem(tabSelection: TabSelection.Settings, content: {
                    SettingsView()
                }, tabItem: {
                    if storeModel.owned, lobstersSession.isAuthenticated {
                        if let avatar = lobstersSession.avatarImage {
                            Image(uiImage: avatar)
                                .renderingMode(.original)
                                .clipShape(Circle())
                                .shadow(
                                    color: .black.opacity(0.28),
                                    radius: 2,
                                    x: 0,
                                    y: 1
                                )
                        } else {
                            Image(systemName: "person.crop.circle.fill")
                        }
                    } else {
                        Image(systemName: "gear")
                    }
                    Text("Settings")
                })
            }
            .tabBarMinimizeBehavior(tabBarMinimizePreference.behavior)
        }
        .environment(\.didReselect, didReselect.eraseToAnyPublisher())
        .environmentObject(lobstersSession)
        .onAppear {
            handlePendingAppURL()
            let entitlementAvailable = storeModel.hasInitialized && storeModel.owned
            lobstersSession.setEntitlementAvailable(entitlementAvailable)
            if entitlementAvailable {
                lobstersSession.preparePage(for: _selection)
            }
        }
        .onChange(of: storeModel.owned) { _, owned in
            guard storeModel.hasInitialized else {
                return
            }
            lobstersSession.setEntitlementAvailable(owned)
            Task {
                if owned {
                    await lobstersSession.start()
                    lobstersSession.preparePage(for: _selection)
                } else {
                    await lobstersSession.signOut()
                }
            }
        }
        .onChange(of: scenePhase) { _, phase in
            guard storeModel.owned else {
                return
            }
            switch phase {
            case .active:
                lobstersSession.applicationDidBecomeActive()
            case .background:
                lobstersSession.applicationDidEnterBackground()
            default:
                break
            }
        }
        .task {
            do {
                if !storeModel.hasInitialized {
                    try await storeModel.initialize()
                }
                lobstersSession.setEntitlementAvailable(storeModel.owned)
                if storeModel.owned {
                    await lobstersSession.start()
                    lobstersSession.preparePage(for: _selection)
                } else {
                    await lobstersSession.signOut()
                }
            } catch {
                lobstersSession.setEntitlementAvailable(false)
                lobstersSession.markEntitlementUnavailable(error)
            }
        }
        .onChange(of: sceneDelegate.pendingURL) { _, _ in
            handlePendingAppURL()
        }
        .sheet(item: self.$observableSheet.sheet, content: { item in
            switch item {
            case .story(let id, let url):
                withEnvironment {
                    SimplePanel{
                        StoryView(id, commentsURL: url).id(id)
                    }.id(id)
                }
            case .user(let username):
                withEnvironment {
                    SimplePanel{
                        UserView(username).id(username)
                    }.id(username)
                }
            case .url(let url):
                withEnvironment {
                    SimplePanel {
                        VStack {
                            Text("Unknown URL").bold()
                            Text("\(url)").foregroundColor(Color.accentColor).underline()
                        }
                    }
                }
            case .share(let url):
                ShareSheet(activityItems: [url])
            default:
                withEnvironment {
                    SimplePanel {
                        Text("Error: \(item.debugDescription)")
                    }
                }
            }
        })
    }

    func withEnvironment<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        content()
            .environment(settings)
            .environmentObject(lobstersSession)
            .environmentObject(self.observableSheet)
            .environmentObject(urlToOpen)
            .tint(settings.accentColor)
            .font(Font(.body, sizeModifier: CGFloat(settings.textSizeModifier)))
            .environment(\.openURL, OpenURLAction { url in
                return handleUrl(url)
            })
    }

    private func handleIncomingURL(_ url: URL) {
        let openAction = {
            if url.host == "open",
               let components = URLComponents(
                url: url,
                resolvingAgainstBaseURL: false
               ),
               let item = components.queryItems?.first(where: { $0.name == "url" }),
               let value = item.value,
               let lobstersURL = URL(string: value),
               APIConfiguration.shared.isLobstersURL(lobstersURL) {
                if lobstersURL.pathComponents.count > 2,
                   lobstersURL.pathComponents[1] == "s" {
                    observableSheet.sheet = .story(
                        id: lobstersURL.pathComponents[2],
                        url: lobstersURL
                    )
                } else if lobstersURL.pathComponents.count > 2,
                          lobstersURL.pathComponents[1] == "u" {
                    observableSheet.sheet = .user(
                        username: lobstersURL.pathComponents[2]
                    )
                } else {
                    observableSheet.sheet = .url(lobstersURL)
                }
            } else {
                observableSheet.sheet = .url(url)
            }
        }

        // If the share sheet is currently present, dismiss it. See #22.
        if url.host == "open",
           let shareSheet = (
            (UIApplication.shared.windows.first?.rootViewController?
                .presentedViewController as? SwiftUI.UIHostingController<SwiftUI.AnyView>)?
                .children.first as? UIActivityViewController
           ) {
            shareSheet.dismiss(animated: true, completion: openAction)
        } else if url.host == "open"
                    && (observableSheet.sheet != nil || urlToOpen.url != nil) {
            // Dismiss the current sheet before presenting the new route. See #22.
            UIApplication.shared.windows.first?.rootViewController?
                .presentedViewController?
                .dismiss(animated: true, completion: openAction)
        } else {
            openAction()
        }
    }

    private func handlePendingAppURL() {
        guard let url = sceneDelegate.pendingURL else {
            return
        }
        handleIncomingURL(url)
        sceneDelegate.consume(url)
    }

    func handleUrl(_ url: URL) -> OpenURLAction.Result {
        if settings.browser == .inAppSafari, (url.scheme == "https" || url.scheme == nil || url.scheme == "http") {
            if url.scheme == nil {
                var comps = URLComponents(url: url, resolvingAgainstBaseURL: true)
                comps?.scheme = "https"
                if let newUrl = comps?.url {
                    urlToOpen.url = newUrl
                    return .handled
                }
                return .systemAction
            }
            urlToOpen.url = url
            return .handled
        } else {
            return .systemAction
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .modelContainer(PersistenceControllerV2.preview.container)
            .environmentObject(StoreKitModel.pro)
            .environmentObject(ClawSceneDelegate())
    }
}
