import Foundation
import SwiftUI
import SwiftData

struct HottestView: View {
    @ObservedObject var hottest = HottestFetcher.shared
    @EnvironmentObject private var observableSheet: ObservableActiveSheet
    @Environment(Settings.self) var settings
    @Environment(\.didReselect) var didReselect
    @State var isVisible = false
    @State var error: Error?

    var body: some View {
        ScrollViewReader { scrollProxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    Divider().padding(0).padding([.leading])
                    if hottest.items.isEmpty && (!hottest.hasAttemptedLoad || hottest.isLoading) {
                        ForEach(1..<10) { _ in
                            StoryListCellView(story: NewestStory.placeholder).redacted(reason: .placeholder).allowsTightening(false).disabled(true)
                        }
                        Divider().padding(0).padding([.leading])
                    } else if hottest.items.isEmpty {
                        StoryFeedEmptyView()
                    } else {
                        ForEach(hottest.items) { story in
                            StoryListCellView(story: story).id(story).task {
                                do {
                                    try await self.hottest.more(story)
                                } catch {
                                    print("error", error)
                                }
                            }
                            Divider().padding(0).padding([.leading])
                        }
                    }
                    if hottest.isLoadingMore {
                        HStack {
                            Spacer()
                            ProgressView()
                            Spacer()
                        }
                    }
                }
                .animation(.default, value: hottest.items)
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
                                scrollProxy.scrollTo(hottest.items.first)
                            }
                        }
                    }
                }
            }
            .task {
                guard observableSheet.sheet == nil else {
                    return
                }
                do {
                    try await hottest.loadIfEmpty()
                } catch {
                    if observableSheet.sheet == nil {
                        self.error = error
                    }
                }
            }
            .refreshable {
                await Task {
                    do {
                        try await self.hottest.reload()
                    } catch {
                        self.error = error
                    }
                }.value
            }
            .errorAlert(error: $error)
        }
    }
}
