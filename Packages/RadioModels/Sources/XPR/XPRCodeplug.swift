import Foundation
import RadioCore
import RadioModelCore

// MARK: - XPR Codeplug Data Model

/// Complete codeplug data for XPR (MOTOTRBO) radios.
/// This is the parsed representation of data read from the radio.
@Observable
public final class XPRCodeplug: Identifiable, @unchecked Sendable {
    public let id = UUID()

    // MARK: - Device Info

    public var modelNumber: String = ""
    public var serialNumber: String = ""
    public var firmwareVersion: String = ""
    public var codeplugVersion: String = ""

    // MARK: - General Settings

    public var radioID: UInt32 = 1
    public var radioAlias: String = "Radio"
    public var powerOnChannel: PowerOnChannelOption = .lastUsed
    public var backlightTimer: BacklightTimer = .seconds5
    public var introScreenText: String = "MOTOTRBO"

    // MARK: - Audio Settings

    public var volumeLevel: UInt8 = 5
    public var voxEnabled: Bool = false
    public var voxSensitivity: UInt8 = 3
    public var keyBeepEnabled: Bool = true

    // MARK: - Zones

    public var zones: [XPRZone] = []
    public var maxZones: Int = 250

    // MARK: - Contacts

    public var contacts: [XPRContact] = []
    public var maxContacts: Int = 256

    // MARK: - Scan Lists

    public var scanLists: [XPRScanList] = []
    public var maxScanLists: Int = 64

    // MARK: - RX Group Lists

    public var rxGroupLists: [XPRRxGroupList] = []
    public var maxRxGroupLists: Int = 64

    // MARK: - Advanced

    public var totTimeout: UInt16 = 60
    public var loneWorkerEnabled: Bool = false
    public var loneWorkerTimer: UInt8 = 60
    public var passwordEnabled: Bool = false
    public var encryptionEnabled: Bool = false
    public var gpsEnabled: Bool = false
    public var gpsReportInterval: UInt16 = 300

    public init() {}

    /// Total number of channels across all zones.
    public var totalChannels: Int {
        zones.reduce(0) { $0 + $1.channels.count }
    }
}

// MARK: - Zone

/// A zone containing up to 16 channels.
public struct XPRZone: Identifiable, Sendable, Codable {
    public var id = UUID()
    public var name: String = "Zone"
    public var channels: [XPRChannel] = []
    public var position: Int = 0

    public init(name: String = "Zone", position: Int = 0) {
        self.name = name
        self.position = position
    }

    /// Maximum channels per zone for XPR radios.
    public static let maxChannelsPerZone = 16
}

// MARK: - Channel

/// A single channel with all its settings.
public struct XPRChannel: Identifiable, Sendable, Codable {
    public var id = UUID()

    // MARK: - Basic Info

    public var position: Int = 0
    public var name: String = "Channel"
    public var channelType: ChannelType = .digital

    // MARK: - Frequencies

    public var rxFrequencyHz: UInt32 = 450_000_000
    public var txFrequencyHz: UInt32 = 450_000_000

    /// RX Frequency in MHz for display.
    public var rxFrequencyMHz: Double {
        Double(rxFrequencyHz) / 1_000_000.0
    }

    /// TX Frequency in MHz for display.
    public var txFrequencyMHz: Double {
        Double(txFrequencyHz) / 1_000_000.0
    }

    // MARK: - Analog Settings

    public var bandwidth: Bandwidth = .narrow
    public var rxSquelchType: SquelchType = .carrier
    public var rxCTCSS: CTCSSCode = .none
    public var rxDCS: DCSCode = .none
    public var rxDCSInvert: Bool = false
    public var txCTCSS: CTCSSCode = .none
    public var txDCS: DCSCode = .none
    public var scrambleEnabled: Bool = false

    // MARK: - Digital (DMR) Settings

    public var colorCode: UInt8 = 1
    public var timeSlot: TimeSlot = .slot1
    public var txContact: String = ""
    public var txContactID: UInt32 = 0
    public var rxGroupList: String = ""
    public var rxGroupListID: UInt8 = 0

    // MARK: - Power & Timing

    public var txPower: TxPower = .high
    public var totTimeout: UInt16 = 60
    public var rxOnly: Bool = false

    // MARK: - Scanning

    public var scanList: String = ""
    public var scanListID: UInt8 = 0
    public var autoScan: Bool = false
    public var allowTalkaround: Bool = true

    // MARK: - Privacy/Encryption

    public var privacyEnabled: Bool = false
    public var privacyType: PrivacyType = .none
    public var privacyKey: UInt8 = 0
    public var ignoreRxClearVoice: Bool = false

