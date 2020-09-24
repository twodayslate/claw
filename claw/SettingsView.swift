//
//  SettingsView.swift
//  claw
//
//  Created by Zachary Gorak on 9/17/20.
//

import SwiftUI
import MessageUI

struct CustomLabelStyle: LabelStyle {
    ///https://www.hackingwithswift.com/forums/swiftui/vertical-align-icon-of-label/3346
    @Environment(\.sizeCategory) var size
    
    func makeBody(configuration: Configuration) -> some View {
        HStack(alignment: .center) {
            if size >= .accessibilityMedium {
                configuration.icon
                    .frame(width: 80)
            } else {
                configuration.icon
                    .frame(width: 30)
            }
            configuration.title
        }
    }
}

struct SettingsLinkView: View {
    var icon: Image
    var text: String
    var url: String
    
    var body: some View {
            Button(action: {
                UIApplication.shared.open(URL(string: url)!)
            }, label: {
                Label(
                    title: { Text(text) },
                    icon: { icon.resizable().aspectRatio(contentMode: .fit) }
                ).labelStyle(CustomLabelStyle())
            
//            icon.resizable().frame(width: 28, height: 28, alignment: /*@START_MENU_TOKEN@*/.center/*@END_MENU_TOKEN@*/)
//            Link(text, destination: URL(string: url)!).icon
        })
    }
}

struct SettingsLayoutSlider: View {
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject var settings: Settings
    
    var body: some View {
        VStack(alignment: .leading) {
            List {
                if HottestFetcher.cachedStories.count > 0 {
                    ForEach(HottestFetcher.cachedStories) { story in
                        StoryCell(story: story).environmentObject(settings).allowsHitTesting(false)
                    }
                } else {
                    ForEach(1..<5) { _ in
                        StoryCell(story: NewestStory.placeholder).environmentObject(settings).allowsHitTesting(false)
                    }
                }
            }.listStyle(PlainListStyle()).frame(height: 175).padding(0).allowsHitTesting(false).overlay(Rectangle().foregroundColor(.clear).opacity(0.0).background(LinearGradient(gradient: Gradient(colors: [Color(UIColor.secondarySystemGroupedBackground.withAlphaComponent(0.0)), Color(UIColor.secondarySystemGroupedBackground.withAlphaComponent(0.0)), Color(UIColor.secondarySystemGroupedBackground)]), startPoint: .top, endPoint: .bottom)))
            HStack {
                Image(systemName: "doc.plaintext").renderingMode(.template).foregroundColor(.accentColor)
                Slider(value: $settings.layoutValue, in: 0...2, step: 1, onEditingChanged: { _ in
                    try? settings.managedObjectContext?.save()
                }) {
                        Text("Layout")
                }
                Image(systemName: "doc.richtext").renderingMode(.template).foregroundColor(.accentColor)
            }
        }
    }
}

struct AppIcon: Codable {
    var alternateIconName: String?
    var name: String
    var assetName: String
}

struct AppIconView: View {
    var icon: AppIcon
    
    @EnvironmentObject var settings: Settings
    
    var body: some View {
        let path = Bundle.main.resourcePath! + "/" + icon.assetName
        HStack {
            Image(uiImage: UIImage(contentsOfFile: path)!).clipShape(RoundedRectangle(cornerRadius: 18.0, style: .circular))
            Text("\(icon.name)")
            if settings.alternateIconName == icon.alternateIconName {
                Spacer()
                Image(systemName: "checkmark").foregroundColor(.accentColor)
            }
        }
    }
}

struct ColorIconView: View {
    var color: UIColor
    
    @EnvironmentObject var settings: Settings
    
