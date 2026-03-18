import SwiftUI
import RadioCore
import RadioModelCore

/// Main document view with three-column layout.
struct ContentView: View {
    @Environment(AppCoordinator.self) private var coordinator
    @State private var selectedCategory: FieldCategory? = .general
    @State private var selectedNodeID: String?
    @State private var showInspector = true
    @State private var searchText = ""

    private var document: CodeplugDocument? { coordinator.currentDocument }

    /// Window title with edited indicator.
    private var windowTitle: String {
        let baseTitle = document?.modelIdentifier ?? "RadioWriter"
        if coordinator.hasUnsavedChanges {
            return "\(baseTitle) — Edited"
        }
        return baseTitle
    }

    var body: some View {
        NavigationSplitView {
            sidebar
        } detail: {
            contentArea
        }
        .inspector(isPresented: $showInspector) {
            inspectorPanel
        }
        .navigationTitle(windowTitle)
        .toolbar { toolbarContent }
    }

    // MARK: - Sidebar

    private var sidebar: some View {
        List(selection: $selectedCategory) {
            if let codeplug = document?.codeplug,
               let model = RadioModelRegistry.model(for: codeplug.modelIdentifier) {
                ForEach(model.nodes, id: \.id) { node in
                    Label(node.displayName, systemImage: iconForCategory(node.category))
                        .tag(node.category)
                        .accessibilityIdentifier("sidebar.\(node.category.rawValue)")
                }
            } else {
                ForEach(FieldCategory.allCases, id: \.self) { category in
                    Label(category.rawValue, systemImage: iconForCategory(category))
                        .tag(category)
                        .accessibilityIdentifier("sidebar.\(category.rawValue)")
                }
            }
        }
        .listStyle(.sidebar)
        .navigationSplitViewColumnWidth(min: 160, ideal: 180, max: 220)
        .accessibilityIdentifier("categorySidebar")
        .accessibilityLabel("Category sidebar")
    }

    // MARK: - Content Area

    @ViewBuilder
    private var contentArea: some View {
        // Priority 1: Show parsed codeplug from radio (zones/channels view)
        if coordinator.parsedCodeplug != nil {
            switch selectedCategory {
            case .channel:
                ZoneChannelView(searchText: searchText)
            case .contacts:
                ContactsView(searchText: searchText)
            case .scan:
                ScanListsView()
            case .signaling:
                RxGroupListsView()  // RX Group Lists are signaling-related
            case .general:
                GeneralSettingsView()
            case .some(let category):
                // For other categories, show placeholder or form editor
                if let codeplug = document?.codeplug, let doc = document {
                    FormEditorView(codeplug: codeplug, category: category, modelIdentifier: doc.modelIdentifier)
                } else {
                    ParsedCodeplugCategoryView(category: category)
                }
            case .none:
                ContentUnavailableView(
                    "Select a Category",
                    systemImage: "radio",
                    description: Text("Choose a category from the sidebar to view settings.")
                )
            }
        }
        // Priority 2: Show traditional document-based editing
        else if let codeplug = document?.codeplug, let doc = document {
            if selectedCategory == .channel {
                ChannelEditorView(codeplug: codeplug, modelIdentifier: doc.modelIdentifier)
            } else if let category = selectedCategory {
                FormEditorView(codeplug: codeplug, category: category, modelIdentifier: doc.modelIdentifier)
            } else {
                ContentUnavailableView(
                    "Select a Category",
                    systemImage: "radio",
                    description: Text("Choose a category from the sidebar to edit settings.")
                )
            }
        } else {
            ContentUnavailableView(
                "No Profile Loaded",
                systemImage: "doc.badge.plus",
                description: Text("Create a new profile or read from a connected radio.")
            )
        }
    }

    // MARK: - Inspector

    private var inspectorPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Inspector")
                .font(.headline)
                .padding(.horizontal)

            Divider()

            if let category = selectedCategory {
                VStack(alignment: .leading, spacing: 8) {
                    Label("Category", systemImage: iconForCategory(category))
                        .font(.subheadline.bold())

                    Text(helpTextForCategory(category))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal)
            }

