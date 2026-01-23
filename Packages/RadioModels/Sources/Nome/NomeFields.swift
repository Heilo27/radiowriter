import Foundation
import RadioCore
import RadioModelCore

/// Field definitions for Nome radio family (RM110/160/410/460).
/// UHF/VHF analog radios with programmable frequencies, scramble, and scan lists.
public enum NomeFields {
    static let channelStride = 256 // bits per channel

    // MARK: - General Settings

    public static let numberOfChannels = FieldDefinition(
        id: "nome.general.numChannels", name: "numberOfChannels",
        displayName: "Number of Channels", category: .general,
        valueType: .uint8, bitOffset: 0, bitLength: 8, defaultValue: .uint8(4),
        constraint: .range(min: 1, max: 99), isReadOnly: true
    )

    public static let quietMode = FieldDefinition(
        id: "nome.general.quietMode", name: "quietMode",
        displayName: "Quiet Mode", category: .general,
        valueType: .bool, bitOffset: 8, bitLength: 1, defaultValue: .bool(false),
        helpText: "Disable all audible tones"
    )

    public static let codeplugResetDisabled = FieldDefinition(
        id: "nome.advanced.codeplugReset", name: "codeplugResetDisabled",
        displayName: "Disable Factory Reset", category: .advanced,
        valueType: .bool, bitOffset: 9, bitLength: 1, defaultValue: .bool(false)
    )

    public static let batterySaveDisabled = FieldDefinition(
        id: "nome.general.battSaveDisabled", name: "batterySaveDisabled",
        displayName: "Disable Battery Save", category: .general,
        valueType: .bool, bitOffset: 10, bitLength: 1, defaultValue: .bool(false)
    )

    public static let lastCallTone = FieldDefinition(
        id: "nome.audio.callTone", name: "lastCallTone",
        displayName: "Call Tone", category: .audio,
        valueType: .enumeration([
            EnumOption(id: 0, name: "off", displayName: "Off"),
            EnumOption(id: 1, name: "tone1", displayName: "Tone 1"),
            EnumOption(id: 2, name: "tone2", displayName: "Tone 2"),
            EnumOption(id: 3, name: "tone3", displayName: "Tone 3"),
            EnumOption(id: 4, name: "tone4", displayName: "Tone 4"),
            EnumOption(id: 5, name: "tone5", displayName: "Tone 5"),
        ]),
        bitOffset: 16, bitLength: 8, defaultValue: .enumValue(1)
    )

    public static let scrambleDisabled = FieldDefinition(
        id: "nome.signaling.scrambleDis", name: "scrambleDisabled",
        displayName: "Disable Scramble", category: .signaling,
        valueType: .bool, bitOffset: 24, bitLength: 1, defaultValue: .bool(false)
    )

    public static let presetChannel1 = FieldDefinition(
        id: "nome.general.presetCh1", name: "presetChannel1",
        displayName: "Preset Channel 1", category: .general,
        valueType: .uint8, bitOffset: 32, bitLength: 8, defaultValue: .uint8(0),
        constraint: .range(min: 0, max: 98)
    )

    public static let presetChannel2 = FieldDefinition(
        id: "nome.general.presetCh2", name: "presetChannel2",
        displayName: "Preset Channel 2", category: .general,
        valueType: .uint8, bitOffset: 40, bitLength: 8, defaultValue: .uint8(1),
        constraint: .range(min: 0, max: 98)
    )

    // MARK: - Channel Fields

    public static func channelName(channel: Int) -> FieldDefinition {
        let base = 512 + (channel * channelStride)
        return FieldDefinition(
            id: "nome.channel.\(channel).name", name: "channelName",
            displayName: "Name", category: .channel,
            valueType: .string(maxLength: 6, encoding: .utf8),
            bitOffset: base, bitLength: 48, defaultValue: .string("CH\(channel + 1)")
        )
    }

    public static func channelRxFreq(channel: Int) -> FieldDefinition {
        let base = 512 + (channel * channelStride)
        return FieldDefinition(
            id: "nome.channel.\(channel).rxFreq", name: "rxFreq",
            displayName: "RX Frequency", category: .channel,
            valueType: .uint32, bitOffset: base + 48, bitLength: 32, defaultValue: .uint32(4625625),
            constraint: .range(min: 4000000, max: 4700000)
        )
    }

