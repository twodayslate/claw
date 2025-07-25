import SwiftUI


struct NewestView: View {
    @ObservedObject var newest = NewestFetcher.shared
    @Environment(Settings.self) var settings
    @Environment(\.didReselect) var didReselect
    @State var isVisible = false
    @State var error: Error?

    var body: some View {
        ScrollViewReader { scrollProxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    Divider().padding(0).padding([.leading])
                    if newest.items.isEmpty {
                        ForEach(1..<10) { _ in
                            StoryListCellView(story: NewestStory.placeholder).redacted(reason: .placeholder).allowsTightening(false).disabled(true)
                            Divider().padding(0).padding([.leading])
                        }
                    } else {
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
                    }

                    if newest.isLoadingMore {
                        HStack {
                            Spacer()
                            ProgressView()
                            Spacer()
                        }
                    }
                }
                .animation(.default, value: newest.items)
                .onDisappear {
                    self.isVisible = false
                }
                .onAppear {
                    self.isVisible = true
                }
                .navigationBarTitle("Newest")
                .onReceive(didReselect) { _ in
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
                    self.error = error
                }
            }
            .refreshable {
                await Task {
                    do {
                        try await self.newest.reload()
                    } catch {
                        self.error = error
                    }
                }.value
            }
            .errorAlert(error: $error)
        }
    }
}

