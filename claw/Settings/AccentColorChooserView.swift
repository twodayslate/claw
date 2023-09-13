//
//  AccentColorChooserView.swift
//  claw
//
//  Created by Zachary Gorak on 9/10/23.
//

import SwiftUI

struct AccentColorChooserView: View {
    @EnvironmentObject var settings: Settings
    @State var customColor: Color = .accentColor
    @StateObject var storeModel = StoreKitModel.pro

    @Environment(\.dismiss) var dismiss

    var colors: [UIColor] {
        [settings.defaultAccentColor, UIColor.label, UIColor.systemRed, UIColor.systemBlue, UIColor.systemGreen, UIColor.systemGray, UIColor.systemYellow, UIColor.systemTeal, UIColor.systemOrange, UIColor.systemPurple, UIColor.systemIndigo, UIColor.systemMint]
    }

    var isCustom: Bool {
        return !colors.contains(settings.accentUIColor)
    }

    var body: some View {
        List {
            ForEach(colors, id: \.self) { color in
                ColorIconView(color: color)
            }
            ZStack(alignment: .leading) {
                customRow
                    .disabled(!storeModel.owned)
                    .blur(radius: storeModel.owned ? 0.0 : 5.0)
                if !storeModel.owned {
                    NavigationLink(destination: Pro()) {
                        HStack {
                            Spacer()
                            Text("Unlock Custom Colors")
                                .font(.headline)
                                .foregroundColor(.accentColor)
                                .shadow(color: Color(UIColor.systemBackground), radius: 3.0)
                            Spacer()
                        }

                    }
                }
            }

        }
        .navigationTitle("Accent Color")
        .listStyle(GroupedListStyle())
        .onAppear {
            if isCustom {
                customColor = settings.accentColor
            } else {
                customColor = Color(UIColor.link)
            }
        }
    }

    var customRow: some View {
        Button {
            settings.accentColorData = UIColor(customColor).data
            try? settings.managedObjectContext?.save()
            dismiss()
        } label: {
            HStack {
                ColorPicker("Custom Accent Color", selection: $customColor)
                .labelsHidden()
                .onChange(of: customColor) {
                    if isCustom {
                        settings.accentColorData = UIColor($0).data
                        try? settings.managedObjectContext?.save()
                    }
                }
                Text("Custom").foregroundColor(Color(UIColor.label))
                if isCustom {
                    Spacer()
                    Text("\(Image(systemName: "checkmark"))").bold().foregroundColor(.accentColor)
                }
            }
        }
    }
}

#if DEBUG
struct AccentColorChooserViewPreview: PreviewProvider {
    static var previews: some View {
        AccentColorChooserView()
            .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
            .environmentObject(Settings(context: PersistenceController.preview.container.viewContext))
            .environmentObject(ObservableURL())
    }
}
#endif