    public static func channelTxFreq(channel: Int) -> FieldDefinition {
        let base = 512 + (channel * channelStride)
        return FieldDefinition(
            id: "nome.channel.\(channel).txFreq", name: "txFreq",
            displayName: "TX Frequency", category: .channel,
            valueType: .uint32, bitOffset: base + 80, bitLength: 32, defaultValue: .uint32(4625625),
            constraint: .range(min: 4000000, max: 4700000)
        )
    }

    public static func channelRxBandwidth(channel: Int) -> FieldDefinition {
        let base = 512 + (channel * channelStride)
        return FieldDefinition(
            id: "nome.channel.\(channel).rxBw", name: "rxBandwidth",
            displayName: "RX Bandwidth", category: .channel,
            valueType: .enumeration([
                EnumOption(id: 0, name: "narrow", displayName: "12.5 kHz"),
                EnumOption(id: 1, name: "wide", displayName: "25 kHz"),
            ]),
            bitOffset: base + 112, bitLength: 8, defaultValue: .enumValue(0)
        )
    }

    public static func channelTxBandwidth(channel: Int) -> FieldDefinition {
        let base = 512 + (channel * channelStride)
        return FieldDefinition(
            id: "nome.channel.\(channel).txBw", name: "txBandwidth",
            displayName: "TX Bandwidth", category: .channel,
            valueType: .enumeration([
                EnumOption(id: 0, name: "narrow", displayName: "12.5 kHz"),
                EnumOption(id: 1, name: "wide", displayName: "25 kHz"),
            ]),
            bitOffset: base + 120, bitLength: 8, defaultValue: .enumValue(0)
        )
    }

    public static func channelTxPower(channel: Int) -> FieldDefinition {
        let base = 512 + (channel * channelStride)
        return FieldDefinition(
            id: "nome.channel.\(channel).txPower", name: "txPower",
            displayName: "TX Power", category: .channel,
            valueType: .enumeration([
                EnumOption(id: 0, name: "low", displayName: "Low"),
                EnumOption(id: 1, name: "high", displayName: "High"),
            ]),
            bitOffset: base + 128, bitLength: 8, defaultValue: .enumValue(1)
        )
    }

    public static func channelRxCode(channel: Int) -> FieldDefinition {
        let base = 512 + (channel * channelStride)
        return FieldDefinition(
            id: "nome.channel.\(channel).rxCode", name: "rxCode",
            displayName: "RX Code", category: .signaling,
            valueType: .uint8, bitOffset: base + 136, bitLength: 8, defaultValue: .uint8(0),
            constraint: .range(min: 0, max: 121)
        )
    }

    public static func channelTxCode(channel: Int) -> FieldDefinition {
        let base = 512 + (channel * channelStride)
        return FieldDefinition(
            id: "nome.channel.\(channel).txCode", name: "txCode",
            displayName: "TX Code", category: .signaling,
            valueType: .uint8, bitOffset: base + 144, bitLength: 8, defaultValue: .uint8(0),
            constraint: .range(min: 0, max: 121)
        )
    }

    public static func channelScrambleCode(channel: Int) -> FieldDefinition {
        let base = 512 + (channel * channelStride)
        return FieldDefinition(
            id: "nome.channel.\(channel).scramble", name: "scrambleCode",
            displayName: "Scramble Code", category: .signaling,
            valueType: .uint8, bitOffset: base + 152, bitLength: 8, defaultValue: .uint8(0),
            constraint: .range(min: 0, max: 16)
        )
    }

    public static func channelDisabled(channel: Int) -> FieldDefinition {
        let base = 512 + (channel * channelStride)
        return FieldDefinition(
            id: "nome.channel.\(channel).disabled", name: "disableChannel",
            displayName: "Disabled", category: .channel,
            valueType: .bool, bitOffset: base + 160, bitLength: 1, defaultValue: .bool(false)
        )
    }
}
