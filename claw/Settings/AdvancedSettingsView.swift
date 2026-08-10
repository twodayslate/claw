import SwiftUI

enum TabBarMinimizePreference: String, CaseIterable, Identifiable {
    case automatic
    case never
    case onScroll

    static let defaultsKey = "tabBarMinimizePreference"

    var id: Self { self }

    var title: String {
        switch self {
        case .automatic:
            return "Automatic"
        case .never:
            return "Never"
        case .onScroll:
            return "On Scroll"
        }
    }

    var behavior: TabBarMinimizeBehavior {
        switch self {
        case .automatic:
            return .automatic
        case .never:
            return .never
        case .onScroll:
            return .onScrollDown
        }
    }
}

struct AdvancedSettingsView: View {
    @AppStorage(TabBarMinimizePreference.defaultsKey)
    private var tabBarMinimizePreference: TabBarMinimizePreference = .onScroll

    #if DEBUG
    @EnvironmentObject private var lobstersSession: LobstersSession
    @State private var debugServer = APIConfiguration.shared.debugServer
    @State private var isSwitchingDebugServer = false
    #endif

    var body: some View {
        Form {
            Section {
                Picker("Minimize Tab Bar", selection: $tabBarMinimizePreference) {
                    ForEach(TabBarMinimizePreference.allCases) { preference in
                        Text(preference.title).tag(preference)
                    }
                }
            } header: {
                Text("Tab Bar").font(style: .footnote)
            } footer: {
                Text("Choose whether the tab bar minimizes as you scroll through content.")
            }

            #if DEBUG
            Section {
                Picker("Lobsters Website", selection: $debugServer) {
                    ForEach(APIConfiguration.DebugServer.allCases) { server in
                        Text(server.title).tag(server)
                    }
                }
                .disabled(isSwitchingDebugServer)
                .onChange(of: debugServer) { oldServer, newServer in
                    guard oldServer != newServer else {
                        return
                    }
                    switchDebugServer(to: newServer)
                }

                LabeledContent(
                    "Base URL",
                    value: APIConfiguration.shared.baseURL.absoluteString
                )

                if isSwitchingDebugServer {
                    HStack {
                        ProgressView()
                        Text("Switching Lobsters website…")
                            .foregroundStyle(.secondary)
                    }
                }

                if debugServer == .production {
                    Label(
                        "This uses the real lobste.rs website and account data.",
                        systemImage: "exclamationmark.triangle.fill"
                    )
                    .font(.caption)
                    .foregroundStyle(.orange)
                }
            } header: {
                Text("Debug").font(style: .footnote)
            } footer: {
                Text("Debug builds default to the disposable local test server. Switching websites signs out the current Lobsters session and refreshes all content.")
            }
            #endif
        }
        .formStyle(.grouped)
        .navigationTitle("Advanced")
        .navigationBarTitleDisplayMode(.inline)
    }

    #if DEBUG
    private func switchDebugServer(to server: APIConfiguration.DebugServer) {
        guard !isSwitchingDebugServer else {
            return
        }
        isSwitchingDebugServer = true
        Task {
            await lobstersSession.switchDebugServer(to: server)
            debugServer = APIConfiguration.shared.debugServer
            isSwitchingDebugServer = false
        }
    }
    #endif
}

#Preview {
    NavigationStack {
        AdvancedSettingsView()
    }
    .environmentObject(LobstersSession())
}
