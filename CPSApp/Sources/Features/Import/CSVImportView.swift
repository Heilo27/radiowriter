import SwiftUI
import RadioProgrammer
import RadioModelCore

// MARK: - CSV Format Spec Sheet

/// Full format specification sheet shown when user taps "View Format Specification".
private struct ChannelFormatSpecView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Channel CSV columns are matched by header name — column order does not matter.")
                        .foregroundStyle(.secondary)

                    Group {
                        specSection("Required Columns") {
                            specRow("Channel Name (or Name)", "Display name for the channel (e.g., VHF Simplex)")
                            specRow("RX Frequency (MHz)", "Receive frequency in MHz (e.g., 146.520000)")
                        }

                        specSection("Optional Columns") {
                            specRow("Zone Name", "Zone the channel belongs to. Creates zone if missing.")
                            specRow("TX Frequency (MHz)", "Transmit frequency in MHz. Defaults to RX if omitted.")
                            specRow("Mode", "\"Analog\" or \"Digital\". Default: Analog")
                            specRow("Color Code", "DMR color code 0–15. Required for Digital channels.")
                            specRow("Time Slot", "DMR time slot 1 or 2. Default: 1")
                            specRow("TX Power", "\"High\" or \"Low\". Default: High")
                            specRow("Bandwidth (kHz)", "Channel bandwidth: 12.5 or 25. Default: 12.5")
                            specRow("Squelch", "Squelch level 0–9. Default: 5")
                            specRow("RX CTCSS/DCS", "Receive tone/code (e.g., 100.0, D023N)")
                            specRow("TX CTCSS/DCS", "Transmit tone/code (e.g., 100.0, D023N)")
                        }
                    }

                    Divider()

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Example Row (Analog)").font(.headline)
                        Text("Zone 1,1,VHF Simplex,146.520000,146.520000,Analog,,,,,High,12.5,,,90,100.0,100.0,,,CTCSS/DCS,None,")
                            .font(.caption.monospaced())
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Example Row (Digital)").font(.headline)
                        Text("Zone 1,2,DMR Talk,446.500000,441.500000,Digital,1,1,99,Group,High,12.5,,,90,,,,Carrier,None,")
                            .font(.caption.monospaced())
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                    }

                    Text("Download a pre-filled template via Tools → Export → Download Channel Template.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding()
            }
            .navigationTitle("Channel CSV Format")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .frame(minWidth: 500, minHeight: 550)
    }

    private func specSection(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.headline)
            content()
        }
    }

    private func specRow(_ column: String, _ description: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(column)
                .font(.caption.monospaced())
                .foregroundStyle(.primary)
                .frame(width: 160, alignment: .leading)
            Text(description)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(.leading, 8)
    }
}

/// Full format specification for contacts CSV.
private struct ContactFormatSpecView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Contact CSV columns are matched by header name — column order does not matter.")
                        .foregroundStyle(.secondary)

                    Group {
                        specSection("Required Columns") {
                            specRow("Contact Name (or Name)", "Contact display name (e.g., Local Repeater)")
                            specRow("DMR ID (or Radio ID)", "DMR radio identifier — integer 1 to 16,777,215")
                        }

                        specSection("Optional Columns") {
                            specRow("Call Type (or Type)", "\"Private\", \"Group\", or \"All Call\". Default: Group")
                            specRow("Receive Tone", "\"Yes\" or \"No\" — alert tone on incoming call. Default: No")
                            specRow("Call Alert", "\"Yes\" or \"No\" — call alert notification. Default: No")
                        }
                    }

                    Divider()

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Example Rows").font(.headline)
                        Text(verbatim: "Local Talkgroup,3161,Group,No,No\nMy Radio,1234567,Private,Yes,No")
                            .font(.caption.monospaced())
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                    }

                    Text("Download a pre-filled template via Tools → Export → Download Contact Template.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding()
            }
            .navigationTitle("Contact CSV Format")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .frame(minWidth: 450, minHeight: 400)
    }

    private func specSection(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.headline)
            content()
        }
    }

    private func specRow(_ column: String, _ description: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(column)
                .font(.caption.monospaced())
                .foregroundStyle(.primary)
                .frame(width: 180, alignment: .leading)
            Text(description)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(.leading, 8)
    }
}

