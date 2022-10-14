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
                    AppIconView(icon: AppIcon(alternateIconName: nil, name: "claw", assetName: "claw@2x.png", subtitle: "Maria Garcia (mariajgarcia.com)")).environmentObject(settings)
                })
            }
            Section {
                Button(action: {
                    UIApplication.shared.setAlternateIconName("akhmad437_lobster_dark", completionHandler: {error in
                        guard error == nil else {
                            // show error
                            return
                        }
                        settings.alternateIconName = "akhmad437_lobster_dark"
                        try? settings.managedObjectContext?.save()
                        self.presentationMode.wrappedValue.dismiss()
                    })
                }, label: {
                    AppIconView(icon: AppIcon(alternateIconName: "akhmad437_lobster_dark", name: "Dark Lobster", assetName: "akhmad437_lobster_dark", subtitle: "akhmad437"))
                        .environmentObject(settings)
                })
                
                Button(action: {
                    UIApplication.shared.setAlternateIconName("akhmad437_lobster_light", completionHandler: {error in
                        guard error == nil else {
                            // show error
                            return
                        }
                        settings.alternateIconName = "akhmad437_lobster_light"
                        try? settings.managedObjectContext?.save()
                        self.presentationMode.wrappedValue.dismiss()
                    })
                }, label: {
                    AppIconView(icon: AppIcon(alternateIconName: "akhmad437_lobster_light", name: "Light Lobster", assetName: "akhmad437_lobster_light", subtitle: "akhmad437"))
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
        }.listStyle(GroupedListStyle()).navigationTitle("App Icon").alert(isPresented: $showAlert, content: {
            Alert(title: Text("Error"), message: Text("Unable to set icon. Try again later."), dismissButton: .default(Text("Okay")))
        })
    }
}
