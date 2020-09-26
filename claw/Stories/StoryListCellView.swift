import Foundation
import SwiftUI

enum ActiveSheet: Identifiable {
    case first, second
    
    var id: Int {
        hashValue
    }
}

struct StoryListCellView: View {
    var story: NewestStory
    @EnvironmentObject var settings: Settings
    
    @State var activeSheet: ActiveSheet?
    
    var body: some View {
        SGNavigationLink(destination: StoryView(story).environmentObject(settings)) {
            StoryCell(story: story).environmentObject(settings)
        }.contextMenu(menuItems:{
            if story.url.isEmpty {
                Button(action: {
                    activeSheet = .second
                }, label: {
                    Label("Share", systemImage: "square.and.arrow.up")
                })
            } else {
                Menu(content: {
                    Button(action: {
                        activeSheet = .second
                    }, label: {
                        Label("Lobsters URL", systemImage: "book")
                    })
                    if !story.url.isEmpty {
                        Button(action: {
                            activeSheet = .first
                        }, label: {
                            Label("Story URL", systemImage: "link")
                        })
                    }
                }, label: {
                    Label("Share", systemImage: "square.and.arrow.up.on.square")
                })
            }
        }).sheet(item: self.$activeSheet) {
            item in
            if item == .first {
                ShareSheet(activityItems: [URL(string: story.url)!])
            } else if item == .second {
                ShareSheet(activityItems: [URL(string: story.short_id_url)!])
            } else {
                Text("\(activeSheet.debugDescription)")
            }
        }
    }
}
