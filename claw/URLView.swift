//
//  URLView.swift
//  claw
//
//  Created by Zachary Gorak on 9/13/20.
//

import SwiftUI

struct URLView: View {
    var link: HTMLLink
    var body: some View {
        VStack(alignment: .leading){
            if link.text != link.url {
                Text("\(link.text)").font(.footnote).bold().foregroundColor(Color.primary)
            }
            Text("\(link.url)").font(.caption).foregroundColor(Color.primary)
        }.padding().background(Color.secondary).overlay(
            RoundedRectangle(cornerRadius: 8.0)
                .stroke(Color.primary, lineWidth: 2.0)
        ).clipShape(RoundedRectangle(cornerRadius: 8.0)).onTapGesture {
            UIApplication.shared.open(URL(string: link.url)!)
        }
    }
}

struct URLView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            URLView(link: HTMLLink(text: "zac.gorak.us", url: "https://zac.gorak.us"))
            URLView(link: HTMLLink(text: "https://zac.gorak.us", url: "https://zac.gorak.us"))
            ZStack {
                URLView(link: HTMLLink(text: "zac.gorak.us", url: "https://zac.gorak.us"))
            }.background(Color(UIColor.systemBackground)).environment(\.colorScheme, .dark)
        }.previewLayout(.sizeThatFits)
        
    }
}
