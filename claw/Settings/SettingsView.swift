import SwiftUI
import SwiftData
import MessageUI
import SimpleCommon

struct SettingsView: View {
    @State var mailResult: Result<MFMailComposeResult, Error>? = nil
    @State var isShowingMailView = false
    @State var isShowingMailViewAlert = false
    @EnvironmentObject var storeModel: StoreKitModel
    @EnvironmentObject var lobstersSession: LobstersSession
    @State private var isShowingLobstersLogin = false
    @State private var isShowingStorySubmission = false
    
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
    @Environment(\.modelContext) var modelContext

    var body: some View {
        @Bindable var bindableSettings = settings
        Form {
            Section {
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
            } header: {
                Text("Apperance").font(style: .footnote)
            }
            Section {
                SettingsLayoutSlider()
            } header: {
                Text("Layout").font(style: .footnote)
            }
            Section {
                
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
            } header: {
                Text("Browsing").font(style: .footnote)
            }
            Section {
                NavigationLink(destination: AdvancedSettingsView()) {
                    SimpleIconLabel(
                        iconBackgroundColor: .accentColor,
                        iconColor: settings.accentUIColor == .white ? .black : .white,
                        systemImage: "gearshape.2.fill",
                        text: "Advanced"
                    )
                }
            }
            Section {
                if storeModel.owned {
                    switch lobstersSession.state {
                    case .checking, .signingIn:
                        HStack {
                            ProgressView()
                            Text(lobstersSession.state == .signingIn ? "Signing in to Lobsters…" : "Checking Lobsters session…")
                                .foregroundStyle(.secondary)
                        }
                    case .signedIn(let username), .signingOut(let username):
                        NavigationLink(destination: UserView(username)) {
                            HStack(spacing: 12) {
                                accountAvatar
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Signed in as \(username)")
                                    Text("Managed by Claw · Beta")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .accessibilityIdentifier("lobsters-account-profile")

                        Button("Sign Out", role: .destructive) {
                            Task {
                                await lobstersSession.signOut()
                            }
                        }
                        .disabled(lobstersSession.activeAction != nil)

                        Button {
                            isShowingStorySubmission = true
                        } label: {
                            Label("Submit a Story", systemImage: "square.and.pencil")
                        }
                        .disabled(lobstersSession.activeAction != nil)
                    case .signedOut:
                        Button {
                            isShowingLobstersLogin = true
                        } label: {
                            SimpleIconLabel(
                                iconBackgroundColor: .accentColor,
                                iconColor: .white,
                                systemImage: "person.crop.circle.badge.checkmark",
                                text: "Sign In to Lobsters"
                            )
                        }
                    case .unavailable(let message):
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Lobsters login is temporarily unavailable.")
                            Text(message)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Button("Retry") {
                                Task { await lobstersSession.start(force: true) }
                            }
                        }
                    }
                } else {
                    NavigationLink(destination: Pro()) {
                        HStack {
                            SimpleIconLabel(
                                iconBackgroundColor: .accentColor,
                                iconColor: .white,
                                systemImage: "person.crop.circle.badge.checkmark",
                                text: "Lobsters Login"
                            )
                            Spacer()
                            Text("Supporter")
                                .font(.caption.bold())
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            } header: {
                Text("Lobsters Account · Beta").font(style: .footnote)
            } footer: {
                Text("Third-party login management. Claw is an unofficial app and is not operated by Lobsters. While in beta, login is currently only available to additional supporters. Your password is handled by the Lobsters webpage; Claw securely stores only the resulting session cookie in Keychain.")
                    .font(.caption2)
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
            Section {
                SettingsLinkView(systemImage: "doc.text.magnifyingglass", text: "Privacy Policy", url: "https://zac.gorak.us/ios/privacy", iconColor: .gray)
                SettingsLinkView(systemImage: "doc.text", text: "Terms of Use", url: "https://zac.gorak.us/ios/terms", iconColor: .gray)
            } header: {
                Text("Legal").font(style: .footnote)
            } footer: {
                Text(showingShortVersion ? emailSubject : longVersion)
                    .font(style: .caption2)
                    .opacity(0.4)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .onTapGesture {
                        showingShortVersion.toggle()
                    }
            }
        }
        .formStyle(.grouped)
        .sheet(isPresented: $isShowingMailView) {
            SimpleMailView(result: self.$mailResult, subject: emailSubject, toReceipt: ["zac+claw@gorak.us"])
        }
        .sheet(isPresented: $isShowingLobstersLogin) {
            LobstersLoginView()
                .environmentObject(lobstersSession)
        }
        .sheet(isPresented: $isShowingStorySubmission) {
            LobstersStorySubmissionView()
                .environmentObject(lobstersSession)
        }
        .alert(
            "Lobsters Login Error",
            isPresented: Binding(
                get: { lobstersSession.errorMessage != nil },
                set: { isPresented in
                    if !isPresented {
                        lobstersSession.errorMessage = nil
                    }
                }
            )
        ) {
            Button("OK", role: .cancel) {
                lobstersSession.errorMessage = nil
            }
        } message: {
            Text(lobstersSession.errorMessage ?? "An unknown error occurred.")
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            do {
                if !storeModel.hasInitialized {
                    try await storeModel.initialize()
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

    @ViewBuilder
    private var accountAvatar: some View {
        if let avatarImage = lobstersSession.avatarImage {
            Image(uiImage: avatarImage)
                .resizable()
                .frame(width: 36, height: 36)
                .clipShape(Circle())
                .shadow(
                    color: .black.opacity(0.28),
                    radius: 2,
                    x: 0,
                    y: 1
                )
        } else {
            Image(systemName: "person.crop.circle.fill")
                .resizable()
                .foregroundStyle(.secondary)
                .frame(width: 36, height: 36)
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
        .environmentObject(StoreKitModel.pro)
        .environmentObject(LobstersSession())
        
    }
}
