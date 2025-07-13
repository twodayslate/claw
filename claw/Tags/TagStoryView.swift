import Foundation
import SwiftUI

import SimpleCommon

struct TagStoryView: View {
    @ObservedObject var stories: TagStoryFetcher
    @ObservedObject var tags = TagFetcher.shared
    @Environment(Settings.self) var settings
    @Environment(\.didReselect) var didReselect
    @State var isVisible = false
    
    init(tags: [String]) {
        self.stories = TagStoryFetcher(tags: tags)
    }
    
    @State private var scrollViewContentOffset = CGFloat(0)
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ScrollViewReader { scrollProxy in
            SimpleScrollView(contentOffset: $scrollViewContentOffset) {
                LazyVStack(alignment: .leading, spacing: 0) {
                    if self.stories.tags.count == 1, let tag = tags.tags.first(where: {$0.tag == self.stories.tags.first }) {
                        Text("\(tag.description)").id(0).padding().foregroundColor(.gray)
                        Divider().padding(0).padding([.leading])
                    } else {
                        Divider().id(0).padding(0).padding([.leading])
                    }
                   
                    if stories.items.count <= 0 {
                        ForEach(1..<10) { _ in
                            StoryListCellView(story: NewestStory.placeholder).redacted(reason: .placeholder).allowsTightening(false).disabled(true)
                            Divider().padding(0).padding([.leading])
                        }
                    }
                    ForEach(stories.items) { story in
                        StoryListCellView(story: story).id(story).task {
                            self.stories.more(story)
                        }
                        Divider().padding(0).padding([.leading])
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
                .task {
                    self.stories.loadIfEmpty()
                }
                .task {
                    do {
                        try await self.tags.loadIfEmpty()
                    } catch {
                        // todo: set and use error
                    }
                }
                .onAppear {
                    self.isVisible = true
                }
                .navigationBarTitle(self.stories.tags.joined(separator: ", ")).onReceive(didReselect) { _ in
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
                        try await stories.refresh()
                    } catch {
                        // no-op
                    }
                }.value
            }
        }
    }
}
