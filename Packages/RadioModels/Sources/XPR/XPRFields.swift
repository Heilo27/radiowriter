import Foundation
import RadioCore
import RadioModelCore

/// Field definitions for the XPR (MOTOTRBO) radio family.
public enum XPRFields {
    static let channelStride = 512 // bits per channel entry

    // MARK: - General

    public static let radioId = FieldDefinition(
        id: "xpr.general.radioId", name: "radioId", displayName: "Radio ID",
        category: .general, valueType: .uint32,
        bitOffset: 0, bitLength: 32, defaultValue: .uint32(1),
        constraint: .range(min: 1, max: 16776415),
        helpText: "DMR radio identifier (1-16776415)"
    )

    public static let radioAlias = FieldDefinition(
        id: "xpr.general.alias", name: "radioAlias", displayName: "Radio Alias",
        category: .general, valueType: .string(maxLength: 16, encoding: .utf16),
        bitOffset: 32, bitLength: 256, defaultValue: .string("Radio"),
        constraint: .stringLength(min: 0, max: 16), helpText: "Radio display name (shown on screen)"
    )

    public static let numberOfChannels = FieldDefinition(
        id: "xpr.general.numChannels", name: "numberOfChannels", displayName: "Number of Channels",
        category: .general, valueType: .uint8,
        bitOffset: 288, bitLength: 8, defaultValue: .uint8(16),
        constraint: .range(min: 1, max: 255), helpText: "Active channel count"
    )

    public static let powerOnChannel = FieldDefinition(
        id: "xpr.general.powerOnChannel", name: "powerOnChannel", displayName: "Power-On Channel",
        category: .general, valueType: .enumeration([
            EnumOption(id: 0, name: "last", displayName: "Last Used"),
            EnumOption(id: 1, name: "default", displayName: "Channel 1"),
        ]),
        bitOffset: 296, bitLength: 8, defaultValue: .enumValue(0),
        helpText: "Channel selected when radio powers on"
    )

    public static let backlightTimer = FieldDefinition(
        id: "xpr.general.backlight", name: "backlightTimer", displayName: "Backlight Timer",
        category: .general, valueType: .enumeration([
            EnumOption(id: 0, name: "off", displayName: "Off"),
            EnumOption(id: 5, name: "5sec", displayName: "5 Seconds"),
            EnumOption(id: 10, name: "10sec", displayName: "10 Seconds"),
            EnumOption(id: 15, name: "15sec", displayName: "15 Seconds"),
            EnumOption(id: 30, name: "30sec", displayName: "30 Seconds"),
            EnumOption(id: 255, name: "always", displayName: "Always On"),
        ]),
        bitOffset: 304, bitLength: 8, defaultValue: .enumValue(5),
        helpText: "Display backlight duration"
    )

    public static let introScreenText = FieldDefinition(
        id: "xpr.general.introScreen", name: "introScreenText", displayName: "Intro Screen Text",
        category: .general, valueType: .string(maxLength: 20, encoding: .utf16),
        bitOffset: 312, bitLength: 320, defaultValue: .string("MOTOTRBO"),
        constraint: .stringLength(min: 0, max: 20),
        helpText: "Text shown on display at power-on"
    )

    // MARK: - Audio

    public static let volumeLevel = FieldDefinition(
        id: "xpr.audio.volume", name: "volumeLevel", displayName: "Volume Level",
        category: .audio, valueType: .uint8,
        bitOffset: 640, bitLength: 8, defaultValue: .uint8(5),
        constraint: .range(min: 0, max: 16), helpText: "Default volume level (0-16)"
    )

    public static let voxEnabled = FieldDefinition(
        id: "xpr.audio.voxEnabled", name: "voxEnabled", displayName: "VOX Enabled",
        category: .audio, valueType: .bool,
        bitOffset: 648, bitLength: 1, defaultValue: .bool(false),
        helpText: "Enable hands-free voice-activated transmit"
    )

