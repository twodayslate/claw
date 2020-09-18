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
    
    var body: some View {
        NavigationView {
            List {
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
            SettingsView()
        }.previewLayout(.sizeThatFits)
        
    }
}
