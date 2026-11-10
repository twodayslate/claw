import Combine
import Foundation
import Network

/// Reachability is a reason to retry, never proof that a login is invalid.
@MainActor
final class ConnectivityRecovery {
    static let shared = ConnectivityRecovery()

    private let monitor: NWPathMonitor?
    private let subject = PassthroughSubject<Void, Never>()
    private var wasConnected: Bool?

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
        if reconnected { subject.send() }
    }
}
