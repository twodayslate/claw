//
//  URLView.swift
//  claw
//
//  Created by Zachary Gorak on 9/13/20.
//

import SwiftUI

struct URLView: View {
    var link: String
    var body: some View {
        Text("\(link)").padding().font(.footnote).foregroundColor(Color.primary).background(Color.secondary).overlay(
            RoundedRectangle(cornerRadius: 8.0)
                .stroke(Color.primary, lineWidth: 2.0)
        ).clipShape(RoundedRectangle(cornerRadius: 8.0)).onTapGesture {
            UIApplication.shared.open(URL(string: link)!)
        }
    }
}

struct URLView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            URLView(link: "https://zac.gorak.us")
        }.previewLayout(.sizeThatFits)
        
    }
}
