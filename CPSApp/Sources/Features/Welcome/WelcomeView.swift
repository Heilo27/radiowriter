import SwiftUI
import RadioModelCore
import Network

/// Welcome screen shown at app launch.
struct WelcomeView: View {
    @Environment(AppCoordinator.self) private var coordinator
    @State private var selectedModel: String?
    @State private var showModelPickerForRead = false

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            content
        }
        .onAppear {
            // Sync local selection with coordinator's selected model
            if let modelId = coordinator.selectedModelIdentifier {
                selectedModel = modelId
            }
        }
        .onChange(of: coordinator.selectedModelIdentifier) { _, newValue in
            // Keep local selection in sync when coordinator changes it (e.g., auto-detection)
            if let newValue, selectedModel != newValue {
                selectedModel = newValue
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: 8) {
            Image(systemName: "antenna.radiowaves.left.and.right")
                .font(.system(size: 48))
                .foregroundStyle(.tint)
            Text("RadioWriter")
                .font(.title.bold())
            Text("Radio Programming Software")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 24)
    }

    // MARK: - Content

    private var content: some View {
        HStack(spacing: 0) {
            // Left: Actions
            VStack(alignment: .leading, spacing: 16) {
                Text("Get Started")
                    .font(.headline)

                Button {
                    // Scroll to model picker on the right
                } label: {
                    Label("New Profile", systemImage: "doc.badge.plus")
                }
                .buttonStyle(.link)
                .accessibilityIdentifier("welcome.newProfile")

                Button {
                    coordinator.showingOpenDialog = true
                } label: {
                    Label("Open Existing", systemImage: "folder")
                }
                .buttonStyle(.link)
                .accessibilityIdentifier("welcome.openExisting")

                // Show detected radio section
                if !coordinator.detectedDevices.isEmpty {
                    Divider()

                    // Identified radio info
                    if let identified = coordinator.identifiedRadio {
                        detectedRadioInfo(identified)
                    } else {
                        Text("Radio Detected")
                            .font(.headline)

                        ForEach(coordinator.detectedDevices) { device in
                            Label(device.displayName, systemImage: "cable.connector")
                                .foregroundStyle(.secondary)
                        }
                    }

                    // Read from Radio button
                    Button {
                        Task {
                            await coordinator.readFromRadio()
                        }
                    } label: {
                        Label("Read from Radio", systemImage: "arrow.down.to.line")
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(selectedModel == nil)
                    .accessibilityIdentifier("welcome.readRadio")
                    .padding(.top, 8)

                    if selectedModel == nil {
                        Text("Select a radio model to continue")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    // No radio detected - show help
                    Divider()

                    noRadioDetectedSection
                }

                Spacer()
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)

            Divider()

            // Right: Radio Model Picker
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Choose Radio Model")
                        .font(.headline)

                    if coordinator.identifiedRadio != nil {
                        Text("(Auto-selected)")
                            .font(.caption)
                            .foregroundStyle(.green)
                    }
                }

                ScrollView {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 120))], spacing: 12) {
                        ForEach(coordinator.availableModels) { model in
                            RadioModelCard(
                                model: model,
                                isSelected: selectedModel == model.id,
                                isRecommended: model.id == coordinator.identifiedRadio?.suggestedModelIdentifier
                            )
                            .contentShape(Rectangle())
                            .onTapGesture {
                                withAnimation(.easeInOut(duration: 0.15)) {
                                    selectedModel = model.id
                                    coordinator.selectedModelIdentifier = model.id
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 4)
                }

                Spacer()

                HStack {
                    Spacer()
                    Button("Create Profile") {
                        if let modelID = selectedModel {
                            coordinator.newDocument(modelIdentifier: modelID)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(selectedModel == nil)
                    .accessibilityIdentifier("welcome.createProfile")
                }
            }
            .padding()
            .frame(maxWidth: .infinity)
        }
    }

    // MARK: - Detected Radio Info

    @ViewBuilder
    private func detectedRadioInfo(_ radio: IdentifiedRadio) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                Text("Radio Detected")
                    .font(.headline)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Model:")
                        .foregroundStyle(.secondary)
                    Text(radio.modelNumber)
                        .fontWeight(.medium)
                }
                .font(.caption)

                if let serial = radio.serialNumber {
                    HStack {
                        Text("Serial:")
                            .foregroundStyle(.secondary)
                        Text(serial)
                    }
                    .font(.caption)
                }

                if let firmware = radio.firmwareVersion {
                    HStack {
                        Text("Firmware:")
                            .foregroundStyle(.secondary)
                        Text(firmware)
                    }
                    .font(.caption)
                }
            }
            .padding(.leading, 24)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Radio detected: \(radio.modelNumber), serial \(radio.serialNumber ?? "unknown")")
    }

    // MARK: - No Radio Detected

    @State private var showingScanLog = false
    @State private var showingManualIP = false
    @State private var manualIPAddress = "192.168.10.1"

    private var noRadioDetectedSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "antenna.radiowaves.left.and.right.slash")
                    .foregroundStyle(.secondary)
                Text("No Radio Detected")
                    .font(.headline)
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("To connect your radio:")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                VStack(alignment: .leading, spacing: 2) {
                    Label("Power on the radio (not just charging)", systemImage: "power")
                    Label("Connect USB data cable", systemImage: "cable.connector")
                    Label("Wait 5-10 seconds for network to initialize", systemImage: "clock")
                }
                .font(.caption)
                .foregroundStyle(.tertiary)
                .padding(.leading, 8)

                Text("The radio uses CDC-ECM which macOS supports natively.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .padding(.top, 2)
            }

            HStack(spacing: 12) {
                // Show scan diagnostics button
                Button {
                    showingScanLog = true
                } label: {
                    Label("Show Scan Log", systemImage: "doc.text.magnifyingglass")
                }
                .buttonStyle(.link)
                .font(.caption)

                // Manual IP entry button
                Button {
                    showingManualIP = true
                } label: {
                    Label("Enter IP Manually", systemImage: "keyboard")
                }
                .buttonStyle(.link)
                .font(.caption)
            }
            .padding(.top, 4)
        }
        .sheet(isPresented: $showingScanLog) {
            ScanLogSheet(log: coordinator.radioDetector.lastScanLog)
        }
        .sheet(isPresented: $showingManualIP) {
            ManualIPSheet(ipAddress: $manualIPAddress) { ip in
                // Add manual device
                coordinator.addManualDevice(ip: ip)
                showingManualIP = false
            }
        }
    }
}

