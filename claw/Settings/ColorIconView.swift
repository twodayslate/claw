//
//  ColorIconView.swift
//  claw
//
//  Created by Zachary Gorak on 9/10/23.
//

import SwiftUI
import SwiftData

struct ColorIconView: View {
    var color: UIColor

    @Environment(\.dismiss) private var dismiss
    @Environment(Settings.self) var settings

    var body: some View {
        Button(action: {
            settings.accentColorData = color.data
            dismiss()
        }, label: {
            HStack {
                ColorPicker(color.name ?? "Unknown", selection: .constant(Color(color)))
                    .overlay {
                        Circle().strokeBorder(Color(color), lineWidth: 3)
                    }
                    .labelsHidden()
                    .disabled(true)
                Text("\(color.name ?? "Unkown")").foregroundColor(Color(UIColor.label))
                if settings.accentColor == Color(color) {
                    Spacer()
                    Text("\(Image(systemName: "checkmark"))").bold().foregroundColor(.accentColor)
                }
            }
        })
    }
}

#if DEBUG
struct ColorIconViewPreview: PreviewProvider {
    static var previews: some View {
        let _ =  (UIColor.additionalNameMapping[UIColor.lobsterRed] = "Lobsters Red")
        Group {
            ColorIconView(color: .lobsterRed)
            ColorIconView(color: .blue.withAlphaComponent(0.5))
        }
            .modelContainer(PersistenceControllerV2.preview.container)
            .environment(SettingsV2())
            .environmentObject(ObservableURL())
    }
}
#endif
