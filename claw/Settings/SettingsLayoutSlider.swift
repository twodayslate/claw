import Foundation
import SwiftUI

struct SettingsLayoutSlider: View {
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject var settings: Settings
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            List {
                if HottestFetcher.cachedStories.count > 0 {
                    ForEach(HottestFetcher.cachedStories) { story in
                        StoryCell(story: story).environmentObject(settings).allowsHitTesting(false)
                    }
                } else {
                    ForEach(1..<5) { _ in
                        StoryCell(story: NewestStory.placeholder).environmentObject(settings).allowsHitTesting(false)
                    }
                }
            }.listStyle(PlainListStyle()).frame(height: 175).padding(0).allowsHitTesting(false).overlay(Rectangle().foregroundColor(.clear).opacity(0.0).background(LinearGradient(gradient: Gradient(colors: [Color(UIColor.secondarySystemGroupedBackground.withAlphaComponent(0.0)), Color(UIColor.secondarySystemGroupedBackground.withAlphaComponent(0.0)), Color(UIColor.secondarySystemGroupedBackground)]), startPoint: .top, endPoint: .bottom)))
            Divider().padding([.bottom], 8.0)
            HStack {
                Image(systemName: "doc.plaintext").renderingMode(.template).foregroundColor(.accentColor)
                Picker("Story Cell Layout", selection: $settings.layoutValue, content: {
                    Text("Compact").tag(0.0)
                    Text("Comfortable").tag(1.0)
                    Text("Default").tag(2.0)
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
