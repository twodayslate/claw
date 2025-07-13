import Foundation
import SwiftUI

import SimpleCommon

struct TagStoryView: View {
    @StateObject var stories: TagStoryFetcher
    @ObservedObject var tags = TagFetcher.shared
    @Environment(Settings.self) var settings
    @Environment(\.didReselect) var didReselect
    @State var isVisible = false

    @State var error: Error?

    init(tags: [String]) {
        self._stories = StateObject(wrappedValue: TagStoryFetcher(tags: tags))
    }
    
    @State private var scrollViewContentOffset = CGFloat(0)
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ScrollViewReader { scrollProxy in
            SimpleScrollView(contentOffset: $scrollViewContentOffset) {
                LazyVStack(alignment: .leading, spacing: 0) {
                    if self.stories.tags.count == 1, let tag = tags.tags.first(where: {$0.tag == self.stories.tags.first }), let description = tag.description {
                        Text("\(description)").id(0).padding().foregroundColor(.gray)
                        Divider().padding(0).padding([.leading])
                    } else {
                        Divider().id(0).padding(0).padding([.leading])
                    }
                   
                    if stories.items.isEmpty {
                        ForEach(1..<10) { _ in
                            StoryListCellView(story: NewestStory.placeholder).redacted(reason: .placeholder).allowsTightening(false).disabled(true)
                            Divider().padding(0).padding([.leading])
                        }
                    } else {
                        ForEach(stories.items) { story in
                            StoryListCellView(story: story).id(story).task {
                                do {
                                    try await self.stories.more(story)
                                } catch {
                                    print("error", error)
                                }
                            }
                            Divider().padding(0).padding([.leading])
                        }
                    }
                    if stories.isLoadingMore {
                        HStack {
                            Spacer()
                            ProgressView()
                            Spacer()
                        }
                    }
                }.onDisappear(perform: {
                    self.isVisible = false
                })
                .animation(.default, value: stories.items)
                .task {
                    do {
                        try await self.stories.loadIfEmpty()
                    } catch {
                        self.error = error
                    }
                }
                .task {
                    do {
                        try await self.tags.loadIfEmpty()
                    } catch {
                        self.error = error
                    }
                }
                .onAppear {
                    self.isVisible = true
                }
                .navigationBarTitle(self.stories.tags.joined(separator: ", "))
                .onReceive(didReselect) { _ in
                    DispatchQueue.main.async {
                        if self.isVisible && scrollViewContentOffset > 0.1 {
                            withAnimation {
                                scrollProxy.scrollTo(0)
                            }
                        } else {
                            dismiss()
                        }
                    }
                }
            }
            .refreshable {
                await Task {
                    do {
                        try await stories.reload()
                    } catch {
                        self.error = error
                    }
                }.value
            }
            .errorAlert(error: $error)
        }
    }
}
