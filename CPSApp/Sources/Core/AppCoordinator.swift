import Foundation
import RadioCore
import RadioModelCore
import USBTransport
import Discovery
import RadioProgrammer
import UniformTypeIdentifiers

// Re-export RadioProtocolRegistry for use in AppCoordinator
// (This is defined in RadioProgrammer module)

/// App navigation phase.
enum AppPhase {
    case welcome
    case editing
}

/// Central coordinator for the CPS application.
@Observable
@MainActor
final class AppCoordinator {
    let radioDetector = RadioDetector()
    var connectionState: ConnectionState = .disconnected
    var selectedModelIdentifier: String?

    var phase: AppPhase = .welcome
    var currentDocument: CodeplugDocument?
    var documentURL: URL?

    // File dialog triggers
    var showingOpenDialog = false
    var showingSaveDialog = false
    var showingCloseConfirmation = false
    var pendingCloseAction: (() -> Void)?

    /// Detected devices - tracked separately for proper SwiftUI observation.
    var detectedDevices: [USBDeviceInfo] = []

    /// Auto-transition to editing view when radio is detected.
    var autoTransitionEnabled = true

    /// Shows programming mode instructions when needed.
    var showingProgrammingModeInstructions = false
    var programmingModeInstructions: String?

    /// Detected radio identification (if auto-identified).
    var identifiedRadio: IdentifiedRadio?

    private var observationTask: Task<Void, Never>?
    private var previousDeviceCount = 0

