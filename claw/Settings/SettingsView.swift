//
//  SettingsView.swift
//  claw
//
//  Created by Zachary Gorak on 9/17/20.
//

import SwiftUI
import MessageUI

struct AppIcon: Codable {
    var alternateIconName: String?
    var name: String
    var assetName: String
    var subtitle: String?
}

struct AppIconView: View {
    var icon: AppIcon
    
    @EnvironmentObject var settings: Settings
    
    var body: some View {
        let path = Bundle.main.resourcePath! + "/" + icon.assetName
        HStack {
            Image(uiImage: UIImage(contentsOfFile: path)!).mask(Image(systemName: "app.fill").resizable().aspectRatio(contentMode: .fit))
            VStack(alignment: .leading) {
                Text("\(icon.name)").foregroundColor(Color(UIColor.label))
                if let subtitle = icon.subtitle {
                    Text("\(subtitle)").foregroundColor(.gray)
                        .font(Font(.subheadline, sizeModifier: CGFloat(settings.textSizeModifier)))
                }
            }
            
            if settings.alternateIconName == icon.alternateIconName {
                Spacer()
                Text("\(Image(systemName: "checkmark"))").bold().foregroundColor(.accentColor)
            }
        }
    }
}

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
                Image(systemName: "app.fill").foregroundColor(Color(color))
                Text("\(color.name ?? "Unkown")").foregroundColor(Color(UIColor.label))
                if settings.accentColor == Color(color) {
                    Spacer()
                    Text("\(Image(systemName: "checkmark"))").bold().foregroundColor(.accentColor)
                }
            }
        })
    }
}
struct AccentColorChooserView: View {
    @EnvironmentObject var settings: Settings
    
    var body: some View {
        List {
            ForEach([settings.defaultAccentColor, UIColor.black, UIColor.white, UIColor.systemRed, UIColor.systemBlue, UIColor.systemGreen, UIColor.systemGray, UIColor.systemYellow, UIColor.systemTeal, UIColor.systemOrange, UIColor.systemPurple, UIColor.systemIndigo], id: \.self) { color in
                ColorIconView(color: color)
            }
        }.navigationTitle("Accent Color").listStyle(GroupedListStyle())
    }
}
struct AppIconChooserView: View {
    @EnvironmentObject var settings: Settings
    @Environment(\.presentationMode) var presentationMode: Binding<PresentationMode>
    
