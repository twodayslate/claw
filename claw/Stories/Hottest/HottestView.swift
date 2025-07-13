import Foundation
import SwiftUI
import SwiftData

struct HottestView: View {
    @ObservedObject var hottest = HottestFetcher.shared
    @Environment(Settings.self) var settings
    @Environment(\.didReselect) var didReselect
    @State var isVisible = false
    
    var body: some View {
        ScrollViewReader { scrollProxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    Divider().padding(0).padding([.leading])
                    if hottest.stories.count <= 0 {
                        ForEach(1..<10) { _ in
                            StoryListCellView(story: NewestStory.placeholder).redacted(reason: .placeholder).allowsTightening(false).disabled(true)
                        }
                        Divider().padding(0).padding([.leading])
                    }
                    ForEach(hottest.stories) { story in
                        StoryListCellView(story: story).id(story).task {
                            self.hottest.more(story)
                        }
                        Divider().padding(0).padding([.leading])
                    }
                    if hottest.isLoadingMore {
                        HStack {
                            Spacer()
                            ProgressView()
                            Spacer()
                        }
                    }
                }
                .onDisappear {
                    self.isVisible = false
                }
                .onAppear {
                    self.isVisible = true
                }
                .navigationBarTitle("Hottest")
                .onReceive(didReselect) { _ in
                    DispatchQueue.main.async {
                        if self.isVisible {
                            withAnimation {
                                scrollProxy.scrollTo(hottest.stories.first)
                            }
                        }
                    }
                }
            }
            .refreshable {
                await Task {
                    do {
                        try await self.hottest.refresh()
                    } catch {
                        // no-op
                    }
                }.value
            }
        }
    }
}
