import Foundation
import RadioCore
import RadioModelCore

/// Field definitions for the CLP radio family.
public enum CLPFields {

    // MARK: - General Settings

    public static let radioAlias = FieldDefinition(
        id: "clp.general.alias",
        name: "radioAlias",
        displayName: "Radio Alias",
        category: .general,
        valueType: .string(maxLength: 16, encoding: .utf8),
        bitOffset: 0,
        bitLength: 128,
        defaultValue: .string(""),
        constraint: .stringLength(min: 0, max: 16),
        helpText: "A name to identify this radio"
    )

    public static let txPower = FieldDefinition(
        id: "clp.general.txPower",
        name: "txPower",
        displayName: "Transmit Power",
        category: .general,
        valueType: .enumeration([
            EnumOption(id: 0, name: "low", displayName: "Low (0.5W)"),
            EnumOption(id: 1, name: "high", displayName: "High (1W)"),
        ]),
        bitOffset: 128,
        bitLength: 8,
        defaultValue: .enumValue(1),
        helpText: "Radio transmit power level"
    )

    public static let volumeLevel = FieldDefinition(
        id: "clp.audio.volume",
        name: "volumeLevel",
        displayName: "Volume Level",
        category: .audio,
        valueType: .uint8,
        bitOffset: 136,
        bitLength: 8,
        defaultValue: .uint8(5),
        constraint: .range(min: 0, max: 10),
        helpText: "Default volume level (0-10)"
    )

    // MARK: - Channel Fields

    public static let channel1Frequency = FieldDefinition(
        id: "clp.channel.0.frequency",
        name: "channel1Frequency",
        displayName: "Frequency",
        category: .channel,
        valueType: .uint32,
        bitOffset: 256,
        bitLength: 32,
        defaultValue: .uint32(4625625),
        constraint: .range(min: 4000000, max: 4700000),
        helpText: "Channel frequency in 100 Hz units (e.g., 4625625 = 462.5625 MHz)"
    )

    /// Creates a frequency field definition for a specific channel index.
    public static func channelFrequency(channel: Int) -> FieldDefinition {
        let stride = 128 // bits per channel entry
        return FieldDefinition(
            id: "clp.channel.\(channel).frequency",
            name: "channel\(channel + 1)Frequency",
            displayName: "Frequency",
            category: .channel,
            valueType: .uint32,
            bitOffset: 256 + (channel * stride),
            bitLength: 32,
            defaultValue: .uint32(4625625),
            constraint: .range(min: 4000000, max: 4700000),
            helpText: "Channel \(channel + 1) frequency in 100 Hz units"
        )
    }

    /// Creates a channel name field definition.
    public static func channelName(channel: Int) -> FieldDefinition {
        let stride = 128
        return FieldDefinition(
            id: "clp.channel.\(channel).name",
            name: "channel\(channel + 1)Name",
            displayName: "Name",
            category: .channel,
            valueType: .string(maxLength: 8, encoding: .utf8),
            bitOffset: 256 + (channel * stride) + 32,
            bitLength: 64,
            defaultValue: .string("CH\(channel + 1)"),
            constraint: .stringLength(min: 0, max: 8),
            helpText: "Channel \(channel + 1) display name"
        )
    }

    /// Creates a channel TX tone field.
    public static func channelTxTone(channel: Int) -> FieldDefinition {
        let stride = 128
        return FieldDefinition(
            id: "clp.channel.\(channel).txTone",
            name: "channel\(channel + 1)TxTone",
            displayName: "TX Tone",
            category: .signaling,
            valueType: .uint8,
            bitOffset: 256 + (channel * stride) + 96,
            bitLength: 8,
            defaultValue: .uint8(0),
            constraint: .range(min: 0, max: 50),
            helpText: "CTCSS transmit tone code (0 = None)"
        )
    }

