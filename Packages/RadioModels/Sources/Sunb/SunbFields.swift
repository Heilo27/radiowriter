import Foundation
import RadioCore
import RadioModelCore

/// Field definitions for Sunb radio family (CLS1410b/CLS1450).
/// UHF analog business radios (CLS series) with scan lists and scramble.
public enum SunbFields {
    static let channelStride = 256 // bits per channel

    // MARK: - General Settings

    public static let numberOfChannels = FieldDefinition(
        id: "sunb.general.numChannels", name: "numberOfChannels",
        displayName: "Number of Channels", category: .general,
        valueType: .uint8, bitOffset: 0, bitLength: 8, defaultValue: .uint8(4),
        constraint: .range(min: 1, max: 99), isReadOnly: true
    )

    public static let txPowerMode = FieldDefinition(
        id: "sunb.general.powerMode", name: "txPowerMode",
        displayName: "TX Power", category: .general,
        valueType: .enumeration([
            EnumOption(id: 0, name: "low", displayName: "Low Power"),
            EnumOption(id: 1, name: "high", displayName: "High Power"),
        ]),
        bitOffset: 8, bitLength: 8, defaultValue: .enumValue(1)
    )

    public static let txTimeoutTimer = FieldDefinition(
        id: "sunb.general.tot", name: "txTimeoutTimer",
        displayName: "TX Timeout Timer", category: .general,
        valueType: .enumeration([
            EnumOption(id: 0, name: "off", displayName: "Off"),
            EnumOption(id: 1, name: "30s", displayName: "30 seconds"),
            EnumOption(id: 2, name: "60s", displayName: "60 seconds"),
            EnumOption(id: 3, name: "90s", displayName: "90 seconds"),
            EnumOption(id: 4, name: "120s", displayName: "120 seconds"),
            EnumOption(id: 5, name: "180s", displayName: "180 seconds"),
        ]),
        bitOffset: 16, bitLength: 8, defaultValue: .enumValue(2)
    )

    public static let pttHoldEnabled = FieldDefinition(
        id: "sunb.general.pttHold", name: "pttHoldEnabled",
        displayName: "PTT Hold", category: .general,
        valueType: .bool, bitOffset: 24, bitLength: 1, defaultValue: .bool(false)
    )

    public static let keypadBeep = FieldDefinition(
        id: "sunb.audio.keypadBeep", name: "keypadBeep",
        displayName: "Keypad Beep", category: .audio,
        valueType: .bool, bitOffset: 25, bitLength: 1, defaultValue: .bool(true)
    )

    public static let powerUpTone = FieldDefinition(
        id: "sunb.audio.powerUpTone", name: "powerUpTone",
        displayName: "Power-Up Tone", category: .audio,
        valueType: .bool, bitOffset: 26, bitLength: 1, defaultValue: .bool(true)
    )

    public static let vpEnabled = FieldDefinition(
        id: "sunb.audio.vpEnabled", name: "vpEnabled",
        displayName: "Voice Prompts", category: .audio,
        valueType: .bool, bitOffset: 27, bitLength: 1, defaultValue: .bool(true)
    )

    public static let codeplugResetEnabled = FieldDefinition(
        id: "sunb.advanced.codeplugReset", name: "codeplugResetEnabled",
        displayName: "Factory Reset Enabled", category: .advanced,
        valueType: .bool, bitOffset: 28, bitLength: 1, defaultValue: .bool(true)
    )

    public static let scrambleEnabled = FieldDefinition(
        id: "sunb.signaling.scrambleEn", name: "scrambleEnabled",
        displayName: "Scramble", category: .signaling,
        valueType: .bool, bitOffset: 29, bitLength: 1, defaultValue: .bool(false),
        helpText: "Enable voice scrambling for privacy"
    )

    public static let scanListVisible = FieldDefinition(
        id: "sunb.scan.scanListVisible", name: "scanListVisible",
        displayName: "Scan List Visible", category: .scan,
        valueType: .bool, bitOffset: 30, bitLength: 1, defaultValue: .bool(true)
    )

    // MARK: - Channel Fields

    public static func channelName(channel: Int) -> FieldDefinition {
        let base = 256 + (channel * channelStride)
        return FieldDefinition(
            id: "sunb.channel.\(channel).name", name: "name",
            displayName: "Name", category: .channel,
            valueType: .string(maxLength: 8, encoding: .utf8),
            bitOffset: base, bitLength: 64, defaultValue: .string("CH\(channel + 1)"),
            constraint: .stringLength(min: 0, max: 8)
        )
    }

