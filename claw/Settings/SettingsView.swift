import SwiftUI
import SwiftData
import MessageUI
import SimpleCommon

struct SettingsView: View {
    @State var mailResult: Result<MFMailComposeResult, Error>? = nil
    @State var isShowingMailView = false
    @State var isShowingMailViewAlert = false
    @StateObject var storeModel = StoreKitModel.pro
    
    var twitterURL: URL {
        let twitter = URL(string: "twitter://user?screen_name=twodayslate")!
        
        if UIApplication.shared.canOpenURL(twitter) {
            return twitter
        }
        
        return URL(string: "https://twitter.com/twodayslate")!
    }
    
    var emailSubject: String {
        "\(Bundle.main.name) v\(Bundle.main.shortVersion)"
    }
    
    var longVersion: String {
        "\(Bundle.main.name) v\(Bundle.main.longVersion)"
    }
    
    @State var showingShortVersion = true
    
    var alternativeIconNameMap = [
        "Classic": "Classic",
        "Akhmad437LobsterLightIcon": "Light Lobster",
        "Akhmad437LobsterDarkIcon": "Dark Lobster"
    ]
    
    @Environment(Settings.self) var settings
    @Environment(\.sizeCategory) var sizeCategory
    @Environment(\.modelContext) var modelContext

    var body: some View {
        @Bindable var bindableSettings = settings
        Form {
            Section(
                header:
                    Text("Appearance")
                    .font(Font(.footnote, sizeModifier: CGFloat(settings.textSizeModifier)))) {
                        if UIApplication.shared.supportsAlternateIcons {
                            NavigationLink(destination: AppIconChooserView(), label: {
                                HStack {
                                    SimpleIconLabel(
                                        iconBackgroundColor: .clear,
                                        imageName: (settings.alternateIconName ?? "AppIcon") + "-thumb",
                                        text: "App Icon",
                                        iconScale: 1.0
                                    )
                                    Spacer()
                                    Text("\(alternativeIconNameMap[settings.alternateIconName ?? "Default"] ?? "Default")").foregroundColor(.gray)
                                }
                            })
                        }
                        NavigationLink(destination: AccentColorChooserView(), label: {
                            HStack {
                                SimpleIconLabel(iconBackgroundColor: .accentColor, iconColor: settings.accentUIColor == .white ? .black : .white, systemImage: "paintbrush.fill", text: "Accent Color")
                                Spacer()
                                Text("\(settings.accentUIColor.name ?? "Custom")").foregroundColor(.gray)
                            }
                        })

                        NavigationLink(destination: CommentColorPicker(), label: {
                            HStack {
                                SimpleIconLabel(iconBackgroundColor: (settings.commentColorScheme.colors.first ?? Color.accentColor), iconColor: (settings.commentColorScheme.colors.first ?? Color.accentColor) == .white ? .black : .white, systemImage: "list.bullet.indent", text: "Comment Colors")
                                Spacer()
                                Text(settings.commentColorScheme.name).foregroundColor(.gray)
                            }
                        })

                        HStack {
                            SettingsTextSizeSlider()
                        }
                    }
            Section(header: Text("Layout").font(Font(.footnote, sizeModifier: CGFloat(settings.textSizeModifier)))) {
                SettingsLayoutSlider()
            }
            Section(header: Text("Browsing").font(Font(.footnote, sizeModifier: CGFloat(settings.textSizeModifier)))) {
                
                Picker(selection: $bindableSettings.browser, label:
                        SimpleIconLabel(iconBackgroundColor: .accentColor, iconColor: settings.accentUIColor == .white ? .black : .white, systemImage: "safari.fill", text: "Browser")
                       , content: {
                    Text("In-App Safari").tag(BrowserSetting.inAppSafari)
                    Text("Default Browser").tag(BrowserSetting.defaultBrowser)
                })
                
                if settings.browser == BrowserSetting.inAppSafari {
                    Toggle(isOn: $bindableSettings.readerModeEnabled, label: {
                        SimpleIconLabel(iconBackgroundColor: .accentColor, iconColor: settings.accentUIColor == .white ? .black : .white, systemImage: "textformat.size", text: "Reader Mode")
                    })
                }
            }
            Section {
                if storeModel.owned {
                    SimpleIconLabel(systemImage: "heart.fill", text: "Thank you for the support!")
                } else {
                    NavigationLink(destination: Pro(), label: {
                        SimpleIconLabel(systemImage: "heart.text.square", text: "Additional Support")
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
                        SimpleIconLabel(iconBackgroundColor: .red, iconColor: .white, systemImage: "at", text: "Contact")
                    })
                } else {
                    Button(action: {
                        self.isShowingMailViewAlert.toggle()
                    }, label: {
                        SimpleIconLabel(iconBackgroundColor: .red, iconColor: .white, systemImage: "at", text: "Contact")
                    }).alert(isPresented: $isShowingMailViewAlert, content: {
                        Alert(title: Text("Email"), message: Text("zac+claw@gorak.us"), dismissButton: .default(Text("Okay")))
                    })
                }
                SettingsLinkView(systemImage:  "star.fill", text: "Rate", url: "https://itunes.apple.com/gb/app/id1531645542?action=write-review&mt=8", iconColor: .yellow)
            }
            Section(
                header: Text("Legal")
                    .font(Font(.footnote, sizeModifier: CGFloat(settings.textSizeModifier))),
                footer: Text(showingShortVersion ? emailSubject : longVersion)
                    .font(Font(.caption2, sizeModifier: CGFloat(settings.textSizeModifier)))
                    .opacity(0.4)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .onTapGesture {
                        showingShortVersion.toggle()
                    }
            ) {
                SettingsLinkView(systemImage: "doc.text.magnifyingglass", text: "Privacy Policy", url: "https://zac.gorak.us/ios/privacy", iconColor: .gray)
                SettingsLinkView(systemImage: "doc.text", text: "Terms of Use", url: "https://zac.gorak.us/ios/terms", iconColor: .gray)
            }
        }
        .formStyle(.grouped)
        .sheet(isPresented: $isShowingMailView) {
            SimpleMailView(result: self.$mailResult, subject: emailSubject, toReceipt: ["zac+claw@gorak.us"])
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            do {
                if !storeModel.hasInitialized {
                    try await storeModel.update()
                }
            } catch {
                print(error.localizedDescription)
            }
        }
        .onDisappear {
            do {
                try modelContext.save()
            } catch {
                print("error", error)
            }
        }
    }
}

struct SettingsView_Previews: PreviewProvider {
    
    static var previews: some View {
        NavigationStack {
            SettingsView()
        }
        .previewLayout(.sizeThatFits)
        .modelContainer(PersistenceControllerV2.preview.container)
        .environment(SettingsV2())
        .environmentObject(ObservableURL())
        
    }
}
