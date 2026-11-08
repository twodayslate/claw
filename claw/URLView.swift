//
//  URLView.swift
//  claw
//
//  Created by Zachary Gorak on 9/13/20.
//

import SwiftUI

struct URLView: View {
    var link: HTMLLink
    var pageURL: URL? = nil
    var commentMenu: CommentContextMenu? = nil
    @Environment(Settings.self) private var settings
    @Environment(\.openURL) private var openURL
    @EnvironmentObject var urlToOpen: ObservableURL
    @EnvironmentObject var observableSheet: ObservableActiveSheet
    
    var body: some View {
        VStack(alignment: .leading){
            if link.text != link.url {
                Text("\(link.text)")
                    .font(style: .footnote)
                    .bold()
                    .foregroundColor(Color.primary)
            }
            Text("\(fixedUpUrl?.absoluteString ?? link.url)")
                .font(style: .caption)
                .foregroundColor(Color.primary)
        }
        .padding()
        .background(.thinMaterial)
        .overlay(
            RoundedRectangle(cornerRadius: 8.0)
                .stroke(Color(UIColor.opaqueSeparator), lineWidth: 2.0)
        )
        .clipShape(RoundedRectangle(cornerRadius: 8.0))
        .onTapGesture {
            guard let url = fixedUpUrl else{
                observableSheet.sheet = .error(URLError(.badURL))
                return
            }
            openURL(url)
        }
        .contextMenu {
            if let url = resolvedURL {
                ShareLink("Share Link", item: url)
                if LobstersLink(url: url) != nil {
                    Button("Open in Browser", systemImage: "safari") {
                        // Bypass native routing only for this explicit action.
                        if settings.browser == .inAppSafari {
                            urlToOpen.url = url
                        } else {
                            UIApplication.shared.open(url)
                        }
                    }
                }
            }
            if let commentMenu {
                Section("Comment") { commentMenu }
            }
        }
    }

    private var resolvedURL: URL? {
        guard let url = fixedUpUrl else { return nil }
        return URL(string: url.relativeString,
                   relativeTo: pageURL ?? APIConfiguration.shared.baseURL)?.absoluteURL
    }

    var fixedUpUrl: URL? {
        guard let url = URL(string: link.url) else {
            return nil
        }
        if url.scheme != nil || link.url.hasPrefix("/") || link.url.hasPrefix("#") {
            return url
        }

        var comps = URLComponents(url: url, resolvingAgainstBaseURL: true)
        comps?.scheme = "https"
        return comps?.url
    }
}

struct URLView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            URLView(link: HTMLLink(text: "zac.gorak.us", url: "https://zac.gorak.us"))
                .padding()
            URLView(link: HTMLLink(text: "zac.gorak.us", url: "//zac.gorak.us"))
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
        .modelContainer(PersistenceControllerV2.preview.container)
        .environment(SettingsV2())
        .environmentObject(ObservableURL())
    }
}
