import SwiftUI
import RadioProgrammer
import RadioCore

/// View displaying zones and channels from a parsed codeplug.
struct ZoneChannelView: View {
    @Environment(AppCoordinator.self) private var coordinator
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
        coordinator.parsedCodeplug?.zones = zones
        selectedZoneIndex = zones.count - 1
        newZoneName = ""
    }

    private func renameSelectedZone() {
        guard !newZoneName.isEmpty,
              var zones = coordinator.parsedCodeplug?.zones,
              selectedZoneIndex >= 0 && selectedZoneIndex < zones.count else { return }
        zones[selectedZoneIndex].name = newZoneName
        coordinator.parsedCodeplug?.zones = zones
        newZoneName = ""
    }

    private func deleteSelectedZone() {
        guard var zones = coordinator.parsedCodeplug?.zones,
              selectedZoneIndex >= 0 && selectedZoneIndex < zones.count else { return }
        zones.remove(at: selectedZoneIndex)
        coordinator.parsedCodeplug?.zones = zones
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
        coordinator.parsedCodeplug?.zones = zones
        selectedChannelIndex = channelCount
    }

    private func deleteSelectedChannel() {
        guard var zones = coordinator.parsedCodeplug?.zones,
              selectedZoneIndex >= 0 && selectedZoneIndex < zones.count,
              let channelIndex = selectedChannelIndex,
              channelIndex >= 0 && channelIndex < zones[selectedZoneIndex].channels.count else { return }

        zones[selectedZoneIndex].channels.remove(at: channelIndex)
        coordinator.parsedCodeplug?.zones = zones

        if channelIndex >= zones[selectedZoneIndex].channels.count {
            selectedChannelIndex = zones[selectedZoneIndex].channels.isEmpty ? nil : zones[selectedZoneIndex].channels.count - 1
        }
    }

    private func updateChannel(_ channel: ChannelData) {
        guard var zones = coordinator.parsedCodeplug?.zones,
              selectedZoneIndex >= 0 && selectedZoneIndex < zones.count,
              let channelIndex = selectedChannelIndex,
              channelIndex >= 0 && channelIndex < zones[selectedZoneIndex].channels.count else { return }

        zones[selectedZoneIndex].channels[channelIndex] = channel
        coordinator.parsedCodeplug?.zones = zones
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
                List(selection: $selectedZoneIndex) {
                    ForEach(Array(zones.enumerated()), id: \.offset) { index, zone in
                        HStack {
                            Image(systemName: "folder")
                                .foregroundStyle(.secondary)
                                .accessibilityHidden(true)
                            Text(zone.name)
                            Spacer()
                            Text("\(zone.channels.count)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .tag(index)
                        .contextMenu {
                            Button {
                                selectedZoneIndex = index
                                newZoneName = zone.name
                                showingRenameZone = true
                            } label: {
                                Label("Rename", systemImage: "pencil")
                            }

                            Divider()

                            Button(role: .destructive) {
                                selectedZoneIndex = index
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
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(Array(zone.channels.enumerated()), id: \.offset) { index, channel in
                            Button {
                                selectedChannelIndex = index
                            } label: {
                                ParsedChannelRow(channel: channel, index: index)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(selectedChannelIndex == index ? Color.accentColor.opacity(0.2) : Color.clear)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Channel \(index + 1): \(channel.name)")
                            .accessibilityHint("Double-tap to edit")
                            .accessibilityAddTraits(selectedChannelIndex == index ? .isSelected : [])
                            .onTapGesture(count: 2) {
                                selectedChannelIndex = index
                                showingChannelEditor = true
                            }
                            .contextMenu {
                                    Button {
                                        selectedChannelIndex = index
                                        showingChannelEditor = true
                                    } label: {
                                        Label("Edit", systemImage: "pencil")
                                    }

                                    Divider()

                                    Button(role: .destructive) {
                                        selectedChannelIndex = index
                                        showingDeleteChannelAlert = true
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                        }
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

    private func moveChannels(from source: IndexSet, to destination: Int) {
        guard var zones = coordinator.parsedCodeplug?.zones,
              selectedZoneIndex >= 0 && selectedZoneIndex < zones.count else { return }

        zones[selectedZoneIndex].channels.move(fromOffsets: source, toOffset: destination)
        coordinator.parsedCodeplug?.zones = zones
    }

    // MARK: - Channel Detail

    private var channelDetailView: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header with Edit button
            HStack {
                Text("Channel Details")
                    .font(.headline)
                Spacer()

                if selectedChannel != nil {
                    Button {
                        showingChannelEditor = true
                    } label: {
                        Label("Edit", systemImage: "pencil")
                    }
                    .buttonStyle(.bordered)
                    .accessibilityLabel("Edit selected channel")
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)

            Divider()

            if let channel = selectedChannel {
                ChannelDetailView(channel: channel)
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
}

// MARK: - Channel Row

struct ParsedChannelRow: View {
    let channel: ChannelData
    let index: Int

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

                HStack(spacing: 8) {
                    // Frequency
                    Text(String(format: "%.4f MHz", channel.rxFrequencyMHz))
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)

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

            // Power indicator
            Text(channel.txPowerHigh ? "H" : "L")
                .font(.caption.bold())
                .foregroundStyle(channel.txPowerHigh ? .red : .green)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(channel.txPowerHigh ? Color.red.opacity(0.1) : Color.green.opacity(0.1))
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
            SettingRow("Channel Name", value: channel.name)
            SettingRow("Position", value: "\(channel.channelIndex + 1)")
            SettingRow("Channel Type", value: channel.channelTypeDisplay)
            SettingRow("Bandwidth", value: channel.bandwidthDisplay)
            if !channel.voiceAnnouncement.isEmpty {
                SettingRow("Voice Announcement", value: channel.voiceAnnouncement)
            }
        }
        .padding(.leading, 24)
        .padding(.vertical, 8)
    }

    // MARK: - Frequency Content

    private var frequencyContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            SettingRow("RX Frequency", value: String(format: "%.5f MHz", channel.rxFrequencyMHz))
            SettingRow("TX Frequency", value: String(format: "%.5f MHz", channel.txFrequencyMHz))

            if channel.rxFrequencyHz != channel.txFrequencyHz {
                SettingRow("TX Offset", value: String(format: "%+.4f MHz", channel.txOffsetMHz))
                SettingRow("Mode", value: channel.txOffsetMHz > 0 ? "Repeater (+)" : "Repeater (-)")
            } else {
                SettingRow("Mode", value: "Simplex")
            }
        }
        .padding(.leading, 24)
        .padding(.vertical, 8)
    }

    // MARK: - Power & Timing

    private var powerTimingContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            SettingRow("TX Power", value: channel.powerDisplay)
            SettingRow("RX Only", value: channel.rxOnly ? "Yes" : "No")
            SettingRow("TOT Timeout", value: "\(channel.totTimeout) seconds")
            SettingRow("Allow Talkaround", value: channel.allowTalkaround ? "Yes" : "No")
        }
        .padding(.leading, 24)
        .padding(.vertical, 8)
    }

    // MARK: - Digital Settings

    private var digitalSettingsContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            SettingRow("Color Code", value: "\(channel.colorCode)")
            SettingRow("Time Slot", value: "Slot \(channel.timeSlot)")
            SettingRow("Contact ID", value: channel.contactID > 0 ? "\(channel.contactID)" : "None")
            SettingRow("Contact Type", value: channel.contactTypeDisplay)
            SettingRow("RX Group List", value: channel.rxGroupListID > 0 ? "List \(channel.rxGroupListID)" : "None")
        }
        .padding(.leading, 24)
        .padding(.vertical, 8)
    }

    // MARK: - Advanced Digital

    private var advancedDigitalContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            SettingRow("Inbound Color Code", value: "\(channel.inboundColorCode)")
            SettingRow("Outbound Color Code", value: "\(channel.outboundColorCode)")
            SettingRow("Dual Capacity Direct Mode", value: channel.dualCapacityDirectMode ? "Enabled" : "Disabled")
            SettingRow("Timing Leader Preference", value: channel.timingLeaderDisplay)
            SettingRow("Extended Range Direct Mode", value: channel.extendedRangeDirectMode ? "Enabled" : "Disabled")
            SettingRow("Window Size", value: "\(channel.windowSize)")
            SettingRow("Compressed UDP Header", value: channel.compressedUDPHeader ? "Enabled" : "Disabled")
            SettingRow("Text Message Type", value: channel.textMessageType == 0 ? "DMR Standard" : "MOTOTRBO")
        }
        .padding(.leading, 24)
        .padding(.vertical, 8)
    }

    // MARK: - Analog Settings

    private var analogSettingsContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            SettingRow("RX Squelch Type", value: channel.squelchTypeDisplay)

            if channel.txCTCSSHz > 0 {
                SettingRow("TX CTCSS", value: String(format: "%.1f Hz", channel.txCTCSSHz))
            } else {
                SettingRow("TX CTCSS", value: "None")
            }

            if channel.rxCTCSSHz > 0 {
                SettingRow("RX CTCSS", value: String(format: "%.1f Hz", channel.rxCTCSSHz))
            } else {
                SettingRow("RX CTCSS", value: "None")
            }

            if channel.txDCSCode > 0 {
                SettingRow("TX DCS", value: String(format: "D%03o", channel.txDCSCode))
            } else {
                SettingRow("TX DCS", value: "None")
            }

            if channel.rxDCSCode > 0 {
                SettingRow("RX DCS", value: String(format: "D%03o", channel.rxDCSCode))
            } else {
                SettingRow("RX DCS", value: "None")
            }

            SettingRow("DCS Invert", value: channel.dcsInvert ? "Yes" : "No")
            SettingRow("Scramble", value: channel.scrambleEnabled ? "Enabled" : "Disabled")
            SettingRow("Voice Emphasis", value: channel.voiceEmphasis ? "Enabled" : "Disabled")
        }
        .padding(.leading, 24)
        .padding(.vertical, 8)
    }

    // MARK: - Privacy

    private var privacyContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            SettingRow("Privacy Type", value: channel.privacyTypeDisplay)

            if channel.privacyType > 0 {
                SettingRow("Privacy Key", value: "\(channel.privacyKey)")
                if !channel.privacyAlias.isEmpty {
                    SettingRow("Privacy Alias", value: channel.privacyAlias)
                }
                SettingRow("Fixed Key Decryption", value: channel.fixedPrivacyKeyDecryption ? "Enabled" : "Disabled")
            }

            SettingRow("Ignore RX Clear Voice", value: channel.ignoreRxClearVoice ? "Yes" : "No")
        }
        .padding(.leading, 24)
        .padding(.vertical, 8)
    }

    // MARK: - Signaling

    private var signalingContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            SettingRow("ARS", value: channel.arsEnabled ? "Enabled" : "Disabled")
            SettingRow("Enhanced GNSS", value: channel.enhancedGNSSEnabled ? "Enabled" : "Disabled")
            SettingRow("Lone Worker", value: channel.loneWorker ? "Enabled" : "Disabled")
            SettingRow("Emergency Alarm Ack", value: channel.emergencyAlarmAck ? "Enabled" : "Disabled")
            SettingRow("TX Interrupt", value: channel.txInterruptType == 0 ? "Disabled" : "Always Allow")
            SettingRow("ARTS", value: channel.artsEnabled ? "Enabled" : "Disabled")
            if !channel.rasAlias.isEmpty {
                SettingRow("RAS Alias", value: channel.rasAlias)
            }
        }
        .padding(.leading, 24)
        .padding(.vertical, 8)
    }

    // MARK: - Scanning

    private var scanningContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            SettingRow("Scan List", value: channel.scanListID > 0 ? "List \(channel.scanListID)" : "None")
            SettingRow("Auto Scan", value: channel.autoScan ? "Enabled" : "Disabled")
        }
        .padding(.leading, 24)
        .padding(.vertical, 8)
    }

    // MARK: - MOTOTRBO Features

    private var mototrboContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            SettingRow("MOTOTRBO Link", value: channel.mototrboLinkEnabled ? "Enabled" : "Disabled")
            SettingRow("OTA Battery Management", value: channel.otaBatteryManagement ? "Enabled" : "Disabled")
            SettingRow("Audio Enhancement", value: channel.audioEnhancement ? "Enabled" : "Disabled")
            if !channel.phoneSystem.isEmpty {
                SettingRow("Phone System", value: channel.phoneSystem)
            }
        }
        .padding(.leading, 24)
        .padding(.vertical, 8)
    }
}

