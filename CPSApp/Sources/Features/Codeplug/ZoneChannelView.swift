import SwiftUI
import RadioProgrammer
import RadioModelCore
import RadioCore

/// View displaying zones and channels from a parsed codeplug.
struct ZoneChannelView: View {
    @Environment(AppCoordinator.self) private var coordinator
    let searchText: String

    @State private var selectedZoneIndex: Int = 0
    @State private var selectedChannelIndex: Int?
    @State private var showingChannelDetail = false

    // Zone management
    @State private var showingAddZone = false
    @State private var showingRenameZone = false
    @State private var showingDeleteZoneAlert = false
    @State private var newZoneName = ""

    // Channel management
    @State private var showingAddChannel = false
    @State private var showingDeleteChannelAlert = false
    @State private var showingChannelEditor = false

    // Channel view mode (List vs Table)
    @State private var channelViewMode: ChannelViewMode = .list
    @State private var sortOrder: [KeyPathComparator<ChannelRowItem>] = [
        KeyPathComparator(\ChannelRowItem.index, order: .forward)
    ]

    private enum ChannelViewMode: String, CaseIterable {
        case list = "List"
        case table = "Table"
    }

    var body: some View {
        HSplitView {
            // Left sidebar: Zone list
            zoneListView
                .frame(minWidth: 150, maxWidth: 200)

            // Middle: Channel list for selected zone
            channelListView
                .frame(minWidth: 250, maxWidth: 350)

            // Right: Channel detail
            channelDetailView
                .frame(minWidth: 300)
        }
        .accessibilityRotor("Zones") {
            if let zones = coordinator.parsedCodeplug?.zones {
                ForEach(Array(zones.enumerated()), id: \.offset) { index, zone in
                    AccessibilityRotorEntry(zone.name, id: index) {
                        selectedZoneIndex = index
                    }
                }
            }
        }
        .accessibilityRotor("Channels") {
            ForEach(filteredChannels, id: \.index) { item in
                AccessibilityRotorEntry(item.channel.name, id: item.index) {
                    selectedChannelIndex = item.index
                }
            }
        }
        // Prevent layout recursion by disabling animations on external state changes
        .transaction { transaction in
            transaction.disablesAnimations = true
        }
        .sheet(isPresented: $showingAddZone) {
            AddZoneSheet(zoneName: $newZoneName) {
                addNewZone()
            }
        }
        .sheet(isPresented: $showingRenameZone) {
            RenameZoneSheet(zoneName: $newZoneName, currentName: selectedZone?.name ?? "") {
                renameSelectedZone()
            }
        }
        .sheet(isPresented: $showingChannelEditor) {
            if let channel = selectedChannel {
                ChannelEditorSheet(channel: channel) { updatedChannel in
                    updateChannel(updatedChannel)
                }
            }
        }
        .alert("Delete Zone?", isPresented: $showingDeleteZoneAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                deleteSelectedZone()
            }
        } message: {
            Text("This will delete the zone '\(selectedZone?.name ?? "")' and all its channels. This cannot be undone.")
        }
        .alert("Delete Channel?", isPresented: $showingDeleteChannelAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                deleteSelectedChannel()
            }
        } message: {
            Text("This will delete the channel '\(selectedChannel?.name ?? "")'. This cannot be undone.")
        }
    }

    // MARK: - Zone Management Actions

    private func addNewZone() {
        guard !newZoneName.isEmpty else { return }
        var zones = coordinator.parsedCodeplug?.zones ?? []
        var newZone = ParsedZone(name: newZoneName, position: zones.count)
        newZone.channels = []
        zones.append(newZone)
        coordinator.updateZones(zones, actionName: "Add Zone")
        selectedZoneIndex = zones.count - 1
        newZoneName = ""
    }

    private func renameSelectedZone() {
        guard !newZoneName.isEmpty,
              var zones = coordinator.parsedCodeplug?.zones,
              selectedZoneIndex >= 0 && selectedZoneIndex < zones.count else { return }
        let oldName = zones[selectedZoneIndex].name
        zones[selectedZoneIndex].name = newZoneName
        coordinator.updateZones(zones, actionName: "Rename Zone '\(oldName)'")
        newZoneName = ""
    }

    private func deleteSelectedZone() {
        guard var zones = coordinator.parsedCodeplug?.zones,
              selectedZoneIndex >= 0 && selectedZoneIndex < zones.count else { return }
        let zoneName = zones[selectedZoneIndex].name
        zones.remove(at: selectedZoneIndex)
        coordinator.updateZones(zones, actionName: "Delete Zone '\(zoneName)'")
        if selectedZoneIndex >= zones.count {
            selectedZoneIndex = max(0, zones.count - 1)
        }
        selectedChannelIndex = nil
    }

    // MARK: - Channel Management Actions

    private func addNewChannel() {
        guard var zones = coordinator.parsedCodeplug?.zones,
              selectedZoneIndex >= 0 && selectedZoneIndex < zones.count else { return }

        let channelCount = zones[selectedZoneIndex].channels.count
        guard channelCount < RadioConstants.maxChannelsPerZone else { return }

        // Determine default frequency based on existing channels in the zone
        let existingFrequency = zones[selectedZoneIndex].channels.first?.rxFrequencyHz
        let defaultFreq = RadioConstants.defaultFrequency(forBand: existingFrequency)

        var newChannel = ChannelData(zoneIndex: selectedZoneIndex, channelIndex: channelCount)
        newChannel.name = "New Channel \(channelCount + 1)"
        newChannel.rxFrequencyHz = defaultFreq
        newChannel.txFrequencyHz = defaultFreq

        zones[selectedZoneIndex].channels.append(newChannel)
        coordinator.updateZones(zones, actionName: "Add Channel")
        selectedChannelIndex = channelCount
    }

    private func deleteSelectedChannel() {
        guard var zones = coordinator.parsedCodeplug?.zones,
              selectedZoneIndex >= 0 && selectedZoneIndex < zones.count,
              let channelIndex = selectedChannelIndex,
              channelIndex >= 0 && channelIndex < zones[selectedZoneIndex].channels.count else { return }

        let channelName = zones[selectedZoneIndex].channels[channelIndex].name
        zones[selectedZoneIndex].channels.remove(at: channelIndex)
        coordinator.updateZones(zones, actionName: "Delete Channel '\(channelName)'")

        if channelIndex >= zones[selectedZoneIndex].channels.count {
            selectedChannelIndex = zones[selectedZoneIndex].channels.isEmpty ? nil : zones[selectedZoneIndex].channels.count - 1
        }
    }

    private func updateChannel(_ channel: ChannelData) {
        guard let channelIndex = selectedChannelIndex else { return }
        coordinator.updateChannel(channel, zoneIndex: selectedZoneIndex, channelIndex: channelIndex, actionName: "Edit Channel")
    }

    // MARK: - Zone List

    private var zoneListView: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header with actions
            HStack {
                Text("Zones")
                    .font(.headline)
                Spacer()
                Text("\(coordinator.parsedCodeplug?.zones.count ?? 0)")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                // Zone actions
                Menu {
                    Button {
                        newZoneName = ""
                        showingAddZone = true
                    } label: {
                        Label("Add Zone", systemImage: "folder.badge.plus")
                    }

                    if selectedZone != nil {
                        Button {
                            newZoneName = selectedZone?.name ?? ""
                            showingRenameZone = true
                        } label: {
                            Label("Rename Zone", systemImage: "pencil")
                        }

                        Divider()

                        Button(role: .destructive) {
                            showingDeleteZoneAlert = true
                        } label: {
                            Label("Delete Zone", systemImage: "trash")
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .foregroundStyle(.secondary)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .menuStyle(.borderlessButton)
                .accessibilityLabel("Zone actions menu")
            }
            .padding(.horizontal)
            .padding(.vertical, 8)

            Divider()

            // Zone list
            if let zones = coordinator.parsedCodeplug?.zones, !zones.isEmpty {
                if !searchText.isEmpty && filteredZones.isEmpty {
                    ContentUnavailableView.search(text: searchText)
                        .accessibilityLabel("No zones match '\(searchText)'")
                } else {
                    List(selection: $selectedZoneIndex) {
                        ForEach(filteredZones, id: \.index) { item in
                            HStack {
                                Image(systemName: "folder")
                                    .foregroundStyle(.secondary)
                                    .accessibilityHidden(true)
                                Text(item.zone.name)
                                    .foregroundStyle(highlightMatch(item.zone.name) ? Color.accentColor : .primary)
                                Spacer()
                                Text("\(item.zone.channels.count)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .tag(item.index)
                            .contextMenu {
                                Button {
                                    selectedZoneIndex = item.index
                                    newZoneName = item.zone.name
                                    showingRenameZone = true
                                } label: {
                                    Label("Rename", systemImage: "pencil")
                                }

                                Button {
                                    if let newIndex = coordinator.cloneZone(item.index) {
                                        selectedZoneIndex = newIndex
                                    }
                                } label: {
                                    Label("Duplicate Zone", systemImage: "doc.on.doc")
                                }

                                Divider()

                                Button(role: .destructive) {
                                    selectedZoneIndex = item.index
                                    showingDeleteZoneAlert = true
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                    }
                    .listStyle(.sidebar)
                    .onChange(of: selectedZoneIndex) { _, _ in
                        selectedChannelIndex = nil
                    }
                }
            } else {
                VStack {
                    ContentUnavailableView {
                        Label("No Zones", systemImage: "folder.badge.questionmark")
                    } description: {
                        Text("Read from a radio to see zones")
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("No zones available")
                    .accessibilityHint("Connect a radio and read from it, or use the Add Zone button below")

                    Button {
                        newZoneName = ""
                        showingAddZone = true
                    } label: {
                        Label("Add Zone", systemImage: "plus")
                    }
                    .buttonStyle(.borderedProminent)
                    .padding(.bottom)
                }
            }
        }
    }

    // MARK: - Channel List

    private var channelListView: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Force VStack to expand to fill available space
            // Header with actions
            HStack {
                Text("Channels")
                    .font(.headline)
                Spacer()
                if let zone = selectedZone {
                    Text("\(zone.channels.count)/\(RadioConstants.maxChannelsPerZone)")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    // View mode toggle (List <-> Table)
                    Picker("View Mode", selection: $channelViewMode) {
                        ForEach(ChannelViewMode.allCases, id: \.self) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .frame(width: 120)
                    .accessibilityLabel("Channel view mode")

                    // Channel actions
                    Menu {
                        Button {
                            addNewChannel()
                        } label: {
                            Label("Add Channel", systemImage: "plus")
                        }
                        .disabled(zone.channels.count >= RadioConstants.maxChannelsPerZone)

                        if selectedChannel != nil {
                            Button {
                                showingChannelEditor = true
                            } label: {
                                Label("Edit Channel", systemImage: "pencil")
                            }

                            Divider()

                            Button(role: .destructive) {
                                showingDeleteChannelAlert = true
                            } label: {
                                Label("Delete Channel", systemImage: "trash")
                            }
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .foregroundStyle(.secondary)
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                    .menuStyle(.borderlessButton)
                    .accessibilityLabel("Channel actions menu")
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)

            Divider()

            // Channel list
            if let zone = selectedZone, !zone.channels.isEmpty {
                if !searchText.isEmpty && filteredChannels.isEmpty {
                    ContentUnavailableView.search(text: searchText)
                        .accessibilityLabel("No channels match '\(searchText)'")
                } else {
                    switch channelViewMode {
                    case .list:
                        channelListMode
                    case .table:
                        channelTableMode
                    }
                }
            } else if selectedZone != nil {
                VStack {
                    ContentUnavailableView {
                        Label("No Channels", systemImage: "antenna.radiowaves.left.and.right")
                    } description: {
                        Text("This zone has no channels")
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("No channels in this zone")
                    .accessibilityHint("Use the Add Channel button below to create a new channel")

                    Button {
                        addNewChannel()
                    } label: {
                        Label("Add Channel", systemImage: "plus")
                    }
                    .buttonStyle(.borderedProminent)
                    .padding(.bottom)
                }
            } else {
                ContentUnavailableView {
                    Label("Select a Zone", systemImage: "folder")
                } description: {
                    Text("Select a zone to see its channels")
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Select a zone")
                .accessibilityHint("Choose a zone from the left sidebar to view its channels")
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    // MARK: - Channel List Mode (native List with selection, keyboard nav, drag reorder)

    private var channelListMode: some View {
        List(selection: $selectedChannelIndex) {
            ForEach(filteredChannels, id: \.index) { item in
                let freqString = String(format: "%.4f", item.channel.rxFrequencyMHz)
                let isHighlighted = highlightMatch(item.channel.name) || highlightMatch(freqString)
                ParsedChannelRow(channel: item.channel, index: item.index, isHighlighted: isHighlighted)
                    .tag(item.index)
                    .contentShape(Rectangle())
                    .accessibilityLabel("Channel \(item.index + 1): \(item.channel.name)")
                    .accessibilityHint("Double-tap to edit")
                    .onTapGesture(count: 2) {
                        selectedChannelIndex = item.index
                        showingChannelEditor = true
                    }
                    .contextMenu {
                        channelContextMenu(for: item.index)
                    }
            }
            // Drag-to-reorder is only meaningful when not filtering.
            .onMove { source, destination in
                guard searchText.isEmpty else { return }
                moveChannels(from: source, to: destination)
            }
        }
    }

    // MARK: - Channel Table Mode (sortable power-user table)

    private var channelTableMode: some View {
        Table(sortedChannelItems, selection: $selectedChannelIndex, sortOrder: $sortOrder) {
            TableColumn("#", value: \.index) { item in
                Text("\(item.index + 1)")
                    .monospacedDigit()
                    .accessibilityLabel("Channel number \(item.index + 1)")
            }
            .width(min: 32, ideal: 40, max: 56)

            TableColumn("Name", value: \.channel.name) { item in
                Text(item.channel.name)
            }

            TableColumn("RX", value: \.channel.rxFrequencyMHz) { item in
                Text(String(format: "%.4f", item.channel.rxFrequencyMHz))
                    .monospacedDigit()
                    .accessibilityLabel("Receive \(String(format: "%.4f", item.channel.rxFrequencyMHz)) megahertz")
            }
            .width(min: 70, ideal: 80)

            TableColumn("TX", value: \.channel.txFrequencyMHz) { item in
                // Show offset for repeaters, absolute TX for simplex.
                if item.channel.rxFrequencyHz != item.channel.txFrequencyHz {
                    Text(String(format: "%+.4f", item.channel.txOffsetMHz))
                        .monospacedDigit()
                        .accessibilityLabel("Transmit offset \(String(format: "%+.4f", item.channel.txOffsetMHz)) megahertz")
                } else {
                    Text(String(format: "%.4f", item.channel.txFrequencyMHz))
                        .monospacedDigit()
                        .accessibilityLabel("Transmit \(String(format: "%.4f", item.channel.txFrequencyMHz)) megahertz")
                }
            }
            .width(min: 70, ideal: 80)

            TableColumn("Mode", value: \.modeSort) { item in
                Text(item.channel.isDigital ? "D" : "A")
                    .accessibilityLabel(item.channel.isDigital ? "Digital" : "Analog")
            }
            .width(min: 36, ideal: 44, max: 56)

            TableColumn("CC", value: \.channel.colorCode) { item in
                Text(item.channel.isDigital ? "\(item.channel.colorCode)" : "—")
                    .monospacedDigit()
                    .accessibilityLabel(item.channel.isDigital ? "Color code \(item.channel.colorCode)" : "No color code")
            }
            .width(min: 32, ideal: 40, max: 52)

            TableColumn("TS", value: \.channel.timeSlot) { item in
                Text(item.channel.isDigital ? "\(item.channel.timeSlot)" : "—")
                    .monospacedDigit()
                    .accessibilityLabel(item.channel.isDigital ? "Time slot \(item.channel.timeSlot)" : "No time slot")
            }
            .width(min: 32, ideal: 40, max: 52)

            TableColumn("Pwr", value: \.powerSort) { item in
                Text(item.channel.txPowerHigh ? "High" : "Low")
                    .accessibilityLabel(item.channel.txPowerHigh ? "High power" : "Low power")
            }
            .width(min: 44, ideal: 52, max: 64)

            TableColumn("BW", value: \.bandwidthSort) { item in
                Text(item.channel.bandwidthWide ? "25" : "12.5")
                    .monospacedDigit()
                    .accessibilityLabel(item.channel.bandwidthWide ? "25 kilohertz" : "12.5 kilohertz")
            }
            .width(min: 44, ideal: 56, max: 72)
        }
        .contextMenu(forSelectionType: Int.self) { indices in
            if let index = indices.first {
                channelContextMenu(for: index)
            }
        } primaryAction: { indices in
            if let index = indices.first {
                selectedChannelIndex = index
                showingChannelEditor = true
            }
        }
    }

    /// Filtered channel items sorted by the active `sortOrder`, wrapped as `Identifiable` for the Table.
    private var sortedChannelItems: [ChannelRowItem] {
        let items = filteredChannels.map { ChannelRowItem(index: $0.index, channel: $0.channel) }
        return items.sorted(using: sortOrder)
    }

    /// Shared context menu used by both the list and the table.
    @ViewBuilder
    private func channelContextMenu(for index: Int) -> some View {
        Button {
            selectedChannelIndex = index
            showingChannelEditor = true
        } label: {
            Label("Edit", systemImage: "pencil")
        }

        Button {
            if let newIndex = coordinator.cloneChannel(zoneIndex: selectedZoneIndex, channelIndex: index) {
                selectedChannelIndex = newIndex
            }
        } label: {
            Label("Duplicate Channel", systemImage: "doc.on.doc")
        }

        Divider()

        Button(role: .destructive) {
            selectedChannelIndex = index
            showingDeleteChannelAlert = true
        } label: {
            Label("Delete", systemImage: "trash")
        }
    }

    private func moveChannels(from source: IndexSet, to destination: Int) {
        guard var zones = coordinator.parsedCodeplug?.zones,
              selectedZoneIndex >= 0 && selectedZoneIndex < zones.count else { return }

        zones[selectedZoneIndex].channels.move(fromOffsets: source, toOffset: destination)
        coordinator.updateZones(zones, actionName: "Move Channels")
    }

    // MARK: - Channel Detail

    private var channelDetailView: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header with More Options button
            HStack {
                Text("Channel Details")
                    .font(.headline)
                Spacer()

                if selectedChannel != nil {
                    Button {
                        showingChannelEditor = true
                    } label: {
                        Label("More Options", systemImage: "slider.horizontal.3")
                    }
                    .buttonStyle(.bordered)
                    .accessibilityLabel("Open full channel editor")
                    .accessibilityHint("Opens a dialog with all channel settings")
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)

            Divider()

            if let channelIndex = selectedChannelIndex,
               let zones = coordinator.parsedCodeplug?.zones,
               selectedZoneIndex >= 0 && selectedZoneIndex < zones.count,
               channelIndex >= 0 && channelIndex < zones[selectedZoneIndex].channels.count {
                EditableChannelDetailView(
                    channel: zones[selectedZoneIndex].channels[channelIndex],
                    onUpdate: { updatedChannel in
                        updateChannel(updatedChannel)
                    }
                )
            } else {
                ContentUnavailableView {
                    Label("Select Channel", systemImage: "info.circle")
                } description: {
                    Text("Select a channel to view details")
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Select a channel")
                .accessibilityHint("Choose a channel from the middle panel to view its details")
            }
        }
    }

    // MARK: - Helpers

    private var selectedZone: ParsedZone? {
        guard let zones = coordinator.parsedCodeplug?.zones,
              selectedZoneIndex >= 0 && selectedZoneIndex < zones.count else {
            return nil
        }
        return zones[selectedZoneIndex]
    }

    private var selectedChannel: ChannelData? {
        guard let zone = selectedZone,
              let index = selectedChannelIndex,
              index >= 0 && index < zone.channels.count else {
            return nil
        }
        return zone.channels[index]
    }

    // MARK: - Search Filtering

    /// Filters zones by name when search text is active
    private var filteredZones: [(index: Int, zone: ParsedZone)] {
        guard let zones = coordinator.parsedCodeplug?.zones else { return [] }
        let indexed = zones.enumerated().map { (index: $0.offset, zone: $0.element) }

        if searchText.isEmpty {
            return indexed
        }

        let lowercasedSearch = searchText.lowercased()
        return indexed.filter { item in
            // Include zone if its name matches
            if item.zone.name.lowercased().contains(lowercasedSearch) {
                return true
            }
            // Or if any of its channels match
            return item.zone.channels.contains { channel in
                channelMatchesSearch(channel, search: lowercasedSearch)
            }
        }
    }

    /// Filters channels in the selected zone by name or frequency
    private var filteredChannels: [(index: Int, channel: ChannelData)] {
        guard let zone = selectedZone else { return [] }
        let indexed = zone.channels.enumerated().map { (index: $0.offset, channel: $0.element) }

        if searchText.isEmpty {
            return indexed
        }

        let lowercasedSearch = searchText.lowercased()
        return indexed.filter { item in
            channelMatchesSearch(item.channel, search: lowercasedSearch)
        }
    }

    /// Checks if a channel matches the search criteria
    private func channelMatchesSearch(_ channel: ChannelData, search: String) -> Bool {
        // Match channel name
        if channel.name.lowercased().contains(search) {
            return true
        }
        // Match frequency (formatted)
        let rxFreq = String(format: "%.4f", channel.rxFrequencyMHz)
        if rxFreq.contains(search) {
            return true
        }
        let txFreq = String(format: "%.4f", channel.txFrequencyMHz)
        if txFreq.contains(search) {
            return true
        }
        // Match DMR ID/Contact ID for digital channels
        if channel.isDigital && String(channel.contactID).contains(search) {
            return true
        }
        return false
    }

    /// Checks if text contains search term (for highlighting)
    private func highlightMatch(_ text: String) -> Bool {
        guard !searchText.isEmpty else { return false }
        return text.lowercased().contains(searchText.lowercased())
    }
}

// MARK: - Channel Row Item (Identifiable wrapper for Table)

/// Identifiable wrapper around an indexed channel so the native `Table`
/// can use `selection:` bound to the channel index (`id == index`).
struct ChannelRowItem: Identifiable {
    let index: Int
    let channel: ChannelData
    var id: Int { index }

    // Comparable proxies for Bool-backed columns (Bool isn't Comparable, so
    // sortable TableColumns can't key on it directly).
    var modeSort: Int { channel.isDigital ? 1 : 0 }
    var powerSort: Int { channel.txPowerHigh ? 1 : 0 }
    var bandwidthSort: Int { channel.bandwidthWide ? 1 : 0 }
}

// MARK: - Channel Row

struct ParsedChannelRow: View {
    let channel: ChannelData
    let index: Int
    var isHighlighted: Bool = false

    var body: some View {
        HStack(spacing: 12) {
            // Channel number
            Text("\(index + 1)")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 24)

            // Channel type icon
            Image(systemName: channel.isDigital ? "waveform" : "waveform.path")
                .foregroundStyle(channel.isDigital ? .blue : .orange)
                .frame(width: 20)
                .accessibilityLabel(channel.isDigital ? "Digital channel" : "Analog channel")

            // Channel name
            VStack(alignment: .leading, spacing: 2) {
                Text(channel.name)
                    .font(.body)
                    .foregroundStyle(isHighlighted ? Color.accentColor : .primary)

                HStack(spacing: 8) {
                    // Frequency
                    Text(String(format: "%.4f MHz", channel.rxFrequencyMHz))
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(isHighlighted ? Color.accentColor.opacity(0.8) : .secondary)

                    // Additional info for digital channels
                    if channel.isDigital {
                        Text("CC\(channel.colorCode)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("TS\(channel.timeSlot)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Spacer()

            // Power indicator — High is emphasized (accent), Low is quiet (neutral).
            // Red is reserved app-wide for errors, never for a normal setting.
            Text(channel.txPowerHigh ? "HIGH" : "LOW")
                .font(.caption2.bold())
                .foregroundStyle(channel.txPowerHigh ? Color.accentColor : Color.secondary)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(
                    Capsule()
                        .fill(channel.txPowerHigh ? Color.accentColor.opacity(0.12) : Color.secondary.opacity(0.12))
                )
                .accessibilityLabel(channel.txPowerHigh ? "High power" : "Low power")
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Channel Detail View

struct ChannelDetailView: View {
    let channel: ChannelData
    @State private var expandedSections: Set<String> = ["basic", "frequency", "power"]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                // MARK: - Basic Information
                DisclosureGroup(
                    isExpanded: binding(for: "basic"),
                    content: { basicInfoContent },
                    label: { sectionHeader("Basic Information", icon: "info.circle") }
                )

                Divider()

                // MARK: - Frequencies
                DisclosureGroup(
                    isExpanded: binding(for: "frequency"),
                    content: { frequencyContent },
                    label: { sectionHeader("Frequencies", icon: "waveform") }
                )

                Divider()

                // MARK: - Power & Timing
                DisclosureGroup(
                    isExpanded: binding(for: "power"),
                    content: { powerTimingContent },
                    label: { sectionHeader("Power & Timing", icon: "bolt.fill") }
                )

                Divider()

                // MARK: - Digital (DMR) Settings
                if channel.isDigital {
                    DisclosureGroup(
                        isExpanded: binding(for: "digital"),
                        content: { digitalSettingsContent },
                        label: { sectionHeader("Digital (DMR)", icon: "antenna.radiowaves.left.and.right") }
                    )

                    Divider()

                    DisclosureGroup(
                        isExpanded: binding(for: "advanced_digital"),
                        content: { advancedDigitalContent },
                        label: { sectionHeader("Advanced Digital", icon: "gearshape.2") }
                    )

                    Divider()
                }

                // MARK: - Analog Settings
                if !channel.isDigital {
                    DisclosureGroup(
                        isExpanded: binding(for: "analog"),
                        content: { analogSettingsContent },
                        label: { sectionHeader("Analog Settings", icon: "waveform.path") }
                    )

                    Divider()
                }

                // MARK: - Privacy/Encryption
                DisclosureGroup(
                    isExpanded: binding(for: "privacy"),
                    content: { privacyContent },
                    label: { sectionHeader("Privacy/Encryption", icon: "lock.shield") }
                )

                Divider()

                // MARK: - Signaling
                DisclosureGroup(
                    isExpanded: binding(for: "signaling"),
                    content: { signalingContent },
                    label: { sectionHeader("Signaling", icon: "bell") }
                )

                Divider()

                // MARK: - Scanning
                DisclosureGroup(
                    isExpanded: binding(for: "scanning"),
                    content: { scanningContent },
                    label: { sectionHeader("Scanning", icon: "magnifyingglass") }
                )

                Divider()

                // MARK: - MOTOTRBO Features
                DisclosureGroup(
                    isExpanded: binding(for: "mototrbo"),
                    content: { mototrboContent },
                    label: { sectionHeader("MOTOTRBO Features", icon: "star") }
                )

                Spacer(minLength: 20)
            }
            .padding()
        }
    }

    // MARK: - Section Header

    private func sectionHeader(_ title: String, icon: String) -> some View {
        HStack {
            Image(systemName: icon)
                .foregroundStyle(.secondary)
                .frame(width: 20)
            Text(title)
                .font(.headline)
        }
    }

    private func binding(for section: String) -> Binding<Bool> {
        Binding(
            get: { expandedSections.contains(section) },
            set: { isExpanded in
                if isExpanded {
                    expandedSections.insert(section)
                } else {
                    expandedSections.remove(section)
                }
            }
        )
    }

    // MARK: - Basic Information

    private var basicInfoContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            LabeledContent("Channel Name", value: channel.name)
            LabeledContent("Position", value: "\(channel.channelIndex + 1)")
            LabeledContent("Channel Type", value: channel.channelTypeDisplay)
                .help("Analog (conventional FM) or Digital (DMR). Determines which settings apply to this channel.")
            LabeledContent("Bandwidth", value: channel.bandwidthDisplay)
                .help("Channel spacing. 12.5 kHz (Narrow) is standard for Part 90 since 2013. Only use 25 kHz (Wide) if required by your system.")
            if !channel.voiceAnnouncement.isEmpty {
                LabeledContent("Voice Announcement", value: channel.voiceAnnouncement)
            }
        }
        .padding(.leading, 24)
        .padding(.vertical, 8)
    }

    // MARK: - Frequency Content

    private var frequencyContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            LabeledContent("RX Frequency", value: String(format: "%.5f MHz", channel.rxFrequencyMHz))
                .help("Receive frequency -- the frequency your radio listens on.")
            LabeledContent("TX Frequency", value: String(format: "%.5f MHz", channel.txFrequencyMHz))
                .help("Transmit frequency -- the frequency your radio transmits on. Matches RX for simplex; offset for repeater use.")

            if channel.rxFrequencyHz != channel.txFrequencyHz {
                LabeledContent("TX Offset", value: String(format: "%+.4f MHz", channel.txOffsetMHz))
                    .help("Difference between TX and RX frequencies. Repeaters require an offset so the radio transmits on a different frequency than it receives.")
                LabeledContent("Mode", value: channel.txOffsetMHz > 0 ? "Repeater (+)" : "Repeater (-)")
                    .help("Repeater mode means the radio uses different TX and RX frequencies to communicate through a repeater station. Simplex uses the same frequency for both.")
            } else {
                LabeledContent("Mode", value: "Simplex")
                    .help("Simplex means the radio transmits and receives on the same frequency -- direct radio-to-radio communication without a repeater.")
            }
        }
        .padding(.leading, 24)
        .padding(.vertical, 8)
    }

    // MARK: - Power & Timing

    private var powerTimingContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            LabeledContent("TX Power", value: channel.powerDisplay)
                .help("Transmit power level. High increases range but drains battery faster. Low is sufficient for short-range or indoor use.")
            LabeledContent("RX Only", value: channel.rxOnly ? "Enabled" : "Disabled")
                .help("When enabled, the radio can only receive on this channel -- transmitting is blocked.")
            LabeledContent("TOT Timeout", value: "\(channel.totTimeout) seconds")
                .help("Timeout Timer -- limits continuous transmission time to prevent accidental channel blockage.")
            LabeledContent("Allow Talkaround", value: channel.allowTalkaround ? "Enabled" : "Disabled")
                .help("Talkaround lets the radio transmit on the receive frequency to bypass the repeater for direct radio-to-radio communication.")
        }
        .padding(.leading, 24)
        .padding(.vertical, 8)
    }

    // MARK: - Digital Settings

    private var digitalSettingsContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            LabeledContent("Color Code", value: "\(channel.colorCode)")
                .help("DMR Color Code (0-15) separates radio systems on the same frequency. All radios in the same system must use the same Color Code.")
            LabeledContent("Time Slot", value: "Slot \(channel.timeSlot)")
                .help("DMR Time Slot (1 or 2). DMR divides a frequency into two time slots, doubling capacity. Check your repeater's plan for the correct slot.")
            LabeledContent("Contact ID", value: channel.contactID > 0 ? "\(channel.contactID)" : "None")
                .help("The DMR ID of the talk group or individual contact this channel calls by default when you press PTT.")
            LabeledContent("Contact Type", value: channel.contactTypeDisplay)
                .help("Group Call broadcasts to a talk group. Private Call goes to one radio. All Call reaches every radio on the channel.")
            LabeledContent("RX Group List", value: channel.rxGroupListID > 0 ? "List \(channel.rxGroupListID)" : "None")
                .help("RX Group List defines which talk groups this channel will receive. Without one, you only hear the default contact.")
        }
        .padding(.leading, 24)
        .padding(.vertical, 8)
    }

    // MARK: - Advanced Digital

    private var advancedDigitalContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            LabeledContent("Inbound Color Code", value: "\(channel.inboundColorCode)")
                .help("Color Code used for incoming transmissions. Usually matches the main Color Code unless the repeater uses asymmetric routing.")
            LabeledContent("Outbound Color Code", value: "\(channel.outboundColorCode)")
                .help("Color Code used for outgoing transmissions. Usually matches the main Color Code.")
            LabeledContent("Dual Capacity Direct Mode", value: channel.dualCapacityDirectMode ? "Enabled" : "Disabled")
                .help("DCDM allows two simultaneous DMR conversations on the same frequency in simplex mode by using both time slots.")
            LabeledContent("Timing Leader Preference", value: channel.timingLeaderDisplay)
                .help("Controls which radio drives timing in a direct DMR call. Set to Leader if this radio should establish timing; Follower if it should sync to another.")
            LabeledContent("Extended Range Direct Mode", value: channel.extendedRangeDirectMode ? "Enabled" : "Disabled")
                .help("ERDM increases simplex range by using a different modulation technique at the cost of reduced audio quality.")
            LabeledContent("Window Size", value: "\(channel.windowSize)")
            LabeledContent("Compressed UDP Header", value: channel.compressedUDPHeader ? "Enabled" : "Disabled")
            LabeledContent("Text Message Type", value: channel.textMessageType == 0 ? "DMR Standard" : "MOTOTRBO")
                .help("DMR Standard text messages are compatible with all DMR radios. MOTOTRBO format adds proprietary features but only works with Motorola radios.")
        }
        .padding(.leading, 24)
        .padding(.vertical, 8)
    }

    // MARK: - Analog Settings

    private var analogSettingsContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            LabeledContent("RX Squelch Type", value: channel.squelchTypeDisplay)
                .help("Squelch suppresses noise when no signal is present. Carrier opens on any signal. CTCSS/DCS only opens when the correct tone or code is received.")

            if channel.txCTCSSHz > 0 {
                LabeledContent("TX CTCSS", value: String(format: "%.1f Hz", channel.txCTCSSHz))
                    .help("CTCSS (Continuous Tone-Coded Squelch) -- a subaudible tone sent with your voice to open squelch on receiving radios set to the same tone.")
            } else {
                LabeledContent("TX CTCSS", value: "None")
                    .help("CTCSS (Continuous Tone-Coded Squelch) -- a subaudible tone sent with your voice. Set to None if not required by your repeater or group.")
            }

            if channel.rxCTCSSHz > 0 {
                LabeledContent("RX CTCSS", value: String(format: "%.1f Hz", channel.rxCTCSSHz))
                    .help("Receive CTCSS tone -- your radio will only unmute when it receives this specific subaudible tone.")
            } else {
                LabeledContent("RX CTCSS", value: "None")
                    .help("Receive CTCSS tone. Set to None to hear all transmissions on this frequency regardless of tone.")
            }

            if channel.txDCSCode > 0 {
                LabeledContent("TX DCS", value: String(format: "D%03o", channel.txDCSCode))
                    .help("DCS (Digital-Coded Squelch) -- a digital code sent below the voice to selectively open squelch. Similar to CTCSS but uses digital data.")
            } else {
                LabeledContent("TX DCS", value: "None")
                    .help("DCS (Digital-Coded Squelch) -- a digital alternative to CTCSS. Set to None if not required.")
            }

            if channel.rxDCSCode > 0 {
                LabeledContent("RX DCS", value: String(format: "D%03o", channel.rxDCSCode))
                    .help("Receive DCS code -- your radio will only unmute when it receives this specific digital code.")
            } else {
                LabeledContent("RX DCS", value: "None")
            }

            LabeledContent("DCS Invert", value: channel.dcsInvert ? "Enabled" : "Disabled")
                .help("DCS polarity. Normal (N) or Inverted (I) must match the repeater or other radio.")
            LabeledContent("Scramble", value: channel.scrambleEnabled ? "Enabled" : "Disabled")
                .help("Analog voice scrambling provides basic privacy by inverting the audio. Not true encryption -- it can be defeated with readily available equipment.")
            LabeledContent("Voice Emphasis", value: channel.voiceEmphasis ? "Enabled" : "Disabled")
        }
        .padding(.leading, 24)
        .padding(.vertical, 8)
    }

    // MARK: - Privacy

    private var privacyContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            LabeledContent("Privacy Type", value: channel.privacyTypeDisplay)
                .help("Privacy scrambles transmissions. Basic Privacy is obfuscation only. Enhanced/AES provides stronger protection. All radios must use the same type and key.")

            if channel.privacyType > 0 {
                LabeledContent("Privacy Key", value: "\(channel.privacyKey)")
                    .help("The encryption key index. All radios in the group must use the same key number to communicate.")
                if !channel.privacyAlias.isEmpty {
                    LabeledContent("Privacy Alias", value: channel.privacyAlias)
                }
                LabeledContent("Fixed Key Decryption", value: channel.fixedPrivacyKeyDecryption ? "Enabled" : "Disabled")
            }

            LabeledContent("Ignore RX Clear Voice", value: channel.ignoreRxClearVoice ? "Enabled" : "Disabled")
                .help("When enabled and privacy is active, the radio ignores unencrypted voice on this channel.")
        }
        .padding(.leading, 24)
        .padding(.vertical, 8)
    }

    // MARK: - Signaling

    private var signalingContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            LabeledContent("ARS", value: channel.arsEnabled ? "Enabled" : "Disabled")
                .help("ARS (Automatic Registration Service) automatically registers the radio with the system when it powers on or changes channels.")
            LabeledContent("Enhanced GNSS", value: channel.enhancedGNSSEnabled ? "Enabled" : "Disabled")
                .help("Enhanced GNSS uses multiple satellite systems (GPS, GLONASS, Galileo, BeiDou) for faster and more accurate position fixes.")
            LabeledContent("Lone Worker", value: channel.loneWorker ? "Enabled" : "Disabled")
                .help("Lone Worker periodically prompts the user to confirm they are safe. If no response, the radio raises an alert.")
            LabeledContent("Emergency Alarm Ack", value: channel.emergencyAlarmAck ? "Enabled" : "Disabled")
            LabeledContent("TX Interrupt", value: channel.txInterruptType == 0 ? "Disabled" : "Always Allow")
                .help("TX Interrupt allows a higher-priority call to interrupt an ongoing transmission on this channel.")
            LabeledContent("ARTS", value: channel.artsEnabled ? "Enabled" : "Disabled")
                .help("ARTS (Auto-Range Transpond System) periodically checks if another radio is within communication range and alerts if contact is lost.")
            if !channel.rasAlias.isEmpty {
                LabeledContent("RAS Alias", value: channel.rasAlias)
            }
        }
        .padding(.leading, 24)
        .padding(.vertical, 8)
    }

    // MARK: - Scanning

    private var scanningContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            LabeledContent("Scan List", value: channel.scanListID > 0 ? "List \(channel.scanListID)" : "None")
                .help("Scan List is a group of channels the radio cycles through to monitor for activity. Assign one to enable scanning from this channel.")
            LabeledContent("Auto Scan", value: channel.autoScan ? "Enabled" : "Disabled")
                .help("When enabled, the radio automatically begins scanning when switched to this channel.")
        }
        .padding(.leading, 24)
        .padding(.vertical, 8)
    }

    // MARK: - MOTOTRBO Features

    private var mototrboContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            LabeledContent("MOTOTRBO Link", value: channel.mototrboLinkEnabled ? "Enabled" : "Disabled")
            LabeledContent("OTA Battery Management", value: channel.otaBatteryManagement ? "Enabled" : "Disabled")
            LabeledContent("Audio Enhancement", value: channel.audioEnhancement ? "Enabled" : "Disabled")
            if !channel.phoneSystem.isEmpty {
                LabeledContent("Phone System", value: channel.phoneSystem)
            }
        }
        .padding(.leading, 24)
        .padding(.vertical, 8)
    }
}

