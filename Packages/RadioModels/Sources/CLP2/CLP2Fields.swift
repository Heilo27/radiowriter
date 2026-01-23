import Foundation
import RadioCore
import RadioModelCore

/// Field definitions for CLP2 radio family (CLP1100/1140/1160/1180).
/// Paths derived from BL.Clp2.Constants.dll decompilation.
public enum CLP2Fields {
    static let channelStride = 256 // bits per channel

    // MARK: - General Settings (DynamicSetting block)

    public static let numberOfChannels = FieldDefinition(
        id: "clp2.general.numChannels", name: "numberOfChannels",
        displayName: "Number of Channels", category: .general,
        valueType: .uint8, bitOffset: 0, bitLength: 8, defaultValue: .uint8(4),
        constraint: .range(min: 1, max: 99), isReadOnly: true
    )

    public static let txPowerMode = FieldDefinition(
        id: "clp2.general.powerMode", name: "txPowerMode",
        displayName: "Power Group", category: .general,
        valueType: .enumeration([
            EnumOption(id: 0, name: "low", displayName: "Low Power"),
            EnumOption(id: 1, name: "high", displayName: "High Power"),
        ]),
        bitOffset: 8, bitLength: 8, defaultValue: .enumValue(1)
    )

    public static let txTimeoutTimer = FieldDefinition(
        id: "clp2.general.tot", name: "txTimeoutTimer",
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
        id: "clp2.general.pttHold", name: "pttHoldEnabled",
        displayName: "PTT Hold", category: .general,
        valueType: .bool, bitOffset: 24, bitLength: 1, defaultValue: .bool(false),
        helpText: "Hold PTT to keep transmitting after release"
    )

    public static let alertToneEnabled = FieldDefinition(
        id: "clp2.audio.alertTone", name: "alertToneEnabled",
        displayName: "Keypad Beep", category: .audio,
        valueType: .bool, bitOffset: 25, bitLength: 1, defaultValue: .bool(true)
    )

    public static let powerUpTone = FieldDefinition(
        id: "clp2.audio.powerUpTone", name: "powerUpTone",
        displayName: "Power-Up Tone", category: .audio,
        valueType: .bool, bitOffset: 26, bitLength: 1, defaultValue: .bool(true)
    )

    public static let codeplugResetEnabled = FieldDefinition(
        id: "clp2.advanced.codeplugReset", name: "codeplugResetEnabled",
        displayName: "Factory Reset Enabled", category: .advanced,
        valueType: .bool, bitOffset: 27, bitLength: 1, defaultValue: .bool(true)
    )

    public static let vpUserModeEnabled = FieldDefinition(
        id: "clp2.audio.vpUserMode", name: "vpUserModeEnabled",
        displayName: "Voice Prompts", category: .audio,
        valueType: .bool, bitOffset: 28, bitLength: 1, defaultValue: .bool(true)
    )

    public static let ledPattern = FieldDefinition(
        id: "clp2.general.ledPattern", name: "ledPattern",
        displayName: "LED Pattern", category: .general,
        valueType: .enumeration([
            EnumOption(id: 0, name: "mode1", displayName: "Mode 1 (Standard)"),
            EnumOption(id: 1, name: "mode2", displayName: "Mode 2 (Stealth)"),
            EnumOption(id: 2, name: "mode3", displayName: "Mode 3 (Minimal)"),
        ]),
        bitOffset: 32, bitLength: 8, defaultValue: .enumValue(0)
    )

    public static let scrambleEnabled = FieldDefinition(
        id: "clp2.signaling.scramble", name: "scrambleEnabled",
        displayName: "Scramble", category: .signaling,
        valueType: .bool, bitOffset: 40, bitLength: 1, defaultValue: .bool(false),
        helpText: "Enable voice scrambling for privacy"
    )

    public static let muteHeadsetVolume = FieldDefinition(
        id: "clp2.audio.muteHeadset", name: "muteHeadsetVolume",
        displayName: "Mute Headset Volume", category: .audio,
        valueType: .bool, bitOffset: 41, bitLength: 1, defaultValue: .bool(false)
    )

    // MARK: - Bluetooth Settings

    public static let btAlwaysConnect = FieldDefinition(
        id: "clp2.bluetooth.alwaysConnect", name: "btAlwaysConnect",
        displayName: "Always Connect", category: .bluetooth,
        valueType: .bool, bitOffset: 48, bitLength: 1, defaultValue: .bool(false),
        helpText: "Automatically reconnect Bluetooth on power-up"
    )

