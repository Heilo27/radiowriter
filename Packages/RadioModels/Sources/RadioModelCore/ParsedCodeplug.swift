import Foundation

// MARK: - Parsed Codeplug (MOTOTRBO Domain Model)

/// Complete parsed codeplug data for MOTOTRBO radios (XPR, SL, DP, DM series).
/// This is the single source of truth for codeplug domain data.
/// Used by the hardware layer (RadioProgrammer) for read/write operations
/// and by the app layer for display and editing.
public struct ParsedCodeplug: Sendable {
    // MARK: - Device Information (read-only from radio)
    public var modelNumber: String = ""
    public var serialNumber: String = ""
    public var firmwareVersion: String = ""
    public var codeplugVersion: String = ""

    // MARK: - General Settings
    public var radioID: UInt32 = 1
    public var radioAlias: String = "Radio"
    public var introScreenLine1: String = ""
    public var introScreenLine2: String = ""
    public var powerOnPassword: String = ""
    public var defaultPowerLevel: Bool = true  // true=High, false=Low

    // MARK: - Display Settings
    public var backlightTime: UInt8 = 5  // seconds, 0=Always On
    public var backlightAuto: Bool = true

    // MARK: - Audio Settings
    public var voxEnabled: Bool = false
    public var voxSensitivity: UInt8 = 3  // 1-10
    public var voxDelay: UInt16 = 500  // ms
    public var keypadTones: Bool = true
    public var callAlertTone: Bool = true
    public var powerUpTone: Bool = true
    public var audioEnhancement: Bool = false

    // MARK: - Timing Settings
    public var totTime: UInt16 = 60  // seconds (0=infinite)
    public var totResetTime: UInt8 = 0  // seconds
    public var groupCallHangTime: UInt16 = 5000  // ms
    public var privateCallHangTime: UInt16 = 5000  // ms

    // MARK: - Signaling Settings
    public var radioCheckEnabled: Bool = true
    public var remoteMonitorEnabled: Bool = false
    public var callConfirmation: Bool = true
    public var emergencyAlertType: UInt8 = 0  // 0=Alarm, 1=Silent, 2=AlarmWithCall
    public var emergencyDestinationID: UInt32 = 0

    // MARK: - GPS/GNSS Settings
    public var gpsEnabled: Bool = false
    public var gpsRevertChannelEnabled: Bool = false
    public var enhancedGNSSEnabled: Bool = false

    // MARK: - Lone Worker Settings
    public var loneWorkerEnabled: Bool = false
    public var loneWorkerResponseTime: UInt16 = 30  // seconds
    public var loneWorkerReminderTime: UInt16 = 300  // seconds

    // MARK: - Man Down Settings (if supported)
    public var manDownEnabled: Bool = false
    public var manDownDelay: UInt16 = 10  // seconds

    // MARK: - Zones and Channels
    public var zones: [ParsedZone] = []

    // MARK: - Contacts
    public var contacts: [ParsedContact] = []

    // MARK: - Scan Lists
    public var scanLists: [ParsedScanList] = []

    // MARK: - RX Group Lists
    public var rxGroupLists: [ParsedRxGroupList] = []

    // MARK: - Text Messages (pre-programmed)
    public var textMessages: [PresetTextMessage] = []

    // MARK: - Emergency Systems
    public var emergencySystems: [EmergencySystem] = []

    // MARK: - Button Assignments
    public var topButtonShortPress: ButtonFunction = .none
    public var topButtonLongPress: ButtonFunction = .none
    public var sideButton1ShortPress: ButtonFunction = .none
    public var sideButton1LongPress: ButtonFunction = .none
    public var sideButton2ShortPress: ButtonFunction = .none
    public var sideButton2LongPress: ButtonFunction = .none

    /// Total number of channels across all zones.
    public var totalChannels: Int {
        zones.reduce(0) { $0 + $1.channels.count }
    }

    public init() {}
}

// MARK: - Channel Data

/// A single channel with all its settings.
/// This is the wire-level representation used for reading/writing to radios
/// and for display/editing in the UI.
public struct ChannelData: Sendable {
    // MARK: - Identity
    public var zoneIndex: Int = 0
    public var channelIndex: Int = 0
    public var name: String = ""
    public var alias: String = ""

    // MARK: - Frequencies
    public var rxFrequencyHz: UInt32 = 0
    public var txFrequencyHz: UInt32 = 0

