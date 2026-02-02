import SwiftUI
import RadioProgrammer

/// View for previewing and confirming CSV channel imports.
struct ChannelImportPreviewView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppCoordinator.self) private var coordinator

    let importResult: CSVService.ChannelImportResult
    let onConfirm: () -> Void

    @State private var selectedRows: Set<Int> = []
    @State private var selectAll = true

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Summary header
                summaryHeader

                Divider()

                // Error/warning section
                if !importResult.errors.isEmpty || !importResult.warnings.isEmpty {
                    issuesSection
                    Divider()
                }

                // Preview table
                previewTable

                Divider()

                // Actions
                actionButtons
            }
            .navigationTitle("Import Channels")
            .frame(minWidth: 700, minHeight: 500)
        }
        .onAppear {
            // Select all valid rows by default
            selectedRows = Set(0..<importResult.channels.count)
        }
    }

    private var summaryHeader: some View {
        HStack(spacing: 20) {
            VStack(alignment: .leading) {
                Text("\(importResult.channels.count) channels parsed")
                    .font(.headline)
                Text("\(selectedRows.count) selected for import")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if !importResult.errors.isEmpty {
                Label("\(importResult.errors.count) errors", systemImage: "exclamationmark.circle.fill")
                    .foregroundStyle(.red)
            }

            if !importResult.warnings.isEmpty {
                Label("\(importResult.warnings.count) warnings", systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.yellow)
            }
        }
        .padding()
    }

    private var issuesSection: some View {
        DisclosureGroup("Issues") {
            ScrollView {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(importResult.errors) { error in
                        HStack {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.red)
                            Text("Row \(error.row): \(error.field) - \(error.message)")
                                .font(.caption)
                        }
                    }

                    ForEach(importResult.warnings, id: \.self) { warning in
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.yellow)
                            Text(warning)
                                .font(.caption)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxHeight: 100)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }

    private var previewTable: some View {
        Table(of: IndexedChannel.self, selection: $selectedRows) {
            TableColumn("Zone") { item in
                Text(item.zoneName)
                    .lineLimit(1)
            }
            .width(min: 80, ideal: 100)

            TableColumn("#") { item in
                Text("\(item.channel.channelIndex + 1)")
            }
            .width(30)

            TableColumn("Name") { item in
                Text(item.channel.name)
                    .lineLimit(1)
            }
            .width(min: 100, ideal: 150)

            TableColumn("RX Freq") { item in
                Text(String(format: "%.4f", item.channel.rxFrequencyMHz))
                    .monospacedDigit()
            }
            .width(80)

            TableColumn("TX Freq") { item in
                Text(String(format: "%.4f", item.channel.txFrequencyMHz))
                    .monospacedDigit()
            }
            .width(80)

            TableColumn("Mode") { item in
                Text(item.channel.isDigital ? "Digital" : "Analog")
            }
            .width(60)

            TableColumn("CC") { item in
                Text(item.channel.isDigital ? "\(item.channel.colorCode)" : "-")
            }
            .width(30)

            TableColumn("TS") { item in
                Text(item.channel.isDigital ? "\(item.channel.timeSlot)" : "-")
            }
            .width(30)

            TableColumn("Power") { item in
                Text(item.channel.txPowerHigh ? "High" : "Low")
            }
            .width(50)
        } rows: {
            ForEach(indexedChannels) { item in
                TableRow(item)
            }
        }
        .tableStyle(.bordered)
    }

    private var indexedChannels: [IndexedChannel] {
        importResult.channels.enumerated().map { index, tuple in
            IndexedChannel(id: index, zoneName: tuple.zoneName, channel: tuple.channel)
        }
    }

    private var actionButtons: some View {
        HStack {
            Toggle("Select All", isOn: $selectAll)
                .onChange(of: selectAll) { _, newValue in
                    if newValue {
                        selectedRows = Set(0..<importResult.channels.count)
                    } else {
                        selectedRows.removeAll()
                    }
                }

            Spacer()

            Button("Cancel") {
                dismiss()
            }
            .keyboardShortcut(.cancelAction)

            Button("Import \(selectedRows.count) Channels") {
                importSelectedChannels()
            }
            .keyboardShortcut(.defaultAction)
            .disabled(selectedRows.isEmpty)
        }
        .padding()
    }

    private func importSelectedChannels() {
        // Group channels by zone
        var zoneChannels: [String: [ChannelData]] = [:]

        for index in selectedRows.sorted() {
            guard index < importResult.channels.count else { continue }
            let (zoneName, channel) = importResult.channels[index]
            zoneChannels[zoneName, default: []].append(channel)
        }

        // Update the codeplug
        guard var codeplug = coordinator.parsedCodeplug else { return }

        for (zoneName, channels) in zoneChannels {
            // Find or create the zone
            if let zoneIndex = codeplug.zones.firstIndex(where: { $0.name == zoneName }) {
                // Append to existing zone
                var zone = codeplug.zones[zoneIndex]
                let startIndex = zone.channels.count
                for (i, var channel) in channels.enumerated() {
                    channel.zoneIndex = zoneIndex
                    channel.channelIndex = startIndex + i
                    zone.channels.append(channel)
                }
                codeplug.zones[zoneIndex] = zone
            } else {
                // Create new zone
                var newZone = ParsedZone()
                newZone.name = zoneName
                newZone.position = codeplug.zones.count
                for (i, var channel) in channels.enumerated() {
                    channel.zoneIndex = newZone.position
                    channel.channelIndex = i
                    newZone.channels.append(channel)
                }
                codeplug.zones.append(newZone)
            }
        }

        coordinator.parsedCodeplug = codeplug
        onConfirm()
        dismiss()
    }
}