// MARK: - Setting Row

struct SettingRow: View {
    let label: String
    let value: String

    init(_ label: String, value: String) {
        self.label = label
        self.value = value
    }

    var body: some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.medium)
        }
        .font(.callout)
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
    let onSave: (ChannelData) -> Void

    init(channel: ChannelData, onSave: @escaping (ChannelData) -> Void) {
        _editedChannel = State(initialValue: channel)
        self.onSave = onSave
    }

    var body: some View {
        NavigationStack {
            Form {
                // MARK: - Basic Settings
                Section("Basic Information") {
                    TextField("Channel Name", text: $editedChannel.name)
                        .accessibilityLabel("Channel Name")
                    ChannelModePicker(isDigital: $editedChannel.isDigital)
                    BandwidthPicker(wideband: $editedChannel.bandwidthWide)
                }

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

                    Section("Analog Options") {
                        Toggle("Scramble", isOn: $editedChannel.scrambleEnabled)
                        Toggle("Voice Emphasis", isOn: $editedChannel.voiceEmphasis)
                    }
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

                // MARK: - Scanning
                Section("Scanning") {
                    Stepper("Scan List: \(editedChannel.scanListID)",
                            value: $editedChannel.scanListID, in: 0...255)
                        .accessibilityLabel("Scan List ID")
                        .accessibilityValue(editedChannel.scanListID == 0 ? "None" : "List \(editedChannel.scanListID)")

                    Toggle("Auto Scan", isOn: $editedChannel.autoScan)
                }

                // MARK: - MOTOTRBO
                Section("MOTOTRBO Features") {
                    Toggle("MOTOTRBO Link", isOn: $editedChannel.mototrboLinkEnabled)
                    Toggle("OTA Battery Management", isOn: $editedChannel.otaBatteryManagement)
                    Toggle("Audio Enhancement", isOn: $editedChannel.audioEnhancement)
                }
            }
            .formStyle(.grouped)
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
    ZoneChannelView()
        .environment(AppCoordinator())
        .frame(width: 800, height: 500)
}
