import WidgetKit
import SwiftUI
import Intents


struct Provider: TimelineProvider {
    @ObservedObject var hottest = HottestFetcher()
    
    func getSnapshot(in context: Context, completion: @escaping (SimpleEntry) -> Void) {
        let entry = SimpleEntry(date: Date(), stories: hottest.stories)
        completion(entry)
    }
    
    func getTimeline(in context: Context, completion: @escaping (Timeline<SimpleEntry>) -> Void) {
        var entries: [SimpleEntry] = []
        
        let url = URL(string: "https://lobste.rs/hottest.json")!
    
        hottest.load()
        
        URLSession.shared.dataTask(with: url) {(data,response,error) in
            do {
                if let d = data {
                    let decodedLists = try JSONDecoder().decode([NewestStory].self, from: d)
                    DispatchQueue.main.async {
                        let entry = SimpleEntry(date: Calendar.current.date(byAdding: .hour, value: 1, to: Date())!, stories: decodedLists)
                        entries.append(entry)
                        let timeline = Timeline(entries: entries, policy: .atEnd)
                        completion(timeline)
                    }
                }else {
                    print("No Data")
                }
            } catch {
                print ("Error \(error)")
            }
        }.resume()
    }
    
    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(date: Date(), stories: hottest.stories)
    }
}

struct SimpleEntry: TimelineEntry {
    let date: Date
    let stories: [NewestStory]?
}

struct hottest_widgetEntryView : View {
    var entry: Provider.Entry
    
    @ObservedObject var hottest = HottestFetcher()
    @Environment(\.widgetFamily) var family

    var body: some View {
        VStack(alignment: .leading) {
            if family == .systemSmall {
                SmallestHottestWidgetView(entry: entry)
            } else if family == .systemMedium {
                MediumHottestWidgetView(entry: entry)
            } else if family == .systemLarge {
                LargeHottestWidgetView(entry: entry)
            } else {
                Text(entry.date, style: .time)
            }
        }.padding()
    }
}

struct SmallestHottestWidgetView: View {
    var entry: Provider.Entry
    
    var body: some View {
        ZStack(alignment: .topLeading) {
            Text("\(Image(systemName: "flame"))").font(Font.system(size: 125)).foregroundColor(.red).opacity(0.4).padding([.top, .leading], -25)
            VStack {
                Spacer(minLength: 0)
                if let stories = entry.stories, let story = stories.first {
                    Text(story.title).font(.subheadline)
                    Spacer(minLength: 0)
                    HStack(alignment: .center, spacing: 4.0) {
                        VStack(alignment: .leading) {
                            Text("\(story.submitter_user.username)").font(.caption)
                            Text("\(story.time_ago)").font(.caption2)
                        }.lineLimit(1).minimumScaleFactor(0.5)
                        Spacer(minLength: 0)
                        Text("\(Image(systemName: "arrow.up")) \(story.score)").font(.footnote)
                    }.foregroundColor(.gray)
                } else {
                    Spacer(minLength: 0)
                    Text("A redacted title goes here").font(.subheadline).redacted(reason: .placeholder)
                    Spacer(minLength: 0)
                    HStack(alignment: .center, spacing: 4.0) {
                        VStack(alignment: .leading) {
                            Text("username").font(.caption).redacted(reason: .placeholder)
                            Text("some time ago").font(.caption2).redacted(reason: .placeholder)
                        }.lineLimit(1).minimumScaleFactor(0.5)
                        Spacer(minLength: 0)
                        Text("\(Image(systemName: "arrow.up")) -").font(.footnote)
                    }.foregroundColor(.gray)
                }
            }.background(Color(UIColor.systemBackground).blur(radius: 10.0).opacity(0.5))
        }
    }
}

struct MediumHottestWidgetView: View {
    var entry: Provider.Entry
    
