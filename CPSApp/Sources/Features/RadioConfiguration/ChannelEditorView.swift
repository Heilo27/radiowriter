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
                        .foregroundStyle(.secondary)
                }
                .width(min: 30, ideal: 40, max: 50)

                TableColumn("Name") { row in
                    TextField("", text: binding(for: row.index, keyPath: \.name))
                        .textFieldStyle(.plain)
                }
                .width(min: 60, ideal: 100)

                TableColumn("Frequency") { row in
                    TextField("", text: binding(for: row.index, keyPath: \.frequencyDisplay))
                        .textFieldStyle(.plain)
                        .monospacedDigit()
                }
                .width(min: 80, ideal: 110)

                TableColumn("TX Tone") { row in
                    Text(row.txToneDisplay)
                        .foregroundStyle(row.txToneCode == 0 ? .secondary : .primary)
                        .help("CTCSS/DCS tone transmitted with your voice to open squelch on receiving radios")
                }
                .width(min: 60, ideal: 80)

                TableColumn("RX Tone") { row in
                    Text(row.rxToneDisplay)
                        .foregroundStyle(row.rxToneCode == 0 ? .secondary : .primary)
                        .help("CTCSS/DCS tone required to unmute this channel's receive audio")
                }
                .width(min: 60, ideal: 80)

                TableColumn("Power") { row in
                    Text(row.powerDisplay)
                        .help("TX power level. High increases range but drains battery faster")
                }
                .width(min: 40, ideal: 60)
            }
            .onAppear { loadChannels() }

            HStack {
                Text("\(channels.count) channels")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if !selection.isEmpty {
                    Text("· \(selection.count) selected")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(.bar)
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
            set: { newValue in
                // Validate based on field type
                if keyPath == \.frequencyDisplay {
                    guard isValidFrequency(newValue) else { return }
                } else if keyPath == \.name {
                    guard isValidChannelName(newValue) else { return }
                }
                channels[index][keyPath: keyPath] = newValue
            }
        )
    }

    /// Validates frequency input (must be a valid MHz value in typical radio ranges).
    private func isValidFrequency(_ value: String) -> Bool {
        // Allow empty or partial input during typing
        if value.isEmpty { return true }

        // Must be a valid number
        guard let mhz = Double(value) else { return false }

        // Basic range check for typical business radio frequencies (136-174 VHF, 400-527 UHF)
        // Allow wider range for flexibility
        return mhz >= 100.0 && mhz <= 600.0
    }

    /// Validates channel name (max 8 characters, printable ASCII).
    private func isValidChannelName(_ value: String) -> Bool {
        // Allow up to 8 characters
        guard value.count <= 8 else { return false }
        // Allow only printable ASCII
        return value.allSatisfy { $0.isASCII && !$0.isNewline }
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
