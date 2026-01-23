import Foundation
import RadioCore
import RadioModelCore

/// Field definitions for Vanu radio family (VL50/RDU4100d).
/// UHF digital radios with contacts, PIN modes, and voice prompts.
public enum VanuFields {
    static let channelStride = 256 // bits per channel

    // MARK: - General Settings

    public static let pin = FieldDefinition(
        id: "vanu.general.pin", name: "pin",
        displayName: "PIN Code", category: .general,
        valueType: .string(maxLength: 4, encoding: .utf8),
        bitOffset: 0, bitLength: 32, defaultValue: .string("0000"),
        constraint: .stringLength(min: 4, max: 4),
        helpText: "4-digit security PIN"
    )

    public static let numChannels = FieldDefinition(
        id: "vanu.general.numChannels", name: "numChannels",
        displayName: "Number of Channels", category: .general,
        valueType: .uint8, bitOffset: 32, bitLength: 8, defaultValue: .uint8(6),
        isReadOnly: true
    )

    public static let pinLockEnabled = FieldDefinition(
        id: "vanu.general.pinLock", name: "pinLockEnabled",
        displayName: "PIN Lock", category: .general,
        valueType: .bool, bitOffset: 40, bitLength: 1, defaultValue: .bool(false),
        helpText: "Require PIN on power-up"
    )

    public static let vpEnabled = FieldDefinition(
        id: "vanu.audio.vpEnabled", name: "vpEnabled",
        displayName: "Voice Prompts", category: .audio,
        valueType: .bool, bitOffset: 41, bitLength: 1, defaultValue: .bool(true)
    )

    public static let powerUpTone = FieldDefinition(
        id: "vanu.audio.powerUpTone", name: "powerUpTone",
        displayName: "Power-Up Tone", category: .audio,
        valueType: .enumeration([
            EnumOption(id: 0, name: "off", displayName: "Off"),
            EnumOption(id: 1, name: "tone", displayName: "Tone"),
            EnumOption(id: 2, name: "silent", displayName: "Silent"),
        ]),
        bitOffset: 48, bitLength: 8, defaultValue: .enumValue(1)
    )

    public static let codeplugResetEnabled = FieldDefinition(
        id: "vanu.advanced.codeplugReset", name: "codeplugResetEnabled",
        displayName: "Factory Reset Enabled", category: .advanced,
        valueType: .bool, bitOffset: 56, bitLength: 1, defaultValue: .bool(true)
    )

    public static let programmingModeEnabled = FieldDefinition(
        id: "vanu.advanced.progMode", name: "programmingModeEnabled",
        displayName: "Programming Mode", category: .advanced,
        valueType: .bool, bitOffset: 57, bitLength: 1, defaultValue: .bool(true),
        helpText: "Allow programming via USB"
    )

    public static let radioName = FieldDefinition(
        id: "vanu.general.radioName", name: "radioName",
        displayName: "Radio Name", category: .general,
        valueType: .string(maxLength: 18, encoding: .utf8),
        bitOffset: 64, bitLength: 144, defaultValue: .string("")
    )

    // MARK: - Contacts

    public static let directContactId = FieldDefinition(
        id: "vanu.contacts.directId", name: "directContactId",
        displayName: "Direct Contact ID", category: .contacts,
        valueType: .uint16, bitOffset: 208, bitLength: 16, defaultValue: .uint16(0)
    )

    // MARK: - Channel Fields

    public static func channelMode(channel: Int) -> FieldDefinition {
        let base = 512 + (channel * channelStride)
        return FieldDefinition(
            id: "vanu.channel.\(channel).mode", name: "pinMode",
            displayName: "Mode", category: .channel,
            valueType: .enumeration([
                EnumOption(id: 0, name: "pin", displayName: "PIN"),
                EnumOption(id: 1, name: "group", displayName: "Group Call"),
                EnumOption(id: 2, name: "private", displayName: "Private Call"),
                EnumOption(id: 3, name: "public", displayName: "Public"),
            ]),
            bitOffset: base, bitLength: 8, defaultValue: .enumValue(3)
        )
    }

    public static func channelContactName(channel: Int) -> FieldDefinition {
        let base = 512 + (channel * channelStride)
        return FieldDefinition(
            id: "vanu.channel.\(channel).contactName", name: "contactName",
            displayName: "Contact Name", category: .channel,
            valueType: .string(maxLength: 20, encoding: .utf8),
            bitOffset: base + 8, bitLength: 160, defaultValue: .string("")
        )
    }
}