// MARK: - Channel Import Preview

/// View for previewing and confirming CSV channel imports.
struct ChannelImportPreviewView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppCoordinator.self) private var coordinator

    let importResult: CSVService.ChannelImportResult
    let onConfirm: () -> Void

    @State private var selectedRows: Set<Int> = []
    @State private var selectAll = true
    @State private var isImporting = false
    @State private var showingFormatSpec = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Format guide banner
                formatGuideBanner

                Divider()

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
        .sheet(isPresented: $showingFormatSpec) {
            ChannelFormatSpecView()
        }
    }

    private var formatGuideBanner: some View {
        HStack(spacing: 12) {
            Image(systemName: "info.circle.fill")
                .foregroundStyle(.blue)

            VStack(alignment: .leading, spacing: 2) {
                Text("Required columns: Channel Name, RX Frequency (MHz)")
                    .font(.caption.bold())
                Text("Optional: Zone Name, TX Frequency, Mode, Power, Color Code, Time Slot, CTCSS/DCS…")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button("Format Specification") {
                showingFormatSpec = true
            }
            .font(.caption)
            .buttonStyle(.link)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(.blue.opacity(0.05))
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

            Button {
                isImporting = true
                importSelectedChannels()
            } label: {
                if isImporting {
                    HStack(spacing: 6) {
                        ProgressView().controlSize(.small)
                        Text("Importing...")
                    }
                } else {
                    Text("Import \(selectedRows.count) Channels")
                }
            }
            .keyboardShortcut(.defaultAction)
            .disabled(selectedRows.isEmpty || isImporting)
        }
        .padding()
    }

    private func importSelectedChannels() {
        // Build a filtered result containing only the selected rows
        let selectedChannels = selectedRows.sorted().compactMap { index -> (zoneName: String, channel: ChannelData)? in
            guard index < importResult.channels.count else { return nil }
            return importResult.channels[index]
        }
        let filteredResult = CSVService.ChannelImportResult(
            channels: selectedChannels,
            errors: [],
            warnings: []
        )
        coordinator.applyChannelImport(filteredResult)
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
    @State private var isImporting = false
    @State private var showingFormatSpec = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Format guide banner
                formatGuideBanner

                Divider()

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
        .sheet(isPresented: $showingFormatSpec) {
            ContactFormatSpecView()
        }
    }

    private var formatGuideBanner: some View {
        HStack(spacing: 12) {
            Image(systemName: "info.circle.fill")
                .foregroundStyle(.blue)

            VStack(alignment: .leading, spacing: 2) {
                Text("Required columns: Contact Name, DMR ID")
                    .font(.caption.bold())
                Text("Optional: Call Type (Group/Private/All Call), Receive Tone, Call Alert")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button("Format Specification") {
                showingFormatSpec = true
            }
            .font(.caption)
            .buttonStyle(.link)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(.blue.opacity(0.05))
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
                Text(item.contact.callReceiveTone ? "Enabled" : "Disabled")
            }
            .width(80)

            TableColumn("Call Alert") { item in
                Text(item.contact.callAlert ? "Enabled" : "Disabled")
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

            Button {
                isImporting = true
                importSelectedContacts()
            } label: {
                if isImporting {
                    HStack(spacing: 6) {
                        ProgressView().controlSize(.small)
                        Text("Importing...")
                    }
                } else {
                    Text("Import \(selectedRows.count) Contacts")
                }
            }
            .keyboardShortcut(.defaultAction)
            .disabled(selectedRows.isEmpty || isImporting)
        }
        .padding()
    }

    private func importSelectedContacts() {
        // Build a filtered result containing only the selected rows
        let selectedContacts = selectedRows.sorted().compactMap { index -> ParsedContact? in
            guard index < importResult.contacts.count else { return nil }
            return importResult.contacts[index]
        }
        let filteredResult = CSVService.ContactImportResult(
            contacts: selectedContacts,
            errors: [],
            warnings: []
        )
        coordinator.applyContactImport(filteredResult)
        onConfirm()
        dismiss()
    }
}

/// Helper struct for table indexing.
private struct IndexedContact: Identifiable {
    let id: Int
    let contact: ParsedContact
}
