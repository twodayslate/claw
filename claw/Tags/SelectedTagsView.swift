import SwiftUI

struct SelectedTagsView: View {
    @State var tags: [String] = UserDefaults.standard.object(forKey: "selectedTags") as? [String] ?? ["programming"] {
        didSet {
            UserDefaults.standard.set(self.tags, forKey: "selectedTags")
        }
    }

    var body: some View {
        let wrapper = TagStoryView(tags: self.tags)
        
        wrapper//.id(self.tags)
            .navigationBarItems(
                leading: NavigationLink(
                    destination: SelectTagsView(tags: $tags)
                        .navigationBarTitle("Selected Tags", displayMode: .inline),
                    label: {
                        Text("Edit").bold()
                    }
                )
            )
    }
}

let alphabet = ["A","B","C","D","E","F","G","H","I","J","K","L","M","N","O","P","Q","R","S","T","U","V","W","X","Y","Z"]

struct SelectTagsView: View {
    @Binding var tags: [String]
    
    @ObservedObject var fetcher = TagFetcher.shared
    
    @ObservedObject var searchBar = SearchBar()
    
    @EnvironmentObject var settings: Settings
    
    var body: some View {
        List {
            ForEach(alphabet, id: \.self) { letter in
                let filtered = fetcher.tags.filter({$0.tag.prefix(1).uppercased() == letter && (self.searchBar.text.isEmpty ||  $0.tag.lowercased().contains(self.searchBar.text.lowercased())) })
                listSection(letter: letter, items: filtered)
            }
            bottom_list_item
        }
        .listStyle(PlainListStyle())
        .listSectionIndexVisibility(.visible)
        .add(self.searchBar)
        .task {
            do {
                try await self.fetcher.loadIfEmpty()
            } catch {
                // todo: set and use error
            }
        }
    }
    
    @ViewBuilder
    var bottom_list_item: some View {
        Text("\(fetcher.tags.count) Tags").font(Font(.footnote, sizeModifier: CGFloat(settings.textSizeModifier))).foregroundColor(.gray)
            .frame(maxWidth: .infinity, alignment: .center)
            .listSectionSeparator(.hidden)

    }
    
    @ViewBuilder
    func listSection(letter: String, items filtered: [Tag]) -> some View {
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
                                if let description = tag.description, !description.isEmpty {
                                    Text(description).foregroundColor(.gray)
                                }
                            }
                            Spacer()
                            if tags.contains(where: {$0 == tag.tag}) {
                                Text("\(Image(systemName: "checkmark"))").bold().foregroundColor(.accentColor)
                            }
                        }
                    })
                }
            }
            .sectionIndexLabel(letter)
        }
    }
}