    // MARK: - Signaling

    public var arsEnabled: Bool = false
    public var enhancedGNSSEnabled: Bool = false
    public var loneWorker: Bool = false
    public var emergencyAlarmAck: Bool = false
    public var txInterruptType: TxInterruptType = .none

    // MARK: - Voice Settings

    public var voiceEmphasis: Bool = false
    public var compressedUDPHeader: Bool = false
    public var voiceAnnouncement: String = ""

    // MARK: - Advanced Digital

    public var dualCapacityDirectMode: Bool = false
    public var timingLeaderPreference: TimingLeaderPreference = .either
    public var extendedRangeDirectMode: Bool = false
    public var inboundColorCode: UInt8 = 1
    public var outboundColorCode: UInt8 = 1
    public var phoneSystem: String = ""
    public var windowSize: UInt8 = 1

    // MARK: - MOTOTRBO Specific

    public var mototrboLinkEnabled: Bool = false
    public var overTheAirBatteryManagement: Bool = false
    public var audioEnhancement: Bool = false
    public var artsEnabled: Bool = false
    public var textMessageType: TextMessageType = .dmr

    public init(name: String = "Channel", position: Int = 0) {
        self.name = name
        self.position = position
    }
}

// MARK: - Contact

/// A contact (individual, group, or all call).
public struct XPRContact: Identifiable, Sendable, Codable {
    public var id = UUID()
    public var name: String = "Contact"
    public var contactType: ContactType = .group
    public var dmrID: UInt32 = 0
    public var callReceiveTone: Bool = true
    public var callAlert: Bool = false

    public init(name: String = "Contact", dmrID: UInt32 = 0) {
        self.name = name
        self.dmrID = dmrID
    }
}

// MARK: - Scan List

/// A scan list containing channel references.
public struct XPRScanList: Identifiable, Sendable, Codable {
    public var id = UUID()
    public var name: String = "Scan List"
    public var channelIDs: [UUID] = []
    public var priorityChannel1: UUID?
    public var priorityChannel2: UUID?
    public var talkbackEnabled: Bool = true
    public var holdTime: UInt16 = 500  // ms

    public init(name: String = "Scan List") {
        self.name = name
    }
}

// MARK: - RX Group List

/// A receive group list for digital channels.
public struct XPRRxGroupList: Identifiable, Sendable, Codable {
    public var id = UUID()
    public var name: String = "RX Group"
    public var contactIDs: [UUID] = []

    public init(name: String = "RX Group") {
        self.name = name
    }
}

// MARK: - Enums

public enum ChannelType: String, Sendable, Codable, CaseIterable {
    case analog = "Analog"
    case digital = "Digital"
}

public enum Bandwidth: String, Sendable, Codable, CaseIterable {
    case narrow = "12.5 kHz"
    case wide = "25 kHz"

    public var khz: Double {
        switch self {
        case .narrow: return 12.5
        case .wide: return 25.0
        }
    }
}

public enum TimeSlot: Int, Sendable, Codable, CaseIterable {
    case slot1 = 1
    case slot2 = 2

    public var displayName: String {
        "Slot \(rawValue)"
    }
}

public enum TxPower: String, Sendable, Codable, CaseIterable {
    case low = "Low"
    case high = "High"

    public var watts: Double {
        switch self {
        case .low: return 1.0
        case .high: return 4.0
        }
    }
}

public enum SquelchType: String, Sendable, Codable, CaseIterable {
    case carrier = "Carrier"
    case ctcss = "CTCSS/DCS"
    case tight = "Tight"
}

public enum ContactType: String, Sendable, Codable, CaseIterable {
    case individual = "Private Call"
    case group = "Group Call"
    case allCall = "All Call"
}

public enum PowerOnChannelOption: String, Sendable, Codable, CaseIterable {
    case lastUsed = "Last Used"
    case defaultChannel = "Default"
}

public enum BacklightTimer: Int, Sendable, Codable, CaseIterable {
    case off = 0
    case seconds5 = 5
    case seconds10 = 10
    case seconds15 = 15
    case seconds30 = 30
    case alwaysOn = 255

    public var displayName: String {
        switch self {
        case .off: return "Off"
        case .seconds5: return "5 Seconds"
        case .seconds10: return "10 Seconds"
        case .seconds15: return "15 Seconds"
        case .seconds30: return "30 Seconds"
        case .alwaysOn: return "Always On"
        }
    }
}

public enum PrivacyType: String, Sendable, Codable, CaseIterable {
    case none = "None"
    case basicPrivacy = "Basic"
    case enhancedPrivacy = "Enhanced"
    case aes256 = "AES-256"
}