/// Sheet for manually entering radio IP address.
struct ManualIPSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var ipAddress: String
    let onConnect: (String) -> Void
    @State private var isChecking = false
    @State private var checkResult: String?

    var body: some View {
        VStack(spacing: 16) {
            Text("Manual Radio Connection")
                .font(.headline)

            Text("Enter the radio's IP address. Most MOTOTRBO radios use 192.168.10.1 (your Mac will be .2)")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            TextField("IP Address", text: $ipAddress)
                .textFieldStyle(.roundedBorder)
                .frame(width: 200)

            if let result = checkResult {
                Text(result)
                    .font(.caption)
                    .foregroundStyle(result.contains("Success") ? .green : .orange)
            }

            HStack(spacing: 16) {
                Button("Cancel") {
                    dismiss()
                }

                Button {
                    isChecking = true
                    checkResult = nil
                    Task {
                        // Try to connect to verify
                        let success = await checkXNLPort(ip: ipAddress)
                        isChecking = false
                        if success {
                            checkResult = "Success! Radio found at \(ipAddress)"
                            try? await Task.sleep(for: .seconds(1))
                            onConnect(ipAddress)
                        } else {
                            checkResult = "Could not reach radio at \(ipAddress). Adding anyway..."
                            try? await Task.sleep(for: .seconds(1))
                            onConnect(ipAddress)
                        }
                    }
                } label: {
                    if isChecking {
                        ProgressView()
                            .scaleEffect(0.7)
                    } else {
                        Text("Connect")
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(ipAddress.isEmpty || isChecking)
            }
        }
        .padding(24)
        .frame(width: 350)
    }

    private func checkXNLPort(ip: String) async -> Bool {
        // Quick check if XNL port is open
        return await withCheckedContinuation { continuation in
            let host = NWEndpoint.Host(ip)
            guard let port = NWEndpoint.Port(rawValue: 8002) else {
                continuation.resume(returning: false)
                return
            }

            let connection = NWConnection(host: host, port: port, using: .tcp)
            let queue = DispatchQueue(label: "com.radiowriter.manualcheck")

            // Use a Sendable class to hold mutable state safely
            final class ConnectionState: @unchecked Sendable {
                var hasResumed = false
                var timeout: DispatchWorkItem?
                let lock = NSLock()
            }
            let state = ConnectionState()

            let safeResume: @Sendable (Bool) -> Void = { value in
                state.lock.lock()
                defer { state.lock.unlock() }
                guard !state.hasResumed else { return }
                state.hasResumed = true
                state.timeout?.cancel()
                connection.cancel()
                continuation.resume(returning: value)
            }

            let timeout = DispatchWorkItem {
                safeResume(false)
            }
            state.timeout = timeout
            queue.asyncAfter(deadline: .now() + 2.0, execute: timeout)

            connection.stateUpdateHandler = { connectionState in
                switch connectionState {
                case .ready:
                    safeResume(true)
                case .failed, .cancelled:
                    safeResume(false)
                default:
                    break
                }
            }

            connection.start(queue: queue)
        }
    }
}

/// Sheet showing the radio scan diagnostic log.
struct ScanLogSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppCoordinator.self) private var coordinator
    @State private var log: String
    @State private var isScanning = false

    init(log: String) {
        _log = State(initialValue: log)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Radio Scan Log")
                    .font(.headline)
                Spacer()

                Button {
                    Task {
                        isScanning = true
                        await coordinator.radioDetector.scanForDevices()
                        log = coordinator.radioDetector.lastScanLog
                        isScanning = false
                    }
                } label: {
                    if isScanning {
                        ProgressView()
                            .scaleEffect(0.7)
                    } else {
                        Label("Scan Again", systemImage: "arrow.clockwise")
                    }
                }
                .disabled(isScanning)

                Button("Done") {
                    dismiss()
                }
            }
            .padding()

            Divider()

            ScrollView {
                Text(log.isEmpty ? "No scan data available. Click 'Scan Again' to start." : log)
                    .font(.system(.caption, design: .monospaced))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .textSelection(.enabled)
            }
        }
        .frame(width: 600, height: 500)
    }
}