    public var rxFrequencyMHz: Double { Double(rxFrequencyHz) / 1_000_000.0 }
    public var txFrequencyMHz: Double { Double(txFrequencyHz) / 1_000_000.0 }

    /// TX offset in MHz (positive = +offset, negative = -offset, 0 = simplex)
    public var txOffsetMHz: Double {
        (Double(txFrequencyHz) - Double(rxFrequencyHz)) / 1_000_000.0
    }

    // MARK: - Channel Type
    public var isDigital: Bool = true

    // MARK: - Digital (DMR) Settings
    public var timeSlot: Int = 1
    public var colorCode: Int = 1
    public var inboundColorCode: Int = 1
    public var outboundColorCode: Int = 1
    public var contactID: UInt32 = 0
    public var contactType: Int = 0  // 0=Private, 1=Group, 2=All Call
    public var rxGroupListID: UInt8 = 0
    public var dualCapacityDirectMode: Bool = false
    public var timingLeaderPreference: Int = 0  // 0=Either, 1=Preferred, 2=Followed
    public var extendedRangeDirectMode: Bool = false
    public var windowSize: UInt8 = 1

    // MARK: - Power & Bandwidth
    public var txPowerHigh: Bool = true
    public var bandwidthWide: Bool = false  // false=12.5kHz, true=25kHz

    // MARK: - Analog Settings
    public var rxSquelchType: Int = 0  // 0=Carrier, 1=CTCSS/DCS, 2=Tight
    public var txCTCSSHz: Double = 0  // In Hz (e.g., 100.0)
    public var rxCTCSSHz: Double = 0
    public var txDCSCode: UInt16 = 0  // Octal code (e.g., 023)
    public var rxDCSCode: UInt16 = 0
    public var dcsInvert: Bool = false
    public var scrambleEnabled: Bool = false
    public var voiceEmphasis: Bool = false

    // MARK: - Privacy/Encryption
    public var privacyType: Int = 0  // 0=None, 1=Basic, 2=Enhanced, 3=AES
    public var privacyKey: UInt8 = 0
    public var privacyAlias: String = ""
    public var ignoreRxClearVoice: Bool = false
    public var fixedPrivacyKeyDecryption: Bool = false

    // MARK: - Signaling
    public var arsEnabled: Bool = false
    public var enhancedGNSSEnabled: Bool = false
    public var loneWorker: Bool = false
    public var emergencyAlarmAck: Bool = false
    public var txInterruptType: Int = 0  // 0=Disabled, 1=Always Allow
    public var artsEnabled: Bool = false
    public var rasAlias: String = ""

    // MARK: - Power & Timing
    public var rxOnly: Bool = false
    public var totTimeout: UInt16 = 60
    public var allowTalkaround: Bool = true
    public var autoScan: Bool = false
    public var scanListID: UInt8 = 0
    public var admitCriteria: Int = 0

    // MARK: - MOTOTRBO Features
    public var mototrboLinkEnabled: Bool = false
    public var compressedUDPHeader: Bool = false
    public var textMessageType: Int = 0  // 0=DMR, 1=MOTOTRBO
    public var otaBatteryManagement: Bool = false
    public var audioEnhancement: Bool = false
    public var phoneSystem: String = ""

    // MARK: - Voice Announcement
    public var voiceAnnouncement: String = ""

    public init(zoneIndex: Int = 0, channelIndex: Int = 0) {
        self.zoneIndex = zoneIndex
        self.channelIndex = channelIndex
    }

    // MARK: - Display Helpers

    /// Human-readable channel type
    public var channelTypeDisplay: String {
        isDigital ? "Digital (DMR)" : "Analog"
    }

    /// Human-readable bandwidth
    public var bandwidthDisplay: String {
        bandwidthWide ? "25 kHz" : "12.5 kHz"
    }

    /// Human-readable power level
    public var powerDisplay: String {
        txPowerHigh ? "High" : "Low"
    }

    /// Human-readable squelch type
    public var squelchTypeDisplay: String {
        switch rxSquelchType {
        case 0: return "Carrier"
        case 1: return "CTCSS/DCS"
        case 2: return "Tight"
        default: return "Unknown"
        }
    }

    /// Human-readable privacy type
    public var privacyTypeDisplay: String {
        switch privacyType {
        case 0: return "None"
        case 1: return "Basic"
        case 2: return "Enhanced"
        case 3: return "AES-256"
        default: return "Unknown"
        }
    }

