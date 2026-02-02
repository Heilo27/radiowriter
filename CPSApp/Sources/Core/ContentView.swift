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

    var body: some View {
        NavigationSplitView {
            sidebar
        } content: {
            contentArea
        } detail: {
            if showInspector {
                inspectorPanel
            }
        }
        // Prevent layout recursion by disabling animations on external state changes
        .transaction { transaction in
            transaction.disablesAnimations = true
        }
        .navigationTitle(document?.modelIdentifier ?? "RadioWriter")
        .toolbar {
            toolbarContent
        }
        .searchable(text: $searchText, prompt: "Search settings")
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
                ContentUnavailableView("Select a Category", systemImage: "radio", description: Text("Choose a category from the sidebar to view settings."))
            }
        }
        // Priority 2: Show traditional document-based editing
        else if let codeplug = document?.codeplug, let doc = document {
            if selectedCategory == .channel {
                ChannelEditorView(codeplug: codeplug, modelIdentifier: doc.modelIdentifier)
            } else if let category = selectedCategory {
                FormEditorView(codeplug: codeplug, category: category, modelIdentifier: doc.modelIdentifier)
            } else {
                ContentUnavailableView("Select a Category", systemImage: "radio", description: Text("Choose a category from the sidebar to edit settings."))
            }
        } else {
            ContentUnavailableView("No Profile Loaded", systemImage: "doc.badge.plus", description: Text("Create a new profile or read from a connected radio."))
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

            Button("Write", systemImage: "arrow.up.to.line") {
                coordinator.writeToRadioWithBackupPrompt()
            }
            .disabled(document?.codeplug == nil || coordinator.detectedDevices.isEmpty)
            .keyboardShortcut("w", modifiers: [.command, .shift])
            .accessibilityIdentifier("toolbar.write")

            Button("Clone", systemImage: "doc.on.doc") {
                // Clone action
            }
            .keyboardShortcut("d", modifiers: [.command])
            .accessibilityIdentifier("toolbar.clone")
        }

        ToolbarItem(placement: .automatic) {
            Toggle(isOn: $showInspector) {
                Label("Inspector", systemImage: "sidebar.trailing")
            }
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
                if codeplug.voxEnabled {
                    LabeledContent("VOX Sensitivity", value: "\(codeplug.voxSensitivity)")
                    LabeledContent("VOX Delay", value: "\(codeplug.voxDelay) ms")
                }
                LabeledContent("Keypad Tones", value: codeplug.keypadTones ? "On" : "Off")
                LabeledContent("Call Alert Tone", value: codeplug.callAlertTone ? "On" : "Off")
                LabeledContent("Power Up Tone", value: codeplug.powerUpTone ? "On" : "Off")
            }

            // Timing Settings
            GroupBox("Timing Settings") {
                LabeledContent("TOT (Timeout Timer)", value: codeplug.totTime == 0 ? "Infinite" : "\(codeplug.totTime) sec")
                LabeledContent("Group Call Hang Time", value: "\(codeplug.groupCallHangTime) ms")
                LabeledContent("Private Call Hang Time", value: "\(codeplug.privateCallHangTime) ms")
            }

            // Display Settings
            GroupBox("Display Settings") {
                LabeledContent("Backlight Time", value: codeplug.backlightTime == 0 ? "Always On" : "\(codeplug.backlightTime) sec")
                LabeledContent("Default Power Level", value: codeplug.defaultPowerLevel ? "High" : "Low")
            }

            // Signaling Settings
            GroupBox("Signaling") {
                LabeledContent("Radio Check", value: codeplug.radioCheckEnabled ? "Enabled" : "Disabled")
                LabeledContent("Remote Monitor", value: codeplug.remoteMonitorEnabled ? "Enabled" : "Disabled")
                LabeledContent("Call Confirmation", value: codeplug.callConfirmation ? "Enabled" : "Disabled")
            }

            // GPS Settings
            GroupBox("GPS/GNSS") {
                LabeledContent("GPS", value: codeplug.gpsEnabled ? "Enabled" : "Disabled")
                LabeledContent("Enhanced GNSS", value: codeplug.enhancedGNSSEnabled ? "Enabled" : "Disabled")
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
            Text("Contact list parsing not yet implemented")
        }
    }

    private var scanListsPlaceholder: some View {
        ContentUnavailableView {
            Label("Scan Lists", systemImage: "magnifyingglass")
        } description: {
            Text("Scan list parsing not yet implemented")
        }
    }

    private var categoryPlaceholder: some View {
        ContentUnavailableView {
            Label(category.rawValue, systemImage: "questionmark.circle")
        } description: {
            Text("This category is not yet available for parsed codeplugs")
        }
    }
}