// MARK: - Editable Channel Detail View

/// An editable version of the channel detail view for inline editing of common fields.
struct EditableChannelDetailView: View {
    let channel: ChannelData
    let onUpdate: (ChannelData) -> Void

    @State private var editingChannel: ChannelData
    @State private var expandedSections: Set<String> = ["quick", "frequency", "digital"]

    /// Suppresses the field `.onChange` → `onUpdate` echo while we programmatically
    /// reset `editingChannel` on channel selection. Without this, selecting a
    /// different channel fires every field's onChange, writing the channel back to
    /// itself — a spurious "Edit Channel" undo step + false dirty flag.
    @State private var isSwitchingChannel = false

    /// Unique key for the channel to detect when a new channel is selected.
    private var channelKey: String {
        "\(channel.zoneIndex)-\(channel.channelIndex)"
    }

    init(channel: ChannelData, onUpdate: @escaping (ChannelData) -> Void) {
        self.channel = channel
        self.onUpdate = onUpdate
        _editingChannel = State(initialValue: channel)
    }

    /// Propagate a genuine user edit — but never the programmatic reset echo.
    private func pushUpdate() {
        guard !isSwitchingChannel else { return }
        pushUpdate()
    }

    var body: some View {
        Form {
            // MARK: - Quick Edit Section
            Section(isExpanded: binding(for: "quick")) {
                quickEditContent
            } header: {
                sectionHeader("Quick Edit", icon: "pencil.circle")
            }

            // MARK: - Frequency Section (Editable)
            Section(isExpanded: binding(for: "frequency")) {
                frequencyEditContent
            } header: {
                sectionHeader("Frequencies", icon: "waveform")
            }

            // MARK: - Digital Settings (Editable if digital)
            if editingChannel.isDigital {
                Section(isExpanded: binding(for: "digital")) {
                    digitalEditContent
                } header: {
                    sectionHeader("Digital (DMR)", icon: "antenna.radiowaves.left.and.right")
                }
            }

            // MARK: - Power Settings
            Section(isExpanded: binding(for: "power")) {
                powerEditContent
            } header: {
                sectionHeader("Power & Options", icon: "bolt.fill")
            }

            // MARK: - Read-only Advanced Info
            Section(isExpanded: binding(for: "advanced")) {
                advancedReadOnlyContent
            } header: {
                sectionHeader("Advanced (Read-Only)", icon: "info.circle")
            }
        }
        .formStyle(.grouped)
        .onChange(of: channelKey) { _, _ in
            // Programmatically reset to the newly-selected channel. Suppress the
            // field onChange echo so this doesn't register as a user edit.
            isSwitchingChannel = true
            editingChannel = channel
            // Clear on the next runloop tick, after the field onChanges have fired.
            Task { @MainActor in isSwitchingChannel = false }
        }
    }