    /// Human-readable timing leader preference
    public var timingLeaderDisplay: String {
        switch timingLeaderPreference {
        case 0: return "Either"
        case 1: return "Preferred"
        case 2: return "Followed"
        default: return "Unknown"
        }
    }

    /// Human-readable contact type
    public var contactTypeDisplay: String {
        switch contactType {
        case 0: return "Private Call"
        case 1: return "Group Call"
        case 2: return "All Call"
        default: return "Unknown"
        }
    }
}

// MARK: - Zone

/// A zone in the parsed codeplug.
public struct ParsedZone: Sendable {
    public var name: String = "Zone"
    public var position: Int = 0
    public var channels: [ChannelData] = []

    public init(name: String = "Zone", position: Int = 0) {
        self.name = name
        self.position = position
    }
}

// MARK: - Contact

/// A contact in the parsed codeplug.
public struct ParsedContact: Sendable, Identifiable {
    public var id = UUID()
    public var name: String = "Contact"
    public var contactType: ContactCallType = .group
    public var dmrID: UInt32 = 0
    public var callReceiveTone: Bool = true
    public var callAlert: Bool = false

    public init(name: String = "Contact", dmrID: UInt32 = 0, type: ContactCallType = .group) {
        self.name = name
        self.dmrID = dmrID
        self.contactType = type
    }
}

/// Contact call types.
public enum ContactCallType: String, Sendable, CaseIterable {
    case privateCall = "Private Call"
    case group = "Group Call"
    case allCall = "All Call"
}

// MARK: - Scan List

/// A scan list in the parsed codeplug.
public struct ParsedScanList: Sendable, Identifiable {
    public var id = UUID()
    public var name: String = "Scan List"
    public var channelMembers: [ScanListMember] = []
    public var priorityChannel1Index: Int?
    public var priorityChannel2Index: Int?
    public var talkbackEnabled: Bool = true
    public var holdTime: UInt16 = 500  // ms

    public init(name: String = "Scan List") {
        self.name = name
    }
}

/// A member of a scan list.
public struct ScanListMember: Sendable, Identifiable {
    public var id = UUID()
    public var zoneIndex: Int
    public var channelIndex: Int

    public init(zoneIndex: Int, channelIndex: Int) {
        self.zoneIndex = zoneIndex
        self.channelIndex = channelIndex
    }
}

// MARK: - RX Group List

/// An RX group list in the parsed codeplug.
public struct ParsedRxGroupList: Sendable, Identifiable {
    public var id = UUID()
    public var name: String = "RX Group"
    public var contactIndices: [Int] = []  // Indices into contacts array

    public init(name: String = "RX Group") {
        self.name = name
    }
}

// MARK: - Supporting Types

/// Pre-programmed text message
public struct PresetTextMessage: Sendable, Identifiable {
    public var id = UUID()
    public var text: String = ""

    public init(text: String = "") {
        self.text = text
    }
}

/// Emergency system definition
public struct EmergencySystem: Sendable, Identifiable {
    public var id = UUID()
    public var name: String = "Emergency"
    public var alarmType: UInt8 = 0  // 0=Alarm, 1=AlarmWithCall, 2=AlarmWithVoice, 3=Silent
    public var mode: UInt8 = 0  // 0=Regular, 1=Acknowledged
    public var hotMicEnabled: Bool = false
    public var hotMicDuration: UInt8 = 10  // seconds
    public var destinationID: UInt32 = 0
    public var callType: UInt8 = 1  // 0=Private, 1=Group, 2=AllCall

    public init() {}
}

/// Available button functions
public enum ButtonFunction: String, Sendable, CaseIterable {
    case none = "None"
    case monitor = "Monitor"
    case scan = "Scan"
    case emergency = "Emergency"
    case zoneSelect = "Zone Select"
    case powerLevel = "Power Level"
    case talkaround = "Talkaround"
    case vox = "VOX"
    case oneTouchCall = "One Touch Call"
    case textMessage = "Text Message"
    case privacy = "Privacy"
    case audioToggle = "Audio Toggle"
    case bluetooth = "Bluetooth"
    case gps = "GPS"
    case manDown = "Man Down"
    case loneWorker = "Lone Worker"
    case radioCheck = "Radio Check"
    case remoteMonitor = "Remote Monitor"
    case callLog = "Call Log"
    case contacts = "Contacts"
}
