import Foundation
import RadioCore
import RadioModelCore

/// Field definitions for DTR radio family (DTR410/620/700).
/// Digital 900 MHz FHSS radios with contacts, text messaging, and PIN security.
public enum DtrFields {
    // MARK: - General Settings

    public static let pin = FieldDefinition(
        id: "dtr.general.pin", name: "pin",
        displayName: "PIN Code", category: .general,
        valueType: .string(maxLength: 5, encoding: .utf8),
        bitOffset: 0, bitLength: 40, defaultValue: .string("00000"),
        constraint: .stringLength(min: 5, max: 5),
        helpText: "5-digit security PIN"
    )

    public static let numChannels = FieldDefinition(
        id: "dtr.general.numChannels", name: "numChannels",
        displayName: "Number of Channels", category: .general,
        valueType: .uint8, bitOffset: 40, bitLength: 8, defaultValue: .uint8(10),
        isReadOnly: true
    )

    public static let vpUserMode = FieldDefinition(
        id: "dtr.audio.vpUserMode", name: "vpUserMode",
        displayName: "Voice Prompts", category: .audio,
        valueType: .bool, bitOffset: 48, bitLength: 1, defaultValue: .bool(true)
    )

    public static let powerUpTone = FieldDefinition(
        id: "dtr.audio.powerUpTone", name: "powerUpTone",
        displayName: "Power-Up Tone", category: .audio,
        valueType: .enumeration([
            EnumOption(id: 0, name: "off", displayName: "Off"),
            EnumOption(id: 1, name: "tone", displayName: "Tone"),
            EnumOption(id: 2, name: "prompt", displayName: "Voice Prompt"),
        ]),
        bitOffset: 56, bitLength: 8, defaultValue: .enumValue(1)
    )

    public static let pinLockEnabled = FieldDefinition(
        id: "dtr.general.pinLock", name: "pinLockEnabled",
        displayName: "PIN Lock", category: .general,
        valueType: .bool, bitOffset: 64, bitLength: 1, defaultValue: .bool(false),
        helpText: "Require PIN on power-up"
    )

    public static let backlightTimer = FieldDefinition(
        id: "dtr.general.backlightTimer", name: "backlightTimer",
        displayName: "Backlight Timer", category: .general,
        valueType: .enumeration([
            EnumOption(id: 0, name: "off", displayName: "Off"),
            EnumOption(id: 1, name: "5s", displayName: "5 seconds"),
            EnumOption(id: 2, name: "10s", displayName: "10 seconds"),
            EnumOption(id: 3, name: "15s", displayName: "15 seconds"),
            EnumOption(id: 4, name: "continuous", displayName: "Continuous"),
        ]),
        bitOffset: 72, bitLength: 8, defaultValue: .enumValue(2)
    )

    public static let contrast = FieldDefinition(
        id: "dtr.general.contrast", name: "contrast",
        displayName: "Display Contrast", category: .general,
        valueType: .uint8, bitOffset: 80, bitLength: 8, defaultValue: .uint8(3),
        constraint: .range(min: 0, max: 6)
    )

    // MARK: - Contacts

    public static let directContactId = FieldDefinition(
        id: "dtr.contacts.directId", name: "directContactId",
        displayName: "Direct Contact ID", category: .contacts,
        valueType: .uint16, bitOffset: 88, bitLength: 16, defaultValue: .uint16(0)
    )

    public static let maxContacts = FieldDefinition(
        id: "dtr.contacts.maxContacts", name: "maxContacts",
        displayName: "Max Contacts", category: .contacts,
        valueType: .uint8, bitOffset: 104, bitLength: 8, defaultValue: .uint8(150),
        isReadOnly: true
    )

    // MARK: - Channel Fields

    static let channelStride = 256 // bits per channel

    public static func channelMode(channel: Int) -> FieldDefinition {
        let base = 512 + (channel * channelStride)
        return FieldDefinition(
            id: "dtr.channel.\(channel).mode", name: "pinMode",
            displayName: "Mode", category: .channel,
            valueType: .enumeration([
                EnumOption(id: 0, name: "pin", displayName: "PIN"),
                EnumOption(id: 1, name: "group", displayName: "Group Call"),
                EnumOption(id: 2, name: "private", displayName: "Private Call"),
                EnumOption(id: 3, name: "public", displayName: "Public"),
            ]),
            bitOffset: base, bitLength: 8, defaultValue: .enumValue(0)
        )
    }

    public static func channelContactName(channel: Int) -> FieldDefinition {
        let base = 512 + (channel * channelStride)
        return FieldDefinition(
            id: "dtr.channel.\(channel).contactName", name: "contactName",
            displayName: "Contact Name", category: .channel,
            valueType: .string(maxLength: 20, encoding: .utf8),
            bitOffset: base + 8, bitLength: 160, defaultValue: .string("")
        )
    }

    public static func channelRinger(channel: Int) -> FieldDefinition {
        let base = 512 + (channel * channelStride)
        return FieldDefinition(
            id: "dtr.channel.\(channel).ringer", name: "ringer",
            displayName: "Ringer", category: .channel,
            valueType: .uint8, bitOffset: base + 168, bitLength: 8, defaultValue: .uint8(0),
            constraint: .range(min: 0, max: 12)
        )
    }
}
