import Foundation
import RadioCore
import RadioModelCore

/// Field definitions for the APX (P25) radio family.
public enum APXFields {
    static let channelStride = 640 // bits per channel entry

    // MARK: - General

    public static let radioId = FieldDefinition(
        id: "apx.general.radioId", name: "radioId", displayName: "Radio ID (WACN Unit ID)",
        category: .general, valueType: .uint32,
        bitOffset: 0, bitLength: 32, defaultValue: .uint32(1),
        constraint: .range(min: 1, max: 16777215),
        helpText: "P25 unit identifier"
    )

    public static let radioAlias = FieldDefinition(
        id: "apx.general.alias", name: "radioAlias", displayName: "Radio Alias",
        category: .general, valueType: .string(maxLength: 16, encoding: .utf16),
        bitOffset: 32, bitLength: 256, defaultValue: .string("APX"),
        constraint: .stringLength(min: 0, max: 16), helpText: "Radio display name"
    )

    public static let numberOfChannels = FieldDefinition(
        id: "apx.general.numChannels", name: "numberOfChannels", displayName: "Number of Channels",
        category: .general, valueType: .uint8,
        bitOffset: 288, bitLength: 8, defaultValue: .uint8(16),
        constraint: .range(min: 1, max: 255), helpText: "Active channel count in current zone"
    )

    public static let defaultZone = FieldDefinition(
        id: "apx.general.defaultZone", name: "defaultZone", displayName: "Default Zone",
        category: .general, valueType: .uint8,
        bitOffset: 296, bitLength: 8, defaultValue: .uint8(0),
        helpText: "Zone selected at power-on (0 = Zone 1)"
    )

    public static let backlightTimer = FieldDefinition(
        id: "apx.general.backlight", name: "backlightTimer", displayName: "Backlight Timer",
        category: .general, valueType: .enumeration([
            EnumOption(id: 0, name: "off", displayName: "Off"),
            EnumOption(id: 5, name: "5sec", displayName: "5 Seconds"),
            EnumOption(id: 10, name: "10sec", displayName: "10 Seconds"),
            EnumOption(id: 30, name: "30sec", displayName: "30 Seconds"),
            EnumOption(id: 255, name: "always", displayName: "Always On"),
        ]),
        bitOffset: 304, bitLength: 8, defaultValue: .enumValue(10),
        helpText: "Display backlight duration"
    )

    public static let introScreenText = FieldDefinition(
        id: "apx.general.introScreen", name: "introScreenText", displayName: "Intro Screen Text",
        category: .general, valueType: .string(maxLength: 16, encoding: .utf16),
        bitOffset: 312, bitLength: 256, defaultValue: .string("ASTRO 25"),
        constraint: .stringLength(min: 0, max: 16),
        helpText: "Text shown on display at power-on"
    )

    // MARK: - Audio

    public static let volumeLevel = FieldDefinition(
        id: "apx.audio.volume", name: "volumeLevel", displayName: "Volume Level",
        category: .audio, valueType: .uint8,
        bitOffset: 576, bitLength: 8, defaultValue: .uint8(5),
        constraint: .range(min: 0, max: 16), helpText: "Default volume level (0-16)"
    )

    public static let keyBeepEnabled = FieldDefinition(
        id: "apx.audio.keyBeep", name: "keyBeepEnabled", displayName: "Key Beep",
        category: .audio, valueType: .bool,
        bitOffset: 584, bitLength: 1, defaultValue: .bool(true),
        helpText: "Enable button press confirmation tone"
    )

    public static let alertToneVolume = FieldDefinition(
        id: "apx.audio.alertVolume", name: "alertToneVolume", displayName: "Alert Tone Volume",
        category: .audio, valueType: .uint8,
        bitOffset: 592, bitLength: 8, defaultValue: .uint8(5),
        constraint: .range(min: 0, max: 10), helpText: "Volume for alert and warning tones"
    )

    // MARK: - Signaling

    public static let emergencyEnabled = FieldDefinition(
        id: "apx.signaling.emergency", name: "emergencyEnabled", displayName: "Emergency Button",
        category: .signaling, valueType: .bool,
        bitOffset: 608, bitLength: 1, defaultValue: .bool(true),
        helpText: "Enable dedicated emergency button"
    )

    public static let emergencyType = FieldDefinition(
        id: "apx.signaling.emergencyType", name: "emergencyType", displayName: "Emergency Type",
        category: .signaling, valueType: .enumeration([
            EnumOption(id: 0, name: "alarm", displayName: "Silent Alarm"),
            EnumOption(id: 1, name: "alarmCall", displayName: "Alarm + Call"),
            EnumOption(id: 2, name: "alarmVoice", displayName: "Alarm + Voice"),
        ]),
        bitOffset: 616, bitLength: 8, defaultValue: .enumValue(1),
        dependencies: ["apx.signaling.emergency"],
        helpText: "Emergency alarm activation behavior"
    )

    public static let manDownEnabled = FieldDefinition(
        id: "apx.signaling.manDown", name: "manDownEnabled", displayName: "Man Down",
        category: .signaling, valueType: .bool,
        bitOffset: 624, bitLength: 1, defaultValue: .bool(false),
        helpText: "Enable accelerometer-based man down detection"
    )

