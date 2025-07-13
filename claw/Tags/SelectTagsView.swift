//
//  SelectTagsView.swift
//  claw
//
//  Created by Zachary Gorak on 7/12/25.
//

import SwiftUI

struct SelectTagsView: View {
    @Binding var tags: [String]
    
    @ObservedObject var fetcher = TagFetcher.shared
    
    @State private var searchText = ""
    
    @Environment(Settings.self) var settings

    @State var error: Error?

    private var missingTags: [String] {
        let fetcherTagNames = Set(fetcher.tags.map { $0.tag })
        return tags.filter { tag in
            !fetcherTagNames.contains(tag) && (searchText.isEmpty || tag.lowercased().contains(searchText.lowercased()))
        }
    }

    private var groupedTags: [(String, [Tag])] {
        let filteredTags = fetcher.tags.filter { tag in
            if searchText.isEmpty {
                return true
            }
            
            let searchLower = searchText.lowercased()
            let tagMatches = tag.tag.lowercased().contains(searchLower)
            let descriptionMatches = tag.description?.lowercased().contains(searchLower) ?? false
            
            return tagMatches || descriptionMatches
        }
        
        let grouped = Dictionary(grouping: filteredTags) { tag in
            String(tag.tag.prefix(1).uppercased())
        }
        return grouped.sorted { $0.key < $1.key }.compactMap { ($0.key, $0.value) }
    }

    var body: some View {
        List {
            // Show missing tags at the top if any exist
            if !missingTags.isEmpty {
                missingTagsSection
            }
            
            ForEach(groupedTags, id: \.0) { letter, tagList in
                listSection(letter: letter, items: tagList)
            }
            tagCount
        }
        .listStyle(PlainListStyle())
        .listSectionIndexVisibility(.automatic)
        .searchable(text: $searchText, prompt: "Search tags...")
        .task {
            do {
                try await self.fetcher.loadIfEmpty()
            } catch {
                self.error = error
            }
        }
        .refreshable {
            do {
                try await fetcher.load()
            } catch {
                self.error = error
            }
        }
        .errorAlert(error: $error)
    }
    
    @ViewBuilder
    var missingTagsSection: some View {
        Section(header: Text("Selected")) {
            ForEach(missingTags, id: \.self) { tag in
                Button(action: {
                    if tags.count > 1 {
                        tags.removeAll(where: {$0 == tag})
                        UserDefaults.standard.set(self.tags, forKey: "selectedTags")
                    }
                }, label: {
                    HStack {
                        VStack(alignment: .leading) {
                            Text(tag).bold()
                        }
                        Spacer()
                        Text("\(Image(systemName: "checkmark"))").bold().foregroundColor(.accentColor)
                    }
                })
            }
        }
    }
    
    @ViewBuilder
    var tagCount: some View {
        Text("\(fetcher.tags.count) Tags")
            .font(style: .footnote)
            .foregroundColor(.gray)
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
