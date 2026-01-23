import Foundation
import RadioCore
import RadioModelCore

/// Field definitions for Fiji radio family (CLS1110/1410/1413).
/// UHF analog radios with scramble codes and CTCSS/DPL signaling.
public enum FijiFields {
    static let channelStride = 128 // bits per channel

    // MARK: - General Settings

    public static let numberOfChannels = FieldDefinition(
        id: "fiji.general.numChannels", name: "numberOfChannels",
        displayName: "Number of Channels", category: .general,
        valueType: .uint8, bitOffset: 0, bitLength: 8, defaultValue: .uint8(4),
        constraint: .range(min: 1, max: 10), isReadOnly: true
    )

    public static let callTone = FieldDefinition(
        id: "fiji.audio.callTone", name: "callTone",
        displayName: "Call Tone", category: .audio,
        valueType: .enumeration([
            EnumOption(id: 0, name: "off", displayName: "Off"),
            EnumOption(id: 1, name: "tone1", displayName: "Tone 1"),
            EnumOption(id: 2, name: "tone2", displayName: "Tone 2"),
            EnumOption(id: 3, name: "tone3", displayName: "Tone 3"),
            EnumOption(id: 4, name: "tone4", displayName: "Tone 4"),
        ]),
        bitOffset: 8, bitLength: 8, defaultValue: .enumValue(1)
    )

    public static let keypadBeep = FieldDefinition(
        id: "fiji.audio.keypadBeep", name: "keypadBeep",
        displayName: "Keypad Beep", category: .audio,
        valueType: .bool, bitOffset: 16, bitLength: 1, defaultValue: .bool(true)
    )

    public static let rogerBeep = FieldDefinition(
        id: "fiji.audio.rogerBeep", name: "rogerBeep",
        displayName: "Roger Beep", category: .audio,
        valueType: .bool, bitOffset: 17, bitLength: 1, defaultValue: .bool(false)
    )

    public static let keypadLock = FieldDefinition(
        id: "fiji.general.keypadLock", name: "keypadLock",
        displayName: "Keypad Lock", category: .general,
        valueType: .bool, bitOffset: 18, bitLength: 1, defaultValue: .bool(false)
    )

    public static let codeplugResetEnabled = FieldDefinition(
        id: "fiji.advanced.codeplugReset", name: "codeplugResetEnabled",
        displayName: "Factory Reset Enabled", category: .advanced,
        valueType: .bool, bitOffset: 19, bitLength: 1, defaultValue: .bool(true)
    )

    public static let backlightEnabled = FieldDefinition(
        id: "fiji.general.backlight", name: "backlightEnabled",
        displayName: "Backlight", category: .general,
        valueType: .bool, bitOffset: 20, bitLength: 1, defaultValue: .bool(true)
    )

    public static let reverseBurst = FieldDefinition(
        id: "fiji.signaling.reverseBurst", name: "reverseBurst",
        displayName: "Reverse Burst", category: .signaling,
        valueType: .bool, bitOffset: 21, bitLength: 1, defaultValue: .bool(false),
        helpText: "Transmit reverse burst at end of TX to eliminate squelch tail"
    )

    public static let voxLevel = FieldDefinition(
        id: "fiji.audio.voxLevel", name: "voxLevel",
        displayName: "VOX Level", category: .audio,
        valueType: .uint8, bitOffset: 24, bitLength: 8, defaultValue: .uint8(0),
        constraint: .range(min: 0, max: 5),
        helpText: "0 = Off, 1-5 = sensitivity"
    )

    public static let micGain = FieldDefinition(
        id: "fiji.audio.micGain", name: "micGain",
        displayName: "Microphone Gain", category: .audio,
        valueType: .uint8, bitOffset: 32, bitLength: 8, defaultValue: .uint8(3),
        constraint: .range(min: 1, max: 5)
    )

    public static let batteryType = FieldDefinition(
        id: "fiji.general.batteryType", name: "batteryType",
        displayName: "Battery Type", category: .general,
        valueType: .enumeration([
            EnumOption(id: 0, name: "alkaline", displayName: "Alkaline"),
            EnumOption(id: 1, name: "nimh", displayName: "NiMH"),
        ]),
        bitOffset: 40, bitLength: 8, defaultValue: .enumValue(0)
    )

    public static let batterySaveDisabled = FieldDefinition(
        id: "fiji.general.battSaveDisabled", name: "batterySaveDisabled",
        displayName: "Disable Battery Save", category: .general,
        valueType: .bool, bitOffset: 48, bitLength: 1, defaultValue: .bool(false)
    )

    // MARK: - Channel Fields

    public static func channelFrequencyIndex(channel: Int) -> FieldDefinition {
        let base = 256 + (channel * channelStride)
        return FieldDefinition(
            id: "fiji.channel.\(channel).freqIdx", name: "freqIndex",
            displayName: "Frequency", category: .channel,
            valueType: .uint8, bitOffset: base, bitLength: 8, defaultValue: .uint8(UInt8(channel)),
            constraint: .range(min: 0, max: 55)
        )
    }

    public static func channelCode(channel: Int) -> FieldDefinition {
        let base = 256 + (channel * channelStride)
        return FieldDefinition(
            id: "fiji.channel.\(channel).code", name: "code",
            displayName: "Code", category: .signaling,
            valueType: .uint8, bitOffset: base + 8, bitLength: 8, defaultValue: .uint8(0),
            constraint: .range(min: 0, max: 121),
            helpText: "0 = None, 1-38 = CTCSS, 39-121 = DPL"
        )
    }

    public static func channelScrambleCode(channel: Int) -> FieldDefinition {
        let base = 256 + (channel * channelStride)
        return FieldDefinition(
            id: "fiji.channel.\(channel).scramble", name: "scrambleCode",
            displayName: "Scramble Code", category: .signaling,
            valueType: .uint8, bitOffset: base + 16, bitLength: 8, defaultValue: .uint8(0),
            constraint: .range(min: 0, max: 16),
            helpText: "0 = Off, 1-16 = scramble code"
        )
    }

    public static func channelBandwidth(channel: Int) -> FieldDefinition {
        let base = 256 + (channel * channelStride)
        return FieldDefinition(
            id: "fiji.channel.\(channel).bw", name: "bandwidth",
            displayName: "Bandwidth", category: .channel,
            valueType: .enumeration([
                EnumOption(id: 0, name: "narrow", displayName: "12.5 kHz"),
                EnumOption(id: 1, name: "wide", displayName: "25 kHz"),
            ]),
            bitOffset: base + 24, bitLength: 8, defaultValue: .enumValue(1)
        )
    }
}