    public static let btPairingPin = FieldDefinition(
        id: "clp2.bluetooth.pin", name: "btPairingPin",
        displayName: "Pairing PIN", category: .bluetooth,
        valueType: .string(maxLength: 4, encoding: .utf8),
        bitOffset: 56, bitLength: 32, defaultValue: .string("0000"),
        constraint: .stringLength(min: 4, max: 4)
    )

    public static let btSidetoneEnabled = FieldDefinition(
        id: "clp2.bluetooth.sidetone", name: "btSidetoneEnabled",
        displayName: "Sidetone", category: .bluetooth,
        valueType: .bool, bitOffset: 88, bitLength: 1, defaultValue: .bool(false),
        helpText: "Play sidetone in Bluetooth headset during TX"
    )

    public static let btVoxLevel = FieldDefinition(
        id: "clp2.bluetooth.voxLevel", name: "btVoxLevel",
        displayName: "BT VOX Level", category: .bluetooth,
        valueType: .uint8, bitOffset: 96, bitLength: 8, defaultValue: .uint8(3),
        constraint: .range(min: 1, max: 5)
    )

    public static let btMicGain = FieldDefinition(
        id: "clp2.bluetooth.micGain", name: "btMicGain",
        displayName: "BT Mic Gain", category: .bluetooth,
        valueType: .uint8, bitOffset: 104, bitLength: 8, defaultValue: .uint8(3),
        constraint: .range(min: 1, max: 5)
    )

    // MARK: - Channel Fields

    public static func channelFrequency(channel: Int) -> FieldDefinition {
        let base = 512 + (channel * channelStride)
        return FieldDefinition(
            id: "clp2.channel.\(channel).rxFreq", name: "rxFreq",
            displayName: "Frequency", category: .channel,
            valueType: .uint32, bitOffset: base, bitLength: 32, defaultValue: .uint32(4625625),
            constraint: .range(min: 4000000, max: 4700000)
        )
    }

    public static func channelName(channel: Int) -> FieldDefinition {
        let base = 512 + (channel * channelStride)
        return FieldDefinition(
            id: "clp2.channel.\(channel).name", name: "name",
            displayName: "Name", category: .channel,
            valueType: .string(maxLength: 8, encoding: .utf8),
            bitOffset: base + 32, bitLength: 64, defaultValue: .string("CH\(channel + 1)"),
            constraint: .stringLength(min: 0, max: 8)
        )
    }

    public static func channelTxCode(channel: Int) -> FieldDefinition {
        let base = 512 + (channel * channelStride)
        return FieldDefinition(
            id: "clp2.channel.\(channel).txCode", name: "txCode",
            displayName: "TX Code", category: .signaling,
            valueType: .uint8, bitOffset: base + 96, bitLength: 8, defaultValue: .uint8(0),
            constraint: .range(min: 0, max: 121)
        )
    }

    public static func channelRxCode(channel: Int) -> FieldDefinition {
        let base = 512 + (channel * channelStride)
        return FieldDefinition(
            id: "clp2.channel.\(channel).rxCode", name: "rxCode",
            displayName: "RX Code", category: .signaling,
            valueType: .uint8, bitOffset: base + 104, bitLength: 8, defaultValue: .uint8(0),
            constraint: .range(min: 0, max: 121)
        )
    }

    public static func channelBandwidth(channel: Int) -> FieldDefinition {
        let base = 512 + (channel * channelStride)
        return FieldDefinition(
            id: "clp2.channel.\(channel).bw", name: "bandwidth",
            displayName: "Bandwidth", category: .channel,
            valueType: .enumeration([
                EnumOption(id: 0, name: "narrow", displayName: "12.5 kHz"),
                EnumOption(id: 1, name: "wide", displayName: "25 kHz"),
            ]),
            bitOffset: base + 112, bitLength: 8, defaultValue: .enumValue(0)
        )
    }

    public static func channelScrambleCode(channel: Int) -> FieldDefinition {
        let base = 512 + (channel * channelStride)
        return FieldDefinition(
            id: "clp2.channel.\(channel).scramble", name: "scrambleCode",
            displayName: "Scramble Code", category: .signaling,
            valueType: .uint8, bitOffset: base + 120, bitLength: 8, defaultValue: .uint8(0),
            constraint: .range(min: 0, max: 16)
        )
    }

    public static func channelScanList(channel: Int) -> FieldDefinition {
        let base = 512 + (channel * channelStride)
        return FieldDefinition(
            id: "clp2.channel.\(channel).scanList", name: "scanList",
            displayName: "In Scan List", category: .scan,
            valueType: .bool, bitOffset: base + 128, bitLength: 1, defaultValue: .bool(true)
        )
    }
}
