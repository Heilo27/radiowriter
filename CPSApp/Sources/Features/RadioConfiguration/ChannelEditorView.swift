import SwiftUI
import RadioCore
import RadioModelCore

/// Table-based channel editor with inline editing, drag-to-reorder, and context menus.
struct ChannelEditorView: View {
    let codeplug: Codeplug
    let modelIdentifier: String
    @State private var channels: [ChannelRow] = []
    @State private var selection: Set<Int> = []
    @State private var sortOrder: [KeyPathComparator<ChannelRow>] = []

    var body: some View {
        VStack(spacing: 0) {
            Table(channels, selection: $selection, sortOrder: $sortOrder) {
                TableColumn("#") { row in
                    Text("\(row.index + 1)")
                        .monospacedDigit()
                }
                .width(30)

                TableColumn("Name", value: \.name) { row in
                    TextField("", text: binding(for: row.index, keyPath: \.name))
                        .textFieldStyle(.plain)
                }
                .width(min: 60, ideal: 80)

                TableColumn("Frequency", value: \.frequencyDisplay) { row in
                    TextField("", text: binding(for: row.index, keyPath: \.frequencyDisplay))
                        .textFieldStyle(.plain)
                        .monospacedDigit()
                }
                .width(min: 80, ideal: 100)

                TableColumn("TX Tone") { row in
                    Text(row.txToneDisplay)
                        .foregroundStyle(row.txToneDisplay == "None" ? .secondary : .primary)
                }
                .width(min: 60, ideal: 80)

                TableColumn("RX Tone") { row in
                    Text(row.rxToneDisplay)
                        .foregroundStyle(row.rxToneDisplay == "None" ? .secondary : .primary)
                }
                .width(min: 60, ideal: 80)

                TableColumn("Power") { row in
                    Text(row.powerDisplay)
                }
                .width(min: 50, ideal: 60)
            }
            .contextMenu(forSelectionType: Int.self) { indices in
                Button("Copy Channel") {}
                Button("Paste Channel") {}
                Divider()
                Button("Clear Channel") {}
            } primaryAction: { indices in
                // Double-click to edit
            }

            // Status bar
            HStack {
                Text("\(channels.count) channels")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                if !selection.isEmpty {
                    Text("\(selection.count) selected")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
            .background(.bar)
        }
        .onAppear {
            loadChannels()
        }
    }

    private func loadChannels() {
        guard let model = RadioModelRegistry.model(for: modelIdentifier) else { return }
        let maxCh = model.maxChannels

        channels = (0..<maxCh).map { ch in
            let freqField = CLPFields.channelFrequency(channel: ch)
            let nameField = CLPFields.channelName(channel: ch)
            let txField = CLPFields.channelTxTone(channel: ch)
            let rxField = CLPFields.channelRxTone(channel: ch)

            let freqRaw = codeplug.getValue(for: freqField).intValue ?? 0
            let freqMHz = String(format: "%.4f", Double(freqRaw) / 10000.0)
            let name = codeplug.getValue(for: nameField).stringValue ?? "CH\(ch + 1)"
            let txTone = codeplug.getValue(for: txField).intValue ?? 0
            let rxTone = codeplug.getValue(for: rxField).intValue ?? 0

            return ChannelRow(
                index: ch,
                name: name,
                frequencyDisplay: freqMHz,
                txToneCode: UInt8(txTone),
                rxToneCode: UInt8(rxTone),
                powerLevel: 1
            )
        }
    }

    private func binding(for index: Int, keyPath: WritableKeyPath<ChannelRow, String>) -> Binding<String> {
        Binding(
            get: { channels[index][keyPath: keyPath] },
            set: { channels[index][keyPath: keyPath] = $0 }
        )
    }
}

/// A row in the channel editor table.
struct ChannelRow: Identifiable {
    let id: Int
    let index: Int
    var name: String
    var frequencyDisplay: String
    var txToneCode: UInt8
    var rxToneCode: UInt8
    var powerLevel: UInt8

    init(index: Int, name: String, frequencyDisplay: String, txToneCode: UInt8, rxToneCode: UInt8, powerLevel: UInt8) {
        self.id = index
        self.index = index
        self.name = name
        self.frequencyDisplay = frequencyDisplay
        self.txToneCode = txToneCode
        self.rxToneCode = rxToneCode
        self.powerLevel = powerLevel
    }

    var txToneDisplay: String {
        txToneCode == 0 ? "None" : CTCSSToneTransform().toDisplay(txToneCode)
    }

    var rxToneDisplay: String {
        rxToneCode == 0 ? "None" : CTCSSToneTransform().toDisplay(rxToneCode)
    }

    var powerDisplay: String {
        powerLevel == 0 ? "Low" : "High"
    }
}

// Temporary reference to CLPFields for channel loading
private enum CLPFields {
    static func channelFrequency(channel: Int) -> FieldDefinition {
        FieldDefinition(
            id: "clp.channel.\(channel).frequency",
            name: "channelFrequency",
            displayName: "Frequency",
            category: .channel,
            valueType: .uint32,
            bitOffset: 256 + (channel * 128),
            bitLength: 32,
            defaultValue: .uint32(4625625)
        )
    }

    static func channelName(channel: Int) -> FieldDefinition {
        FieldDefinition(
            id: "clp.channel.\(channel).name",
            name: "channelName",
            displayName: "Name",
            category: .channel,
            valueType: .string(maxLength: 8, encoding: .utf8),
            bitOffset: 256 + (channel * 128) + 32,
            bitLength: 64,
            defaultValue: .string("CH\(channel + 1)")
        )
    }

    static func channelTxTone(channel: Int) -> FieldDefinition {
        FieldDefinition(
            id: "clp.channel.\(channel).txTone",
            name: "channelTxTone",
            displayName: "TX Tone",
            category: .signaling,
            valueType: .uint8,
            bitOffset: 256 + (channel * 128) + 96,
            bitLength: 8,
            defaultValue: .uint8(0)
        )
    }

    static func channelRxTone(channel: Int) -> FieldDefinition {
        FieldDefinition(
            id: "clp.channel.\(channel).rxTone",
            name: "channelRxTone",
            displayName: "RX Tone",
            category: .signaling,
            valueType: .uint8,
            bitOffset: 256 + (channel * 128) + 104,
            bitLength: 8,
            defaultValue: .uint8(0)
        )
    }
}
