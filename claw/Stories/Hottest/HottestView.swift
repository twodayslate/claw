import Foundation
import SwiftUI

struct HottestView: View {
    @ObservedObject var hottest = HottestFetcher()
    @EnvironmentObject var settings: Settings

    var body: some View {
        List {
            if hottest.stories.count <= 0 {
                ForEach(1..<10) { _ in
                    StoryListCellView(story: NewestStory.placeholder).environmentObject(settings).redacted(reason: .placeholder).allowsTightening(false)
                }
            }
            ForEach(hottest.stories) { story in
                StoryListCellView(story: story).environmentObject(settings).onAppear(perform: {
                    self.hottest.more(story)
                })
            }
            if hottest.isLoadingMore {
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
            }
        }.navigationBarTitle("Hottest")
    }
}
