import SwiftUI
import BetterSafariView

struct StoryView: View {
    var short_id: String
    var from_newest: NewestStory?
    @Environment(\.didReselect) var didReselect
    @Environment(\.presentationMode) var presentationMode: Binding<PresentationMode>
    @ObservedObject var story: StoryFetcher
    
    init(_ short_id: String) {
        self.short_id = short_id
        self.story = StoryFetcher(short_id)
    }
    
    init(_ story: NewestStory) {
        self.from_newest = story
        self.short_id = story.short_id
        self.story = StoryFetcher(short_id)
    }
    
    var title: String {
        if let story = story.story{
            if story.comment_count == 1 {
                return "1 comment"
            }
            return "\(story.comment_count) comments"
        }
        if let story = from_newest {
            if story.comment_count == 1 {
                return "1 comment"
            }
            return "\(story.comment_count) comments"
        }
        return short_id
    }
    
    // https://stackoverflow.com/questions/58093295/swiftui-avoid-recreating-rerendering-view-in-tabview-with-mkmapviewuiviewrepre
    // this webview is recreated everytime a settings changes and is slow af
        
    @State var activeSheet: ActiveSheet?
    
    @EnvironmentObject var settings: Settings
    
    @FetchRequest(fetchRequest: ViewedItem.fetchAllRequest()) var viewedItems: FetchedResults<ViewedItem>
    
    @Environment(\.managedObjectContext) private var viewContext
    
    @State private var scrollViewContentOffset = CGFloat(0)
    
    @EnvironmentObject var urlToOpen: ObservableURL
    @EnvironmentObject var observableSheet: ObservableActiveSheet
    
    var body: some View {
        ScrollViewReader { scrollReader in
            
            TrackableScrollView(contentOffset: $scrollViewContentOffset) {
                VStack(alignment: .leading, spacing: 0) {
                    if let story = story.story {
                        StoryHeaderView<Story>(story: story).id(0).environmentObject(settings).environmentObject(urlToOpen).environmentObject(observableSheet)
                    }
                    else if let story = from_newest  {
                        StoryHeaderView<NewestStory>(story: story).id(0).environmentObject(settings).environmentObject(urlToOpen)
                            .environmentObject(observableSheet)
                    } else {
                        StoryHeaderView<NewestStory>(story: NewestStory.placeholder).id(0).environmentObject(settings).redacted(reason: .placeholder).allowsHitTesting(false)
                    }
                    Divider()
                    if let my_story = story.story {
                        if  my_story.comments.count > 0 {
                            HierarchyList(data: my_story.sorted_comments, header: { comment in
                                HStack(alignment: .center) {
                                    SGNavigationLink(destination: UserView(comment.comment.commenting_user), withChevron: false) {
                                        Text(comment.comment.commenting_user.username).foregroundColor(.gray)
                                    }
                                    Spacer()
                                    Text("\(Image(systemName: "arrow.up")) \(comment.comment.score)").foregroundColor(.gray)
                                }
                            }, rowContent: { comment in
                                VStack(alignment: .leading, spacing: 8.0) {
                                    let html = HTMLView(html: comment.comment.comment)
                                    HStack {
                                        html
                                        Spacer(minLength: 0) // need this cause there is a Vstack with center alignment somewhere
                                    }
                                    ForEach(html.links, id: \.self) { link in
                                            URLView(link: link).environmentObject(urlToOpen)
                                    }
                                }
                            }).padding([.bottom])
                        } else {
                            HStack {
                                Spacer()
                                Text("No comments").foregroundColor(.gray)
                                Spacer()
                            }.padding()
                        }
                    }
                }
            }.navigationBarTitle(self.title, displayMode: .inline).onReceive(didReselect) { _ in
                DispatchQueue.main.async {
                    if scrollViewContentOffset > 0 {
                        withAnimation {
                            scrollReader.scrollTo(0)
                        }
                    } else {
                        self.presentationMode.wrappedValue.dismiss()
                    }
                }
            }.onAppear(perform: {
                let contains = viewedItems.contains { element in
                    element.short_id == story.short_id && element.isStory
                }
                if !contains {
                    viewContext.insert(ViewedItem(context: viewContext, short_id: story.short_id, isStory: true, isComment: false))
                    try? viewContext.save()
                }
            })
        }
        // this is necessary until multiple sheets can be displayed at one time. See #22
        EmptyView().fullScreenCover(item: urlToOpen.bindingUrl, content: { url in
            SafariView(
                url: url,
                configuration: SafariView.Configuration(
                    entersReaderIfAvailable: settings.readerModeEnabled,
                    barCollapsingEnabled: true
                )
            ).preferredControlAccentColor(settings.accentColor).dismissButtonStyle(.close)
        })
    }
}