    @State var showAlert = false
    var body: some View {
        List {
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
            VStack(alignment: .leading) {
                HStack(alignment: .center) {
                    Spacer()
                    Text("More coming soon!").bold().font(.callout)
                    Spacer()
                }
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

struct SettingsView: View {
    @State var mailResult: Result<MFMailComposeResult, Error>? = nil
    @State var isShowingMailView = false
    @State var isShowingMailViewAlert = false
    
    var twitterURL: URL {
        let twitter = URL(string: "twitter://user?screen_name=twodayslate")!
        
        if UIApplication.shared.canOpenURL(twitter) {
            return twitter
        }
        
        return URL(string: "https://twitter.com/twodayslate")!
    }
    
    var emailSubject: String {
        return
             "claw v" + (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as! String)
    }
    
    @EnvironmentObject var settings: Settings
    @Environment(\.sizeCategory) var sizeCategory
    
    var body: some View {
            List {
                Section(header: Text("Appearance").font(Font(.footnote, sizeModifier: CGFloat(settings.textSizeModifier)))) {
                    if UIApplication.shared.supportsAlternateIcons {
                        NavigationLink(destination: AppIconChooserView().environmentObject(settings), label: {
                            HStack {
                                Label(
                                    title: { Text("App Icon").foregroundColor(Color(UIColor.label)) },
                                    icon: { ZStack {
                                        Image(systemName: "app.fill").resizable().aspectRatio( contentMode: .fit).foregroundColor(.accentColor)
                                        Image(uiImage: UIImage(contentsOfFile: Bundle.main.resourcePath! + "/" + (settings.alternateIconName ?? "claw") + "@2x.png")!).resizable().aspectRatio( contentMode: .fit).mask(Image(systemName: "app.fill").resizable().aspectRatio(contentMode: .fit))
                                    } }
                        ).labelStyle(HorizontallyAlignedLabelStyle())
                                //ZZLabel(iconBackgroundColor: Color(UIColor.lobstersRed), iconColor: .white, imageFile: Bundle.main.resourcePath! + "/" + (settings.alternateIconName ?? "claw") + "@2x.png", text: "App Icon", iconScale: 1.0)
                                Spacer()
                                Text("\(settings.alternateIconName ?? "Default")").foregroundColor(.gray)
                            }
                        })
                    }
                    NavigationLink(destination: AccentColorChooserView().environmentObject(settings), label: {
                        HStack {
                            ZZLabel(iconBackgroundColor: .accentColor, iconColor: settings.accentUIColor == .white ? .black : .white, systemImage: "paintbrush.fill", text: "Accent Color")
                            Spacer()
                            Text("\(settings.accentUIColor.name ?? "Unknown")").foregroundColor(.gray)
                        }
                    })
                    
                    HStack {
                        SettingsTextSizeSlider()
                    }
                    
                }
                Section(header: Text("Layout").font(Font(.footnote, sizeModifier: CGFloat(settings.textSizeModifier)))) {
                    SettingsLayoutSlider().environmentObject(settings)
                }
                Section(header: Text("Browsing").font(Font(.footnote, sizeModifier: CGFloat(settings.textSizeModifier)))) {
                        
                    Picker(selection: $settings.browser, label:
                            ZZLabel(iconBackgroundColor: .accentColor, iconColor: settings.accentUIColor == .white ? .black : .white, systemImage: "safari.fill", text: "Browser")
                    , content: {
                        Text("In-App Safari").tag(Browser.inAppSafari)
                        Text("Default Browser").tag(Browser.defaultBrowser)
                    })
                    
                    if settings.browser == Browser.inAppSafari {
                        Toggle(isOn: $settings.readerModeEnabled, label: {
                            ZZLabel(iconBackgroundColor: .accentColor, iconColor: settings.accentUIColor == .white ? .black : .white, systemImage: "textformat.size", text: "Reader Mode")
                        })
                    }
                }
                Section {
                    SettingsLinkView(image: "github", text: "GitHub", url: "https://github.com/twodayslate/claw", iconColor: .black)
                    SettingsLinkView(image: "twitter", text: "Twitter", url: twitterURL.absoluteString, iconColor: .blue)
                    if MFMailComposeViewController.canSendMail() {
                        Button(action: {
                            self.isShowingMailView.toggle()
                        }, label: {
                            ZZLabel(iconBackgroundColor: .red, iconColor: .white, systemImage: "at", text: "Contact")
                        })
                    } else {
                        Button(action: {
                            self.isShowingMailViewAlert.toggle()
                        }, label: {
                            ZZLabel(iconBackgroundColor: .red, iconColor: .white, systemImage: "at", text: "Contact")
                        }).alert(isPresented: $isShowingMailViewAlert, content: {
                            Alert(title: Text("Email"), message: Text("zac+claw@gorak.us"), dismissButton: .default(Text("Okay")))
                        })
                    }
                    SettingsLinkView(systemImage:  "star.fill", text: "Rate", url: "https://itunes.apple.com/gb/app/id1531645542?action=write-review&mt=8", iconColor: .yellow)
                }
                Section(header: Text("Legal").font(Font(.footnote, sizeModifier: CGFloat(settings.textSizeModifier)))) {
                    SettingsLinkView(systemImage: "doc.text.magnifyingglass", text: "Privacy Policy", url: "https://zac.gorak.us/ios/privacy", iconColor: .gray)
                    SettingsLinkView(systemImage: "doc.text", text: "Terms of Use", url: "https://zac.gorak.us/ios/terms", iconColor: .gray)
                }
            }.sheet(isPresented: $isShowingMailView) {
                MailView(isShowing: self.$isShowingMailView, result: self.$mailResult, subject: emailSubject, toReceipt: ["zac+claw@gorak.us"])
            }.listStyle(GroupedListStyle()
            ).navigationTitle("Settings").navigationBarTitleDisplayMode(.inline)
    }
}

struct SettingsView_Previews: PreviewProvider {
    
    static var previews: some View {
        Group {
            SettingsView().environment(\.managedObjectContext, PersistenceController.preview.container.viewContext).environmentObject(Settings(context: PersistenceController.preview.container.viewContext))
        }.previewLayout(.sizeThatFits)
        
    }
}
