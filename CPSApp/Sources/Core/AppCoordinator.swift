import Foundation
import RadioCore
import RadioModelCore
import USBTransport
import Discovery

/// Central coordinator for the CPS application.
@Observable
final class AppCoordinator {
    var radioDetector = RadioDetector()
    var connectionState: ConnectionState = .disconnected
    var selectedModelIdentifier: String?

    init() {
        radioDetector.startScanning()
    }

    /// All available radio models for the UI.
    var availableModels: [RadioModelInfo] {
        RadioModelRegistry.allIdentifiers.compactMap { id in
            guard let model = RadioModelRegistry.model(for: id) else { return nil }
            return RadioModelInfo(from: model)
        }
    }

    /// Creates a new codeplug for the selected model.
    func createNewCodeplug(modelIdentifier: String) -> Codeplug? {
        RadioModelRegistry.createDefaultCodeplug(for: modelIdentifier)
    }
}

/// Radio connection state.
enum ConnectionState: Equatable {
    case disconnected
    case connecting
    case connected(String) // port path
    case programming
    case error(String)

    var isDisconnected: Bool {
        if case .disconnected = self { return true }
        return false
    }

    var statusLabel: String {
        switch self {
        case .disconnected: return "No Radio"
        case .connecting: return "Connecting..."
        case .connected(let port): return "Connected (\(port))"
        case .programming: return "Programming..."
        case .error(let msg): return "Error: \(msg)"
        }
    }

    var statusColor: String {
        switch self {
        case .disconnected: return "gray"
        case .connecting: return "yellow"
        case .connected: return "green"
        case .programming: return "blue"
        case .error: return "red"
        }
    }
}
