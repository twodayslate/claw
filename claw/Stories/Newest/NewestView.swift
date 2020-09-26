import SwiftUI


struct NewestView: View {
    @ObservedObject var newest = NewestFetcher()
    @EnvironmentObject var settings: Settings
    var body: some View {
        NavigationView {
            List {
                if newest.stories.count <= 0 {
                    ForEach(1..<10) { _ in
                        StoryListCellView(story: NewestStory.placeholder).environmentObject(settings).redacted(reason: .placeholder).allowsTightening(false)
                    }
                }
                ForEach(newest.stories) { story in
                    StoryListCellView(story: story).environmentObject(settings).onAppear(perform: {
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
            }.navigationBarTitle("Newest")
        }
    }
}

