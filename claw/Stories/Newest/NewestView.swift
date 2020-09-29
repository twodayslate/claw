import SwiftUI


struct NewestView: View {
    @ObservedObject var newest = NewestFetcher()
    @EnvironmentObject var settings: Settings
    @Environment(\.didReselect) var didReselect
    @State var isVisible = false
    var body: some View {
        ScrollViewReader { scrollProxy in
            List {
                if newest.stories.count <= 0 {
                    ForEach(1..<10) { _ in
                        StoryListCellView(story: NewestStory.placeholder).environmentObject(settings).redacted(reason: .placeholder).allowsTightening(false)
                    }
                }
                ForEach(newest.stories) { story in
                    StoryListCellView(story: story).id(story).environmentObject(settings).onAppear(perform: {
                        withAnimation(.easeIn, {
                            newest.more(story)
                        })
                    })
                }
                if newest.isLoadingMore {
                    HStack {
                        Spacer()
                        ProgressView()
                        Spacer()
                    }
                }
            }.onDisappear(perform: {
                self.isVisible = false
            }).onAppear(perform: {
                self.isVisible = true
            }).navigationBarTitle("Newest").onReceive(didReselect) { _ in
                
                DispatchQueue.main.async {
                    if self.isVisible {
                        withAnimation {
                            scrollProxy.scrollTo(newest.stories.first)
                        }
                    }
                   
                }
            }
        }
    }
}

