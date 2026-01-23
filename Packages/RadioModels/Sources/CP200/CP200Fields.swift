import Foundation
import RadioCore
import RadioModelCore

/// Field definitions for the CP200 commercial radio family.
public enum CP200Fields {
    static let channelStride = 384 // bits per channel entry

    // MARK: - General

    public static let radioId = FieldDefinition(
        id: "cp200.general.radioId", name: "radioId", displayName: "Radio ID",
        category: .general, valueType: .uint32,
        bitOffset: 0, bitLength: 32, defaultValue: .uint32(1),
        constraint: .range(min: 1, max: 16776415),
        helpText: "Unique radio identifier for MDC/digital signaling"
    )

    public static let radioAlias = FieldDefinition(
        id: "cp200.general.alias", name: "radioAlias", displayName: "Radio Alias",
        category: .general, valueType: .string(maxLength: 16, encoding: .utf8),
        bitOffset: 32, bitLength: 128, defaultValue: .string(""),
        constraint: .stringLength(min: 0, max: 16), helpText: "Radio display name"
    )

    public static let numberOfChannels = FieldDefinition(
        id: "cp200.general.numChannels", name: "numberOfChannels", displayName: "Number of Channels",
        category: .general, valueType: .uint8,
        bitOffset: 160, bitLength: 8, defaultValue: .uint8(16),
        constraint: .range(min: 1, max: 16), helpText: "Active channel count"
    )

    public static let powerOnChannel = FieldDefinition(
        id: "cp200.general.powerOnChannel", name: "powerOnChannel", displayName: "Power-On Channel",
        category: .general, valueType: .enumeration([
            EnumOption(id: 0, name: "last", displayName: "Last Used"),
            EnumOption(id: 1, name: "default", displayName: "Channel 1"),
        ]),
        bitOffset: 168, bitLength: 8, defaultValue: .enumValue(0),
        helpText: "Channel selected when radio powers on"
    )

    public static let backlightTimer = FieldDefinition(
        id: "cp200.general.backlight", name: "backlightTimer", displayName: "Backlight Timer",
        category: .general, valueType: .enumeration([
            EnumOption(id: 0, name: "off", displayName: "Off"),
            EnumOption(id: 5, name: "5sec", displayName: "5 Seconds"),
            EnumOption(id: 10, name: "10sec", displayName: "10 Seconds"),
            EnumOption(id: 15, name: "15sec", displayName: "15 Seconds"),
            EnumOption(id: 255, name: "always", displayName: "Always On"),
        ]),
        bitOffset: 176, bitLength: 8, defaultValue: .enumValue(5),
        helpText: "Display backlight duration"
    )

    // MARK: - Audio

    public static let volumeLevel = FieldDefinition(
        id: "cp200.audio.volume", name: "volumeLevel", displayName: "Volume Level",
        category: .audio, valueType: .uint8,
        bitOffset: 192, bitLength: 8, defaultValue: .uint8(5),
        constraint: .range(min: 0, max: 16), helpText: "Default volume level (0-16)"
    )

    public static let voxEnabled = FieldDefinition(
        id: "cp200.audio.voxEnabled", name: "voxEnabled", displayName: "VOX Enabled",
        category: .audio, valueType: .bool,
        bitOffset: 200, bitLength: 1, defaultValue: .bool(false),
        helpText: "Enable hands-free voice-activated transmit"
    )

    public static let voxSensitivity = FieldDefinition(
        id: "cp200.audio.voxSensitivity", name: "voxSensitivity", displayName: "VOX Sensitivity",
        category: .audio, valueType: .uint8,
        bitOffset: 208, bitLength: 8, defaultValue: .uint8(3),
        constraint: .range(min: 1, max: 10), dependencies: ["cp200.audio.voxEnabled"],
        helpText: "VOX trigger sensitivity (1=Low, 10=High)"
    )

    public static let keyBeepEnabled = FieldDefinition(
        id: "cp200.audio.keyBeep", name: "keyBeepEnabled", displayName: "Key Beep",
        category: .audio, valueType: .bool,
        bitOffset: 216, bitLength: 1, defaultValue: .bool(true),
        helpText: "Enable button press confirmation tone"
    )

    public static let toneVolume = FieldDefinition(
        id: "cp200.audio.toneVolume", name: "toneVolume", displayName: "Alert Tone Volume",
        category: .audio, valueType: .uint8,
        bitOffset: 224, bitLength: 8, defaultValue: .uint8(5),
        constraint: .range(min: 0, max: 10), helpText: "Volume level for alert tones"
    )

    // MARK: - Signaling

    public static let mdc1200Id = FieldDefinition(
        id: "cp200.signaling.mdc1200Id", name: "mdc1200Id", displayName: "MDC-1200 ID",
        category: .signaling, valueType: .uint16,
        bitOffset: 240, bitLength: 16, defaultValue: .uint16(0),
        constraint: .range(min: 0, max: 8191),
        helpText: "MDC-1200 unit identifier (0 = Disabled)"
    )