    init() {
        radioDetector.startScanning()

        // Start observing the detector's devices
        observationTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { break }
                let newDevices = self.radioDetector.detectedDevices
                let wasEmpty = self.detectedDevices.isEmpty
                let nowHasDevices = !newDevices.isEmpty

                if newDevices != self.detectedDevices {
                    self.detectedDevices = newDevices

                    // Auto-transition when radio is newly detected
                    if wasEmpty && nowHasDevices && self.autoTransitionEnabled && self.phase == .welcome {
                        await self.handleRadioDetected(newDevices.first!)
                    }
                }
                try? await Task.sleep(for: .milliseconds(500))
            }
        }
    }

    /// Called when a radio is newly detected.
    private func handleRadioDetected(_ device: USBDeviceInfo) async {
        connectionState = .connecting

        // Try to identify the radio
        switch device.connectionType {
        case .network(let ip, _):
            // Use MOTOTRBO programmer to identify
            let programmer = MOTOTRBOProgrammer(host: ip)
            do {
                let identification = try await programmer.identify()
                identifiedRadio = IdentifiedRadio(
                    modelNumber: identification.modelNumber,
                    serialNumber: identification.serialNumber,
                    firmwareVersion: identification.firmwareVersion,
                    suggestedModelIdentifier: findModelIdentifier(for: identification)
                )

                // Select the identified model and transition to editing
                if let modelId = identifiedRadio?.suggestedModelIdentifier ?? findDefaultModel(for: "xpr") {
                    selectedModelIdentifier = modelId
                    // Create a new document for this model
                    let codeplug = RadioModelRegistry.createDefaultCodeplug(for: modelId)
                    currentDocument = CodeplugDocument(codeplug: codeplug, modelIdentifier: modelId)
                    documentURL = nil
                    phase = .editing
                    connectionState = .connected(ip)
                }
            } catch {
                // Identification failed, but we can still transition with a default model
                connectionState = .error("Could not identify radio: \(error.localizedDescription)")
                if let modelId = findDefaultModel(for: "xpr") {
                    selectedModelIdentifier = modelId
                    let codeplug = RadioModelRegistry.createDefaultCodeplug(for: modelId)
                    currentDocument = CodeplugDocument(codeplug: codeplug, modelIdentifier: modelId)
                    documentURL = nil
                    phase = .editing
                }
            }

        case .serial(let path):
            // Serial radios - use default model selection
            let family = guessRadioFamily(from: device)
            if let modelId = findDefaultModel(for: family) {
                selectedModelIdentifier = modelId
                let codeplug = RadioModelRegistry.createDefaultCodeplug(for: modelId)
                currentDocument = CodeplugDocument(codeplug: codeplug, modelIdentifier: modelId)
                documentURL = nil
                phase = .editing
                connectionState = .connected(path)
            }
        }
    }

    /// Finds the model identifier that matches the radio identification.
    private func findModelIdentifier(for identification: RadioIdentification) -> String? {
        // First try to match by model number
        for id in RadioModelRegistry.allIdentifiers {
            if let model = RadioModelRegistry.model(for: id) {
                // Check if model numbers match
                if model.modelNumbers.contains(identification.modelNumber) {
                    return id
                }
                // Check if identifier contains the model number
                if id.lowercased().contains(identification.modelNumber.lowercased()) {
                    return id
                }
            }
        }
        // Fall back to family-based matching
        if let family = identification.radioFamily {
            return findDefaultModel(for: family)
        }
        return nil
    }

    /// Guesses the radio family based on device info.
    private func guessRadioFamily(from device: USBDeviceInfo) -> String {
        switch device.connectionType {
        case .serial:
            // Serial devices are typically CLP, CLS, DLR, CP200
            if device.displayName.lowercased().contains("clp") { return "clp" }
            if device.displayName.lowercased().contains("cls") { return "cls" }
            if device.displayName.lowercased().contains("dlr") { return "dlr" }
            return "clp" // Default for serial

        case .network:
            // Network devices are typically XPR, APX, SL
            if device.displayName.lowercased().contains("apx") { return "apx" }
            if device.displayName.lowercased().contains("sl") { return "sl300" }
            return "xpr" // Default for network (most common)
        }
    }

    /// Finds the first registered model for a given family.
    private func findDefaultModel(for family: String) -> String? {
        let familyLower = family.lowercased()
        return RadioModelRegistry.allIdentifiers.first { id in
            id.lowercased().hasPrefix(familyLower) ||
            RadioModelRegistry.model(for: id)?.family.rawValue.lowercased() == familyLower
        }
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
    /// Shows confirmation dialog if there are unsaved changes.
    func closeDocument() {
        if hasUnsavedChanges {
            pendingCloseAction = { [weak self] in
                self?.forceCloseDocument()
            }
            showingCloseConfirmation = true
        } else {
            forceCloseDocument()
        }
    }

    /// Closes without checking for unsaved changes.
    func forceCloseDocument() {
        currentDocument = nil
        documentURL = nil
        phase = .welcome
    }

    /// Save current document then close.
    func saveAndCloseDocument() {
        if let url = documentURL {
            try? saveDocument(to: url)
            forceCloseDocument()
        } else {
            showingSaveDialog = true
            pendingCloseAction = { [weak self] in
                self?.forceCloseDocument()
            }
        }
    }

    /// Whether the current document has unsaved changes.
    var hasUnsavedChanges: Bool {
        currentDocument?.codeplug?.hasUnsavedChanges ?? false
    }

    // MARK: - Radio Communication

    /// Current read/write progress (0.0 to 1.0).
    var programmingProgress: Double = 0.0

    /// Reads the codeplug from the connected radio.
    /// Uses `selectedModelIdentifier` if set, otherwise falls back to current document's model.
    func readFromRadio() async {
        // Use selected model, or fall back to current document's model
        let modelIdentifier: String
        if let selected = selectedModelIdentifier {
            modelIdentifier = selected
        } else if let current = currentDocument?.modelIdentifier {
            modelIdentifier = current
        } else {
            connectionState = .error("Please select your radio model first")
            return
        }

        guard let model = RadioModelRegistry.model(for: modelIdentifier) else {
            connectionState = .error("Unknown model: \(modelIdentifier)")
            return
        }

        guard let device = detectedDevices.first else {
            connectionState = .error("No radio detected")
            return
        }

        connectionState = .connecting
        programmingProgress = 0.0

        do {
            // Create connection based on type
            let connection: any USBConnection
            let connectionLabel: String

            switch device.connectionType {
            case .serial(let path):
                let serial = SerialConnection(portPath: path)
                try await serial.connect()
                connection = serial
                connectionLabel = path
            case .network(let ip, _):
                // XPR/MOTOTRBO radios use XNL protocol with TEA authentication
                let xnlConnection = XNLConnection(host: ip)
                let result = await xnlConnection.connect()

                switch result {
                case .success(let assignedAddress):
                    connectionState = .connected("XNL:\(ip) (addr: 0x\(String(format: "%04X", assignedAddress)))")
                    // TODO: Implement XCMP codeplug read commands
                    connectionState = .error("XNL authenticated successfully! XCMP codeplug read not yet implemented.")
                    await xnlConnection.disconnect()
                    return

                case .authenticationFailed(let code):
                    connectionState = .error("XNL authentication failed (code: 0x\(String(format: "%02X", code)))")
                    return

                case .connectionError(let message):
                    connectionState = .error("XNL connection error: \(message)")
                    return

                case .timeout:
                    connectionState = .error("XNL connection timeout - radio may be in wrong mode")
                    return
                }
            }

            connectionState = .connected(connectionLabel)

            // Create programmer and read codeplug (for serial radios)
            let programmer = RadioProgrammer(connection: connection)

            connectionState = .programming

            let codeplugData = try await programmer.readCodeplug(size: model.codeplugSize) { [weak self] progress in
                Task { @MainActor in
                    self?.programmingProgress = progress
                }
            }

            // Disconnect
            await connection.disconnect()

            // Create codeplug from data
            let codeplug = Codeplug(modelIdentifier: modelIdentifier, rawData: codeplugData)

            // Update UI
            currentDocument = CodeplugDocument(codeplug: codeplug, modelIdentifier: modelIdentifier)
            documentURL = nil
            phase = .editing
            connectionState = .disconnected
            programmingProgress = 0.0

        } catch {
            connectionState = .error(error.localizedDescription)
            programmingProgress = 0.0
        }
    }

    /// Writes the current codeplug to the connected radio.
    func writeToRadio() async {
        guard let codeplug = currentDocument?.codeplug else {
            connectionState = .error("No codeplug to write")
            return
        }

        guard let device = detectedDevices.first else {
            connectionState = .error("No radio detected")
            return
        }

        connectionState = .connecting
        programmingProgress = 0.0

        do {
            // Create connection based on type
            let connection: any USBConnection
            let connectionLabel: String

            switch device.connectionType {
            case .serial(let path):
                let serial = SerialConnection(portPath: path)
                try await serial.connect()
                connection = serial
                connectionLabel = path
            case .network(let ip, _):
                // XPR/MOTOTRBO radios use XNL protocol with TEA authentication
                let xnlConnection = XNLConnection(host: ip)
                let result = await xnlConnection.connect()

                switch result {
                case .success(let assignedAddress):
                    connectionState = .connected("XNL:\(ip) (addr: 0x\(String(format: "%04X", assignedAddress)))")
                    // TODO: Implement XCMP codeplug write commands
                    connectionState = .error("XNL authenticated successfully! XCMP codeplug write not yet implemented.")
                    await xnlConnection.disconnect()
                    return

                case .authenticationFailed(let code):
                    connectionState = .error("XNL authentication failed (code: 0x\(String(format: "%02X", code)))")
                    return

                case .connectionError(let message):
                    connectionState = .error("XNL connection error: \(message)")
                    return

                case .timeout:
                    connectionState = .error("XNL connection timeout - radio may be in wrong mode")
                    return
                }
            }

            connectionState = .connected(connectionLabel)

            let programmer = RadioProgrammer(connection: connection)

            connectionState = .programming

            try await programmer.writeCodeplug(codeplug.rawData) { [weak self] progress in
                Task { @MainActor in
                    self?.programmingProgress = progress
                }
            }

            await connection.disconnect()
            connectionState = .disconnected
            programmingProgress = 0.0

        } catch {
            connectionState = .error(error.localizedDescription)
            programmingProgress = 0.0
        }
    }
}

/// Information about an identified radio.
struct IdentifiedRadio: Equatable {
    let modelNumber: String
    let serialNumber: String?
    let firmwareVersion: String?
    let suggestedModelIdentifier: String?
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