/// A card displaying a radio model in the picker grid.
struct RadioModelCard: View {
    let model: RadioModelInfo
    let isSelected: Bool
    var isRecommended: Bool = false

    var body: some View {
        VStack(spacing: 6) {
            ZStack(alignment: .topTrailing) {
                Image(systemName: "radio")
                    .font(.title2)
                    .frame(height: 32)

                if isRecommended {
                    Image(systemName: "star.fill")
                        .font(.caption2)
                        .foregroundStyle(.yellow)
                        .offset(x: 8, y: -4)
                }
            }

            Text(model.displayName)
                .font(.caption.bold())
                .lineLimit(1)

            Text("\(model.maxChannels) CH • \(model.frequencyBand.name)")
                .font(.caption2)
                .foregroundStyle(.secondary)

            capabilityBadges
        }
        .frame(width: 120, height: 118)
        .background(isSelected ? Color.accentColor.opacity(0.1) : (isRecommended ? Color.yellow.opacity(0.05) : Color.clear))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(
                    isSelected ? Color.accentColor : (isRecommended ? Color.yellow.opacity(0.5) : Color.secondary.opacity(0.3)),
                    lineWidth: isSelected ? 2 : 1
                )
        )
        .accessibilityIdentifier("radioModel.\(model.id)")
        .accessibilityLabel(
            "\(model.displayName), \(model.maxChannels) channels, \(model.frequencyBand.name)" +
            (isRecommended ? ", recommended for detected radio" : "")
        )
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    @ViewBuilder
    private var capabilityBadges: some View {
        let badges = capabilityLabels
        if !badges.isEmpty {
            VStack(spacing: 2) {
                ForEach(badges, id: \.self) { badge in
                    Text(badge)
                        .font(.system(size: 9, weight: .semibold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.secondary.opacity(0.15))
                        .clipShape(Capsule())
                }
            }
        }
    }

    private var capabilityLabels: [String] {
        var labels: [String] = []
        if model.capabilities.canRead {
            labels.append("READ")
        }
        if model.capabilities.canWrite {
            labels.append("WRITE")
        }
        if model.capabilities.canVerifyWrite {
            labels.append("VERIFY")
        }
        if model.capabilities.isExperimental {
            labels.append("EXPERIMENTAL")
        }
        return labels
    }
}
