
import Foundation
import Network
import Combine

@MainActor
final class ConnectivityMonitor: ObservableObject {
    @Published private(set) var isConnected = false

    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "DeadlineCounter.NetworkMonitor")

    init() {
        monitor.pathUpdateHandler = { [weak self] path in
            let connected = path.status == .satisfied

            Task { @MainActor [weak self] in
                guard let self else { return }

                let wasConnected = self.isConnected
                self.isConnected = connected

                if connected && !wasConnected {
                    print("Internet connection restored")
                }
            }
        }

        monitor.start(queue: queue)
    }

    deinit {
        monitor.cancel()
    }
}
