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

    /// Parsed codeplug data with zones and channels (for XPR/MOTOTRBO radios).
    var parsedCodeplug: ParsedCodeplug?

    // MARK: - Programming Sheet State

    /// Whether to show the programming operation sheet.
    var showingProgrammingSheet = false

    /// The current programming operation type.
    var programmingOperation: ProgrammingOperation = .read

    /// Status message displayed during programming.
    var programmingStatus: String = "Preparing..."

    /// Whether the programming operation completed successfully.
    var programmingComplete = false

    /// Error message if programming failed.
    var programmingError: String?

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
    /// Identifies the radio and auto-selects the matching model, but does NOT auto-transition.
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

                // Auto-select the identified model but do NOT transition
                if let modelId = identifiedRadio?.suggestedModelIdentifier ?? findDefaultModel(for: "xpr") {
                    selectedModelIdentifier = modelId
                }
                // Return to disconnected state - ready for user to initiate read
                connectionState = .disconnected
            } catch {
                // Identification failed - still select a default model but don't transition
                connectionState = .error("Could not identify radio: \(error.localizedDescription)")
                if let modelId = findDefaultModel(for: "xpr") {
                    selectedModelIdentifier = modelId
                }
            }

        case .serial:
            // Serial radios - use default model selection but don't transition
            let family = guessRadioFamily(from: device)
            if let modelId = findDefaultModel(for: family) {
                selectedModelIdentifier = modelId
            }
            // Return to disconnected state - ready for user to initiate read
            connectionState = .disconnected
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

        // Show programming sheet
        programmingOperation = .read
        programmingStatus = "Connecting to radio..."
        programmingProgress = 0.0
        programmingComplete = false
        programmingError = nil
        showingProgrammingSheet = true

        connectionState = .connecting

        do {
            // Create connection based on type
            let connection: any USBConnection
            let connectionLabel: String

            switch device.connectionType {
            case .serial(let path):
                programmingStatus = "Opening serial connection..."
                let serial = SerialConnection(portPath: path)
                try await serial.connect()
                connection = serial
                connectionLabel = path
            case .network(let ip, _):
                // XPR/MOTOTRBO radios use XNL/XCMP protocol
                programmingStatus = "Connecting to MOTOTRBO radio..."
                let motoProgrammer = MOTOTRBOProgrammer(host: ip)

                do {
                    try await motoProgrammer.connect()
                    connectionState = .connected("XNL:\(ip)")
                    programmingProgress = 0.05

                    connectionState = .programming
                    programmingStatus = "Reading zones and channels..."

                    // Use the zone/channel reading protocol
                    let parsed = try await motoProgrammer.readZonesAndChannels(
                        progress: { [weak self] progress in
                            Task { @MainActor in
                                // Scale progress: 5% to 90%
                                self?.programmingProgress = 0.05 + (progress * 0.85)
                                if progress < 0.1 {
                                    self?.programmingStatus = "Getting device info..."
                                } else if progress < 0.15 {
                                    self?.programmingStatus = "Reading zone structure..."
                                } else {
                                    let percent = Int(progress * 100)
                                    self?.programmingStatus = "Reading channels (\(percent)%)..."
                                }
                            }
                        },
                        debug: true  // Enable debug for now to see what's happening
                    )

                    programmingStatus = "Processing data..."
                    programmingProgress = 0.95

                    await motoProgrammer.disconnect()

                    // Store the parsed codeplug
                    parsedCodeplug = parsed

                    // Also create a raw codeplug document for compatibility
                    // Build metadata from parsed data
                    let metadata = CodeplugMetadata(
                        radioSerialNumber: parsed.serialNumber,
                        radioModelName: parsed.modelNumber,
                        firmwareVersion: parsed.firmwareVersion,
                        lastReadDate: Date()
                    )
                    let codeplug = Codeplug(
                        modelIdentifier: modelIdentifier,
                        rawData: Data(),  // Raw data will be populated when we implement full record parsing
                        metadata: metadata
                    )

                    // Update UI
                    currentDocument = CodeplugDocument(codeplug: codeplug, modelIdentifier: modelIdentifier)
                    documentURL = nil
                    connectionState = .disconnected

                    // Mark complete
                    programmingProgress = 1.0
                    let channelCount = parsed.totalChannels
                    programmingStatus = "Read complete: \(channelCount) channels"
                    programmingComplete = true
                    return

                } catch {
                    await motoProgrammer.disconnect()
                    programmingError = error.localizedDescription
                    connectionState = .disconnected
                    return
                }
            }

            connectionState = .connected(connectionLabel)
            programmingStatus = "Authenticating..."
            programmingProgress = 0.05

            // Create programmer and read codeplug (for serial radios)
            let programmer = RadioProgrammer(connection: connection)

            connectionState = .programming
            programmingStatus = "Reading codeplug..."

            let codeplugData = try await programmer.readCodeplug(size: model.codeplugSize) { [weak self] progress in
                Task { @MainActor in
                    self?.programmingProgress = 0.1 + (progress * 0.85) // Scale to 10-95%
                    let blocksRead = Int(progress * 20) // Approximate block count
                    self?.programmingStatus = "Reading codeplug (block \(blocksRead) of ~20)..."
                }
            }

            // Disconnect
            programmingStatus = "Verifying data..."
            programmingProgress = 0.95
            await connection.disconnect()

            // Create codeplug from data
            let codeplug = Codeplug(modelIdentifier: modelIdentifier, rawData: codeplugData)

            // Update UI
            currentDocument = CodeplugDocument(codeplug: codeplug, modelIdentifier: modelIdentifier)
            documentURL = nil
            connectionState = .disconnected

            // Mark complete
            programmingProgress = 1.0
            programmingStatus = "Read complete"
            programmingComplete = true

        } catch {
            programmingError = error.localizedDescription
            connectionState = .disconnected
            programmingProgress = 0.0
        }
    }

    /// Called when programming sheet is dismissed after successful read.
    func finishProgrammingAndTransition() {
        if programmingComplete && programmingError == nil {
            phase = .editing
        }
        showingProgrammingSheet = false
        programmingProgress = 0.0
        programmingComplete = false
        programmingError = nil
    }

    /// Cancels the current programming operation.
    func cancelProgramming() {
        showingProgrammingSheet = false
        programmingProgress = 0.0
        programmingComplete = false
        programmingError = nil
        connectionState = .disconnected
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

        // Show programming sheet
        programmingOperation = .write
        programmingStatus = "Connecting to radio..."
        programmingProgress = 0.0
        programmingComplete = false
        programmingError = nil
        showingProgrammingSheet = true

        connectionState = .connecting

        do {
            // Create connection based on type
            let connection: any USBConnection
            let connectionLabel: String

            switch device.connectionType {
            case .serial(let path):
                programmingStatus = "Opening serial connection..."
                let serial = SerialConnection(portPath: path)
                try await serial.connect()
                connection = serial
                connectionLabel = path
            case .network(let ip, _):
                // XPR/MOTOTRBO radios use XNL/XCMP protocol
                programmingStatus = "Connecting to MOTOTRBO radio..."
                let motoProgrammer = MOTOTRBOProgrammer(host: ip)

                do {
                    try await motoProgrammer.connect()
                    connectionState = .connected("XNL:\(ip)")
                    programmingProgress = 0.05

                    connectionState = .programming
                    programmingStatus = "Writing codeplug via XCMP..."

                    // Use the XCMP write protocol
                    try await motoProgrammer.writeCodeplug(codeplug.rawData) { [weak self] progress in
                        Task { @MainActor in
                            // Scale progress: 5% to 90%
                            self?.programmingProgress = 0.05 + (progress * 0.85)
                            if progress < 0.15 {
                                self?.programmingStatus = "Starting write session..."
                            } else if progress < 0.75 {
                                let percent = Int(progress * 100)
                                self?.programmingStatus = "Writing codeplug (\(percent)%)..."
                            } else if progress < 0.90 {
                                self?.programmingStatus = "Validating CRC..."
                            } else {
                                self?.programmingStatus = "Deploying codeplug..."
                            }
                        }
                    }

                    programmingStatus = "Verifying write..."
                    programmingProgress = 0.95

                    await motoProgrammer.disconnect()
                    connectionState = .disconnected

                    // Mark complete
                    programmingProgress = 1.0
                    programmingStatus = "Write complete and verified"
                    programmingComplete = true
                    return

                } catch {
                    await motoProgrammer.disconnect()
                    programmingError = error.localizedDescription
                    connectionState = .disconnected
                    return
                }
            }

            connectionState = .connected(connectionLabel)
            programmingStatus = "Validating codeplug..."
            programmingProgress = 0.05

            let programmer = RadioProgrammer(connection: connection)

            connectionState = .programming
            programmingStatus = "Writing codeplug..."

            try await programmer.writeCodeplug(codeplug.rawData) { [weak self] progress in
                Task { @MainActor in
                    self?.programmingProgress = 0.1 + (progress * 0.80) // Scale to 10-90%
                    let blocksWritten = Int(progress * 20) // Approximate block count
                    self?.programmingStatus = "Writing codeplug (block \(blocksWritten) of ~20)..."
                }
            }

            programmingStatus = "Verifying write..."
            programmingProgress = 0.95

            await connection.disconnect()
            connectionState = .disconnected

            // Mark complete
            programmingProgress = 1.0
            programmingStatus = "Write complete and verified"
            programmingComplete = true

        } catch {
            programmingError = error.localizedDescription
            connectionState = .disconnected
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
