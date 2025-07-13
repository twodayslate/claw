import SwiftUI

struct AppIconChooserView: View {
    @EnvironmentObject var settings: Settings
    @Environment(\.dismiss) private var dismiss
    @StateObject var storeModel: StoreKitModel = .pro
    
    @State var showAlert = false
    var body: some View {
        List {
            Section {
                Button(action: {
                    UIApplication.shared.setAlternateIconName(nil, completionHandler: {error in
                        guard error == nil else {
                            // show error
                            return
                        }
                        settings.alternateIconName = nil
                        try? settings.managedObjectContext?.save()
                        dismiss()
                    })
                }, label: {
                    AppIconView(icon: AppIcon(alternateIconName: nil, name: "claw", assetName: "AppIcon-thumb", subtitle: "Maria Garcia (mariajgarcia.com)")).environmentObject(settings)
                })
            }
            Section {
                Button(action: {
                    UIApplication.shared.setAlternateIconName("Akhmad437LobsterDarkIcon", completionHandler: {error in
                        guard error == nil else {
                            // show error
                            return
                        }
                        settings.alternateIconName = "Akhmad437LobsterDarkIcon"
                        try? settings.managedObjectContext?.save()
                        dismiss()
                    })
                }, label: {
                    AppIconView(icon: AppIcon(alternateIconName: "Akhmad437LobsterDarkIcon", name: "Dark Lobster", assetName: "Akhmad437LobsterDarkIcon-thumb", subtitle: "@akhmadmaulidi"))
                        .environmentObject(settings)
                })
                
                Button(action: {
                    UIApplication.shared.setAlternateIconName("Akhmad437LobsterLightIcon", completionHandler: {error in
                        guard error == nil else {
                            // show error
                            return
                        }
                        settings.alternateIconName = "Akhmad437LobsterLightIcon"
                        try? settings.managedObjectContext?.save()
                        dismiss()
                    })
                }, label: {
                    AppIconView(icon: AppIcon(alternateIconName: "Akhmad437LobsterLightIcon", name: "Light Lobster", assetName: "Akhmad437LobsterLightIcon-thumb", subtitle: "@akhmadmaulidi"))
                        .environmentObject(settings)
                })
            }
            Section {
                Button(action: {
                    UIApplication.shared.setAlternateIconName("KnuxIcon", completionHandler: {error in
                        guard error == nil else {
                            // show error
                            return
                        }
                        settings.alternateIconName = "KnuxIcon"
                        try? settings.managedObjectContext?.save()
                        dismiss()
                    })
                }, label: {
                    AppIconView(icon: AppIcon(alternateIconName: "KnuxIcon", name: "Pixel Lobster", assetName: "KnuxIcon-thumb", subtitle: "Knux 400"))
                        .environmentObject(settings)
                })
            }

            Section("Supporter Icons") {
                iapAppIcon(AppIcon(alternateIconName: "ClawHeart", name: "clawve", assetName: "ClawHeart-thumb", subtitle: "Maria Garcia (mariajgarcia.com)"))
                iapAppIcon(AppIcon(alternateIconName: "blueprint", name: "Blueprint", assetName: "blueprint-thumb", subtitle: nil))
            }
        }
        .listStyle(GroupedListStyle())
        .navigationTitle("App Icon")
        .alert(isPresented: $showAlert, content: {
            Alert(title: Text("Error"), message: Text("Unable to set icon. Try again later."), dismissButton: .default(Text("Okay")))
        })
    }

    func iapAppIcon(_ icon: AppIcon) -> some View {
        ZStack(alignment: .leading) {
            iconButton(icon)
            .disabled(!storeModel.owned)
            .blur(radius: storeModel.owned ? 0.0 : 5.0)
            if !storeModel.owned {
                NavigationLink(destination: Pro()) {
                    HStack {
                        Spacer()
                        Text("Unlock Supporter Icons")
                            .font(.headline)
                            .foregroundColor(.accentColor)
                            .shadow(color: Color(UIColor.systemBackground), radius: 3.0)
                        Spacer()
                    }

                }
            }
        }
    }

    func iconButton(_ icon: AppIcon) -> some View {
        Button {
            UIApplication.shared.setAlternateIconName(icon.alternateIconName, completionHandler: { error in
                guard error == nil else {
                    // show error
                    return
                }
                settings.alternateIconName = icon.alternateIconName
                try? settings.managedObjectContext?.save()
                self.presentationMode.wrappedValue.dismiss()
            })
        } label: {
            AppIconView(icon: icon)
                .environmentObject(settings)
        }
    }
}