    var body: some View {
        Text("\(Image(systemName: "flame"))").foregroundColor(.red)
        Divider()
        Spacer()
        
        if let stories = entry.stories, let story = stories.first {
            let story2 = stories[1]
            Text(story.title).font(.subheadline)
            HStack(alignment: .center, spacing: 4.0) {
                Text("via").font(.caption)
                Text("\(story.submitter_user.username)").font(.caption)
                Text("\(story.time_ago)").font(.caption)
                Spacer(minLength: 0)
                Text("\(Image(systemName: "arrow.up")) \(story.score)").font(.footnote)
            }.foregroundColor(.gray)
            
            Spacer()
            
            Text(story2.title).font(.subheadline)
            HStack(alignment: .center, spacing: 4.0) {
                Text("via").font(.caption)
                Text("\(story2.submitter_user.username)").font(.caption)
                Text("\(story2.time_ago)").font(.caption)
                Spacer(minLength: 0)
                Text("\(Image(systemName: "arrow.up")) \(story2.score)").font(.footnote)
            }.foregroundColor(.gray)
        } else {
            Text("The first redacted title").font(.subheadline).redacted(reason: .placeholder)
            HStack(alignment: .center, spacing: 4.0) {
                Text("via").font(.caption)
                Text("username").font(.caption).redacted(reason: .placeholder)
                Text("some time ago").font(.caption).redacted(reason: .placeholder)
                Spacer(minLength: 0)
                Text("\(Image(systemName: "arrow.up")) -").font(.footnote)
            }.foregroundColor(.gray)
            
            Spacer()
            
            Text("A second redacted title goes here").font(.subheadline).redacted(reason: .placeholder)
            HStack(alignment: .center, spacing: 4.0) {
                Text("via").font(.caption)
                Text("username").font(.caption).redacted(reason: .placeholder)
                Text("some time ago").font(.caption).redacted(reason: .placeholder)
                Spacer(minLength: 0)
                Text("\(Image(systemName: "arrow.up")) -").font(.footnote)
            }.foregroundColor(.gray)
        }
    }
}

struct LargeStoryView: View {
    var story: NewestStory?
    
    var body: some View {
        if let story = story {
            Text(story.title).font(.subheadline)
            HStack(alignment: .center, spacing: 4.0) {
                Text("via").font(.caption)
                Text("\(story.submitter_user.username)").font(.caption)
                Text("\(story.time_ago)").font(.caption)
                Spacer(minLength: 0)
                Text("\(Image(systemName: "arrow.up")) \(story.score)").font(.footnote)
            }.foregroundColor(.gray)
        } else {
            Text("A title here but it is redacted...").font(.subheadline).redacted(reason: .placeholder)
            HStack(alignment: .center, spacing: 4.0) {
                Text("via").font(.caption)
                Text("username").font(.caption).redacted(reason: .placeholder)
                Text("some tiem ago").font(.caption).redacted(reason: .placeholder)
                Spacer(minLength: 0)
                Text("\(Image(systemName: "arrow.up")) -").font(.footnote)
            }.foregroundColor(.gray)
        }
    }
}

struct LargeHottestWidgetView: View {
    var entry: Provider.Entry
    
    var body: some View {
        Text("\(Image(systemName: "flame"))").foregroundColor(.red)
        Divider()
        Spacer()
        if let stories = entry.stories, stories.count > 3 {
            
            LargeStoryView(story: stories[0])
            Spacer()
            LargeStoryView(story: stories[1])
            Spacer()
            LargeStoryView(story: stories[2])
            Spacer()
            LargeStoryView(story: stories[3])
        } else {
            LargeStoryView(story: nil)
            Spacer()
            LargeStoryView(story: nil)
            Spacer()
            LargeStoryView(story: nil)
            Spacer()
            LargeStoryView(story: nil)
        }
    }
}


@main
struct hottest_widget: Widget {
    let kind: String = "hottest_widget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            hottest_widgetEntryView(entry: entry)
        }
        .configurationDisplayName("Hottest")
        .description("The hottest stories from Lobsters now in a widget")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

