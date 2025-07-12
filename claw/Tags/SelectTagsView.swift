//
//  SelectTagsView.swift
//  claw
//
//  Created by Zachary Gorak on 7/12/25.
//

import SwiftUI


let alphabet = ["A","B","C","D","E","F","G","H","I","J","K","L","M","N","O","P","Q","R","S","T","U","V","W","X","Y","Z"]


struct SelectTagsView: View {
    @Binding var tags: [String]
    
    @ObservedObject var fetcher = TagFetcher.shared
    
    @State private var searchText = ""
    
    @EnvironmentObject var settings: Settings

    @State var error: Error?

    var body: some View {
        List {
            ForEach(alphabet, id: \.self) { letter in
                let filtered = fetcher.tags.filter({$0.tag.prefix(1).uppercased() == letter && (searchText.isEmpty ||  $0.tag.lowercased().contains(searchText.lowercased())) })
                listSection(letter: letter, items: filtered)
            }
            bottom_list_item
        }
        .listStyle(PlainListStyle())
        .listSectionIndexVisibility(.visible)
        .searchable(text: $searchText, prompt: "Search tags...")
        .task {
            do {
                try await self.fetcher.loadIfEmpty()
            } catch {
                // todo: set and use error
            }
        }
        .refreshable {
            do {
                try await fetcher.load()
            } catch {
                self.error = error
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