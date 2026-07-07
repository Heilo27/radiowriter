import SwiftUI
import RadioModelCore
import UniformTypeIdentifiers

/// Displays the raw ISH (Item Storage Header) record dump captured during a
/// live radio read. This is the "discovery run" view: when radiowriter reads a
/// codeplug it enumerates every ISH record on the radio but does NOT yet decode
/// which (partition, type, id) maps to channels vs. contacts vs. zones — CPS
/// resolves that from a metadata DB we don't have. This view surfaces the raw
/// records so the mapping can be worked out against a real radio.
///
/// Records group by partition, then by type. Each row shows id / size and the
/// first bytes as hex. The whole dump can be exported for offline analysis.
struct IshRecordInspectorView: View {
    let records: [IshRecordDump]

    @State private var selectedRecordID: String?
    @State private var showingExporter = false

    private var groupedByPartition: [(partition: UInt8, types: [(type: UInt16, records: [IshRecordDump])])] {
        let byPartition = Dictionary(grouping: records, by: { $0.partition })
        return byPartition.keys.sorted().map { partition in
            let recs = byPartition[partition] ?? []
            let byType = Dictionary(grouping: recs, by: { $0.type })
            let types = byType.keys.sorted().map { type in
                (type: type, records: (byType[type] ?? []).sorted { $0.recordID < $1.recordID })
            }
            return (partition: partition, types: types)
        }
    }

    private var selectedRecord: IshRecordDump? {
        records.first { $0.id == selectedRecordID }
    }

    var body: some View {
        Group {
            if records.isEmpty {
                ContentUnavailableView {
                    Label("No ISH Records", systemImage: "tray")
                } description: {
                    Text("Read a codeplug from a connected radio to capture its ISH record layout.")
                }
            } else {
                HSplitView {
                    recordList
                        .frame(minWidth: 320, idealWidth: 380)
                    recordDetail
                        .frame(minWidth: 300)
                }
            }
        }
        .navigationTitle("ISH Diagnostics")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Export Dump", systemImage: "square.and.arrow.up") {
                    showingExporter = true
                }
                .disabled(records.isEmpty)
                .help("Export all ISH records as text for offline analysis")
            }
        }
        .fileExporter(
            isPresented: $showingExporter,
            document: IshDumpDocument(text: exportText),
            contentType: .plainText,
            defaultFilename: "ish-dump"
        ) { _ in }
    }

    // MARK: - Record list (grouped)

    private var recordList: some View {
        List(selection: $selectedRecordID) {
            summarySection
            ForEach(groupedByPartition, id: \.partition) { group in
                Section("Partition \(group.partition)") {
                    ForEach(group.types, id: \.type) { typeGroup in
                        DisclosureGroup {
                            ForEach(typeGroup.records) { record in
                                recordRow(record)
                                    .tag(record.id)
                            }
                        } label: {
                            HStack {
                                Text("Type 0x\(String(format: "%04X", typeGroup.type))")
                                    .font(.system(.body, design: .monospaced))
                                Spacer()
                                Text("\(typeGroup.records.count)")
                                    .foregroundStyle(.secondary)
                                    .font(.caption)
                            }
                        }
                    }
                }
            }
        }
        .listStyle(.sidebar)
    }

    private var summarySection: some View {
        Section {
            LabeledContent("Total records", value: "\(records.count)")
            LabeledContent("Partitions", value: "\(Set(records.map(\.partition)).count)")
            LabeledContent("Types", value: "\(Set(records.map(\.type)).count)")
            LabeledContent("Total bytes", value: ByteCountFormatter.string(
                fromByteCount: Int64(records.reduce(0) { $0 + $1.data.count }),
                countStyle: .memory))
        } header: {
            Text("Summary")
        }
    }

    private func recordRow(_ record: IshRecordDump) -> some View {
        HStack {
            Text("ID 0x\(String(format: "%04X", record.recordID))")
                .font(.system(.callout, design: .monospaced))
            Spacer()
            Text("\(record.data.count) B")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Detail (hex)

    @ViewBuilder
    private var recordDetail: some View {
        if let record = selectedRecord {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    GroupBox("Record") {
                        VStack(alignment: .leading, spacing: 4) {
                            LabeledContent("Partition", value: "\(record.partition)")
                            LabeledContent("Type", value: "0x\(String(format: "%04X", record.type))")
                            LabeledContent("ID", value: "0x\(String(format: "%04X", record.recordID))")
                            LabeledContent("Item size", value: "\(record.itemSize) bytes")
                            LabeledContent("Data length", value: "\(record.data.count) bytes")
                        }
                        .font(.system(.body, design: .monospaced))
                    }

                    GroupBox("Hex") {
                        Text(hexDump(record.data))
                            .font(.system(.caption, design: .monospaced))
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding()
            }
        } else {
            ContentUnavailableView(
                "Select a Record",
                systemImage: "doc.text.magnifyingglass",
                description: Text("Choose an ISH record to inspect its bytes.")
            )
        }
    }

    // MARK: - Hex formatting

    private func hexDump(_ data: Data) -> String {
        var lines: [String] = []
        let bytes = [UInt8](data)
        var offset = 0
        while offset < bytes.count {
            let chunk = bytes[offset..<min(offset + 16, bytes.count)]
            let hex = chunk.map { String(format: "%02X", $0) }.joined(separator: " ")
            let ascii = chunk.map { (32...126).contains($0) ? String(UnicodeScalar($0)) : "." }.joined()
            let padded = hex.padding(toLength: 47, withPad: " ", startingAt: 0)
            lines.append(String(format: "%04X  %@  %@", offset, padded, ascii))
            offset += 16
        }
        return lines.joined(separator: "\n")
    }

    private var exportText: String {
        var out = "ISH Record Dump\n"
        out += "Total records: \(records.count)\n\n"
        for group in groupedByPartition {
            out += "== Partition \(group.partition) ==\n"
            for typeGroup in group.types {
                out += "  Type 0x\(String(format: "%04X", typeGroup.type)) (\(typeGroup.records.count) records)\n"
                for record in typeGroup.records {
                    out += "    id=0x\(String(format: "%04X", record.recordID)) size=\(record.itemSize) len=\(record.data.count)\n"
                    out += "      " + record.data.map { String(format: "%02X", $0) }.joined(separator: " ") + "\n"
                }
            }
            out += "\n"
        }
        return out
    }
}

/// Minimal plain-text document wrapper for exporting the ISH dump.
private struct IshDumpDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.plainText] }
    var text: String

    init(text: String) { self.text = text }

    init(configuration: ReadConfiguration) throws {
        if let data = configuration.file.regularFileContents {
            text = String(decoding: data, as: UTF8.self)
        } else {
            text = ""
        }
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: Data(text.utf8))
    }
}