    public static let mdc1200Enabled = FieldDefinition(
        id: "cp200.signaling.mdc1200Enabled", name: "mdc1200Enabled", displayName: "MDC-1200 Signaling",
        category: .signaling, valueType: .bool,
        bitOffset: 256, bitLength: 1, defaultValue: .bool(false),
        helpText: "Enable MDC-1200 signaling for PTT ID and call alert"
    )

    // MARK: - Scan

    public static func scanListName(list: Int) -> FieldDefinition {
        FieldDefinition(
            id: "cp200.scan.\(list).name", name: "scanList\(list + 1)Name",
            displayName: "Scan List Name", category: .scan,
            valueType: .string(maxLength: 16, encoding: .utf8),
            bitOffset: 8192 + (list * 512),
            bitLength: 128, defaultValue: .string("Scan\(list + 1)"),
            constraint: .stringLength(min: 0, max: 16),
            helpText: "Name for scan list \(list + 1)"
        )
    }

    public static func scanListPriority1(list: Int) -> FieldDefinition {
        FieldDefinition(
            id: "cp200.scan.\(list).priority1", name: "scanList\(list + 1)Priority1",
            displayName: "Priority Channel 1", category: .scan, valueType: .uint8,
            bitOffset: 8192 + (list * 512) + 128,
            bitLength: 8, defaultValue: .uint8(0),
            constraint: .range(min: 0, max: 16),
            helpText: "Priority 1 channel for scan list (0 = None)"
        )
    }

    public static func scanListPriority2(list: Int) -> FieldDefinition {
        FieldDefinition(
            id: "cp200.scan.\(list).priority2", name: "scanList\(list + 1)Priority2",
            displayName: "Priority Channel 2", category: .scan, valueType: .uint8,
            bitOffset: 8192 + (list * 512) + 136,
            bitLength: 8, defaultValue: .uint8(0),
            constraint: .range(min: 0, max: 16),
            helpText: "Priority 2 channel for scan list (0 = None)"
        )
    }

    // MARK: - Advanced

    public static let totTimeout = FieldDefinition(
        id: "cp200.advanced.tot", name: "totTimeout", displayName: "TX Timeout (TOT)",
        category: .advanced, valueType: .uint8,
        bitOffset: 264, bitLength: 8, defaultValue: .uint8(60),
        constraint: .range(min: 0, max: 255), helpText: "Transmit timeout in seconds (0 = No timeout)"
    )

    public static let squelchLevel = FieldDefinition(
        id: "cp200.advanced.squelch", name: "squelchLevel", displayName: "Squelch Level",
        category: .advanced, valueType: .enumeration([
            EnumOption(id: 0, name: "normal", displayName: "Normal"),
            EnumOption(id: 1, name: "tight", displayName: "Tight"),
            EnumOption(id: 2, name: "open", displayName: "Open"),
        ]),
        bitOffset: 272, bitLength: 8, defaultValue: .enumValue(0),
        helpText: "Squelch threshold sensitivity"
    )

    public static let loneWorkerEnabled = FieldDefinition(
        id: "cp200.advanced.loneWorker", name: "loneWorkerEnabled", displayName: "Lone Worker",
        category: .advanced, valueType: .bool,
        bitOffset: 280, bitLength: 1, defaultValue: .bool(false),
        helpText: "Enable lone worker periodic check-in timer"
    )

    public static let loneWorkerTimer = FieldDefinition(
        id: "cp200.advanced.loneWorkerTimer", name: "loneWorkerTimer", displayName: "Lone Worker Timer",
        category: .advanced, valueType: .uint8,
        bitOffset: 288, bitLength: 8, defaultValue: .uint8(60),
        constraint: .range(min: 1, max: 255), dependencies: ["cp200.advanced.loneWorker"],
        helpText: "Lone worker check-in interval in minutes"
    )

    public static let emergencyEnabled = FieldDefinition(
        id: "cp200.advanced.emergency", name: "emergencyEnabled", displayName: "Emergency Button",
        category: .advanced, valueType: .bool,
        bitOffset: 296, bitLength: 1, defaultValue: .bool(false),
        helpText: "Enable dedicated emergency button"
    )

    // MARK: - Per-Channel Fields

    static let channelBaseOffset = 1024

    public static func channelName(channel: Int) -> FieldDefinition {
        FieldDefinition(
            id: "cp200.channel.\(channel).name", name: "channel\(channel + 1)Name",
            displayName: "Name", category: .channel,
            valueType: .string(maxLength: 16, encoding: .utf8),
            bitOffset: channelBaseOffset + (channel * channelStride),
            bitLength: 128, defaultValue: .string("CH\(channel + 1)"),
            constraint: .stringLength(min: 0, max: 16),
            helpText: "Channel \(channel + 1) display name"
        )
    }

