//
//  SettingsTextSizeSlider.swift
//  claw
//
//  Created by Zachary Gorak on 10/16/20.
//

import Foundation
import SwiftUI

struct SettingsTextSizeSlider: View {
    @EnvironmentObject var settings: Settings
    @Environment(\.sizeCategory) var sizeCategory
    
    var body: some View {
        VStack {
            HStack {
                ZZLabel(iconBackgroundColor: Color(UIColor.darkGray), systemImage: "textformat.size", text: "Text Size")
                Spacer()
                if settings.textSizeModifier == 0 {
                    Text("System Size").foregroundColor(.gray)
                } else if settings.textSizeModifier > 0 {
                    Text("System Size +\(Int(settings.textSizeModifier))").foregroundColor(.gray)
                } else {
                    Text("System Size \(Int(settings.textSizeModifier))").foregroundColor(.gray)
                }
            }
            HStack {
                Text("\(Image(systemName: "textformat.size"))").foregroundColor(.accentColor).font(Font(.body, sizeModifier: CGFloat(settings.textSizeModifier)-2))
                    //.font(Font(.body, sizeModifier: settings.textSizeModifier - 2))
                Slider(value: $settings.textSizeModifier, in: -6.0...6.0, step: 1.0)
                Text("\(Image(systemName: "textformat.size"))").foregroundColor(.accentColor).font(Font(.body, sizeModifier: CGFloat(settings.textSizeModifier)+2))
            }
        }
    }
}
