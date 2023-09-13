//
//  ColorIconView.swift
//  claw
//
//  Created by Zachary Gorak on 9/10/23.
//

import SwiftUI

struct ColorIconView: View {
    var color: UIColor

    @Environment(\.presentationMode) var presentationMode: Binding<PresentationMode>
    @EnvironmentObject var settings: Settings

    var body: some View {
        Button(action: {
            settings.accentColorData = color.data
            try? settings.managedObjectContext?.save()
            self.presentationMode.wrappedValue.dismiss()
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
            .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
            .environmentObject(Settings(context: PersistenceController.preview.container.viewContext))
            .environmentObject(ObservableURL())
    }
}
#endif