    // MARK: - Section Header

    private func sectionHeader(_ title: String, icon: String) -> some View {
        HStack {
            Image(systemName: icon)
                .foregroundStyle(.secondary)
                .frame(width: 20)
            Text(title)
                .font(.headline)
        }
    }

    private func binding(for section: String) -> Binding<Bool> {
        Binding(
            get: { expandedSections.contains(section) },
            set: { isExpanded in
                if isExpanded {
                    expandedSections.insert(section)
                } else {
                    expandedSections.remove(section)
                }
            }
        )
    }

    // MARK: - Quick Edit Content

    private var quickEditContent: some View {
        Group {
            LabeledContent("Name") {
                TextField("Channel Name", text: $editingChannel.name)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit {
                        pushUpdate()
                    }
                    .accessibilityLabel("Channel name")
            }

            // Channel Type (read-only display)
            LabeledContent("Type") {
                Text(editingChannel.isDigital ? "Digital (DMR)" : "Analog")
                    .fontWeight(.medium)
            }
        }
    }

    // MARK: - Frequency Edit Content

    private var frequencyEditContent: some View {
        Group {
            FrequencyInput(frequencyHz: $editingChannel.rxFrequencyHz, label: "RX Freq")
                .onChange(of: editingChannel.rxFrequencyHz) { _, _ in
                    pushUpdate()
                }

            FrequencyInput(frequencyHz: $editingChannel.txFrequencyHz, label: "TX Freq")
                .onChange(of: editingChannel.txFrequencyHz) { _, _ in
                    pushUpdate()
                }

            // Offset (read-only calculated)
            if editingChannel.rxFrequencyHz != editingChannel.txFrequencyHz {
                LabeledContent("Offset") {
                    Text(String(format: "%+.4f MHz", editingChannel.txOffsetMHz))
                        .fontWeight(.medium)
                }
            }
        }
    }