    public static let manDownTimer = FieldDefinition(
        id: "apx.signaling.manDownTimer", name: "manDownTimer", displayName: "Man Down Timer",
        category: .signaling, valueType: .uint8,
        bitOffset: 632, bitLength: 8, defaultValue: .uint8(30),
        constraint: .range(min: 5, max: 120), dependencies: ["apx.signaling.manDown"],
        helpText: "Seconds of no movement before man down alert (5-120)"
    )

    // MARK: - Scan

    public static let scanAutoStart = FieldDefinition(
        id: "apx.scan.autoStart", name: "scanAutoStart", displayName: "Auto-Start Scan",
        category: .scan, valueType: .bool,
        bitOffset: 640, bitLength: 1, defaultValue: .bool(false),
        helpText: "Automatically start scanning at power-on"
    )

    public static let priorityScanEnabled = FieldDefinition(
        id: "apx.scan.priority", name: "priorityScanEnabled", displayName: "Priority Scan",
        category: .scan, valueType: .bool,
        bitOffset: 648, bitLength: 1, defaultValue: .bool(true),
        helpText: "Enable priority channel monitoring during scan"
    )

    // MARK: - Advanced

    public static let totTimeout = FieldDefinition(
        id: "apx.advanced.tot", name: "totTimeout", displayName: "TX Timeout (TOT)",
        category: .advanced, valueType: .uint16,
        bitOffset: 656, bitLength: 16, defaultValue: .uint16(60),
        constraint: .range(min: 0, max: 495),
        helpText: "Transmit timeout in seconds (0 = Infinite)"
    )

    public static let encryptionType = FieldDefinition(
        id: "apx.advanced.encryptionType", name: "encryptionType", displayName: "Encryption Type",
        category: .advanced, valueType: .enumeration([
            EnumOption(id: 0, name: "none", displayName: "None"),
            EnumOption(id: 1, name: "des", displayName: "DES-OFB"),
            EnumOption(id: 2, name: "desxl", displayName: "DES-XL"),
            EnumOption(id: 3, name: "aes256", displayName: "AES-256"),
        ]),
        bitOffset: 672, bitLength: 8, defaultValue: .enumValue(0),
        helpText: "Voice encryption algorithm"
    )

    public static let gpsEnabled = FieldDefinition(
        id: "apx.advanced.gps", name: "gpsEnabled", displayName: "GPS Enabled",
        category: .advanced, valueType: .bool,
        bitOffset: 680, bitLength: 1, defaultValue: .bool(true),
        helpText: "Enable GPS location reporting"
    )

    public static let gpsReportInterval = FieldDefinition(
        id: "apx.advanced.gpsInterval", name: "gpsReportInterval", displayName: "GPS Report Interval",
        category: .advanced, valueType: .uint16,
        bitOffset: 688, bitLength: 16, defaultValue: .uint16(60),
        constraint: .range(min: 5, max: 3600), dependencies: ["apx.advanced.gps"],
        helpText: "GPS position report interval in seconds"
    )

    public static let otaEnabled = FieldDefinition(
        id: "apx.advanced.ota", name: "otaEnabled", displayName: "Over-the-Air Programming",
        category: .advanced, valueType: .bool,
        bitOffset: 704, bitLength: 1, defaultValue: .bool(false),
        helpText: "Allow over-the-air rekeying and programming"
    )

    public static let passwordEnabled = FieldDefinition(
        id: "apx.advanced.password", name: "passwordEnabled", displayName: "Power-On Password",
        category: .advanced, valueType: .bool,
        bitOffset: 712, bitLength: 1, defaultValue: .bool(false),
        helpText: "Require password at power-on"
    )

    // MARK: - Trunking

    public static let trunkingEnabled = FieldDefinition(
        id: "apx.trunking.enabled", name: "trunkingEnabled", displayName: "Trunking Enabled",
        category: .advanced, valueType: .bool,
        bitOffset: 720, bitLength: 1, defaultValue: .bool(false),
        helpText: "Enable P25 trunking mode"
    )

    public static let systemType = FieldDefinition(
        id: "apx.trunking.systemType", name: "systemType", displayName: "System Type",
        category: .advanced, valueType: .enumeration([
            EnumOption(id: 0, name: "conventional", displayName: "Conventional"),
            EnumOption(id: 1, name: "p25phase1", displayName: "P25 Phase I (FDMA)"),
            EnumOption(id: 2, name: "p25phase2", displayName: "P25 Phase II (TDMA)"),
        ]),
        bitOffset: 728, bitLength: 8, defaultValue: .enumValue(0),
        dependencies: ["apx.trunking.enabled"],
        helpText: "Trunking system type"
    )

    public static let wacn = FieldDefinition(
        id: "apx.trunking.wacn", name: "wacn", displayName: "WACN",
        category: .advanced, valueType: .uint32,
        bitOffset: 736, bitLength: 20, defaultValue: .uint32(0),
        constraint: .range(min: 0, max: 1048575),
        dependencies: ["apx.trunking.enabled"],
        helpText: "Wide Area Communication Network ID (20-bit)"
    )

