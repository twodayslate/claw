import Foundation
import SwiftUI

@MainActor
public class ObservableActiveSheet: ObservableObject {
    @Published var sheet: ActiveSheet? = nil
}

struct StoryListCellView: View {
    var story: NewestStory
    @Environment(Settings.self) var settings
    
    @State var activeSheet: ActiveSheet?
    @State var backgroundColorState = Color(UIColor.systemBackground)
    
    @State var navigationLinkActive = false
    
    var body: some View {
        ZStack {
           NavigationLink(
            destination: StoryView(story),
            isActive: $navigationLinkActive,
            label: { EmptyView() })
            StoryCell(story: story)
                .padding([.horizontal]).padding([.vertical], settings.layout > .compact ? 8.0 : 4.0).background(backgroundColorState.ignoresSafeArea()).contextMenu(menuItems:{
            if story.url.isEmpty {
                Button(action: {
                    activeSheet = .share(URL(string: story.short_id_url)!)
                }, label: {
                    Label("Share", systemImage: "square.and.arrow.up")
                })
            } else {
                Menu(content: {
                    Button(action: {
                        activeSheet = .share(URL(string: story.short_id_url)!)
                    }, label: {
                        Label("Lobsters URL", systemImage: "book")
                    })
                    if !story.url.isEmpty {
                        Button(action: {
                            activeSheet = .share(URL(string: story.url)!)
                        }, label: {
                            Label("Story URL", systemImage: "link")
                        })
                        Button(action: {
                            activeSheet = .share(URL(string: "https://archive.md/\(story.url)")!)
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
            switch item {
            case .share(let url):
                ShareSheet(activityItems: [url])
            default:
                Text("\(activeSheet.debugDescription)")
            }
        }
        }.onTapGesture(count: 1, perform: {
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
