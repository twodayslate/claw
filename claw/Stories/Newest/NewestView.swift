import SwiftUI


struct NewestView: View {
    @ObservedObject var newest = NewestFetcher.shared
    @Environment(Settings.self) var settings
    @Environment(\.didReselect) var didReselect
    @State var isVisible = false
    
    var body: some View {
        ScrollViewReader { scrollProxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    Divider().padding(0).padding([.leading])
                    if newest.items.count <= 0 {
                        ForEach(1..<10) { _ in
                            StoryListCellView(story: NewestStory.placeholder).redacted(reason: .placeholder).allowsTightening(false).disabled(true)
                            Divider().padding(0).padding([.leading])
                        }
                    }
                    ForEach(newest.items) { story in
                        StoryListCellView(story: story).id(story).task {
                            do {
                                try await newest.more(story)
                            } catch {
                                print("error", error)
                            }
                        }
                        Divider().padding(0).padding([.leading])
                    }
                    .animation(.default, value: newest.items)
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
                                scrollProxy.scrollTo(newest.items.first)
                            }
                        }
                       
                    }
                }
            }
            .task {
                do {
                    try await newest.loadIfEmpty()
                } catch {
                    print("error", error)
                }
            }
            .refreshable {
                await Task {
                    do {
                        try await self.newest.reload()
                    } catch {
                        // no-op
                    }
                }.value
            }
        }
    }
}

