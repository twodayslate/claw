import Foundation
import SwiftUI
import SwiftData

struct SettingsLayoutSlider: View {
    @Environment(Settings.self) private var settings

    var body: some View {
        @Bindable var bindableSettings = settings

        VStack(alignment: .leading, spacing: 0) {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    if HottestFetcher.cachedStories.count > 0 {
                        ForEach(HottestFetcher.cachedStories) { story in
                            StoryListCellView(story: story).allowsHitTesting(false)
                            Divider().padding(0).padding([.leading])
                        }
                    } else {
                        ForEach(1..<5) { _ in
                                StoryListCellView(story: NewestStory.placeholder).allowsHitTesting(false)
                            Divider().padding(0).padding([.leading])
                        }
                    }
                }
            }
            .listStyle(PlainListStyle())
            .frame(height: 175)
            .allowsHitTesting(false)
            .overlay(Rectangle().foregroundColor(.clear).opacity(0.0).background(LinearGradient(gradient: Gradient(colors: [Color(UIColor.secondarySystemGroupedBackground.withAlphaComponent(0.0)), Color(UIColor.secondarySystemGroupedBackground.withAlphaComponent(0.0)), Color(UIColor.secondarySystemGroupedBackground)]), startPoint: .top, endPoint: .bottom)))
            Divider()
                .padding([.bottom], 8.0)
            HStack {
                Image(systemName: "doc.plaintext").renderingMode(.template).foregroundColor(.accentColor)
                Picker("Story Cell Layout", selection: $bindableSettings.layoutValue, content: {
                    Text("Compact").tag(LayoutSetting.compact.rawValue)
                    Text("Comfortable").tag(LayoutSetting.comfortable.rawValue)
                    Text("Default").tag(LayoutSetting.Default.rawValue)
                }).pickerStyle(SegmentedPickerStyle())
                Image(systemName: "doc.richtext").renderingMode(.template).foregroundColor(.accentColor)
            }
        }
    }
}

struct SettingsLayoutSlider_Previews: PreviewProvider {
    
    static var previews: some View {
        Group {
            SettingsLayoutSlider()
            SettingsLayoutSlider().preferredColorScheme(.dark)

        }.previewLayout(.sizeThatFits)
        .modelContainer(PersistenceControllerV2.preview.container)
        
    }
}