    public static func channelRxFreq(channel: Int) -> FieldDefinition {
        let base = 256 + (channel * channelStride)
        return FieldDefinition(
            id: "sunb.channel.\(channel).rxFreq", name: "rxFreq",
            displayName: "RX Frequency", category: .channel,
            valueType: .uint32, bitOffset: base + 64, bitLength: 32, defaultValue: .uint32(4625625),
            constraint: .range(min: 4000000, max: 4700000)
        )
    }

    public static func channelTxFreq(channel: Int) -> FieldDefinition {
        let base = 256 + (channel * channelStride)
        return FieldDefinition(
            id: "sunb.channel.\(channel).txFreq", name: "txFreq",
            displayName: "TX Frequency", category: .channel,
            valueType: .uint32, bitOffset: base + 96, bitLength: 32, defaultValue: .uint32(4625625),
            constraint: .range(min: 4000000, max: 4700000)
        )
    }

    public static func channelRxBandwidth(channel: Int) -> FieldDefinition {
        let base = 256 + (channel * channelStride)
        return FieldDefinition(
            id: "sunb.channel.\(channel).rxBw", name: "rxBw",
            displayName: "RX Bandwidth", category: .channel,
            valueType: .enumeration([
                EnumOption(id: 0, name: "narrow", displayName: "12.5 kHz"),
                EnumOption(id: 1, name: "wide", displayName: "25 kHz"),
            ]),
            bitOffset: base + 128, bitLength: 8, defaultValue: .enumValue(0)
        )
    }

    public static func channelTxBandwidth(channel: Int) -> FieldDefinition {
        let base = 256 + (channel * channelStride)
        return FieldDefinition(
            id: "sunb.channel.\(channel).txBw", name: "txBw",
            displayName: "TX Bandwidth", category: .channel,
            valueType: .enumeration([
                EnumOption(id: 0, name: "narrow", displayName: "12.5 kHz"),
                EnumOption(id: 1, name: "wide", displayName: "25 kHz"),
            ]),
            bitOffset: base + 136, bitLength: 8, defaultValue: .enumValue(0)
        )
    }

    public static func channelTxCode(channel: Int) -> FieldDefinition {
        let base = 256 + (channel * channelStride)
        return FieldDefinition(
            id: "sunb.channel.\(channel).txCode", name: "txCode",
            displayName: "TX Code", category: .signaling,
            valueType: .uint8, bitOffset: base + 144, bitLength: 8, defaultValue: .uint8(0),
            constraint: .range(min: 0, max: 121)
        )
    }

    public static func channelRxCode(channel: Int) -> FieldDefinition {
        let base = 256 + (channel * channelStride)
        return FieldDefinition(
            id: "sunb.channel.\(channel).rxCode", name: "rxCode",
            displayName: "RX Code", category: .signaling,
            valueType: .uint8, bitOffset: base + 152, bitLength: 8, defaultValue: .uint8(0),
            constraint: .range(min: 0, max: 121)
        )
    }

    public static func channelScrambleCode(channel: Int) -> FieldDefinition {
        let base = 256 + (channel * channelStride)
        return FieldDefinition(
            id: "sunb.channel.\(channel).scramble", name: "scrambleCode",
            displayName: "Scramble Code", category: .signaling,
            valueType: .uint8, bitOffset: base + 160, bitLength: 8, defaultValue: .uint8(0),
            constraint: .range(min: 0, max: 16)
        )
    }

    public static func channelScanList(channel: Int) -> FieldDefinition {
        let base = 256 + (channel * channelStride)
        return FieldDefinition(
            id: "sunb.channel.\(channel).scanList", name: "scanList",
            displayName: "Scan List", category: .scan,
            valueType: .uint8, bitOffset: base + 168, bitLength: 8, defaultValue: .uint8(0),
            constraint: .range(min: 0, max: 16)
        )
    }

    public static func channelDisabled(channel: Int) -> FieldDefinition {
        let base = 256 + (channel * channelStride)
        return FieldDefinition(
            id: "sunb.channel.\(channel).disabled", name: "disableChannel",
            displayName: "Disabled", category: .channel,
            valueType: .bool, bitOffset: base + 176, bitLength: 1, defaultValue: .bool(false)
        )
    }

    public static func channelRepeaterRxOnly(channel: Int) -> FieldDefinition {
        let base = 256 + (channel * channelStride)
        return FieldDefinition(
            id: "sunb.channel.\(channel).repeaterRxOnly", name: "repeaterRxOnly",
            displayName: "Repeater/RX Only", category: .channel,
            valueType: .enumeration([
                EnumOption(id: 0, name: "off", displayName: "Off"),
                EnumOption(id: 1, name: "repeater", displayName: "Repeater"),
                EnumOption(id: 2, name: "rxOnly", displayName: "RX Only"),
            ]),
            bitOffset: base + 184, bitLength: 8, defaultValue: .enumValue(0)
        )
    }
}
