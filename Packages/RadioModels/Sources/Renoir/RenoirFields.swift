import Foundation
import RadioCore
import RadioModelCore

/// Field definitions for Renoir radio family (RMU2040/2080).
/// UHF/VHF digital radios with contacts and PIN modes.
public enum RenoirFields {
    static let channelStride = 256 // bits per channel

    // MARK: - General Settings

    public static let pin = FieldDefinition(
        id: "renoir.general.pin", name: "pin",
        displayName: "PIN Code", category: .general,
        valueType: .string(maxLength: 4, encoding: .utf8),
        bitOffset: 0, bitLength: 32, defaultValue: .string("0000"),
        constraint: .stringLength(min: 4, max: 4),
        helpText: "4-digit security PIN"
    )

    public static let numChannels = FieldDefinition(
        id: "renoir.general.numChannels", name: "numChannels",
        displayName: "Number of Channels", category: .general,
        valueType: .uint8, bitOffset: 32, bitLength: 8, defaultValue: .uint8(4),
        isReadOnly: true
    )

    public static let pinLockEnabled = FieldDefinition(
        id: "renoir.general.pinLock", name: "pinLockEnabled",
        displayName: "PIN Lock", category: .general,
        valueType: .bool, bitOffset: 40, bitLength: 1, defaultValue: .bool(false),
        helpText: "Require PIN on power-up"
    )

    public static let powerUpTone = FieldDefinition(
        id: "renoir.audio.powerUpTone", name: "powerUpTone",
        displayName: "Power-Up Tone", category: .audio,
        valueType: .enumeration([
            EnumOption(id: 0, name: "off", displayName: "Off"),
            EnumOption(id: 1, name: "tone", displayName: "Tone"),
            EnumOption(id: 2, name: "silent", displayName: "Silent"),
        ]),
        bitOffset: 48, bitLength: 8, defaultValue: .enumValue(1)
    )

    public static let codeplugResetEnabled = FieldDefinition(
        id: "renoir.advanced.codeplugReset", name: "codeplugResetEnabled",
        displayName: "Factory Reset Enabled", category: .advanced,
        valueType: .bool, bitOffset: 56, bitLength: 1, defaultValue: .bool(true)
    )

    public static let vibracallEnabled = FieldDefinition(
        id: "renoir.general.vibracall", name: "vibracallEnabled",
        displayName: "VibraCall Alert", category: .general,
        valueType: .bool, bitOffset: 57, bitLength: 1, defaultValue: .bool(false),
        helpText: "Vibration alert for incoming calls"
    )

    public static let radioName = FieldDefinition(
        id: "renoir.general.radioName", name: "radioName",
        displayName: "Radio Name", category: .general,
        valueType: .string(maxLength: 12, encoding: .utf8),
        bitOffset: 64, bitLength: 96, defaultValue: .string("")
    )

    public static let backlightTimer = FieldDefinition(
        id: "renoir.general.backlightTimer", name: "backlightTimer",
        displayName: "Backlight Timer", category: .general,
        valueType: .enumeration([
            EnumOption(id: 0, name: "off", displayName: "Off"),
            EnumOption(id: 1, name: "5s", displayName: "5 seconds"),
            EnumOption(id: 2, name: "10s", displayName: "10 seconds"),
            EnumOption(id: 3, name: "15s", displayName: "15 seconds"),
            EnumOption(id: 4, name: "continuous", displayName: "Continuous"),
        ]),
        bitOffset: 160, bitLength: 8, defaultValue: .enumValue(2)
    )

    public static let powerSaveMode = FieldDefinition(
        id: "renoir.general.powerSave", name: "powerSaveMode",
        displayName: "Power Save Mode", category: .general,
        valueType: .bool, bitOffset: 168, bitLength: 1, defaultValue: .bool(true)
    )

    public static let managerMode = FieldDefinition(
        id: "renoir.advanced.managerMode", name: "managerMode",
        displayName: "Manager Mode", category: .advanced,
        valueType: .bool, bitOffset: 169, bitLength: 1, defaultValue: .bool(false),
        helpText: "Enable manager-only features"
    )

    // MARK: - Contacts

    public static let directContactId = FieldDefinition(
        id: "renoir.contacts.directId", name: "directContactId",
        displayName: "Direct Contact ID", category: .contacts,
        valueType: .uint16, bitOffset: 176, bitLength: 16, defaultValue: .uint16(0)
    )

    public static let homeChanIndex = FieldDefinition(
        id: "renoir.general.homeChan", name: "homeChanIndex",
        displayName: "Home Channel", category: .general,
        valueType: .uint8, bitOffset: 192, bitLength: 8, defaultValue: .uint8(0)
    )

    // MARK: - Channel Fields

    public static func channelMode(channel: Int) -> FieldDefinition {
        let base = 512 + (channel * channelStride)
        return FieldDefinition(
            id: "renoir.channel.\(channel).mode", name: "pinMode",
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
            id: "renoir.channel.\(channel).contactName", name: "contactName",
            displayName: "Contact Name", category: .channel,
            valueType: .string(maxLength: 20, encoding: .utf8),
            bitOffset: base + 8, bitLength: 160, defaultValue: .string("")
        )
    }
}
