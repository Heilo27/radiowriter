import Foundation
import RadioCore
import RadioModelCore

/// Field definitions for the RMM (Mobile Mount) radio family.
public enum RMMFields {
    static let channelStride = 224 // bits per channel entry

    // MARK: - General

    public static let numberOfChannels = FieldDefinition(
        id: "rmm.general.numChannels", name: "numberOfChannels", displayName: "Number of Channels",
        category: .general, valueType: .uint8,
        bitOffset: 0, bitLength: 8, defaultValue: .uint8(5),
        constraint: .range(min: 1, max: 8), helpText: "Active channel count"
    )

    public static let defaultChannel = FieldDefinition(
        id: "rmm.general.defaultChannel", name: "defaultChannel", displayName: "Default Channel",
        category: .general, valueType: .uint8,
        bitOffset: 8, bitLength: 8, defaultValue: .uint8(0),
        constraint: .range(min: 0, max: 7), helpText: "Channel selected at power-on"
    )

    public static let powerOnChannel = FieldDefinition(
        id: "rmm.general.powerOnChannel", name: "powerOnChannel", displayName: "Power-On Channel",
        category: .general, valueType: .enumeration([
            EnumOption(id: 0, name: "last", displayName: "Last Used"),
            EnumOption(id: 1, name: "default", displayName: "Default Channel"),
        ]),
        bitOffset: 16, bitLength: 8, defaultValue: .enumValue(0),
        helpText: "Channel selected when radio powers on"
    )

    // MARK: - Audio

    public static let volumeLevel = FieldDefinition(
        id: "rmm.audio.volume", name: "volumeLevel", displayName: "Volume Level",
        category: .audio, valueType: .uint8,
        bitOffset: 24, bitLength: 8, defaultValue: .uint8(5),
        constraint: .range(min: 0, max: 16), helpText: "Default volume level (0-16)"
    )

    public static let keyBeepEnabled = FieldDefinition(
        id: "rmm.audio.keyBeep", name: "keyBeepEnabled", displayName: "Key Beep",
        category: .audio, valueType: .bool,
        bitOffset: 32, bitLength: 1, defaultValue: .bool(true),
        helpText: "Enable button press confirmation tone"
    )

    public static let toneVolume = FieldDefinition(
        id: "rmm.audio.toneVolume", name: "toneVolume", displayName: "Alert Tone Volume",
        category: .audio, valueType: .uint8,
        bitOffset: 40, bitLength: 8, defaultValue: .uint8(5),
        constraint: .range(min: 0, max: 10), helpText: "Volume level for alert tones"
    )

    // MARK: - Signaling

    public static let scramblerEnabled = FieldDefinition(
        id: "rmm.signaling.scrambler", name: "scramblerEnabled", displayName: "Voice Scrambler",
        category: .signaling, valueType: .bool,
        bitOffset: 48, bitLength: 1, defaultValue: .bool(false),
        helpText: "Enable basic voice scrambling"
    )

    // MARK: - Advanced

    public static let totTimeout = FieldDefinition(
        id: "rmm.advanced.tot", name: "totTimeout", displayName: "TX Timeout (TOT)",
        category: .advanced, valueType: .uint8,
        bitOffset: 56, bitLength: 8, defaultValue: .uint8(60),
        constraint: .range(min: 0, max: 255), helpText: "Transmit timeout in seconds (0 = No timeout)"
    )

    public static let squelchLevel = FieldDefinition(
        id: "rmm.advanced.squelch", name: "squelchLevel", displayName: "Squelch Level",
        category: .advanced, valueType: .enumeration([
            EnumOption(id: 0, name: "normal", displayName: "Normal"),
            EnumOption(id: 1, name: "tight", displayName: "Tight"),
        ]),
        bitOffset: 64, bitLength: 8, defaultValue: .enumValue(0),
        helpText: "Squelch threshold sensitivity"
    )

    // MARK: - Per-Channel Fields

    static let channelBaseOffset = 128

    public static func channelFrequency(channel: Int) -> FieldDefinition {
        FieldDefinition(
            id: "rmm.channel.\(channel).frequency", name: "channel\(channel + 1)Frequency",
            displayName: "Frequency", category: .channel, valueType: .uint32,
            bitOffset: channelBaseOffset + (channel * channelStride),
            bitLength: 32, defaultValue: .uint32(1518200),
            constraint: .range(min: 1510000, max: 1550000),
            helpText: "Channel \(channel + 1) frequency in 100 Hz units"
        )
    }

    public static func channelName(channel: Int) -> FieldDefinition {
        FieldDefinition(
            id: "rmm.channel.\(channel).name", name: "channel\(channel + 1)Name",
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
            id: "rmm.channel.\(channel).txPower", name: "channel\(channel + 1)TxPower",
            displayName: "TX Power", category: .channel,
            valueType: .enumeration([
                EnumOption(id: 0, name: "low", displayName: "Low (5W)"),
                EnumOption(id: 1, name: "mid", displayName: "Mid (10W)"),
                EnumOption(id: 2, name: "high", displayName: "High (25W)"),
            ]),
            bitOffset: channelBaseOffset + (channel * channelStride) + 96,
            bitLength: 8, defaultValue: .enumValue(2),
            helpText: "Channel \(channel + 1) transmit power"
        )
    }

    public static func channelBandwidth(channel: Int) -> FieldDefinition {
        FieldDefinition(
            id: "rmm.channel.\(channel).bandwidth", name: "channel\(channel + 1)Bandwidth",
            displayName: "Bandwidth", category: .channel,
            valueType: .enumeration([
                EnumOption(id: 0, name: "narrow", displayName: "Narrow (11.25 kHz)"),
                EnumOption(id: 1, name: "wide", displayName: "Wide (20 kHz)"),
            ]),
            bitOffset: channelBaseOffset + (channel * channelStride) + 104,
            bitLength: 8, defaultValue: .enumValue(0),
            helpText: "Channel \(channel + 1) bandwidth"
        )
    }

    public static func channelTxCode(channel: Int) -> FieldDefinition {
        FieldDefinition(
            id: "rmm.channel.\(channel).txCode", name: "channel\(channel + 1)TxCode",
            displayName: "TX Code", category: .signaling, valueType: .uint8,
            bitOffset: channelBaseOffset + (channel * channelStride) + 112,
            bitLength: 8, defaultValue: .uint8(0),
            constraint: .range(min: 0, max: 50),
            helpText: "CTCSS/DPL transmit code (0 = None)"
        )
    }

    public static func channelRxCode(channel: Int) -> FieldDefinition {
        FieldDefinition(
            id: "rmm.channel.\(channel).rxCode", name: "channel\(channel + 1)RxCode",
            displayName: "RX Code", category: .signaling, valueType: .uint8,
            bitOffset: channelBaseOffset + (channel * channelStride) + 120,
            bitLength: 8, defaultValue: .uint8(0),
            constraint: .range(min: 0, max: 50),
            helpText: "CTCSS/DPL receive code (0 = None)"
        )
    }
}
