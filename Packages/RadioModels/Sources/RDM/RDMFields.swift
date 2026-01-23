import Foundation
import RadioCore
import RadioModelCore

/// Field definitions for the RDM (Retail Display Model) radio family.
public enum RDMFields {
    static let channelStride = 192 // bits per channel entry

    // MARK: - General

    public static let radioAlias = FieldDefinition(
        id: "rdm.general.alias", name: "radioAlias", displayName: "Radio Alias",
        category: .general, valueType: .string(maxLength: 16, encoding: .utf8),
        bitOffset: 0, bitLength: 128, defaultValue: .string(""),
        constraint: .stringLength(min: 0, max: 16), helpText: "A name to identify this radio"
    )

    public static let numberOfChannels = FieldDefinition(
        id: "rdm.general.numChannels", name: "numberOfChannels", displayName: "Number of Channels",
        category: .general, valueType: .uint8,
        bitOffset: 128, bitLength: 8, defaultValue: .uint8(2),
        constraint: .range(min: 1, max: 7), helpText: "Active channel count"
    )

    public static let defaultChannel = FieldDefinition(
        id: "rdm.general.defaultChannel", name: "defaultChannel", displayName: "Default Channel",
        category: .general, valueType: .uint8,
        bitOffset: 136, bitLength: 8, defaultValue: .uint8(0),
        constraint: .range(min: 0, max: 6), helpText: "Channel selected at power-on (0-indexed)"
    )

    // MARK: - Audio

    public static let volumeLevel = FieldDefinition(
        id: "rdm.audio.volume", name: "volumeLevel", displayName: "Volume Level",
        category: .audio, valueType: .uint8,
        bitOffset: 144, bitLength: 8, defaultValue: .uint8(5),
        constraint: .range(min: 0, max: 10), helpText: "Default volume level (0-10)"
    )

    public static let voxEnabled = FieldDefinition(
        id: "rdm.audio.voxEnabled", name: "voxEnabled", displayName: "VOX Enabled",
        category: .audio, valueType: .bool,
        bitOffset: 152, bitLength: 1, defaultValue: .bool(false),
        helpText: "Enable hands-free voice-activated transmit"
    )

    public static let voxSensitivity = FieldDefinition(
        id: "rdm.audio.voxSensitivity", name: "voxSensitivity", displayName: "VOX Sensitivity",
        category: .audio, valueType: .uint8,
        bitOffset: 160, bitLength: 8, defaultValue: .uint8(3),
        constraint: .range(min: 1, max: 5), dependencies: ["rdm.audio.voxEnabled"],
        helpText: "VOX trigger sensitivity (1=Low, 5=High)"
    )

    public static let keyBeepEnabled = FieldDefinition(
        id: "rdm.audio.keyBeep", name: "keyBeepEnabled", displayName: "Key Beep",
        category: .audio, valueType: .bool,
        bitOffset: 168, bitLength: 1, defaultValue: .bool(true),
        helpText: "Enable button press confirmation tone"
    )

    // MARK: - Signaling

    public static let scrambleEnabled = FieldDefinition(
        id: "rdm.signaling.scramble", name: "scrambleEnabled", displayName: "Voice Scramble",
        category: .signaling, valueType: .bool,
        bitOffset: 176, bitLength: 1, defaultValue: .bool(false),
        helpText: "Enable basic voice scrambling"
    )

    // MARK: - Advanced

    public static let totTimeout = FieldDefinition(
        id: "rdm.advanced.tot", name: "totTimeout", displayName: "TX Timeout (TOT)",
        category: .advanced, valueType: .uint8,
        bitOffset: 184, bitLength: 8, defaultValue: .uint8(60),
        constraint: .range(min: 0, max: 255), helpText: "Transmit timeout in seconds (0 = No timeout)"
    )

    public static let batterySaveEnabled = FieldDefinition(
        id: "rdm.advanced.batterySave", name: "batterySaveEnabled", displayName: "Battery Save",
        category: .advanced, valueType: .bool,
        bitOffset: 192, bitLength: 1, defaultValue: .bool(true),
        helpText: "Enable battery save mode when idle"
    )

    // MARK: - Per-Channel Fields

    static let channelBaseOffset = 256

    public static func channelFrequency(channel: Int) -> FieldDefinition {
        FieldDefinition(
            id: "rdm.channel.\(channel).frequency", name: "channel\(channel + 1)Frequency",
            displayName: "Frequency", category: .channel, valueType: .uint32,
            bitOffset: channelBaseOffset + (channel * channelStride),
            bitLength: 32, defaultValue: .uint32(1518200),
            constraint: .range(min: 1510000, max: 1550000),
            helpText: "Channel \(channel + 1) frequency in 100 Hz units"
        )
    }

    public static func channelName(channel: Int) -> FieldDefinition {
        FieldDefinition(
            id: "rdm.channel.\(channel).name", name: "channel\(channel + 1)Name",
            displayName: "Name", category: .channel,
            valueType: .string(maxLength: 8, encoding: .utf8),
            bitOffset: channelBaseOffset + (channel * channelStride) + 32,
            bitLength: 64, defaultValue: .string("MURS\(channel + 1)"),
            constraint: .stringLength(min: 0, max: 8),
            helpText: "Channel \(channel + 1) display name"
        )
    }

    public static func channelTxPower(channel: Int) -> FieldDefinition {
        FieldDefinition(
            id: "rdm.channel.\(channel).txPower", name: "channel\(channel + 1)TxPower",
            displayName: "TX Power", category: .channel,
            valueType: .enumeration([
                EnumOption(id: 0, name: "low", displayName: "Low (1W)"),
                EnumOption(id: 1, name: "high", displayName: "High (2W)"),
            ]),
            bitOffset: channelBaseOffset + (channel * channelStride) + 96,
            bitLength: 8, defaultValue: .enumValue(1),
            helpText: "Channel \(channel + 1) transmit power"
        )
    }

    public static func channelTxCode(channel: Int) -> FieldDefinition {
        FieldDefinition(
            id: "rdm.channel.\(channel).txCode", name: "channel\(channel + 1)TxCode",
            displayName: "TX Code", category: .signaling, valueType: .uint8,
            bitOffset: channelBaseOffset + (channel * channelStride) + 104,
            bitLength: 8, defaultValue: .uint8(0),
            constraint: .range(min: 0, max: 50),
            helpText: "CTCSS/DPL transmit code (0 = None)"
        )
    }

    public static func channelRxCode(channel: Int) -> FieldDefinition {
        FieldDefinition(
            id: "rdm.channel.\(channel).rxCode", name: "channel\(channel + 1)RxCode",
            displayName: "RX Code", category: .signaling, valueType: .uint8,
            bitOffset: channelBaseOffset + (channel * channelStride) + 112,
            bitLength: 8, defaultValue: .uint8(0),
            constraint: .range(min: 0, max: 50),
            helpText: "CTCSS/DPL receive code (0 = None)"
        )
    }
}