    // MARK: - Digital Edit Content

    private var digitalEditContent: some View {
        Group {
            ColorCodePicker(colorCode: $editingChannel.colorCode)
                .onChange(of: editingChannel.colorCode) { _, _ in
                    pushUpdate()
                }

            TimeslotPicker(timeslot: $editingChannel.timeSlot)
                .onChange(of: editingChannel.timeSlot) { _, _ in
                    pushUpdate()
                }

            LabeledContent("Contact ID") {
                TextField("Contact ID", value: $editingChannel.contactID, format: .number)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 100)
                    .onSubmit {
                        pushUpdate()
                    }
                    .accessibilityLabel("Contact ID")
            }
        }
    }

    // MARK: - Power Edit Content

    private var powerEditContent: some View {
        Group {
            PowerPicker(highPower: $editingChannel.txPowerHigh)
                .onChange(of: editingChannel.txPowerHigh) { _, _ in
                    pushUpdate()
                }

            BandwidthPicker(wideband: $editingChannel.bandwidthWide)
                .onChange(of: editingChannel.bandwidthWide) { _, _ in
                    pushUpdate()
                }

            Toggle("RX Only", isOn: $editingChannel.rxOnly)
                .onChange(of: editingChannel.rxOnly) { _, _ in
                    pushUpdate()
                }
                .accessibilityLabel("Receive only mode")
        }
    }

    // MARK: - Advanced Read-Only Content

    private var advancedReadOnlyContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            LabeledContent("Position", value: "\(editingChannel.channelIndex + 1)")
            LabeledContent("TOT Timeout", value: "\(editingChannel.totTimeout) seconds")
            LabeledContent("Allow Talkaround", value: editingChannel.allowTalkaround ? "Enabled" : "Disabled")
            if editingChannel.isDigital {
                LabeledContent("RX Group List", value: "\(editingChannel.rxGroupListID)")
                LabeledContent("Privacy", value: editingChannel.privacyType == 0 ? "None" : "Enabled")
            }
            LabeledContent("Auto Scan", value: editingChannel.autoScan ? "Enabled" : "Disabled")

            Text("Use 'More Options' for additional settings")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .padding(.top, 8)
        }
        .padding(.leading, 24)
        .padding(.vertical, 8)
    }
}

