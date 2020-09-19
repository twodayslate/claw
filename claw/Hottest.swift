import Foundation
import SwiftUI

struct HottestView: View {
    @ObservedObject var hottest = HottestFetcher()
    @EnvironmentObject var settings: Settings
    var body: some View {
        NavigationView {
            List {
                ForEach(hottest.stories) { story in
                    SGNavigationLink(destination: StoryView(story)) {
                        StoryCell(story: story).environmentObject(settings)
                    }
                }
            }.navigationBarTitle("Hottest")
        }
    }
}
