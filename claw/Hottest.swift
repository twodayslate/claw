import Foundation
import SwiftUI

struct HottestView: View {
    @ObservedObject var hottest = HottestFetcher()
    @EnvironmentObject var settings: Settings

    var body: some View {
        NavigationView {
            List {
                ForEach(hottest.stories) { story in
                    StoryListCellView(story: story).environmentObject(settings)
                }
            }.navigationBarTitle("Hottest")
        }
    }
}
