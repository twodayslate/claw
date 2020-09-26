import Foundation
import SwiftUI

struct SettingsLinkView: View {
    var systemImage: String? = nil
    var image: String? = nil
    var text: String
    var url: String
    var iconColor: Color = Color.accentColor
    
    var body: some View {
            Button(action: {
                UIApplication.shared.open(URL(string: url)!)
            }, label: {
                ZZLabel(iconBackgroundColor: iconColor, iconColor: .white, systemImage: systemImage, image: image, text: text)
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
