//
//  URLView.swift
//  claw
//
//  Created by Zachary Gorak on 9/13/20.
//

import SwiftUI

struct URLView: View {
    var link: HTMLLink
    @EnvironmentObject var settings: Settings
    @EnvironmentObject var urlToOpen: ObservableURL
    
    var body: some View {
        VStack(alignment: .leading){
            if link.text != link.url {
                Text("\(link.text)").font(Font(.footnote, sizeModifier: CGFloat(settings.textSizeModifier))).bold().foregroundColor(Color.primary)
            }
            Text("\(link.url)").font(Font(.caption, sizeModifier: CGFloat(settings.textSizeModifier))).foregroundColor(Color.primary)
        }
        .padding()
        .background(.thinMaterial)
        .overlay(
            RoundedRectangle(cornerRadius: 8.0)
                .stroke(Color(UIColor.opaqueSeparator), lineWidth: 2.0)
        )
        .clipShape(RoundedRectangle(cornerRadius: 8.0)).onTapGesture {
            if settings.browser == .inAppSafari {
                urlToOpen.url = URL(string: link.url)
            } else {
                UIApplication.shared.open(URL(string: link.url)!)
            }
        }
    }
}

struct URLView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            URLView(link: HTMLLink(text: "zac.gorak.us", url: "https://zac.gorak.us"))
                .padding()
            URLView(link: HTMLLink(text: "https://zac.gorak.us", url: "https://zac.gorak.us"))
                .padding()
            Group {
                URLView(link: HTMLLink(text: "zac.gorak.us", url: "https://zac.gorak.us"))
                    .padding()
            }
            .background(Color(UIColor.systemBackground))
            .environment(\.colorScheme, .dark)
        }
        .previewLayout(.sizeThatFits)
        .environmentObject(Settings(context: PersistenceController.preview.container.viewContext))
        .environmentObject(ObservableURL())
    }
}