struct hottest_widget_Previews: PreviewProvider {
    static var previews: some View {
        let generic_stories = [NewestStory(short_id: "whatever", short_id_url: ".", created_at: ".", title: "The compositor is evil", url: ".", score: 45, flags: 0, comment_count: 4, description: "", comments_url: ".", submitter_user: NewestUser(username: "twodayslate", created_at: ".", is_admin: false, about: "about", is_moderator: false, karma: 1, avatar_url: "", invited_by_user: "wa", github_username: "", twitter_username: "", keybase_signatures: nil), tags: ["tag1", "tag2"]), NewestStory(short_id: "whatever", short_id_url: ".", created_at: ".", title: "spawnfest/bakeware - Compile Elixir applications into single, easily distributed executable binaries", url: ".", score: 45, flags: 0, comment_count: 4, description: "", comments_url: ".", submitter_user: NewestUser(username: "twodayslate", created_at: ".", is_admin: false, about: "about", is_moderator: false, karma: 1, avatar_url: "", invited_by_user: "wa", github_username: "", twitter_username: "", keybase_signatures: nil), tags: ["tag1", "tag2"]), NewestStory(short_id: "whatever", short_id_url: ".", created_at: ".", title: "Semantic Import Versioning is unsound ", url: ".", score: 45, flags: 0, comment_count: 4, description: "", comments_url: ".", submitter_user: NewestUser(username: "twodayslate", created_at: ".", is_admin: false, about: "about", is_moderator: false, karma: 1, avatar_url: "", invited_by_user: "wa", github_username: "", twitter_username: "", keybase_signatures: nil), tags: ["tag1", "tag2"]), NewestStory(short_id: "whatever", short_id_url: ".", created_at: ".", title: "Launching the 2020 State of Rust Survey ", url: ".", score: 45, flags: 0, comment_count: 4, description: "", comments_url: ".", submitter_user: NewestUser(username: "twodayslate", created_at: ".", is_admin: false, about: "about", is_moderator: false, karma: 1, avatar_url: "", invited_by_user: "wa", github_username: "", twitter_username: "", keybase_signatures: nil), tags: ["tag1", "tag2"]), NewestStory(short_id: "whatever", short_id_url: ".", created_at: ".", title: "spawnfest/bakeware - Compile Elixir applications into single, easily distributed executable binaries ", url: ".", score: 45, flags: 0, comment_count: 4, description: "", comments_url: ".", submitter_user: NewestUser(username: "twodayslate", created_at: ".", is_admin: false, about: "about", is_moderator: false, karma: 1, avatar_url: "", invited_by_user: "wa", github_username: "", twitter_username: "", keybase_signatures: nil), tags: ["tag1", "tag2"])]
        Group {
            hottest_widgetEntryView(entry: SimpleEntry(date: Date(), stories: []))
                .previewContext(WidgetPreviewContext(family: .systemSmall))
            hottest_widgetEntryView(entry: SimpleEntry(date: Date(), stories: generic_stories))
                .previewContext(WidgetPreviewContext(family: .systemSmall))
            hottest_widgetEntryView(entry: SimpleEntry(date: Date(), stories: generic_stories))
                .previewContext(WidgetPreviewContext(family: .systemSmall)).background(Color(UIColor.systemBackground)).environment(\.colorScheme, .dark)
            hottest_widgetEntryView(entry: SimpleEntry(date: Date(), stories: generic_stories))
                .previewContext(WidgetPreviewContext(family: .systemMedium))
            hottest_widgetEntryView(entry: SimpleEntry(date: Date(), stories: []))
                .previewContext(WidgetPreviewContext(family: .systemMedium))
            hottest_widgetEntryView(entry: SimpleEntry(date: Date(), stories: generic_stories))
                .previewContext(WidgetPreviewContext(family: .systemLarge))
            hottest_widgetEntryView(entry: SimpleEntry(date: Date(), stories: []))
                .previewContext(WidgetPreviewContext(family: .systemLarge))
        }.previewLayout(.sizeThatFits)
        
    }
}