    public static let voxSensitivity = FieldDefinition(
        id: "xpr.audio.voxSensitivity", name: "voxSensitivity", displayName: "VOX Sensitivity",
        category: .audio, valueType: .uint8,
        bitOffset: 656, bitLength: 8, defaultValue: .uint8(3),
        constraint: .range(min: 1, max: 10), dependencies: ["xpr.audio.voxEnabled"],
        helpText: "VOX trigger sensitivity (1=Low, 10=High)"
    )

    public static let keyBeepEnabled = FieldDefinition(
        id: "xpr.audio.keyBeep", name: "keyBeepEnabled", displayName: "Key Beep",
        category: .audio, valueType: .bool,
        bitOffset: 664, bitLength: 1, defaultValue: .bool(true),
        helpText: "Enable button press confirmation tone"
    )

    // MARK: - Contacts

    public static let maxContacts = FieldDefinition(
        id: "xpr.contacts.max", name: "maxContacts", displayName: "Max Contacts",
        category: .contacts, valueType: .uint16,
        bitOffset: 672, bitLength: 16, defaultValue: .uint16(256),
        helpText: "Maximum number of digital contacts"
    )

    public static let contactsCount = FieldDefinition(
        id: "xpr.contacts.count", name: "contactsCount", displayName: "Contact Count",
        category: .contacts, valueType: .uint16,
        bitOffset: 688, bitLength: 16, defaultValue: .uint16(0),
        helpText: "Current number of programmed contacts"
    )

    // MARK: - Signaling

    public static let emergencyAlarmType = FieldDefinition(
        id: "xpr.signaling.emergencyType", name: "emergencyAlarmType", displayName: "Emergency Type",
        category: .signaling, valueType: .enumeration([
            EnumOption(id: 0, name: "none", displayName: "None"),
            EnumOption(id: 1, name: "alarm", displayName: "Alarm Only"),
            EnumOption(id: 2, name: "alarmCall", displayName: "Alarm + Call"),
            EnumOption(id: 3, name: "alarmVoice", displayName: "Alarm + Voice"),
        ]),
        bitOffset: 704, bitLength: 8, defaultValue: .enumValue(0),
        helpText: "Emergency alarm activation behavior"
    )

    public static let txInterruptEnabled = FieldDefinition(
        id: "xpr.signaling.txInterrupt", name: "txInterruptEnabled", displayName: "TX Interrupt",
        category: .signaling, valueType: .bool,
        bitOffset: 712, bitLength: 1, defaultValue: .bool(false),
        helpText: "Allow incoming calls to interrupt current transmission"
    )

    // MARK: - Scan

    public static let scanAutoStart = FieldDefinition(
        id: "xpr.scan.autoStart", name: "scanAutoStart", displayName: "Auto-Start Scan",
        category: .scan, valueType: .bool,
        bitOffset: 720, bitLength: 1, defaultValue: .bool(false),
        helpText: "Automatically start scanning at power-on"
    )

    public static let scanTalkback = FieldDefinition(
        id: "xpr.scan.talkback", name: "scanTalkback", displayName: "Scan Talkback",
        category: .scan, valueType: .bool,
        bitOffset: 728, bitLength: 1, defaultValue: .bool(true),
        helpText: "Respond on the channel where signal was received during scan"
    )

    // MARK: - Advanced

    public static let totTimeout = FieldDefinition(
        id: "xpr.advanced.tot", name: "totTimeout", displayName: "TX Timeout (TOT)",
        category: .advanced, valueType: .uint16,
        bitOffset: 736, bitLength: 16, defaultValue: .uint16(60),
        constraint: .range(min: 0, max: 495),
        helpText: "Transmit timeout in seconds (0 = Infinite, max 495s)"
    )

    public static let loneWorkerEnabled = FieldDefinition(
        id: "xpr.advanced.loneWorker", name: "loneWorkerEnabled", displayName: "Lone Worker",
        category: .advanced, valueType: .bool,
        bitOffset: 752, bitLength: 1, defaultValue: .bool(false),
        helpText: "Enable lone worker periodic check-in"
    )

