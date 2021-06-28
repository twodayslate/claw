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
public class SettingModel:ObservableObject {
    @FetchRequest(fetchRequest: Settings.fetchAllRequest()) var all_settings: FetchedResults<Settings>
       
    var viewContext = PersistenceController.shared.container.viewContext
    @ObservedObject var observableSheet = ObservableActiveSheet()
    @ObservedObject var urlToOpen = ObservableURL()
    @Published var settings: Settings? = nil
//    var settings: Settings {
//        if let first = self.all_settings.first {
//            if UIApplication.shared.alternateIconName != first.alternateIconName {
//                UIApplication.shared.setAlternateIconName(first.alternateIconName, completionHandler: {error in
//                    if let _ = error {
//                        first.alternateIconName = nil
//                        try? first.managedObjectContext?.save()
//                        return
//                    }
//                })
//            }
//            return first
//        }
//        return Settings(context: viewContext)
//    }
}

struct SettingValue: EnvironmentKey {
    static var defaultValue: SettingModel = .init()
}

extension EnvironmentValues {
    var settingValue: SettingModel {
        get { self[SettingValue.self] }
        set { self[SettingValue.self] = newValue }
    }
}
extension View {
    func settingValue(_ settings: SettingModel) -> some View {
        environment(\.settingValue, settings)
    }
}

enum TabSelection: String {
    case Hottest, Newest, Settings, Tags
}
/** https://stackoverflow.com/a/64019877/193772 */
struct NavigableTabViewItem<Content: View, TabItem: View>: View {
    @Environment(\.settingValue) var settingValue
    @Environment(\.didReselect) var didReselect
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
            self.content.environmentObject(settingValue.settings!).onReceive(didReselect) { _ in
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
    @Environment(\.settingValue) var settingValue
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
            self.settingValue.settings = first
            return first
        }
        self.settingValue.settings = Settings(context: settingValue.viewContext)
        return Settings(context: settingValue.viewContext)
    }

    @AppStorage("contentViewSelection") private var _selection: TabSelection = .Hottest

    @State private var didReselect = PassthroughSubject<TabSelection, Never>()

    @Environment(\.sizeCategory) var sizeCategory

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
            }).environment(\.settingValue,settingValue)
            
            NavigableTabViewItem(tabSelection: TabSelection.Newest, content: {
                    NewestView()
            }, tabItem: {
                _selection == .Newest ? Image(systemName: "burst.fill") : Image(systemName: "burst")
                Text("Newest")
            }).environment(\.settingValue,settingValue)
            
            NavigableTabViewItem(tabSelection: TabSelection.Tags, content: {
                    SelectedTagsView()
            }, tabItem: {
                _selection == .Tags ? Image(systemName: "tag.fill") : Image(systemName: "tag")
                Text("Tags")
            }).environment(\.settingValue,settingValue)

            NavigableTabViewItem(tabSelection: TabSelection.Settings, content: {
                    SettingsView()
            }, tabItem: {
                Image(systemName: "gear")
                Text("Settings")
            }).environment(\.settingValue,settingValue)
        }.environment(\.didReselect, didReselect.eraseToAnyPublisher()).accentColor(settings.accentColor).font(Font(.body, sizeModifier: CGFloat(settings.textSizeModifier))).onOpenURL(perform: { url in
            let _ = print(url)
            //UIApplication.shared.windows.first?.rootViewController?.presentedViewController?.dismiss(animated: true, completion: nil)
            
            if url.host == "open", let comps = URLComponents(url: url, resolvingAgainstBaseURL: false), let items = comps.queryItems, let item = items.first, item.name == "url", let itemValue = item.value, let lobsters_url = URL(string: itemValue), lobsters_url.host == "lobste.rs" {
                if lobsters_url.pathComponents.count > 2 {
                    if lobsters_url.pathComponents[1] == "s" {
                        settingValue.observableSheet.sheet = ActiveSheet.story(id: lobsters_url.pathComponents[2])
                    }
                    else if lobsters_url.pathComponents[1] == "u" {
                        settingValue.observableSheet.sheet = ActiveSheet.user(username: lobsters_url.pathComponents[2])
                    } else {
                        settingValue.observableSheet.sheet = ActiveSheet.url(lobsters_url)
                    }
                } else {
                    settingValue.observableSheet.sheet = ActiveSheet.url(lobsters_url)
                }
            } else {
                settingValue.observableSheet.sheet = ActiveSheet.url(url)
            }
        })
        .sheet(item: settingValue.observableSheet.bindingSheet, content: { item in
            switch item {
            case .story(let id):
                EZPanel{ StoryView(id)
                }
                .environment(\.settingValue,settingValue)
            case .user(let username):
                EZPanel{ UserView(username) }.environment(\.settingValue,settingValue)
            case .url(let url):
                EZPanel {
                    VStack {
                        Text("Unknown URL").bold()
                        Text("\(url)")
                    }
                }
            case .share(let url):
                ShareSheet(activityItems: [url])
            default:
                Text("Error: \(item.debugDescription)")
            }
        }).environmentObject(settings).environment(\.settingValue,settingValue)
        EmptyView().fullScreenCover(item: settingValue.urlToOpen.bindingUrl, content: { url in
            SafariView(
                url: url,
                configuration: SafariView.Configuration(
                    entersReaderIfAvailable: settingValue.settings!.readerModeEnabled,
                    barCollapsingEnabled: true
                )
            ).preferredControlAccentColor(settingValue.settings!.accentColor).dismissButtonStyle(.close)
        })
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView().environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
    }
}
