import SwiftUI
import RadioProgrammer

/// View for managing scan lists.
struct ScanListsView: View {
    @Environment(AppCoordinator.self) private var coordinator
    @State private var selectedScanListIndex: Int?
    @State private var showingAddScanList = false
    @State private var showingEditScanList = false
    @State private var showingDeleteAlert = false
    @State private var showingAddChannel = false

    var body: some View {
        HSplitView {
            // Left: Scan list list
            scanListListView
                .frame(minWidth: 200, maxWidth: 250)

            // Middle: Channels in scan list
            scanListChannelsView
                .frame(minWidth: 250, maxWidth: 350)

            // Right: Available channels
            availableChannelsView
                .frame(minWidth: 250)
        }
        .sheet(isPresented: $showingAddScanList) {
            ScanListEditorSheet(scanList: nil) { newList in
                addScanList(newList)
            }
        }
        .sheet(isPresented: $showingEditScanList) {
            if let list = selectedScanList {
                ScanListEditorSheet(scanList: list) { updatedList in
                    updateScanList(updatedList)
                }
            }
        }
        .alert("Delete Scan List?", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                deleteSelectedScanList()
            }
        } message: {
            Text("This will delete '\(selectedScanList?.name ?? "")'. This cannot be undone.")
        }
    }

    // MARK: - Scan List List

    private var scanListListView: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Scan Lists")
                    .font(.headline)
                Spacer()
                Text("\(coordinator.parsedCodeplug?.scanLists.count ?? 0)")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Button {
                    showingAddScanList = true
                } label: {
                    Image(systemName: "plus")
                }
                .buttonStyle(.borderless)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)

            Divider()

            if let scanLists = coordinator.parsedCodeplug?.scanLists, !scanLists.isEmpty {
                List(selection: $selectedScanListIndex) {
                    ForEach(Array(scanLists.enumerated()), id: \.offset) { index, list in
                        HStack {
                            Image(systemName: "magnifyingglass")
                                .foregroundStyle(.secondary)
                            Text(list.name)
                            Spacer()
                            Text("\(list.channelMembers.count)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .tag(index)
                        .contextMenu {
                            Button {
                                selectedScanListIndex = index
                                showingEditScanList = true
                            } label: {
                                Label("Edit", systemImage: "pencil")
                            }

                            Divider()

                            Button(role: .destructive) {
                                selectedScanListIndex = index
                                showingDeleteAlert = true
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                }
                .listStyle(.sidebar)
            } else {
                VStack {
                    ContentUnavailableView {
                        Label("No Scan Lists", systemImage: "magnifyingglass")
                    } description: {
                        Text("Create scan lists to group channels")
                    }

                    Button {
                        showingAddScanList = true
                    } label: {
                        Label("Add Scan List", systemImage: "plus")
                    }
                    .buttonStyle(.borderedProminent)
                    .padding(.bottom)
                }
            }
        }
    }

    // MARK: - Scan List Channels

    private var scanListChannelsView: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Channels in List")
                    .font(.headline)
                Spacer()
                if let list = selectedScanList {
                    Text("\(list.channelMembers.count)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)

            Divider()

            if let list = selectedScanList, !list.channelMembers.isEmpty {
                List {
                    ForEach(list.channelMembers) { member in
                        if let channel = getChannel(zoneIndex: member.zoneIndex, channelIndex: member.channelIndex) {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(channel.name)
                                        .font(.body)
                                    Text("Zone \(member.zoneIndex + 1), CH \(member.channelIndex + 1)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Button {
                                    removeChannelFromList(member)
                                } label: {
                                    Image(systemName: "minus.circle")
                                        .foregroundStyle(.red)
                                }
                                .buttonStyle(.borderless)
                            }
                        }
                    }
                    .onMove { from, to in
                        moveChannelsInList(from: from, to: to)
                    }
                }
                .listStyle(.inset)
            } else if selectedScanList != nil {
                ContentUnavailableView {
                    Label("No Channels", systemImage: "antenna.radiowaves.left.and.right")
                } description: {
                    Text("Drag channels from the right to add them")
                }
            } else {
                ContentUnavailableView {
                    Label("Select Scan List", systemImage: "magnifyingglass")
                } description: {
                    Text("Select a scan list to see its channels")
                }
            }
        }
    }

    // MARK: - Available Channels

    private var availableChannelsView: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Available Channels")
                    .font(.headline)
                Spacer()
            }
            .padding(.horizontal)
            .padding(.vertical, 8)

            Divider()

            if let zones = coordinator.parsedCodeplug?.zones, !zones.isEmpty {
                List {
                    ForEach(Array(zones.enumerated()), id: \.offset) { zoneIndex, zone in
                        Section(zone.name) {
                            ForEach(Array(zone.channels.enumerated()), id: \.offset) { channelIndex, channel in
                                HStack {
                                    Text(channel.name)
                                    Spacer()
                                    if selectedScanList != nil {
                                        let isInList = isChannelInSelectedList(zoneIndex: zoneIndex, channelIndex: channelIndex)
                                        Button {
                                            if isInList {
                                                removeChannelFromList(zoneIndex: zoneIndex, channelIndex: channelIndex)
                                            } else {
                                                addChannelToList(zoneIndex: zoneIndex, channelIndex: channelIndex)
                                            }
                                        } label: {
                                            Image(systemName: isInList ? "checkmark.circle.fill" : "plus.circle")
                                                .foregroundStyle(isInList ? .green : .blue)
                                        }
                                        .buttonStyle(.borderless)
                                    }
                                }
                            }
                        }
                    }
                }
                .listStyle(.inset)
            } else {
                ContentUnavailableView {
                    Label("No Channels", systemImage: "folder")
                } description: {
                    Text("Read from radio to see available channels")
                }
            }
        }
    }

    // MARK: - Helpers

    private var selectedScanList: ParsedScanList? {
        guard let lists = coordinator.parsedCodeplug?.scanLists,
              let index = selectedScanListIndex,
              index >= 0 && index < lists.count else { return nil }
        return lists[index]
    }

    private func getChannel(zoneIndex: Int, channelIndex: Int) -> ChannelData? {
        guard let zones = coordinator.parsedCodeplug?.zones,
              zoneIndex >= 0 && zoneIndex < zones.count,
              channelIndex >= 0 && channelIndex < zones[zoneIndex].channels.count else { return nil }
        return zones[zoneIndex].channels[channelIndex]
    }

    private func isChannelInSelectedList(zoneIndex: Int, channelIndex: Int) -> Bool {
        selectedScanList?.channelMembers.contains { $0.zoneIndex == zoneIndex && $0.channelIndex == channelIndex } ?? false
    }

    private func addScanList(_ list: ParsedScanList) {
        var lists = coordinator.parsedCodeplug?.scanLists ?? []
        lists.append(list)
        coordinator.parsedCodeplug?.scanLists = lists
        selectedScanListIndex = lists.count - 1
    }

    private func updateScanList(_ list: ParsedScanList) {
        guard var lists = coordinator.parsedCodeplug?.scanLists,
              let index = selectedScanListIndex,
              index >= 0 && index < lists.count else { return }
        lists[index] = list
        coordinator.parsedCodeplug?.scanLists = lists
    }

    private func deleteSelectedScanList() {
        guard var lists = coordinator.parsedCodeplug?.scanLists,
              let index = selectedScanListIndex,
              index >= 0 && index < lists.count else { return }
        lists.remove(at: index)
        coordinator.parsedCodeplug?.scanLists = lists
        if index >= lists.count {
            selectedScanListIndex = lists.isEmpty ? nil : lists.count - 1
        }
    }

    private func addChannelToList(zoneIndex: Int, channelIndex: Int) {
        guard var lists = coordinator.parsedCodeplug?.scanLists,
              let index = selectedScanListIndex,
              index >= 0 && index < lists.count else { return }

        let member = ScanListMember(zoneIndex: zoneIndex, channelIndex: channelIndex)
        lists[index].channelMembers.append(member)
        coordinator.parsedCodeplug?.scanLists = lists
    }

    private func removeChannelFromList(_ member: ScanListMember) {
        guard var lists = coordinator.parsedCodeplug?.scanLists,
              let index = selectedScanListIndex,
              index >= 0 && index < lists.count else { return }

        lists[index].channelMembers.removeAll { $0.id == member.id }
        coordinator.parsedCodeplug?.scanLists = lists
    }

    private func removeChannelFromList(zoneIndex: Int, channelIndex: Int) {
        guard var lists = coordinator.parsedCodeplug?.scanLists,
              let index = selectedScanListIndex,
              index >= 0 && index < lists.count else { return }

        lists[index].channelMembers.removeAll { $0.zoneIndex == zoneIndex && $0.channelIndex == channelIndex }
        coordinator.parsedCodeplug?.scanLists = lists
    }

    private func moveChannelsInList(from source: IndexSet, to destination: Int) {
        guard var lists = coordinator.parsedCodeplug?.scanLists,
              let index = selectedScanListIndex,
              index >= 0 && index < lists.count else { return }

        lists[index].channelMembers.move(fromOffsets: source, toOffset: destination)
        coordinator.parsedCodeplug?.scanLists = lists
    }
}