    public static let loneWorkerTimer = FieldDefinition(
        id: "xpr.advanced.loneWorkerTimer", name: "loneWorkerTimer", displayName: "Lone Worker Timer",
        category: .advanced, valueType: .uint8,
        bitOffset: 760, bitLength: 8, defaultValue: .uint8(60),
        constraint: .range(min: 1, max: 255), dependencies: ["xpr.advanced.loneWorker"],
        helpText: "Lone worker check-in interval in minutes"
    )

    public static let passwordEnabled = FieldDefinition(
        id: "xpr.advanced.password", name: "passwordEnabled", displayName: "Power-On Password",
        category: .advanced, valueType: .bool,
        bitOffset: 768, bitLength: 1, defaultValue: .bool(false),
        helpText: "Require password at power-on"
    )

    public static let encryptionEnabled = FieldDefinition(
        id: "xpr.advanced.encryption", name: "encryptionEnabled", displayName: "Enhanced Privacy",
        category: .advanced, valueType: .bool,
        bitOffset: 776, bitLength: 1, defaultValue: .bool(false),
        helpText: "Enable ARC4 or AES-256 voice encryption"
    )

    // MARK: - GPS

    public static let gpsEnabled = FieldDefinition(
        id: "xpr.gps.enabled", name: "gpsEnabled", displayName: "GPS Enabled",
        category: .advanced, valueType: .bool,
        bitOffset: 784, bitLength: 1, defaultValue: .bool(false),
        helpText: "Enable GPS location reporting"
    )

    public static let gpsReportInterval = FieldDefinition(
        id: "xpr.gps.reportInterval", name: "gpsReportInterval", displayName: "GPS Report Interval",
        category: .advanced, valueType: .uint16,
        bitOffset: 792, bitLength: 16, defaultValue: .uint16(300),
        constraint: .range(min: 5, max: 3600), dependencies: ["xpr.gps.enabled"],
        helpText: "GPS position report interval in seconds"
    )

    // MARK: - Per-Channel Fields

    static let channelBaseOffset = 2048

    public static func channelName(channel: Int) -> FieldDefinition {
        FieldDefinition(
            id: "xpr.channel.\(channel).name", name: "channel\(channel + 1)Name",
            displayName: "Name", category: .channel,
            valueType: .string(maxLength: 16, encoding: .utf16),
            bitOffset: channelBaseOffset + (channel * channelStride),
            bitLength: 256, defaultValue: .string("CH\(channel + 1)"),
            constraint: .stringLength(min: 0, max: 16),
            helpText: "Channel \(channel + 1) display name"
        )
    }

    public static func channelRxFreq(channel: Int) -> FieldDefinition {
        FieldDefinition(
            id: "xpr.channel.\(channel).rxFreq", name: "channel\(channel + 1)RxFreq",
            displayName: "RX Frequency", category: .channel, valueType: .uint32,
            bitOffset: channelBaseOffset + (channel * channelStride) + 256,
            bitLength: 32, defaultValue: .uint32(4500000),
            helpText: "Channel \(channel + 1) receive frequency in 100 Hz units"
        )
    }

    public static func channelTxFreq(channel: Int) -> FieldDefinition {
        FieldDefinition(
            id: "xpr.channel.\(channel).txFreq", name: "channel\(channel + 1)TxFreq",
            displayName: "TX Frequency", category: .channel, valueType: .uint32,
            bitOffset: channelBaseOffset + (channel * channelStride) + 288,
            bitLength: 32, defaultValue: .uint32(4500000),
            helpText: "Channel \(channel + 1) transmit frequency in 100 Hz units"
        )
    }

