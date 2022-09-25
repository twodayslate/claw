import SwiftUI
import CoreData
import Combine
import BetterSafariView

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
    @EnvironmentObject var settings: Settings
    @Environment(\.presentationMode) var presentationMode: Binding<PresentationMode>
    
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
                self.content.environmentObject(settings).onReceive(didReselect) { _ in
                    DispatchQueue.main.async {
                        self.presentationMode.wrappedValue.dismiss()
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
    @Environment(\.managedObjectContext) private var viewContext
        
    @FetchRequest(fetchRequest: Settings.fetchAllRequest()) var all_settings: FetchedResults<Settings>
            
    var settings: Settings {
        if let first = self.all_settings.first {
            if UIApplication.shared.alternateIconName != first.alternateIconName {
                UIApplication.shared.setAlternateIconName(first.alternateIconName, completionHandler: {error in
                    if let _ = error {
                        first.alternateIconName = nil
                        try? first.managedObjectContext?.save()
                        return
                    }
                })
            }
            return first
        }

        return Settings(context: viewContext)
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
            }).environmentObject(settings)
            
            NavigableTabViewItem(tabSelection: TabSelection.Newest, content: {
                    NewestView()
            }, tabItem: {
                _selection == .Newest ? Image(systemName: "burst.fill") : Image(systemName: "burst")
                Text("Newest")
            }).environmentObject(settings)
            
            NavigableTabViewItem(tabSelection: TabSelection.Tags, content: {
                    SelectedTagsView()
            }, tabItem: {
                _selection == .Tags ? Image(systemName: "tag.fill") : Image(systemName: "tag")
                Text("Tags")
            }).environmentObject(settings)

            NavigableTabViewItem(tabSelection: TabSelection.Settings, content: {
                    SettingsView()
            }, tabItem: {
                Image(systemName: "gear")
                Text("Settings")
            }).environmentObject(settings).environment(\.managedObjectContext, viewContext)
        }.environment(\.didReselect, didReselect.eraseToAnyPublisher())
        .onOpenURL(perform: { url in
            let _ = print(url)
            let openAction = {
                if url.host == "open", let comps = URLComponents(url: url, resolvingAgainstBaseURL: false), let items = comps.queryItems, let item = items.first, item.name == "url", let itemValue = item.value, let lobsters_url = URL(string: itemValue), lobsters_url.host == "lobste.rs" {
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
                EZPanel{
                    StoryView(id).id(id)
                }.id(id)
                .environmentObject(urlToOpen)
                .environmentObject(settings)
                .environmentObject(self.observableSheet)
                .environment(\.managedObjectContext, viewContext)
                .environment(\.openURL, OpenURLAction { url in
                    if settings.browser == .inAppSafari {
                        urlToOpen.url = url
                        return .handled
                    }
                    return .systemAction
                })
            case .user(let username):
                EZPanel{
                    UserView(username).id(username)
                }.id(username)
                .environmentObject(urlToOpen)
                .environmentObject(settings)
                .environmentObject(self.observableSheet)
                .environment(\.managedObjectContext, viewContext)
                .environment(\.openURL, OpenURLAction { url in
                    if settings.browser == .inAppSafari {
                        urlToOpen.url = url
                        return .handled
                    }
                    return .systemAction
                })
            case .url(let url):
                EZPanel {
                    VStack {
                        Text("Unknown URL").bold()
                        Text("\(url)").foregroundColor(Color.accentColor).underline()
                    }
                }
                .environmentObject(urlToOpen)
                .environmentObject(settings)
                .environmentObject(self.observableSheet)
                .environment(\.managedObjectContext, viewContext)
                .environment(\.openURL, OpenURLAction { url in
                    if settings.browser == .inAppSafari {
                        urlToOpen.url = url
                        return .handled
                    }
                    return .systemAction
                })
            case .share(let url):
                ShareSheet(activityItems: [url])
            default:
                EZPanel {
                    Text("Error: \(item.debugDescription)")
                }
                .environmentObject(settings)
                .environment(\.managedObjectContext, viewContext)
                .environmentObject(self.observableSheet)
                .environmentObject(urlToOpen)
                .environment(\.openURL, OpenURLAction { url in
                    if settings.browser == .inAppSafari {
                        urlToOpen.url = url
                        return .handled
                    }
                    return .systemAction
                })
            }
        })
        .environmentObject(settings)
        .environment(\.managedObjectContext, viewContext)
        .environmentObject(self.observableSheet)
        .environmentObject(urlToOpen)
        .accentColor(settings.accentColor)
        .font(Font(.body, sizeModifier: CGFloat(settings.textSizeModifier)))
        .environment(\.openURL, OpenURLAction { url in
            if settings.browser == .inAppSafari {
                urlToOpen.url = url
                return .handled
            }
            return .systemAction
        })
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView().environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
    }
}