    var body: some View {
        Button(action: {
            settings.accentColorData = color.data
        }, label: {
            HStack {
                Image(systemName: "app.fill").foregroundColor(Color(color))
                Text("\(color.name ?? "Unkown")")
                if settings.accentColor == Color(color) {
                    Spacer()
                    Image(systemName: "checkmark").foregroundColor(.accentColor)
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
        }.navigationTitle("Accent Color")
    }
}

struct AppIconChooserView: View {
    @EnvironmentObject var settings: Settings
    
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
                })
            }, label: {
                AppIconView(icon: AppIcon(alternateIconName: nil, name: "claw", assetName: "claw@2x.png")).environmentObject(settings)
            })
            Button(action: {
                UIApplication.shared.setAlternateIconName("Classic", completionHandler: { error in
                    guard error == nil else {
                        showAlert = true
                        return
                    }
                    settings.alternateIconName = "Classic"
                    try? settings.managedObjectContext?.save()
                })
            }, label: {
                AppIconView(icon: AppIcon(alternateIconName: "Classic", name: "Classic", assetName: "Classic@2x.png")).environmentObject(settings)
            })
        }.navigationTitle("App Icon").alert(isPresented: $showAlert, content: {
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
    
    var body: some View {
        NavigationView {
            List {
                Section(header: Text("Appearance")) {
                    if UIApplication.shared.supportsAlternateIcons {
                        NavigationLink(destination: AppIconChooserView().environmentObject(settings), label: {
                            Label(title: {
                                HStack {
                                    Text("App Icon")
                                    Spacer()
                                    Text("\(settings.alternateIconName ?? "Default")").foregroundColor(.gray)
                                }
                                
                            }, icon: {Image(systemName: "app.fill").renderingMode(.template).resizable().aspectRatio(contentMode: .fit).foregroundColor(.accentColor) }).labelStyle(CustomLabelStyle())
                        })
                    }
                    NavigationLink(destination: AccentColorChooserView().environmentObject(settings), label: {
                        Label(title: {
                            HStack {
                                Text("Accent Color")
                                Spacer()
                                Text("\(settings.accentUIColor.name ?? "Unknown")").foregroundColor(.gray)
                            }
                            
                        }, icon: {Image(systemName: "paintbrush.fill").renderingMode(.template).resizable().aspectRatio(contentMode: .fit).foregroundColor(.accentColor) }).labelStyle(CustomLabelStyle())
                    })
                }
                Section(header: Text("Layout")) {
                    SettingsLayoutSlider().environmentObject(settings)
                }
                Section {
                    SettingsLinkView(icon: Image("github"), text: "GitHub", url: "https://github.com/twodayslate/claw")
                    SettingsLinkView(icon: Image("twitter"), text: "Twitter", url: twitterURL.absoluteString)
                    if MFMailComposeViewController.canSendMail() {
                        Button(action: {
                            self.isShowingMailView.toggle()
                        }, label: {
                            Label(
                                title: { Text("Contact") },
                                icon: { Image(systemName: "at").resizable().aspectRatio(contentMode: .fit) }
                            ).labelStyle(CustomLabelStyle())
                        })
                    } else {
                        Button(action: {
                            self.isShowingMailViewAlert.toggle()
                        }, label: {
                            Label(
                                title: { Text("Contact") },
                                icon: { Image(systemName: "at").resizable().aspectRatio(contentMode: .fit) }
                            ).labelStyle(CustomLabelStyle())
                        }).alert(isPresented: $isShowingMailViewAlert, content: {
                            Alert(title: Text("Email"), message: Text("zac+claw@gorak.us"), dismissButton: .default(Text("Okay")))
                        })
                    }
                    SettingsLinkView(icon:  Image(systemName: "star.fill"), text: "Rate", url: "https://itunes.apple.com/gb/app/id1531645542?action=write-review&mt=8")
                }
                Section(header: Text("Legal")) {
                    SettingsLinkView(icon: Image(systemName: "doc.text.magnifyingglass"), text: "Privacy Policy", url: "https://zac.gorak.us/ios/privacy")
                    SettingsLinkView(icon: Image(systemName: "doc.text"), text: "Terms of Use", url: "https://zac.gorak.us/ios/terms")
                }
            }.sheet(isPresented: $isShowingMailView) {
                MailView(isShowing: self.$isShowingMailView, result: self.$mailResult, subject: emailSubject, toReceipt: ["zac+claw@gorak.us"])
            }.listStyle(GroupedListStyle()
            ).navigationBarTitle("Settings", displayMode: .inline)
        }
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            SettingsView().environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
        }.previewLayout(.sizeThatFits)
        
    }
}