    public static func channelTxPower(channel: Int) -> FieldDefinition {
        FieldDefinition(
            id: "xpr.channel.\(channel).txPower", name: "channel\(channel + 1)TxPower",
            displayName: "TX Power", category: .channel,
            valueType: .enumeration([
                EnumOption(id: 0, name: "low", displayName: "Low (1W)"),
                EnumOption(id: 1, name: "high", displayName: "High (4W)"),
            ]),
            bitOffset: channelBaseOffset + (channel * channelStride) + 320,
            bitLength: 8, defaultValue: .enumValue(1),
            helpText: "Channel \(channel + 1) transmit power"
        )
    }

    public static func channelBandwidth(channel: Int) -> FieldDefinition {
        FieldDefinition(
            id: "xpr.channel.\(channel).bandwidth", name: "channel\(channel + 1)Bandwidth",
            displayName: "Bandwidth", category: .channel,
            valueType: .enumeration([
                EnumOption(id: 0, name: "narrow", displayName: "12.5 kHz"),
                EnumOption(id: 1, name: "wide", displayName: "25 kHz"),
            ]),
            bitOffset: channelBaseOffset + (channel * channelStride) + 328,
            bitLength: 8, defaultValue: .enumValue(0),
            helpText: "Channel \(channel + 1) bandwidth"
        )
    }

    public static func channelMode(channel: Int) -> FieldDefinition {
        FieldDefinition(
            id: "xpr.channel.\(channel).mode", name: "channel\(channel + 1)Mode",
            displayName: "Channel Type", category: .channel,
            valueType: .enumeration([
                EnumOption(id: 0, name: "analog", displayName: "Analog"),
                EnumOption(id: 1, name: "digital", displayName: "Digital"),
            ]),
            bitOffset: channelBaseOffset + (channel * channelStride) + 336,
            bitLength: 8, defaultValue: .enumValue(1),
            helpText: "Channel \(channel + 1) operating mode (Analog FM or DMR Digital)"
        )
    }

    public static func channelColorCode(channel: Int) -> FieldDefinition {
        FieldDefinition(
            id: "xpr.channel.\(channel).colorCode", name: "channel\(channel + 1)ColorCode",
            displayName: "Color Code", category: .channel, valueType: .uint8,
            bitOffset: channelBaseOffset + (channel * channelStride) + 344,
            bitLength: 8, defaultValue: .uint8(1),
            constraint: .range(min: 0, max: 15),
            helpText: "DMR color code (0-15)"
        )
    }

    public static func channelTimeSlot(channel: Int) -> FieldDefinition {
        FieldDefinition(
            id: "xpr.channel.\(channel).timeSlot", name: "channel\(channel + 1)TimeSlot",
            displayName: "Time Slot", category: .channel,
            valueType: .enumeration([
                EnumOption(id: 1, name: "ts1", displayName: "Slot 1"),
                EnumOption(id: 2, name: "ts2", displayName: "Slot 2"),
            ]),
            bitOffset: channelBaseOffset + (channel * channelStride) + 352,
            bitLength: 8, defaultValue: .enumValue(1),
            helpText: "DMR TDMA time slot"
        )
    }

    public static func channelContactName(channel: Int) -> FieldDefinition {
        FieldDefinition(
            id: "xpr.channel.\(channel).contact", name: "channel\(channel + 1)Contact",
            displayName: "TX Contact", category: .channel,
            valueType: .string(maxLength: 16, encoding: .utf16),
            bitOffset: channelBaseOffset + (channel * channelStride) + 360,
            bitLength: 256, defaultValue: .string(""),
            constraint: .stringLength(min: 0, max: 16),
            helpText: "Default contact for transmissions on channel \(channel + 1)"
        )
    }

    public static func channelRxGroupList(channel: Int) -> FieldDefinition {
        FieldDefinition(
            id: "xpr.channel.\(channel).rxGroup", name: "channel\(channel + 1)RxGroup",
            displayName: "RX Group List", category: .channel, valueType: .uint8,
            bitOffset: channelBaseOffset + (channel * channelStride) + 448,
            bitLength: 8, defaultValue: .uint8(0),
            constraint: .range(min: 0, max: 64),
            helpText: "Receive group list index (0 = None)"
        )
    }
}
