import SwiftUI


struct NewestView: View {
    @ObservedObject var newest = NewestFetcher.shared
    @EnvironmentObject var settings: Settings
    @Environment(\.didReselect) var didReselect
    @State var isVisible = false
    
    var body: some View {
        ScrollViewReader { scrollProxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    Divider().padding(0).padding([.leading])
                    if newest.stories.count <= 0 {
                        ForEach(1..<10) { _ in
                            StoryListCellView(story: NewestStory.placeholder).environmentObject(settings).redacted(reason: .placeholder).allowsTightening(false).disabled(true)
                            Divider().padding(0).padding([.leading])
                        }
                    }
                    ForEach(newest.stories) { story in
                        StoryListCellView(story: story).id(story).environmentObject(settings).task {
                            withAnimation(.easeIn, {
                                newest.more(story)
                            })
                        }
                        Divider().padding(0).padding([.leading])
                    }
                    if newest.isLoadingMore {
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
                .navigationBarTitle("Newest").onReceive(didReselect) { _ in
                    DispatchQueue.main.async {
                        if self.isVisible {
                            withAnimation {
                                scrollProxy.scrollTo(newest.stories.first)
                            }
                        }
                       
                    }
                }
            }
            .refreshable {
                await Task {
                    do {
                        try await self.newest.refresh()
                    } catch {
                        // no-op
                    }
                }.value
            }
        }
    }
}

