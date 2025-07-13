//
//  TextSizeAwareFontModifier.swift
//  claw
//
//  Created by Zachary Gorak on 7/13/25.
//

import SwiftUI

struct TextSizeAwareFontModifier: ViewModifier {

    @Environment(Settings.self) var settings

    var style: Font.TextStyle

    init(style: Font.TextStyle) {
        self.style = style
    }

    func body(content: Content) -> some View {
        content
            .font(Font(style, sizeModifier: CGFloat(settings.textSizeModifier)))
    }

}

extension View {

    func font(style: Font.TextStyle) -> some View {
        self.modifier(TextSizeAwareFontModifier(style: style))
    }

}
