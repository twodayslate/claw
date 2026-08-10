import UIKit

final class ClawAppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        configurationForConnecting connectingSceneSession: UISceneSession,
        options: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        let configuration = UISceneConfiguration(
            name: nil,
            sessionRole: connectingSceneSession.role
        )
        if connectingSceneSession.role == .windowApplication {
            configuration.delegateClass = ClawSceneDelegate.self
        }
        return configuration
    }
}

@MainActor
final class ClawSceneDelegate: NSObject, UIWindowSceneDelegate, ObservableObject {
    @Published private(set) var pendingURL: URL?

    func scene(
        _ scene: UIScene,
        willConnectTo session: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) {
        receive(connectionOptions.urlContexts)
    }

    func scene(
        _ scene: UIScene,
        openURLContexts URLContexts: Set<UIOpenURLContext>
    ) {
        receive(URLContexts)
    }

    func consume(_ url: URL) {
        guard pendingURL == url else {
            return
        }
        pendingURL = nil
    }

    private func receive(_ contexts: Set<UIOpenURLContext>) {
        if let url = contexts.first?.url {
            pendingURL = url
        }
    }
}
