import Foundation
import SwiftUI

struct HottestView: View {
    @ObservedObject var hottest = HottestFetcher()
    @EnvironmentObject var settings: Settings
    @Environment(\.didReselect) var didReselect
    @State var isVisible = false
    
    var body: some View {
        ScrollViewReader { scrollProxy in
            List {
                if hottest.stories.count <= 0 {
                    ForEach(1..<10) { _ in
                        StoryListCellView(story: NewestStory.placeholder).environmentObject(settings).redacted(reason: .placeholder).allowsTightening(false)
                    }
                }
                ForEach(hottest.stories) { story in
                    StoryListCellView(story: story).id(story).environmentObject(settings).onAppear(perform: {
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
            }.onDisappear(perform: {
                self.isVisible = false
            }).onAppear(perform: {
                self.isVisible = true
            }).navigationBarTitle("Hottest").onReceive(didReselect) { _ in
                DispatchQueue.main.async {
                    if self.isVisible {
                        withAnimation {
                            scrollProxy.scrollTo(hottest.stories.first)
                        }
                    }
                }
            }
        }
    }
}