    public static let systemId = FieldDefinition(
        id: "apx.trunking.systemId", name: "systemId", displayName: "System ID",
        category: .advanced, valueType: .uint16,
        bitOffset: 768, bitLength: 12, defaultValue: .uint16(0),
        constraint: .range(min: 0, max: 4095),
        dependencies: ["apx.trunking.enabled"],
        helpText: "Trunking system identifier (12-bit)"
    )

    // MARK: - Per-Channel Fields

    static let channelBaseOffset = 2048

    public static func channelName(channel: Int) -> FieldDefinition {
        FieldDefinition(
            id: "apx.channel.\(channel).name", name: "channel\(channel + 1)Name",
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
            id: "apx.channel.\(channel).rxFreq", name: "channel\(channel + 1)RxFreq",
            displayName: "RX Frequency", category: .channel, valueType: .uint32,
            bitOffset: channelBaseOffset + (channel * channelStride) + 256,
            bitLength: 32, defaultValue: .uint32(7700000),
            helpText: "Channel \(channel + 1) receive frequency in 100 Hz units"
        )
    }

    public static func channelTxFreq(channel: Int) -> FieldDefinition {
        FieldDefinition(
            id: "apx.channel.\(channel).txFreq", name: "channel\(channel + 1)TxFreq",
            displayName: "TX Frequency", category: .channel, valueType: .uint32,
            bitOffset: channelBaseOffset + (channel * channelStride) + 288,
            bitLength: 32, defaultValue: .uint32(7700000),
            helpText: "Channel \(channel + 1) transmit frequency in 100 Hz units"
        )
    }

    public static func channelTxPower(channel: Int) -> FieldDefinition {
        FieldDefinition(
            id: "apx.channel.\(channel).txPower", name: "channel\(channel + 1)TxPower",
            displayName: "TX Power", category: .channel,
            valueType: .enumeration([
                EnumOption(id: 0, name: "low", displayName: "Low (1W)"),
                EnumOption(id: 1, name: "mid", displayName: "Mid (2.5W)"),
                EnumOption(id: 2, name: "high", displayName: "High (5W)"),
            ]),
            bitOffset: channelBaseOffset + (channel * channelStride) + 320,
            bitLength: 8, defaultValue: .enumValue(2),
            helpText: "Channel \(channel + 1) transmit power"
        )
    }

    public static func channelBandwidth(channel: Int) -> FieldDefinition {
        FieldDefinition(
            id: "apx.channel.\(channel).bandwidth", name: "channel\(channel + 1)Bandwidth",
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
            id: "apx.channel.\(channel).mode", name: "channel\(channel + 1)Mode",
            displayName: "Channel Type", category: .channel,
            valueType: .enumeration([
                EnumOption(id: 0, name: "analog", displayName: "Analog (FM)"),
                EnumOption(id: 1, name: "p25conv", displayName: "P25 Conventional"),
                EnumOption(id: 2, name: "p25trunk", displayName: "P25 Trunked"),
            ]),
            bitOffset: channelBaseOffset + (channel * channelStride) + 336,
            bitLength: 8, defaultValue: .enumValue(1),
            helpText: "Channel \(channel + 1) operating mode"
        )
    }

    public static func channelNAC(channel: Int) -> FieldDefinition {
        FieldDefinition(
            id: "apx.channel.\(channel).nac", name: "channel\(channel + 1)NAC",
            displayName: "NAC", category: .channel, valueType: .uint16,
            bitOffset: channelBaseOffset + (channel * channelStride) + 344,
            bitLength: 12, defaultValue: .uint16(0x293),
            constraint: .range(min: 0, max: 4095),
            helpText: "P25 Network Access Code (12-bit, default 0x293)"
        )
    }

    public static func channelEncryption(channel: Int) -> FieldDefinition {
        FieldDefinition(
            id: "apx.channel.\(channel).encryption", name: "channel\(channel + 1)Encryption",
            displayName: "Encryption", category: .channel,
            valueType: .enumeration([
                EnumOption(id: 0, name: "none", displayName: "Clear"),
                EnumOption(id: 1, name: "des", displayName: "DES"),
                EnumOption(id: 2, name: "aes", displayName: "AES-256"),
            ]),
            bitOffset: channelBaseOffset + (channel * channelStride) + 360,
            bitLength: 8, defaultValue: .enumValue(0),
            helpText: "Channel \(channel + 1) encryption mode"
        )
    }

    public static func channelTalkgroup(channel: Int) -> FieldDefinition {
        FieldDefinition(
            id: "apx.channel.\(channel).talkgroup", name: "channel\(channel + 1)Talkgroup",
            displayName: "Talkgroup", category: .channel, valueType: .uint16,
            bitOffset: channelBaseOffset + (channel * channelStride) + 368,
            bitLength: 16, defaultValue: .uint16(0),
            constraint: .range(min: 0, max: 65535),
            helpText: "P25 talkgroup ID"
        )
    }
}
