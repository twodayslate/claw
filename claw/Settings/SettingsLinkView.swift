import Foundation
import SwiftUI
import BetterSafariView

struct SettingsLinkView: View {
    var systemImage: String? = nil
    var image: String? = nil
    var text: String
    var url: String
    var iconColor: Color = Color.accentColor
    
    @EnvironmentObject var settings: Settings
    @Environment(\.settingValue) var settingValue
    
    var body: some View {
            Button(action: {
                if settings.browser == .inAppSafari {
                    settingValue.urlToOpen.url = URL(string: url)
                } else {
                    UIApplication.shared.open(URL(string: url)!)
                }
            }, label: {
                ZZLabel(iconBackgroundColor: iconColor, iconColor: .white, systemImage: systemImage, image: image, text: text)
        })
            // this is necessary until multiple sheets can be displayed at one time. See #22
        EmptyView().fullScreenCover(item: settingValue.urlToOpen.bindingUrl, content: { url in
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

struct SettingsLinkView_Previews: PreviewProvider {
    
    static var previews: some View {
        Group {
            SettingsLinkView(text: "Hello World", url: "https://zac.gorak.us").environment(\.managedObjectContext, PersistenceController.preview.container.viewContext).environmentObject(Settings(context: PersistenceController.preview.container.viewContext))
            SettingsLinkView(systemImage: "square",  text: "Hello Square", url: "https://zac.gorak.us", iconColor: .red)
            SettingsLinkView(image: "twitter",  text: "Hello Square", url: "https://zac.gorak.us", iconColor: .blue)

        }.previewLayout(.sizeThatFits)
        
    }
}
