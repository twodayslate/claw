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
                                        })
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
                Image(systemName: "gear")
                Text("Settings")
            })
        }
        .tabBarMinimizeBehavior(.onScrollDown)
        .environment(\.didReselect, didReselect.eraseToAnyPublisher())
        .onOpenURL(perform: { url in
            let _ = print(url)
            let openAction = {
                if url.host == "open", let comps = URLComponents(url: url, resolvingAgainstBaseURL: false), let items = comps.queryItems, let item = items.first, item.name == "url", let itemValue = item.value, let lobsters_url = URL(string: itemValue), APIConfiguration.shared.isLobstersHost(lobsters_url.host) {
                    if lobsters_url.pathComponents.count > 2 {
                        if lobsters_url.pathComponents[1] == "s" {
                            self.observableSheet.sheet = ActiveSheet.story(id: lobsters_url.pathComponents[2])
                        }
                        else if lobsters_url.pathComponents[1] == "u" {
                            self.observableSheet.sheet = ActiveSheet.user(username: lobsters_url.pathComponents[2])
                        } else {
                            self.observableSheet.sheet = ActiveSheet.url(lobsters_url)
                        }
                    } else {
                        self.observableSheet.sheet = ActiveSheet.url(lobsters_url)
                    }
                } else {
                    self.observableSheet.sheet = ActiveSheet.url(url)
                }
            }
            // If the share sheet is currently present, dismiss it. See #22
            if url.host == "open", let shareSheet = ((UIApplication.shared.windows.first?.rootViewController?.presentedViewController as? SwiftUI.UIHostingController<SwiftUI.AnyView>)?.children.first as? UIActivityViewController) {
                shareSheet.dismiss(animated: true, completion: {
                    openAction()
                })
            }
            // Dismiss the current sheet. See #22
            else if url.host == "open" && (self.observableSheet.sheet != nil || self.urlToOpen.url != nil) {
                UIApplication.shared.windows.first?.rootViewController?.presentedViewController?.dismiss(animated: true, completion: {
                        openAction()
                })
            } else {
                openAction()
            }
        })
        .sheet(item: self.$observableSheet.sheet, content: { item in
            switch item {
            case .story(let id):
                SimplePanel{
                    StoryView(id).id(id)
                }.id(id)
                .environmentObject(urlToOpen)
                .environment(settings)
                .environmentObject(self.observableSheet)
                .environment(\.openURL, OpenURLAction { url in
                    return handleUrl(url)
                })
            case .user(let username):
                SimplePanel{
                    UserView(username).id(username)
                }.id(username)
                .environmentObject(urlToOpen)
                .environment(settings)
                .environmentObject(self.observableSheet)
                .environment(\.openURL, OpenURLAction { url in
                    return handleUrl(url)
                })
            case .url(let url):
                SimplePanel {
                    VStack {
                        Text("Unknown URL").bold()
                        Text("\(url)").foregroundColor(Color.accentColor).underline()
                    }
                }
                .environmentObject(urlToOpen)
                .environment(self.settings)
                .environmentObject(self.observableSheet)
                .environment(\.openURL, OpenURLAction { url in
                    return handleUrl(url)
                })
            case .share(let url):
                ShareSheet(activityItems: [url])
            default:
                SimplePanel {
                    Text("Error: \(item.debugDescription)")
                }
                .environment(self.settings)
                .environmentObject(self.observableSheet)
                .environmentObject(urlToOpen)
                .environment(\.openURL, OpenURLAction { url in
                    return handleUrl(url)
                })
            }
        })
        .environment(settings)
        .environmentObject(self.observableSheet)
        .environmentObject(urlToOpen)
        .tint(settings.accentColor)
        .font(Font(.body, sizeModifier: CGFloat(settings.textSizeModifier)))
        .environment(\.openURL, OpenURLAction { url in
            return handleUrl(url)
        })
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
        ContentView().modelContainer(PersistenceControllerV2.preview.container)
    }
}
