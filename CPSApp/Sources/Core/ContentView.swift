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
        .navigationTitle(document?.modelIdentifier ?? "Motorola CPS")
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
        if let codeplug = document?.codeplug, let doc = document {
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
            RadioStatusIndicator(state: coordinator.connectionState)
        }

        ToolbarItemGroup(placement: .primaryAction) {
            Button("Read", systemImage: "antenna.radiowaves.left.and.right") {
                // Read radio action
            }
            .disabled(!coordinator.connectionState.isDisconnected)
            .accessibilityIdentifier("toolbar.read")

            Button("Write", systemImage: "arrow.up.to.line") {
                // Write radio action
            }
            .disabled(document?.codeplug == nil)
            .accessibilityIdentifier("toolbar.write")

            Button("Clone", systemImage: "doc.on.doc") {
                // Clone action
            }
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

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .foregroundStyle(color)
                .font(.caption)
                .accessibilityHidden(true)
            Text(state.statusLabel)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
    }

    private var icon: String {
        switch state {
        case .disconnected: return "antenna.radiowaves.left.and.right.slash"
        case .connecting: return "antenna.radiowaves.left.and.right"
        case .connected: return "checkmark.circle.fill"
        case .programming: return "arrow.triangle.2.circlepath"
        case .error: return "exclamationmark.triangle.fill"
        }
    }

    private var color: Color {
        switch state {
        case .disconnected: return .gray
        case .connecting: return .yellow
        case .connected: return .green
        case .programming: return .blue
        case .error: return .red
        }
    }

    private var accessibilityLabel: String {
        switch state {
        case .disconnected: return "Radio disconnected"
        case .connecting: return "Connecting to radio"
        case .connected(let port): return "Radio connected on \(port)"
        case .programming: return "Programming radio in progress"
        case .error(let msg): return "Radio error: \(msg)"
        }
    }
}
