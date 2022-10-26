//
//  SettingsTextSizeSlider.swift
//  claw
//
//  Created by Zachary Gorak on 10/16/20.
//

import Foundation
import SwiftUI

import SimpleCommon

struct SettingsTextSizeSlider: View {
    @EnvironmentObject var settings: Settings
    @Environment(\.sizeCategory) var sizeCategory
    
    var body: some View {
        VStack {
            HStack {
                IconLabel(iconBackgroundColor: Color(UIColor.darkGray), systemImage: "textformat.size", text: "Text Size")
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
                    Text("\(Image(systemName: "minus"))").foregroundColor(.accentColor).font(.body)
                }).buttonStyle(BorderlessButtonStyle())
                
                Slider(value: $settings.textSizeModifier, in: -6.0...6.0, step: 0.5).zIndex(1.0)
                
                Button(action: {
                    if settings.textSizeModifier <= 5.0 {
                        settings.textSizeModifier += 1.0
                    }
                }, label: {
                    Text("\(Image(systemName: "plus"))").foregroundColor(.accentColor).font(.body)
                }).buttonStyle(BorderlessButtonStyle())
            }
        }
    }
}