/// Helper struct for table indexing.
private struct IndexedChannel: Identifiable {
    let id: Int
    let zoneName: String
    let channel: ChannelData
}

// MARK: - Contact Import Preview

/// View for previewing and confirming CSV contact imports.
struct ContactImportPreviewView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppCoordinator.self) private var coordinator

    let importResult: CSVService.ContactImportResult
    let onConfirm: () -> Void

    @State private var selectedRows: Set<Int> = []
    @State private var selectAll = true

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Summary header
                summaryHeader

                Divider()

                // Error/warning section
                if !importResult.errors.isEmpty || !importResult.warnings.isEmpty {
                    issuesSection
                    Divider()
                }

                // Preview table
                previewTable

                Divider()

                // Actions
                actionButtons
            }
            .navigationTitle("Import Contacts")
            .frame(minWidth: 600, minHeight: 400)
        }
        .onAppear {
            selectedRows = Set(0..<importResult.contacts.count)
        }
    }

    private var summaryHeader: some View {
        HStack(spacing: 20) {
            VStack(alignment: .leading) {
                Text("\(importResult.contacts.count) contacts parsed")
                    .font(.headline)
                Text("\(selectedRows.count) selected for import")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if !importResult.errors.isEmpty {
                Label("\(importResult.errors.count) errors", systemImage: "exclamationmark.circle.fill")
                    .foregroundStyle(.red)
            }

            if !importResult.warnings.isEmpty {
                Label("\(importResult.warnings.count) warnings", systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.yellow)
            }
        }
        .padding()
    }

    private var issuesSection: some View {
        DisclosureGroup("Issues") {
            ScrollView {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(importResult.errors) { error in
                        HStack {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.red)
                            Text("Row \(error.row): \(error.field) - \(error.message)")
                                .font(.caption)
                        }
                    }

                    ForEach(importResult.warnings, id: \.self) { warning in
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.yellow)
                            Text(warning)
                                .font(.caption)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxHeight: 100)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }

    private var previewTable: some View {
        Table(of: IndexedContact.self, selection: $selectedRows) {
            TableColumn("Name") { item in
                Text(item.contact.name)
                    .lineLimit(1)
            }
            .width(min: 150, ideal: 200)

            TableColumn("DMR ID") { item in
                Text("\(item.contact.dmrID)")
                    .monospacedDigit()
            }
            .width(100)

            TableColumn("Type") { item in
                Text(item.contact.contactType.rawValue)
            }
            .width(100)

            TableColumn("Receive Tone") { item in
                Text(item.contact.callReceiveTone ? "Yes" : "No")
            }
            .width(80)

            TableColumn("Call Alert") { item in
                Text(item.contact.callAlert ? "Yes" : "No")
            }
            .width(80)
        } rows: {
            ForEach(indexedContacts) { item in
                TableRow(item)
            }
        }
        .tableStyle(.bordered)
    }

    private var indexedContacts: [IndexedContact] {
        importResult.contacts.enumerated().map { index, contact in
            IndexedContact(id: index, contact: contact)
        }
    }

    private var actionButtons: some View {
        HStack {
            Toggle("Select All", isOn: $selectAll)
                .onChange(of: selectAll) { _, newValue in
                    if newValue {
                        selectedRows = Set(0..<importResult.contacts.count)
                    } else {
                        selectedRows.removeAll()
                    }
                }

            Spacer()

            Button("Cancel") {
                dismiss()
            }
            .keyboardShortcut(.cancelAction)

            Button("Import \(selectedRows.count) Contacts") {
                importSelectedContacts()
            }
            .keyboardShortcut(.defaultAction)
            .disabled(selectedRows.isEmpty)
        }
        .padding()
    }

    private func importSelectedContacts() {
        guard var codeplug = coordinator.parsedCodeplug else { return }

        for index in selectedRows.sorted() {
            guard index < importResult.contacts.count else { continue }
            let contact = importResult.contacts[index]
            codeplug.contacts.append(contact)
        }

        coordinator.parsedCodeplug = codeplug
        onConfirm()
        dismiss()
    }
}

/// Helper struct for table indexing.
private struct IndexedContact: Identifiable {
    let id: Int
    let contact: ParsedContact
}