    /// Creates a channel RX tone field.
    public static func channelRxTone(channel: Int) -> FieldDefinition {
        let stride = 128
        return FieldDefinition(
            id: "clp.channel.\(channel).rxTone",
            name: "channel\(channel + 1)RxTone",
            displayName: "RX Tone",
            category: .signaling,
            valueType: .uint8,
            bitOffset: 256 + (channel * stride) + 104,
            bitLength: 8,
            defaultValue: .uint8(0),
            constraint: .range(min: 0, max: 50),
            helpText: "CTCSS receive tone code (0 = None)"
        )
    }

    // MARK: - Signaling (Single Channel)

    public static let ctcssTxTone = FieldDefinition(
        id: "clp.signaling.txTone",
        name: "ctcssTxTone",
        displayName: "TX CTCSS Tone",
        category: .signaling,
        valueType: .uint8,
        bitOffset: 352,
        bitLength: 8,
        defaultValue: .uint8(0),
        constraint: .range(min: 0, max: 50),
        helpText: "Transmit CTCSS tone code (0 = None)"
    )

    public static let ctcssRxTone = FieldDefinition(
        id: "clp.signaling.rxTone",
        name: "ctcssRxTone",
        displayName: "RX CTCSS Tone",
        category: .signaling,
        valueType: .uint8,
        bitOffset: 360,
        bitLength: 8,
        defaultValue: .uint8(0),
        constraint: .range(min: 0, max: 50),
        helpText: "Receive CTCSS tone code (0 = None)"
    )

    // MARK: - Audio Settings

    public static let voxEnabled = FieldDefinition(
        id: "clp.audio.voxEnabled",
        name: "voxEnabled",
        displayName: "VOX Enabled",
        category: .audio,
        valueType: .bool,
        bitOffset: 144,
        bitLength: 1,
        defaultValue: .bool(false),
        helpText: "Enable hands-free voice-activated transmit"
    )

    public static let voxSensitivity = FieldDefinition(
        id: "clp.audio.voxSensitivity",
        name: "voxSensitivity",
        displayName: "VOX Sensitivity",
        category: .audio,
        valueType: .uint8,
        bitOffset: 152,
        bitLength: 8,
        defaultValue: .uint8(3),
        constraint: .range(min: 0, max: 5),
        dependencies: ["clp.audio.voxEnabled"],
        helpText: "VOX trigger sensitivity (1=Low, 5=High)"
    )

    public static let toneVolume = FieldDefinition(
        id: "clp.audio.toneVolume",
        name: "toneVolume",
        displayName: "Alert Tone Volume",
        category: .audio,
        valueType: .uint8,
        bitOffset: 160,
        bitLength: 8,
        defaultValue: .uint8(5),
        constraint: .range(min: 0, max: 10),
        helpText: "Volume level for alert tones"
    )

    public static let squelchLevel = FieldDefinition(
        id: "clp.audio.squelch",
        name: "squelchLevel",
        displayName: "Squelch Level",
        category: .audio,
        valueType: .enumeration([
            EnumOption(id: 0, name: "normal", displayName: "Normal"),
            EnumOption(id: 1, name: "tight", displayName: "Tight"),
        ]),
        bitOffset: 168,
        bitLength: 8,
        defaultValue: .enumValue(0),
        helpText: "Squelch threshold sensitivity"
    )

    // MARK: - Advanced

    public static let totTimeout = FieldDefinition(
        id: "clp.advanced.tot",
        name: "totTimeout",
        displayName: "TX Timeout (TOT)",
        category: .advanced,
        valueType: .uint8,
        bitOffset: 176,
        bitLength: 8,
        defaultValue: .uint8(60),
        constraint: .range(min: 0, max: 255),
        helpText: "Transmit timeout in seconds (0 = No timeout)"
    )

    public static let scanEnabled = FieldDefinition(
        id: "clp.scan.enabled",
        name: "scanEnabled",
        displayName: "Scan Enabled",
        category: .scan,
        valueType: .bool,
        bitOffset: 184,
        bitLength: 1,
        defaultValue: .bool(false),
        helpText: "Enable channel scanning"
    )
}
