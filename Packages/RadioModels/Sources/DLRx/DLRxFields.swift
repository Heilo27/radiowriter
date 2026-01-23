import Foundation
import RadioCore
import RadioModelCore

/// Field definitions for DLRx radio family (DLR1020/1060).
/// Digital 900 MHz FHSS radios with contacts and PIN security.
public enum DLRxFields {
    public static let pin = FieldDefinition(
        id: "dlrx.general.pin", name: "pin",
        displayName: "PIN Code", category: .general,
        valueType: .string(maxLength: 4, encoding: .utf8),
        bitOffset: 0, bitLength: 32, defaultValue: .string("0000"),
        constraint: .stringLength(min: 4, max: 4),
        helpText: "4-digit security PIN"
    )

    public static let numChannels = FieldDefinition(
        id: "dlrx.general.numChannels", name: "numChannels",
        displayName: "Number of Channels", category: .general,
        valueType: .uint8, bitOffset: 32, bitLength: 8, defaultValue: .uint8(2),
        isReadOnly: true
    )

    public static let vpUserMode = FieldDefinition(
        id: "dlrx.audio.vpUserMode", name: "vpUserMode",
        displayName: "Voice Prompts", category: .audio,
        valueType: .bool, bitOffset: 40, bitLength: 1, defaultValue: .bool(true)
    )

    public static let powerUpTone = FieldDefinition(
        id: "dlrx.audio.powerUpTone", name: "powerUpTone",
        displayName: "Power-Up Tone", category: .audio,
        valueType: .enumeration([
            EnumOption(id: 0, name: "off", displayName: "Off"),
            EnumOption(id: 1, name: "tone", displayName: "Tone"),
            EnumOption(id: 2, name: "prompt", displayName: "Voice Prompt"),
        ]),
        bitOffset: 48, bitLength: 8, defaultValue: .enumValue(1)
    )

    public static let pinLockEnabled = FieldDefinition(
        id: "dlrx.general.pinLock", name: "pinLockEnabled",
        displayName: "PIN Lock", category: .general,
        valueType: .bool, bitOffset: 56, bitLength: 1, defaultValue: .bool(false),
        helpText: "Require PIN on power-up"
    )

    public static let directContactId = FieldDefinition(
        id: "dlrx.contacts.directId", name: "directContactId",
        displayName: "Direct Contact ID", category: .contacts,
        valueType: .uint16, bitOffset: 64, bitLength: 16, defaultValue: .uint16(0)
    )

    public static let favContactCount = FieldDefinition(
        id: "dlrx.contacts.favCount", name: "favContactCount",
        displayName: "Favorite Contacts", category: .contacts,
        valueType: .uint8, bitOffset: 80, bitLength: 8, defaultValue: .uint8(0),
        constraint: .range(min: 0, max: 10)
    )

    public static let wifiEnabled = FieldDefinition(
        id: "dlrx.advanced.wifiEnabled", name: "wifiEnabled",
        displayName: "WiFi Enabled", category: .advanced,
        valueType: .bool, bitOffset: 88, bitLength: 1, defaultValue: .bool(false)
    )

    public static let wifiSSID = FieldDefinition(
        id: "dlrx.advanced.wifiSSID", name: "wifiSSID",
        displayName: "WiFi SSID", category: .advanced,
        valueType: .string(maxLength: 32, encoding: .utf8),
        bitOffset: 96, bitLength: 256, defaultValue: .string("")
    )

    public static func channelMode(channel: Int) -> FieldDefinition {
        let base = 512 + (channel * 256)
        return FieldDefinition(
            id: "dlrx.channel.\(channel).mode", name: "pinMode",
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
        let base = 512 + (channel * 256)
        return FieldDefinition(
            id: "dlrx.channel.\(channel).contactName", name: "contactName",
            displayName: "Contact Name", category: .channel,
            valueType: .string(maxLength: 18, encoding: .utf8),
            bitOffset: base + 8, bitLength: 144, defaultValue: .string("")
        )
    }
}