// MARK: - Scan List Editor Sheet

struct ScanListEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var talkbackEnabled: Bool
    @State private var holdTime: UInt16

    let isNew: Bool
    let onSave: (ParsedScanList) -> Void

    init(scanList: ParsedScanList?, onSave: @escaping (ParsedScanList) -> Void) {
        self.isNew = scanList == nil
        self.onSave = onSave
        let list = scanList ?? ParsedScanList()
        _name = State(initialValue: list.name)
        _talkbackEnabled = State(initialValue: list.talkbackEnabled)
        _holdTime = State(initialValue: list.holdTime)
    }

    var body: some View {
        VStack(spacing: 20) {
            Text(isNew ? "Add Scan List" : "Edit Scan List")
                .font(.headline)

            Form {
                TextField("Scan List Name", text: $name)

                Toggle("Talkback Enabled", isOn: $talkbackEnabled)

                Stepper("Hold Time: \(holdTime)ms", value: $holdTime, in: 100...5000, step: 100)
            }
            .formStyle(.grouped)
            .frame(height: 200)

            HStack {
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.escape)

                Button("Save") {
                    var list = ParsedScanList(name: name)
                    list.talkbackEnabled = talkbackEnabled
                    list.holdTime = holdTime
                    onSave(list)
                    dismiss()
                }
                .keyboardShortcut(.return)
                .disabled(name.isEmpty)
            }
        }
        .padding(30)
        .frame(minWidth: 350)
    }
}

#Preview {
    ScanListsView()
        .environment(AppCoordinator())
        .frame(width: 800, height: 500)
}
