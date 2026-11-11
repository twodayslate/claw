import Combine
import Foundation
import Network
import Observation

/// Reachability is a reason to retry, never proof that a login is invalid.
@MainActor
@Observable
final class ConnectivityRecovery {
    static let shared: ConnectivityRecovery = {
        #if DEBUG
        // Simulate a disconnected path without changing the host's networking.
        if ProcessInfo.processInfo.arguments.contains("--claw-ui-testing"),
           ProcessInfo.processInfo.arguments.contains("--claw-ui-testing-offline") {
            let connectivity = ConnectivityRecovery(monitor: nil)
            connectivity.update(isConnected: false)
            return connectivity
        }
        #endif
        return ConnectivityRecovery()
    }()

    private let monitor: NWPathMonitor?
    private let subject = PassthroughSubject<Void, Never>()
    @ObservationIgnored
    private var wasConnected: Bool?
    private(set) var isOffline = false

    var reconnections: AnyPublisher<Void, Never> {
        subject.eraseToAnyPublisher()
    }

    init(monitor: NWPathMonitor? = NWPathMonitor()) {
        self.monitor = monitor
        monitor?.pathUpdateHandler = { [weak self] path in
            let connected = path.status == .satisfied
            Task { @MainActor [weak self] in
                self?.update(isConnected: connected)
            }
        }
        monitor?.start(queue: DispatchQueue(label: "com.twodayslate.claw.connectivity"))
    }

    deinit {
        monitor?.cancel()
    }

    func update(isConnected: Bool) {
        let reconnected = wasConnected == false && isConnected
        wasConnected = isConnected
        isOffline = !isConnected
        if reconnected { subject.send() }
    }
}
