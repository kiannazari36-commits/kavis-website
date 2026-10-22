import Foundation
import Network
import Observation

/// Tells the screens whether the phone has internet (offline banner on home).
/// Test switch: `-kavis.offline 1` pretends there is no internet.
@Observable
final class NetworkMonitor {
    private(set) var isOnline = true
    private let monitor = NWPathMonitor()

    init() {
        if MockFlag.value("offline") == "1" { isOnline = false; return }
        monitor.pathUpdateHandler = { [weak self] path in
            let online = path.status == .satisfied
            Task { @MainActor in self?.isOnline = online }
        }
        monitor.start(queue: DispatchQueue(label: "kavis.network"))
    }

    deinit { monitor.cancel() }
}
