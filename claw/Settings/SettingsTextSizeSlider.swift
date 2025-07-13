//
//  SettingsTextSizeSlider.swift
//  claw
//
//  Created by Zachary Gorak on 10/16/20.
//

import Foundation
import SwiftUI
import SwiftData

import SimpleCommon

struct SettingsTextSizeSlider: View {
    @Environment(Settings.self) var settings
    @Environment(\.sizeCategory) var sizeCategory
    
    var body: some View {
        @Bindable var bindableSettings = settings
        VStack {
            HStack {
                SimpleIconLabel(iconBackgroundColor: Color(UIColor.darkGray), systemImage: "textformat.size", text: "Text Size")
                Spacer()
                if settings.textSizeModifier == 0 {
                    Text("System Size").foregroundColor(.gray)
                } else if settings.textSizeModifier > 0 {
                    Text("System Size +\(String(format: "%.1f", settings.textSizeModifier))").foregroundColor(.gray)
                } else {
                    Text("System Size \(String(format: "%.1f", settings.textSizeModifier))").foregroundColor(.gray)
                }
            }
            HStack {
                Button(action: {
                    if settings.textSizeModifier >= -5.0 {
                        settings.textSizeModifier -= 1.0
                    }
                    
                }, label: {
                    Text("\(Image(systemName: "minus"))")
                        .foregroundColor(.accentColor)
                        .font(style: .body)
                }).buttonStyle(BorderlessButtonStyle())

                Slider(value: $bindableSettings.textSizeModifier, in: -6.0...6.0, step: 0.5).zIndex(1.0)

                Button(action: {
                    if settings.textSizeModifier <= 5.0 {
                        settings.textSizeModifier += 1.0
                    }
                }, label: {
                    Text("\(Image(systemName: "plus"))")
                        .foregroundColor(.accentColor)
                        .font(style: .body)
                }).buttonStyle(BorderlessButtonStyle())
            }
        }
    }
}