    public static func channelRxFreq(channel: Int) -> FieldDefinition {
        FieldDefinition(
            id: "cp200.channel.\(channel).rxFreq", name: "channel\(channel + 1)RxFreq",
            displayName: "RX Frequency", category: .channel, valueType: .uint32,
            bitOffset: channelBaseOffset + (channel * channelStride) + 128,
            bitLength: 32, defaultValue: .uint32(4500000),
            helpText: "Channel \(channel + 1) receive frequency in 100 Hz units"
        )
    }

    public static func channelTxFreq(channel: Int) -> FieldDefinition {
        FieldDefinition(
            id: "cp200.channel.\(channel).txFreq", name: "channel\(channel + 1)TxFreq",
            displayName: "TX Frequency", category: .channel, valueType: .uint32,
            bitOffset: channelBaseOffset + (channel * channelStride) + 160,
            bitLength: 32, defaultValue: .uint32(4500000),
            helpText: "Channel \(channel + 1) transmit frequency in 100 Hz units"
        )
    }

    public static func channelTxPower(channel: Int) -> FieldDefinition {
        FieldDefinition(
            id: "cp200.channel.\(channel).txPower", name: "channel\(channel + 1)TxPower",
            displayName: "TX Power", category: .channel,
            valueType: .enumeration([
                EnumOption(id: 0, name: "low", displayName: "Low (1W)"),
                EnumOption(id: 1, name: "high", displayName: "High (4W)"),
            ]),
            bitOffset: channelBaseOffset + (channel * channelStride) + 192,
            bitLength: 8, defaultValue: .enumValue(1),
            helpText: "Channel \(channel + 1) transmit power"
        )
    }

    public static func channelBandwidth(channel: Int) -> FieldDefinition {
        FieldDefinition(
            id: "cp200.channel.\(channel).bandwidth", name: "channel\(channel + 1)Bandwidth",
            displayName: "Bandwidth", category: .channel,
            valueType: .enumeration([
                EnumOption(id: 0, name: "narrow", displayName: "Narrow (12.5 kHz)"),
                EnumOption(id: 1, name: "wide", displayName: "Wide (25 kHz)"),
            ]),
            bitOffset: channelBaseOffset + (channel * channelStride) + 200,
            bitLength: 8, defaultValue: .enumValue(0),
            helpText: "Channel \(channel + 1) bandwidth"
        )
    }

    public static func channelMode(channel: Int) -> FieldDefinition {
        FieldDefinition(
            id: "cp200.channel.\(channel).mode", name: "channel\(channel + 1)Mode",
            displayName: "Mode", category: .channel,
            valueType: .enumeration([
                EnumOption(id: 0, name: "analog", displayName: "Analog (FM)"),
                EnumOption(id: 1, name: "digital", displayName: "Digital (DMR)"),
            ]),
            bitOffset: channelBaseOffset + (channel * channelStride) + 208,
            bitLength: 8, defaultValue: .enumValue(0),
            helpText: "Channel \(channel + 1) operating mode"
        )
    }

    public static func channelColorCode(channel: Int) -> FieldDefinition {
        FieldDefinition(
            id: "cp200.channel.\(channel).colorCode", name: "channel\(channel + 1)ColorCode",
            displayName: "Color Code", category: .channel, valueType: .uint8,
            bitOffset: channelBaseOffset + (channel * channelStride) + 216,
            bitLength: 8, defaultValue: .uint8(1),
            constraint: .range(min: 0, max: 15),
            helpText: "DMR color code (0-15, only for digital mode)"
        )
    }

    public static func channelRxCode(channel: Int) -> FieldDefinition {
        FieldDefinition(
            id: "cp200.channel.\(channel).rxCode", name: "channel\(channel + 1)RxCode",
            displayName: "RX Code", category: .signaling, valueType: .uint8,
            bitOffset: channelBaseOffset + (channel * channelStride) + 224,
            bitLength: 8, defaultValue: .uint8(0),
            constraint: .range(min: 0, max: 50),
            helpText: "CTCSS/DPL receive code (0 = None, analog only)"
        )
    }

    public static func channelTxCode(channel: Int) -> FieldDefinition {
        FieldDefinition(
            id: "cp200.channel.\(channel).txCode", name: "channel\(channel + 1)TxCode",
            displayName: "TX Code", category: .signaling, valueType: .uint8,
            bitOffset: channelBaseOffset + (channel * channelStride) + 232,
            bitLength: 8, defaultValue: .uint8(0),
            constraint: .range(min: 0, max: 50),
            helpText: "CTCSS/DPL transmit code (0 = None, analog only)"
        )
    }

    public static func channelScanAdd(channel: Int) -> FieldDefinition {
        FieldDefinition(
            id: "cp200.channel.\(channel).scanAdd", name: "channel\(channel + 1)ScanAdd",
            displayName: "Scan List Member", category: .scan, valueType: .bool,
            bitOffset: channelBaseOffset + (channel * channelStride) + 240,
            bitLength: 1, defaultValue: .bool(true),
            helpText: "Include channel \(channel + 1) in scan list"
        )
    }
}
