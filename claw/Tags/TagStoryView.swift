import Foundation
import SwiftUI

struct TagStoryViewWrapper: View {
    @Binding var tags: [String]
    
    var body: some View {
        let story = TagStoryView(tags: self.tags)
        story.onChange(of: tags, perform: { value in
            DispatchQueue.main.async {
                story.stories.tags = tags
                story.stories.load()
            }
        })
    }
}

struct TagStoryView: View {
    @ObservedObject var stories: TagStoryFetcher
    @ObservedObject var tags = TagFetcher.shared
    @EnvironmentObject var settings: Settings
    @Environment(\.didReselect) var didReselect
    @State var isVisible = false
    
    init(tags: [String]) {
        self.stories = TagStoryFetcher(tags: tags)
    }
    @State private var scrollViewContentOffset = CGFloat(0)
    @Environment(\.presentationMode) var presentationMode: Binding<PresentationMode>
    
    var body: some View {
        ScrollViewReader { scrollProxy in
            TrackableScrollView(contentOffset: $scrollViewContentOffset) {
                LazyVStack(alignment: .leading, spacing: 0) {
                    if self.stories.tags.count == 1, let tag = tags.tags.first(where: {$0.tag == self.stories.tags.first }) {
                        Text("\(tag.description)").id(0).padding().foregroundColor(.gray)
                        Divider().padding(0).padding([.leading])
                    } else {
                        Divider().id(0).padding(0).padding([.leading])
                    }
                   
                    if stories.stories.count <= 0 {
                        ForEach(1..<10) { _ in
                            StoryListCellView(story: NewestStory.placeholder).environmentObject(settings).redacted(reason: .placeholder).allowsTightening(false)
                            Divider().padding(0).padding([.leading])
                        }
                    }
                    ForEach(stories.stories) { story in
                        StoryListCellView(story: story).id(story).environmentObject(settings).onAppear(perform: {
                            self.stories.more(story)
                        })
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
                }).onAppear(perform: {
                    self.stories.load()
                    self.tags.loadIfEmpty()
                    self.isVisible = true
                }).navigationBarTitle(self.stories.tags.joined(separator: ", ")).onReceive(didReselect) { _ in
                    DispatchQueue.main.async {
                        if self.isVisible && scrollViewContentOffset > 0.1 {
                            withAnimation {
                                scrollProxy.scrollTo(0)
                            }
                        } else {
                            presentationMode.wrappedValue.dismiss()
                        }
                    }
                }
            }
        }
    }
}
