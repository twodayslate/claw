//
//  SwiftUIView.swift
//  claw
//
//  Created by Zachary Gorak on 10/27/20.
//

import SwiftUI

/**
 An simple NavigationView that has an X in the top right
 */
struct EZPanel<Content>: View where Content: View {
    let content: () -> Content
    
    @Environment(\.presentationMode) var presentationMode: Binding<PresentationMode>
    
    init(@ViewBuilder content: @escaping () -> Content) {
        self.content = content
    }
    var body: some View {
        NavigationView {
            content().navigationBarItems(trailing: Button(action: {self.presentationMode.wrappedValue.dismiss()}) {
                Image(systemName: "xmark.circle.fill").foregroundColor(Color(UIColor.systemGray3))
            })
        }
    }
}

struct SwiftUIView_Previews: PreviewProvider {
    static var previews: some View {
        EZPanel {
            Text("Hello World")
        }
    }
}
