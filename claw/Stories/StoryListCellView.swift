import Foundation
import SwiftUI

enum ActiveSheet: Identifiable {
    case first, second, third
    
    var id: Int {
        hashValue
    }
}

struct StoryListCellView: View {
    var story: NewestStory
    @EnvironmentObject var settings: Settings
    
    @State var activeSheet: ActiveSheet?
    @State var backgroundColorState = Color(UIColor.systemBackground)
    
    @State var navigationLinkActive = false
    
    var body: some View {
        ZStack {
           NavigationLink(
            destination: StoryView(story),
            isActive: $navigationLinkActive,
            label: { EmptyView() })
            StoryCell(story: story).environmentObject(settings)
                .padding([.horizontal]).padding([.vertical], settings.layout > .compact ? 8.0 : 4.0).background(backgroundColorState.ignoresSafeArea()).contextMenu(menuItems:{
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
                        Button(action: {
                            activeSheet = .third
                        }, label: {
                            Label("Story Cache URL", systemImage: "archivebox")
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
            } else if item == .third {
                ShareSheet(activityItems: [URL(string: "https://archive.md/\(story.url)")!])
            } else {
                Text("\(activeSheet.debugDescription)")
            }
        }
        }.onTapGesture(count: /*@START_MENU_TOKEN@*/1/*@END_MENU_TOKEN@*/, perform: {
            withAnimation(.easeIn) {
                backgroundColorState = Color(UIColor.systemGray4)
                withAnimation(.easeOut) {
                    backgroundColorState = Color(UIColor.systemBackground)
                    navigationLinkActive = true
                }
            }
        })
    }
}
