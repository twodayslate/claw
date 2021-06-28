import Foundation
import SwiftUI

struct SettingsLayoutSlider: View {
    @Environment(\.settingValue) var settingValue
    @EnvironmentObject var settings: Settings
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    if HottestFetcher.cachedStories.count > 0 {
                        ForEach(HottestFetcher.cachedStories) { story in
                            StoryListCellView(story: story).environmentObject(settings) .environment(\.settingValue,settingValue).allowsHitTesting(false)
                            Divider().padding(0).padding([.leading])
                        }
                    } else {
                        ForEach(1..<5) { _ in
                                StoryListCellView(story: NewestStory.placeholder).environmentObject(settings)
                                    .environment(\.settingValue,settingValue).allowsHitTesting(false)
                            Divider().padding(0).padding([.leading])
                        }
                    }
                }
            }.listStyle(PlainListStyle()).frame(height: 175).padding(0).allowsHitTesting(false).overlay(Rectangle().foregroundColor(.clear).opacity(0.0).background(LinearGradient(gradient: Gradient(colors: [Color(UIColor.secondarySystemGroupedBackground.withAlphaComponent(0.0)), Color(UIColor.secondarySystemGroupedBackground.withAlphaComponent(0.0)), Color(UIColor.secondarySystemGroupedBackground)]), startPoint: .top, endPoint: .bottom)))
            Divider().padding([.bottom], 8.0)
            HStack {
                Image(systemName: "doc.plaintext").renderingMode(.template).foregroundColor(.accentColor)
                Picker("Story Cell Layout", selection: $settings.layoutValue, content: {
                    Text("Compact").tag(Settings.Layout.compact.rawValue)
                    Text("Comfortable").tag(Settings.Layout.comfortable.rawValue)
                    Text("Default").tag(Settings.Layout.Default.rawValue)
                }).pickerStyle(SegmentedPickerStyle())
                Image(systemName: "doc.richtext").renderingMode(.template).foregroundColor(.accentColor)
            }
        }
    }
}

struct SettingsLayoutSlider_Previews: PreviewProvider {
    
    static var previews: some View {
        Group {
            SettingsLayoutSlider().environment(\.managedObjectContext, PersistenceController.preview.container.viewContext).environmentObject(Settings(context: PersistenceController.preview.container.viewContext))
            SettingsLayoutSlider().environment(\.managedObjectContext, PersistenceController.preview.container.viewContext).environmentObject(Settings(context: PersistenceController.preview.container.viewContext)).preferredColorScheme(.dark)

        }.previewLayout(.sizeThatFits)
        
    }
}
