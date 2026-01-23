import Foundation
import RadioCore
import RadioModelCore
import USBTransport
import Discovery
import UniformTypeIdentifiers

/// App navigation phase.
enum AppPhase {
    case welcome
    case editing
}

/// Central coordinator for the CPS application.
@Observable
final class AppCoordinator {
    var radioDetector = RadioDetector()
    var connectionState: ConnectionState = .disconnected
    var selectedModelIdentifier: String?

    var phase: AppPhase = .welcome
    var currentDocument: CodeplugDocument?
    var documentURL: URL?

    // File dialog triggers
    var showingOpenDialog = false
    var showingSaveDialog = false

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

    /// Creates a new document for the given model and transitions to editing.
    func newDocument(modelIdentifier: String) {
        let codeplug = RadioModelRegistry.createDefaultCodeplug(for: modelIdentifier)
        currentDocument = CodeplugDocument(codeplug: codeplug, modelIdentifier: modelIdentifier)
        documentURL = nil
        phase = .editing
    }

    /// Opens a codeplug file from disk and transitions to editing.
    func openDocument(_ url: URL) throws {
        let data = try Data(contentsOf: url)
        let serializer = CodeplugSerializer()
        let codeplug = try serializer.deserialize(data)
        currentDocument = CodeplugDocument(codeplug: codeplug, modelIdentifier: codeplug.modelIdentifier)
        documentURL = url
        phase = .editing
    }

    /// Saves the current codeplug to a file.
    func saveDocument(to url: URL) throws {
        guard let codeplug = currentDocument?.codeplug else { return }
        let serializer = CodeplugSerializer()
        let data = try serializer.serialize(codeplug)
        try data.write(to: url, options: .atomic)
        documentURL = url
    }

    /// Returns to the welcome screen.
    func closeDocument() {
        currentDocument = nil
        documentURL = nil
        phase = .welcome
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
