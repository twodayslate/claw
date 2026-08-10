import WidgetKit
import SwiftUI
import Intents


struct Provider: TimelineProvider {
    @ObservedObject var hottest = HottestFetcher()
    
    func getSnapshot(in context: Context, completion: @escaping (SimpleEntry) -> Void) {
        let stories = HottestWidgetCache.load() ?? hottest.items
        let entry = SimpleEntry(date: Date(), stories: stories)
        completion(entry)
    }
    
    func getTimeline(in context: Context, completion: @escaping (Timeline<SimpleEntry>) -> Void) {
        var entries: [SimpleEntry] = []

        Task {
            do {
                try await hottest.load()
                HottestWidgetCache.save(hottest.items)
            } catch {
                hottest.items = HottestWidgetCache.load() ?? []
            }

            let now = Date()
            let entry = SimpleEntry(date: now, stories: hottest.items)
            entries.append(entry)
            let refreshDate = Calendar.current.date(
                byAdding: .hour,
                value: 1,
                to: now
            ) ?? now.addingTimeInterval(3600)
            let timeline = Timeline(entries: entries, policy: .after(refreshDate))
            completion(timeline)
        }
    }
    
    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(date: Date(), stories: nil)
    }
}

private enum HottestWidgetCache {
    private static let suiteName = "group.com.twodayslate.claw"
    private static var key: String {
        let baseURL = APIConfiguration.shared.baseURL
        var origin = URLComponents()
        origin.scheme = baseURL.scheme
        origin.host = baseURL.host
        origin.port = baseURL.port
        return "hottest-widget-stories-v3-\(origin.string ?? baseURL.absoluteString)"
    }

    static func load() -> [NewestStory]? {
        guard let defaults = UserDefaults(suiteName: suiteName),
              let data = defaults.data(forKey: key) else {
            return nil
        }
        return try? JSONDecoder().decode([NewestStory].self, from: data)
    }

    static func save(_ stories: [NewestStory]) {
        guard let data = try? JSONEncoder().encode(stories) else {
            return
        }
        UserDefaults(suiteName: suiteName)?.set(data, forKey: key)
    }
}

struct SimpleEntry: TimelineEntry {
    let date: Date
    let stories: [NewestStory]?
}

extension View {
    func fixupContainerBackgroundWidget<V>(@ViewBuilder content: () -> V) -> some View where V: View {
        if #available(iOS 17, *) {
            return self.containerBackground(for: .widget, alignment: .center, content: {
                content()
            })
        } else {
            return self.background {
                content()
            }
        }
    }
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
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding()
        .fixupContainerBackgroundWidget {
            Color(UIColor.systemBackground)
                .opacity(0.5)
                .ignoresSafeArea()
        }

    }
}

struct SmallestHottestWidgetView: View {
    var entry: Provider.Entry
    
    var body: some View {
        ZStack(alignment: .topLeading) {
            Image(systemName: "flame")
                .ignoresSafeArea()
                .font(Font.system(size: 125))
                .foregroundColor(.red)
                .opacity(0.4)
                .padding([.top, .leading], -25)
            VStack(alignment: .leading) {
                Spacer(minLength: 0)
                if let stories = entry.stories, let story = stories.first {
                    Text(story.title)
                        .font(.subheadline)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Spacer(minLength: 0)
                    HStack(alignment: .center, spacing: 4.0) {
                        VStack(alignment: .leading) {
                            Text("\(story.submitter_user)").font(.caption)
                            Text("\(story.time_ago)").font(.caption2)
                        }
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                        Spacer(minLength: 0)
                        Text("\(Image(systemName: "arrow.up")) \(story.displayedScore)").font(.footnote)
                    }
                    .foregroundColor(.gray)
                    .widgetURL(URL(string: "claw://open?url=\(story.short_id_url)"))
                } else if entry.stories != nil {
                    WidgetEmptyStateView()
                } else {
                    Spacer(minLength: 0)
                    Text("A redacted title goes here")
                        .font(.subheadline)
                        .redacted(reason: .placeholder)
                        .frame(maxWidth: .infinity, alignment: .leading)
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
            }
        }
    }
}

struct MediumHottestWidgetView: View {
    var entry: Provider.Entry
    