// MARK: - Add Zone Sheet

struct AddZoneSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var zoneName: String
    let onSave: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Text("Add New Zone")
                .font(.headline)

            TextField("Zone Name", text: $zoneName)
                .textFieldStyle(.roundedBorder)
                .frame(width: 250)
                .accessibilityLabel("Zone Name")

            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.escape)

                Button("Add") {
                    onSave()
                    dismiss()
                }
                .keyboardShortcut(.return)
                .disabled(zoneName.isEmpty)
            }
        }
        .padding(30)
    }
}

// MARK: - Rename Zone Sheet

struct RenameZoneSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var zoneName: String
    let currentName: String
    let onSave: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Text("Rename Zone")
                .font(.headline)

            TextField("Zone Name", text: $zoneName)
                .textFieldStyle(.roundedBorder)
                .frame(width: 250)
                .accessibilityLabel("Zone Name")

            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.escape)

                Button("Save") {
                    onSave()
                    dismiss()
                }
                .keyboardShortcut(.return)
                .disabled(zoneName.isEmpty)
            }
        }
        .padding(30)
        .onAppear {
            zoneName = currentName
        }
    }
}

// MARK: - Channel Editor Sheet

struct ChannelEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var editedChannel: ChannelData
    @State private var frequencyStep: RadioConstants.FrequencyStep = .step12_5kHz
    @Namespace private var formSections
    let onSave: (ChannelData) -> Void

    init(channel: ChannelData, onSave: @escaping (ChannelData) -> Void) {
        _editedChannel = State(initialValue: channel)
        self.onSave = onSave
    }

    /// Section identifiers for VoiceOver rotor navigation.
    private enum FormSection: String, CaseIterable {
        case basic = "Basic Information"
        case frequencies = "Frequencies"
        case powerTiming = "Power & Timing"
        case digital = "Digital (DMR) Settings"
        case advancedDigital = "Advanced Digital"
        case analogSignaling = "Analog Signaling"
        case analogOptions = "Analog Options"
        case privacy = "Privacy/Encryption"
        case signaling = "Signaling"
        case scanning = "Scanning"
        case mototrbo = "MOTOTRBO Features"

        /// Sections relevant for a digital channel.
        static var digitalSections: [FormSection] {
            [.basic, .frequencies, .powerTiming, .digital, .advancedDigital, .privacy, .signaling, .scanning, .mototrbo]
        }

        /// Sections relevant for an analog channel.
        static var analogSections: [FormSection] {
            [.basic, .frequencies, .powerTiming, .analogSignaling, .analogOptions, .privacy, .signaling, .scanning, .mototrbo]
        }
    }

    /// Active sections based on channel type.
    private var activeSections: [FormSection] {
        editedChannel.isDigital ? FormSection.digitalSections : FormSection.analogSections
    }

    var body: some View {
        NavigationStack {
            ScrollViewReader { scrollProxy in
                Form {
                    // MARK: - Basic Settings
                    Section("Basic Information") {
                        TextField("Channel Name", text: $editedChannel.name)
                            .accessibilityLabel("Channel Name")
                        ChannelModePicker(isDigital: $editedChannel.isDigital)
                        BandwidthPicker(wideband: $editedChannel.bandwidthWide)
                    }
                    .id(FormSection.basic)

                    // MARK: - Frequencies
                    Section {
                        FrequencyInput(frequencyHz: $editedChannel.rxFrequencyHz, step: frequencyStep, label: "RX Frequency")
                        FrequencyInput(frequencyHz: $editedChannel.txFrequencyHz, step: frequencyStep, label: "TX Frequency")

                        // Show offset for repeaters
                        if editedChannel.txFrequencyHz != editedChannel.rxFrequencyHz {
                            LabeledContent("TX Offset") {
                                Text(String(format: "%+.4f MHz", editedChannel.txOffsetMHz))
                                    .foregroundStyle(.secondary)
                            }
                        }

                        Picker("Frequency Step", selection: $frequencyStep) {
                            ForEach(RadioConstants.FrequencyStep.allCases, id: \.self) { step in
                                Text(step.displayName).tag(step)
                            }
                        }
                    } header: {
                        Text("Frequencies")
                    }
                    .id(FormSection.frequencies)

                    // MARK: - Power & Timing
                    Section("Power & Timing") {
                        PowerPicker(highPower: $editedChannel.txPowerHigh)
                        Toggle("RX Only", isOn: $editedChannel.rxOnly)

                        Stepper("TOT Timeout: \(editedChannel.totTimeout)s",
                                value: $editedChannel.totTimeout, in: 0...300, step: 15)
                            .accessibilityLabel("Timeout Timer")
                            .accessibilityValue("\(editedChannel.totTimeout) seconds")

                        Toggle("Allow Talkaround", isOn: $editedChannel.allowTalkaround)
                    }
                    .id(FormSection.powerTiming)

                    // MARK: - Digital Settings
                    if editedChannel.isDigital {
                        Section("Digital (DMR) Settings") {
                            ColorCodePicker(colorCode: $editedChannel.colorCode)
                            TimeslotPicker(timeslot: $editedChannel.timeSlot)

                            LabeledContent("Contact ID") {
                                TextField("Contact ID", value: $editedChannel.contactID, format: .number)
                                    .textFieldStyle(.roundedBorder)
                                    .frame(width: 100)
                                    .accessibilityLabel("DMR Contact ID")
                                    .accessibilityHint("Enter the contact DMR ID number")
                            }

                            ContactTypePicker(contactType: $editedChannel.contactType)
                        }
                        .id(FormSection.digital)

                        Section("Advanced Digital") {
                            ColorCodePicker(colorCode: $editedChannel.inboundColorCode, label: "Inbound CC")
                            ColorCodePicker(colorCode: $editedChannel.outboundColorCode, label: "Outbound CC")

                            Toggle("Dual Capacity Direct Mode", isOn: $editedChannel.dualCapacityDirectMode)

                            TimingLeaderPicker(preference: $editedChannel.timingLeaderPreference)

                            Toggle("Extended Range Direct Mode", isOn: $editedChannel.extendedRangeDirectMode)
                            Toggle("Compressed UDP Header", isOn: $editedChannel.compressedUDPHeader)

                            Picker("Text Message Type", selection: $editedChannel.textMessageType) {
                                Text("DMR Standard").tag(0)
                                Text("MOTOTRBO").tag(1)
                            }
                        }
                        .id(FormSection.advancedDigital)
                    }

                    // MARK: - Analog Settings
                    if !editedChannel.isDigital {
                        Section("Analog Signaling") {
                            SquelchTypePicker(squelchType: $editedChannel.rxSquelchType)

                            CTCSSPicker(toneHz: $editedChannel.txCTCSSHz, label: "TX CTCSS")
                            CTCSSPicker(toneHz: $editedChannel.rxCTCSSHz, label: "RX CTCSS")

                            DCSPicker(code: $editedChannel.txDCSCode, inverted: $editedChannel.dcsInvert, label: "TX DCS")
                            DCSPicker(code: $editedChannel.rxDCSCode, inverted: $editedChannel.dcsInvert, label: "RX DCS")
                        }
                        .id(FormSection.analogSignaling)

                        Section("Analog Options") {
                            Toggle("Scramble", isOn: $editedChannel.scrambleEnabled)
                            Toggle("Voice Emphasis", isOn: $editedChannel.voiceEmphasis)
                        }
                        .id(FormSection.analogOptions)
                    }

                    // MARK: - Privacy
                    Section("Privacy/Encryption") {
                        PrivacyTypePicker(privacyType: $editedChannel.privacyType)

                        if editedChannel.privacyType > 0 {
                            Stepper("Privacy Key: \(editedChannel.privacyKey)",
                                    value: $editedChannel.privacyKey, in: 0...255)
                                .accessibilityLabel("Privacy Key")
                                .accessibilityValue("\(editedChannel.privacyKey) of 255")

                            Toggle("Fixed Key Decryption", isOn: $editedChannel.fixedPrivacyKeyDecryption)
                        }

                        Toggle("Ignore RX Clear Voice", isOn: $editedChannel.ignoreRxClearVoice)
                    }
                    .id(FormSection.privacy)

                    // MARK: - Signaling
                    Section("Signaling") {
                        Toggle("ARS", isOn: $editedChannel.arsEnabled)
                        Toggle("Enhanced GNSS", isOn: $editedChannel.enhancedGNSSEnabled)
                        Toggle("Lone Worker", isOn: $editedChannel.loneWorker)
                        Toggle("Emergency Alarm Ack", isOn: $editedChannel.emergencyAlarmAck)
                        Toggle("ARTS", isOn: $editedChannel.artsEnabled)

                        Picker("TX Interrupt", selection: $editedChannel.txInterruptType) {
                            Text("Disabled").tag(0)
                            Text("Always Allow").tag(1)
                        }
                    }
                    .id(FormSection.signaling)

                    // MARK: - Scanning
                    Section("Scanning") {
                        Stepper("Scan List: \(editedChannel.scanListID)",
                                value: $editedChannel.scanListID, in: 0...255)
                            .accessibilityLabel("Scan List ID")
                            .accessibilityValue(editedChannel.scanListID == 0 ? "None" : "List \(editedChannel.scanListID)")

                        Toggle("Auto Scan", isOn: $editedChannel.autoScan)
                    }
                    .id(FormSection.scanning)

                    // MARK: - MOTOTRBO
                    Section("MOTOTRBO Features") {
                        Toggle("MOTOTRBO Link", isOn: $editedChannel.mototrboLinkEnabled)
                        Toggle("OTA Battery Management", isOn: $editedChannel.otaBatteryManagement)
                        Toggle("Audio Enhancement", isOn: $editedChannel.audioEnhancement)
                    }
                    .id(FormSection.mototrbo)
                }
                .formStyle(.grouped)
                .accessibilityRotor("Form Sections") {
                    ForEach(activeSections, id: \.self) { section in
                        AccessibilityRotorEntry(section.rawValue, id: section) {
                            withAnimation {
                                scrollProxy.scrollTo(section, anchor: .top)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Edit Channel")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(editedChannel)
                        dismiss()
                    }
                }
            }
        }
        .frame(minWidth: 550, minHeight: 650)
    }
}

#Preview {
    ZoneChannelView(searchText: "")
        .environment(AppCoordinator())
        .frame(width: 800, height: 500)
}