            Spacer()
        }
        .padding(.top)
        .navigationSplitViewColumnWidth(min: 150, ideal: 180, max: 220)
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .navigation) {
            RadioStatusIndicator(
                state: coordinator.connectionState,
                hasDetectedRadio: !coordinator.detectedDevices.isEmpty,
                progress: coordinator.programmingProgress
            )
        }

        ToolbarItemGroup(placement: .primaryAction) {
            Button("Read", systemImage: "antenna.radiowaves.left.and.right") {
                Task {
                    await coordinator.readFromRadio()
                }
            }
            .disabled(!coordinator.connectionState.isDisconnected || coordinator.detectedDevices.isEmpty)
            .keyboardShortcut("r", modifiers: [.command])
            .accessibilityIdentifier("toolbar.read")
            .accessibilityLabel("Read from radio")
            .help("Read codeplug from connected radio (Cmd+R)")

            Button("Write", systemImage: "arrow.up.to.line") {
                coordinator.writeToRadioWithBackupPrompt()
            }
            .disabled(document?.codeplug == nil || coordinator.detectedDevices.isEmpty)
            .keyboardShortcut("w", modifiers: [.command, .shift])
            .accessibilityIdentifier("toolbar.write")
            .accessibilityLabel("Write to radio")
            .help("Write codeplug to connected radio (Cmd+Shift+W)")

            Menu {
                Button("Clone Codeplug for Fleet") {
                    coordinator.cloneCodeplug()
                }
                .disabled(coordinator.parsedCodeplug == nil)
            } label: {
                Label("Clone", systemImage: "doc.on.doc")
            }
            .menuStyle(.borderlessButton)
            .help("Clone codeplug for programming multiple radios")
            .accessibilityIdentifier("toolbar.clone")
        }

        ToolbarItem(placement: .automatic) {
            Toggle(isOn: $showInspector) {
                Label("Inspector", systemImage: "sidebar.trailing")
            }
            .accessibilityLabel("Toggle inspector panel")
            .help("Show or hide the inspector panel")
        }
    }

    // MARK: - Helpers

    private func iconForCategory(_ category: FieldCategory) -> String {
        switch category {
        case .general: return "gearshape"
        case .channel: return "antenna.radiowaves.left.and.right"
        case .audio: return "speaker.wave.2"
        case .signaling: return "waveform"
        case .scan: return "magnifyingglass"
        case .contacts: return "person.2"
        case .bluetooth: return "headphones"
        case .voicePrompts: return "mic"
        case .advanced: return "wrench.and.screwdriver"
        }
    }

    private func helpTextForCategory(_ category: FieldCategory) -> String {
        switch category {
        case .general: return "Basic radio identification and power settings."
        case .channel: return "Configure receive and transmit frequencies for each channel."
        case .audio: return "Volume, VOX, and tone settings."
        case .signaling: return "CTCSS and DPL tone squelch codes."
        case .scan: return "Automatic channel scanning behavior."
        case .contacts: return "Subscriber contacts and call groups."
        case .bluetooth: return "Bluetooth audio accessory settings."
        case .voicePrompts: return "Custom voice announcements."
        case .advanced: return "Advanced radio parameters."
        }
    }
}

/// Radio connection status indicator for the toolbar.
/// Uses both color AND icons for accessibility (not color-only).
struct RadioStatusIndicator: View {
    let state: ConnectionState
    let hasDetectedRadio: Bool
    var progress: Double = 0.0