    var body: some View {
        Text("\(Image(systemName: "flame"))").foregroundColor(.red)
        Divider()
        
        if let stories = entry.stories {
            if stories.isEmpty {
                WidgetEmptyStateView()
            } else {
                let visibleStories = Array(stories.prefix(2))
                ForEach(visibleStories) { story in
                    LargeStoryView(story: story)
                    if story != visibleStories.last {
                        Spacer()
                    }
                }
            }
        } else {
            Spacer()
            LargeStoryView(story: nil)
            Spacer()
            LargeStoryView(story: nil)
        }
    }
}

struct WidgetEmptyStateView: View {
    var body: some View {
        VStack {
            Spacer(minLength: 0)
            Text("No stories available")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
            Spacer(minLength: 0)
        }
    }
}

struct LargeStoryView: View {
    var story: NewestStory?
    
    var body: some View {
        if let story = story {
            Link(destination: URL(string: "claw://open?url=\(story.short_id_url)") ?? URL(string: "claw://")!) {
                Text(story.title)
                    .font(.subheadline)
                    .frame(maxWidth: .infinity, alignment: .leading)
                HStack(alignment: .center, spacing: 4.0) {
                    Text("via").font(.caption)
                    Text("\(story.submitter_user)").font(.caption)
                    Text("\(story.time_ago)").font(.caption)
                    Spacer(minLength: 0)
                    Text("\(Image(systemName: "arrow.up")) \(story.displayedScore)").font(.footnote)
                }.foregroundColor(.gray)
            }
        } else {
            Text("A title here but it is redacted...")
                .font(.subheadline)
                .frame(maxWidth: .infinity, alignment: .leading)
                .redacted(reason: .placeholder)
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
        if let stories = entry.stories {
            if stories.isEmpty {
                WidgetEmptyStateView()
            } else {
                let visibleStories = Array(stories.prefix(4))
                ForEach(visibleStories) { story in
                    LargeStoryView(story: story)
                    if story != visibleStories.last {
                        Spacer()
                    }
                }
            }
        } else {
            Spacer()
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
        let generic_stories = [NewestStory(short_id: "whatever", short_id_url: ".", created_at: ".", title: "The compositor is evil", url: ".", score: 45, flags: 0, comment_count: 4, description: "", comments_url: ".", submitter_user: "placeholder", user_is_author: false, tags: ["tag1", "tag2"]), NewestStory(short_id: "whatever", short_id_url: ".", created_at: ".", title: "spawnfest/bakeware - Compile Elixir applications into single, easily distributed executable binaries", url: ".", score: 45, flags: 0, comment_count: 4, description: "", comments_url: ".", submitter_user: "placeholder", user_is_author: false, tags: ["tag1", "tag2"]), NewestStory(short_id: "whatever", short_id_url: ".", created_at: ".", title: "Semantic Import Versioning is unsound ", url: ".", score: 45, flags: 0, comment_count: 4, description: "", comments_url: ".", submitter_user: "placeholder", user_is_author: false, tags: ["tag1", "tag2"]), NewestStory(short_id: "whatever", short_id_url: ".", created_at: ".", title: "Launching the 2020 State of Rust Survey ", url: ".", score: 45, flags: 0, comment_count: 4, description: "", comments_url: ".", submitter_user: "placeholder", user_is_author: false, tags: ["tag1", "tag2"]), NewestStory(short_id: "whatever", short_id_url: ".", created_at: ".", title: "spawnfest/bakeware - Compile Elixir applications into single, easily distributed executable binaries ", url: ".", score: 45, flags: 0, comment_count: 4, description: "", comments_url: ".", submitter_user: "placeholder", user_is_author: false, tags: ["tag1", "tag2"])]
        Group {
            hottest_widgetEntryView(entry: SimpleEntry(date: Date(), stories: []))
                .previewContext(WidgetPreviewContext(family: .systemSmall))
            hottest_widgetEntryView(entry: SimpleEntry(date: Date(), stories: generic_stories))
                .previewContext(WidgetPreviewContext(family: .systemSmall))
            hottest_widgetEntryView(entry: SimpleEntry(date: Date(), stories: generic_stories))
                .previewContext(WidgetPreviewContext(family: .systemSmall))
                .environment(\.colorScheme, .dark)
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