public enum TxInterruptType: String, Sendable, Codable, CaseIterable {
    case none = "Disabled"
    case alwaysAllow = "Always Allow"
}

public enum TimingLeaderPreference: String, Sendable, Codable, CaseIterable {
    case either = "Either"
    case preferred = "Preferred"
    case followed = "Followed"
}

public enum TextMessageType: String, Sendable, Codable, CaseIterable {
    case dmr = "DMR Standard"
    case mototrbo = "MOTOTRBO"
}

// MARK: - CTCSS Tones

public enum CTCSSCode: Double, Sendable, Codable, CaseIterable {
    case none = 0
    case tone67_0 = 67.0
    case tone69_3 = 69.3
    case tone71_9 = 71.9
    case tone74_4 = 74.4
    case tone77_0 = 77.0
    case tone79_7 = 79.7
    case tone82_5 = 82.5
    case tone85_4 = 85.4
    case tone88_5 = 88.5
    case tone91_5 = 91.5
    case tone94_8 = 94.8
    case tone97_4 = 97.4
    case tone100_0 = 100.0
    case tone103_5 = 103.5
    case tone107_2 = 107.2
    case tone110_9 = 110.9
    case tone114_8 = 114.8
    case tone118_8 = 118.8
    case tone123_0 = 123.0
    case tone127_3 = 127.3
    case tone131_8 = 131.8
    case tone136_5 = 136.5
    case tone141_3 = 141.3
    case tone146_2 = 146.2
    case tone151_4 = 151.4
    case tone156_7 = 156.7
    case tone159_8 = 159.8
    case tone162_2 = 162.2
    case tone165_5 = 165.5
    case tone167_9 = 167.9
    case tone171_3 = 171.3
    case tone173_8 = 173.8
    case tone177_3 = 177.3
    case tone179_9 = 179.9
    case tone183_5 = 183.5
    case tone186_2 = 186.2
    case tone189_9 = 189.9
    case tone192_8 = 192.8
    case tone196_6 = 196.6
    case tone199_5 = 199.5
    case tone203_5 = 203.5
    case tone206_5 = 206.5
    case tone210_7 = 210.7
    case tone218_1 = 218.1
    case tone225_7 = 225.7
    case tone229_1 = 229.1
    case tone233_6 = 233.6
    case tone241_8 = 241.8
    case tone250_3 = 250.3
    case tone254_1 = 254.1

    public var displayName: String {
        if self == .none { return "None" }
        return String(format: "%.1f Hz", rawValue)
    }
}

// MARK: - DCS Codes

public enum DCSCode: UInt16, Sendable, Codable, CaseIterable {
    case none = 0
    case d023 = 23
    case d025 = 25
    case d026 = 26
    case d031 = 31
    case d032 = 32
    case d043 = 43
    case d047 = 47
    case d051 = 51
    case d054 = 54
    case d065 = 65
    case d071 = 71
    case d072 = 72
    case d073 = 73
    case d074 = 74
    case d114 = 114
    case d115 = 115
    case d116 = 116
    case d125 = 125
    case d131 = 131
    case d132 = 132
    case d134 = 134
    case d143 = 143
    case d152 = 152
    case d155 = 155
    case d156 = 156
    case d162 = 162
    case d165 = 165
    case d172 = 172
    case d174 = 174
    case d205 = 205
    case d223 = 223
    case d226 = 226
    case d243 = 243
    case d244 = 244
    case d245 = 245
    case d251 = 251
    case d261 = 261
    case d263 = 263
    case d265 = 265
    case d271 = 271
    case d306 = 306
    case d311 = 311
    case d315 = 315
    case d331 = 331
    case d343 = 343
    case d346 = 346
    case d351 = 351
    case d364 = 364
    case d365 = 365
    case d371 = 371
    case d411 = 411
    case d412 = 412
    case d413 = 413
    case d423 = 423
    case d431 = 431
    case d432 = 432
    case d445 = 445
    case d464 = 464
    case d465 = 465
    case d466 = 466
    case d503 = 503
    case d506 = 506
    case d516 = 516
    case d532 = 532
    case d546 = 546
    case d565 = 565
    case d606 = 606
    case d612 = 612
    case d624 = 624
    case d627 = 627
    case d631 = 631
    case d632 = 632
    case d654 = 654
    case d662 = 662
    case d664 = 664
    case d703 = 703
    case d712 = 712
    case d723 = 723
    case d731 = 731
    case d732 = 732
    case d734 = 734
    case d743 = 743
    case d754 = 754

    public var displayName: String {
        if self == .none { return "None" }
        return String(format: "D%03o", rawValue)
    }
}
