import SwiftUI

struct AppIconChooserView: View {
    @EnvironmentObject var settings: Settings
    @Environment(\.presentationMode) var presentationMode: Binding<PresentationMode>
    
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
                        self.presentationMode.wrappedValue.dismiss()
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
                        self.presentationMode.wrappedValue.dismiss()
                    })
                }, label: {
                    AppIconView(icon: AppIcon(alternateIconName: "Akhmad437LobsterDarkIcon", name: "Dark Lobster", assetName: "Akhmad437LobsterDarkIcon-thumb", subtitle: "akhmad437"))
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
                        self.presentationMode.wrappedValue.dismiss()
                    })
                }, label: {
                    AppIconView(icon: AppIcon(alternateIconName: "Akhmad437LobsterLightIcon", name: "Light Lobster", assetName: "Akhmad437LobsterLightIcon-thumb", subtitle: "akhmad437"))
                        .environmentObject(settings)
                })
            }
            VStack(alignment: .leading) {
                HStack(alignment: .bottom) {
                    Spacer()
                    Text("Thank you for the support!").font(.subheadline)
                    Spacer()
                }
            }
        }
        .listStyle(GroupedListStyle())
        .navigationTitle("App Icon")
        .alert(isPresented: $showAlert, content: {
            Alert(title: Text("Error"), message: Text("Unable to set icon. Try again later."), dismissButton: .default(Text("Okay")))
        })
    }
}
