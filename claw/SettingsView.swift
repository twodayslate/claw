//
//  SettingsView.swift
//  claw
//
//  Created by Zachary Gorak on 9/17/20.
//

import SwiftUI
import MessageUI
import SwiftDB

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
    
    @State var layoutValue: Double = 2.0
    
    @EnvironmentObject var container: PersistentContainer
    
    @FetchModels<SettingsEntity>() var settings
    
    var settingsEntity: SettingsEntity {
        return settings.first ?? container.create(SettingsEntity.self)
    }
    
    var body: some View {
        NavigationView {
            List {
                
                Section(header: Text("Layout")) {
                    VStack {
                        StoryCell(story: NewestStory(short_id: "", short_id_url: "", created_at: "2020-09-17T08:35:19.000-05:00", title: "Story title", url: "https://zac.gorak.us", score: 69, flags: 0, comment_count: 420, description: "Description", comments_url: "", submitter_user: NewestUser(username: "twodayslate", created_at: "", is_admin: false, about: "", is_moderator: false, karma: 0, avatar_url: "", invited_by_user: "", github_username: nil, twitter_username: nil, keybase_signatures: nil), tags: ["programming", "apple"])).allowsHitTesting(false)
                        Slider(value: settingsEntity.$layoutChoice, in: 0...2, step: 1, minimumValueLabel: Label(
                            title: { Text("Minimal") },
                            icon: { Image(systemName: "doc.plaintext") }
                        ), maximumValueLabel: Label(
                            title: { Text("Full") },
                            icon: { Image(systemName: "doc.richtext") }
    )) {
                            Text("Layout")
                        }
                    }
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
    @StateObject var container = PersistentContainer(SettingsSchema())
    
    static var previews: some View {
        Group {
            SettingsView()
        }.previewLayout(.sizeThatFits)
        
    }
}