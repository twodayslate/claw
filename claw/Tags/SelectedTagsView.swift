import SwiftUI

struct SelectedTagsView: View {
    @State var tags: [String] = UserDefaults.standard.object(forKey: "selectedTags") as? [String] ?? ["programming"] {
        didSet {
            UserDefaults.standard.set(self.tags, forKey: "selectedTags")
        }
    }

    var body: some View {
        let wrapper = TagStoryView(tags: self.tags)
        
        wrapper.id(self.tags)
            .navigationBarItems(leading: NavigationLink(
                                    destination: SelectTagsView(tags: $tags).navigationBarTitle("Selected Tags", displayMode: .inline),
            label: {
                Text("Edit").bold()
            }), trailing: Button(action: {
                DispatchQueue.main.async {
                    wrapper.stories.reload()
                }
            }, label: {
                if wrapper.stories.isReloading {
                    ProgressView().progressViewStyle(CircularProgressViewStyle())
                } else {
                    Image(systemName: "arrow.clockwise")
                }
            })).onChange(of: tags, perform: { value in
                wrapper.stories.tags = tags
                wrapper.stories.load()
            })
    }
}

let alphabet = ["A","B","C","D","E","F","G","H","I","J","K","L","M","N","O","P","Q","R","S","T","U","V","W","X","Y","Z"]

/// https://stackoverflow.com/a/58901508/193772
struct DestinationDataKey: PreferenceKey {
    typealias Value = [DestinationData]

    static var defaultValue: [DestinationData] = []

    static func reduce(value: inout [DestinationData], nextValue: () -> [DestinationData]) {
        value.append(contentsOf: nextValue())
    }
}

struct DestinationData: Equatable {
    let destination: String
    let frame: CGRect
}

struct DestinationDataSetter: View {
    let destination: String

    var body: some View {
        GeometryReader { geometry in
            Rectangle()
                .fill(Color.clear)
                .preference(key: DestinationDataKey.self,
                            value: [DestinationData(destination: self.destination, frame: geometry.frame(in: .global))])
        }
    }
}

/// https://stackoverflow.com/questions/58809357/swiftui-list-with-section-index-on-right-hand-side
struct SelectTagsView: View {
    @Binding var tags: [String]
    
    @ObservedObject var fetcher = TagFetcher.shared
    
    @GestureState var longPressGestureState = false
    
    @State var destinations: [String: CGRect] = [:]
    
    @ObservedObject var searchBar = SearchBar()
    
    @State var lastScrolledId: String? = nil
    
    @EnvironmentObject var settings: Settings
    
    var body: some View {
        ScrollViewReader { scrollReader in
            ZStack(alignment: .topTrailing) {
                List {
                    EmptyView().id("top")
                    ForEach(alphabet, id: \.self) { letter in
                        let filtered = fetcher.tags.filter({$0.tag.prefix(1).uppercased() == letter && (self.searchBar.text.isEmpty ||  $0.tag.lowercased().contains(self.searchBar.text.lowercased())) })
                        if filtered.count > 0 {
                            Section(header: Text(letter)) {
                                ForEach(filtered) { tag in
                                    Button(action: {
                                        
                                        if tags.contains(where: {$0 == tag.tag}) {
                                            if tags.count > 1 {
                                                tags.removeAll(where: {$0 == tag.tag})
                                            }
                                        } else {
                                            tags.append(tag.tag)
                                        }
                                        UserDefaults.standard.set(self.tags, forKey: "selectedTags")
                                    }, label: {
                                        HStack {
                                            VStack(alignment: .leading) {
                                                Text("\(tag.tag)").bold()
                                                Text("\(tag.description)").foregroundColor(.gray)
                                            }
                                            Spacer()
                                            if tags.contains(where: {$0 == tag.tag}) {
                                                Text("\(Image(systemName: "checkmark"))").bold().foregroundColor(.accentColor)
                                            }
                                        }
                                    })
                                }
                            }.id(letter)
                        }
                    }
                    HStack {
                        Spacer()
                        Text("\(fetcher.tags.count) Tags").font(Font(.footnote, sizeModifier: CGFloat(settings.textSizeModifier))).foregroundColor(.gray)
                        Spacer()
                    }.id("bottom")
                }.listStyle(PlainListStyle()).add(self.searchBar)
                
                VStack(alignment: .trailing) {
                    Spacer().background(DestinationDataSetter(destination: "top"))
                        ForEach(alphabet, id: \.self) { letter in
                            HStack {
                                Spacer()
                                Button(action: {
                                    print("letter = \(letter)")
                                    //need to figure out if there is a name in this section before I allow scrollto or it will crash
                                    if fetcher.tags.first(where: { $0.tag.prefix(1).uppercased() == letter }) != nil {
                                        UISelectionFeedbackGenerator().selectionChanged()
                                        //withAnimation {
                                        scrollReader.scrollTo(letter, anchor: .top)
                                       //}
                                    }
                                }, label: {
                                    Text(letter)
                                    .font(.system(size: 12))
                                        .padding(.trailing, 7).background(DestinationDataSetter(destination: letter))
                                })
                            }
                        }
                    Spacer().background(DestinationDataSetter(destination: "bottom"))
                }.ignoresSafeArea(.keyboard, edges: .all).zIndex(1.0).simultaneousGesture(DragGesture(minimumDistance: 0.0, coordinateSpace: .global).onChanged({ action in
                    print("drag letter", action, action.location, self.destinations)
                    for (id, frame) in self.destinations {
                        if frame.insetBy(dx: -20, dy: 0).contains(action.location) {
                            print("letter", id)
                            DispatchQueue.main.async {
                                if fetcher.tags.first(where: { $0.tag.prefix(1).uppercased() == id }) != nil {
                                    if lastScrolledId != id {
                                        UISelectionFeedbackGenerator().selectionChanged()
                                    }
                                    self.lastScrolledId = id
                                    scrollReader.scrollTo(id, anchor: .top)
                                } else if id == "top" {
                                    scrollReader.scrollTo(id, anchor: .top)
                                } else if id == "bottom" {
                                    scrollReader.scrollTo("bottom", anchor: .top)
                                }
                            }
                        }
                    }
                }).onEnded({ action in
                    self.lastScrolledId = nil
                }))
            }.onPreferenceChange(DestinationDataKey.self) { preferences in
                for p in preferences {
                    self.destinations[p.destination] = p.frame
                }
            }.onAppear(perform: {
                self.fetcher.loadIfEmpty()
            })
        }
    }
}