    var body: some View {
        HStack(spacing: 6) {
            if case .programming = state {
                ProgressView(value: progress)
                    .progressViewStyle(.linear)
                    .frame(width: 80)
                    .accessibilityLabel("Programming progress: \(Int(progress * 100)) percent")
            } else {
                Image(systemName: icon)
                    .foregroundStyle(color)
                    .font(.caption)
                    .accessibilityHidden(true)
            }
            Text(statusLabel)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
    }

    private var statusLabel: String {
        if case .disconnected = state, hasDetectedRadio {
            return "Radio Detected"
        }
        return state.statusLabel
    }

    private var icon: String {
        switch state {
        case .disconnected:
            return hasDetectedRadio ? "antenna.radiowaves.left.and.right" : "antenna.radiowaves.left.and.right.slash"
        case .connecting: return "antenna.radiowaves.left.and.right"
        case .connected: return "checkmark.circle.fill"
        case .programming: return "arrow.triangle.2.circlepath"
        case .error: return "exclamationmark.triangle.fill"
        }
    }

    private var color: Color {
        switch state {
        case .disconnected:
            return hasDetectedRadio ? .green : .gray
        case .connecting: return .yellow
        case .connected: return .green
        case .programming: return .blue
        case .error: return .red
        }
    }

    private var accessibilityLabel: String {
        switch state {
        case .disconnected:
            return hasDetectedRadio ? "Radio detected, not connected" : "No radio detected"
        case .connecting: return "Connecting to radio"
        case .connected(let port): return "Radio connected on \(port)"
        case .programming: return "Programming radio in progress"
        case .error(let msg): return "Radio error: \(msg)"
        }
    }
}

// MARK: - Parsed Codeplug Category View

/// Placeholder view for non-channel categories when viewing a parsed codeplug.
struct ParsedCodeplugCategoryView: View {
    @Environment(AppCoordinator.self) private var coordinator
    let category: FieldCategory

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                switch category {
                case .general:
                    generalSettingsView
                case .contacts:
                    contactsPlaceholder
                case .scan:
                    scanListsPlaceholder
                default:
                    categoryPlaceholder
                }
            }
            .padding()
        }
    }

    @ViewBuilder
    private var generalSettingsView: some View {
        if let codeplug = coordinator.parsedCodeplug {
            // Device Information (read-only)
            GroupBox("Device Information") {
                LabeledContent("Model", value: codeplug.modelNumber.isEmpty ? "Unknown" : codeplug.modelNumber)
                LabeledContent("Serial Number", value: codeplug.serialNumber.isEmpty ? "Unknown" : codeplug.serialNumber)
                LabeledContent("Firmware", value: codeplug.firmwareVersion.isEmpty ? "Unknown" : codeplug.firmwareVersion)
                LabeledContent("Codeplug Version", value: codeplug.codeplugVersion.isEmpty ? "Unknown" : codeplug.codeplugVersion)
            }

            // Identity Settings
            GroupBox("Radio Identity") {
                LabeledContent("Radio ID", value: "\(codeplug.radioID)")
                LabeledContent("Radio Alias", value: codeplug.radioAlias.isEmpty ? "(None)" : codeplug.radioAlias)
                if !codeplug.introScreenLine1.isEmpty || !codeplug.introScreenLine2.isEmpty {
                    LabeledContent("Intro Line 1", value: codeplug.introScreenLine1.isEmpty ? "(None)" : codeplug.introScreenLine1)
                    LabeledContent("Intro Line 2", value: codeplug.introScreenLine2.isEmpty ? "(None)" : codeplug.introScreenLine2)
                }
            }

            // Audio Settings
            GroupBox("Audio Settings") {
                LabeledContent("VOX", value: codeplug.voxEnabled ? "Enabled" : "Disabled")
                    .help("VOX (Voice Operated Exchange) keys the transmitter automatically when it detects your voice")
                if codeplug.voxEnabled {
                    LabeledContent("VOX Sensitivity", value: "\(codeplug.voxSensitivity)")
                    LabeledContent("VOX Delay", value: "\(codeplug.voxDelay) ms")
                }
                LabeledContent("Keypad Tones", value: codeplug.keypadTones ? "Enabled" : "Disabled")
                LabeledContent("Call Alert Tone", value: codeplug.callAlertTone ? "Enabled" : "Disabled")
                LabeledContent("Power Up Tone", value: codeplug.powerUpTone ? "Enabled" : "Disabled")
            }

            // Timing Settings
            GroupBox("Timing Settings") {
                LabeledContent("TOT (Timeout Timer)", value: codeplug.totTime == 0 ? "Infinite" : "\(codeplug.totTime) sec")
                    .help("TOT limits continuous transmission time to prevent accidental channel blockage")
                LabeledContent("Group Call Hang Time", value: "\(codeplug.groupCallHangTime) ms")
                    .help("How long the channel stays assigned to a group call after the last transmission ends")
                LabeledContent("Private Call Hang Time", value: "\(codeplug.privateCallHangTime) ms")
                    .help("How long the channel stays in private call mode after transmission ends")
            }

            // Display Settings
            GroupBox("Display Settings") {
                LabeledContent("Backlight Time", value: codeplug.backlightTime == 0 ? "Always On" : "\(codeplug.backlightTime) sec")
                LabeledContent("Default Power Level", value: codeplug.defaultPowerLevel ? "High" : "Low")
            }

            // Signaling Settings
            GroupBox("Signaling") {
                LabeledContent("Radio Check", value: codeplug.radioCheckEnabled ? "Enabled" : "Disabled")
                    .help("Radio Check lets dispatchers silently verify that your radio is active and reachable")
                LabeledContent("Remote Monitor", value: codeplug.remoteMonitorEnabled ? "Enabled" : "Disabled")
                    .help("Remote Monitor allows a controller to remotely activate this radio's microphone")
                LabeledContent("Call Confirmation", value: codeplug.callConfirmation ? "Enabled" : "Disabled")
                    .help("Sends an acknowledgement to confirm each call was received")
            }

            // GPS Settings
            GroupBox("GPS/GNSS") {
                LabeledContent("GPS", value: codeplug.gpsEnabled ? "Enabled" : "Disabled")
                    .help("Enables the radio's GPS receiver for location reporting")
                LabeledContent("Enhanced GNSS", value: codeplug.enhancedGNSSEnabled ? "Enabled" : "Disabled")
                    .help("Enhanced GNSS uses multiple satellite systems (GPS, GLONASS, Galileo, BeiDou) for better accuracy")
            }

            // Safety Settings
            GroupBox("Safety Features") {
                LabeledContent("Lone Worker", value: codeplug.loneWorkerEnabled ? "Enabled" : "Disabled")
                if codeplug.loneWorkerEnabled {
                    LabeledContent("LW Response Time", value: "\(codeplug.loneWorkerResponseTime) sec")
                }
                LabeledContent("Man Down", value: codeplug.manDownEnabled ? "Enabled" : "Disabled")
            }

            // Statistics
            GroupBox("Codeplug Statistics") {
                LabeledContent("Total Zones", value: "\(codeplug.zones.count)")
                let totalChannels = codeplug.zones.reduce(0) { $0 + $1.channels.count }
                LabeledContent("Total Channels", value: "\(totalChannels)")
                LabeledContent("Total Contacts", value: "\(codeplug.contacts.count)")
                LabeledContent("Scan Lists", value: "\(codeplug.scanLists.count)")
                LabeledContent("RX Group Lists", value: "\(codeplug.rxGroupLists.count)")
            }
        } else {
            ContentUnavailableView("No Data", systemImage: "doc.questionmark", description: Text("No codeplug data available"))
        }
    }

    private var contactsPlaceholder: some View {
        ContentUnavailableView {
            Label("Contacts", systemImage: "person.2")
        } description: {
            Text("Contacts aren't available for this codeplug format yet.")
        }
    }

    private var scanListsPlaceholder: some View {
        ContentUnavailableView {
            Label("Scan Lists", systemImage: "magnifyingglass")
        } description: {
            Text("Scan lists aren't available for this codeplug format yet.")
        }
    }

    private var categoryPlaceholder: some View {
        ContentUnavailableView {
            Label(category.rawValue, systemImage: "questionmark.circle")
        } description: {
            Text("This section isn't available for this codeplug format.")
        }
    }
}
