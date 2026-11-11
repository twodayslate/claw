import SwiftUI

struct OfflineStatusBanner: View {
    let connectivity: ConnectivityRecovery = .shared

    var body: some View {
        if connectivity.isOffline {
            Label("You’re offline", systemImage: "wifi.slash")
                .font(.subheadline)
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity)
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(.regularMaterial, ignoresSafeAreaEdges: [])
                .accessibilityIdentifier("offline-status-banner")
        }
    }
}
