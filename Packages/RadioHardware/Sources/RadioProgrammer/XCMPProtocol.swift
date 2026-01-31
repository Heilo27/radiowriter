import Foundation

// MARK: - XCMP OpCodes

/// XCMP protocol operation codes for MOTOTRBO radios.
/// Request codes have the high bit clear, reply codes have 0x8000 OR'd.
/// Broadcast messages typically have 0xB000 prefix.
///
/// VERIFIED FROM CPS 2.0 CAPTURE (2026-01-30):
/// - Reading uses 0x0012 (SecurityKey), 0x0010 (Model), 0x000F (Version),
///   0x0011 (Serial), 0x001F (CodeplugId), 0x002E (CodeplugRead)
/// - NO programming mode (0x0106) required for reading!
public enum XCMPOpCode: UInt16 {
    // === VERIFIED WORKING FROM CPS CAPTURE ===

    // Device Info Commands (used by CPS for reading)
    case versionInfoRequest = 0x000F      // Param: 0x00=full, 0x41=build, P/R/Q variants
    case versionInfoReply = 0x800F
    case modelNumberRequest = 0x0010      // Param: 0x00
    case modelNumberReply = 0x8010
    case serialNumberRequest = 0x0011     // Param: 0x00
    case serialNumberReply = 0x8011
    case securityKeyRequest = 0x0012      // No params - returns 16-byte session key
    case securityKeyReply = 0x8012
    case codeplugIdRequest = 0x001F       // Params: 0x00 0x00
    case codeplugIdReply = 0x801F

    // Codeplug Read (record-based, NOT linear addressing!)
    case codeplugReadRequest = 0x002E     // Record list format
    case codeplugReadReply = 0x802E

    // Status Commands
    case statusFlagsRequest = 0x003D      // Params: 0x00 0x00
    case statusFlagsReply = 0x803D
    case featureSetRequest = 0x0037       // 3 bytes params
    case featureSetReply = 0x8037
    case languagePackRequest = 0x002C     // 1 byte param
    case languagePackReply = 0x802C

    // === LEGACY/UNVERIFIED OPCODES ===

    // Status and Info (0x000E)
    case radioStatusRequest = 0x000E
    case radioStatusReply = 0x800E

    // Codeplug Attributes (0x0025)
    case codeplugAttributeRequest = 0x0025
    case codeplugAttributeReply = 0x8025

    // CPS Operations (0x0100-0x010F) - May be for WRITE only
    case cpsUnlockRequest = 0x0100
    case cpsUnlockReply = 0x8100
    case cpsReadRequest = 0x0104
    case cpsReadReply = 0x8104
    case cpsWriteRequest = 0x0105
    case cpsWriteReply = 0x8105
    case ishProgramModeRequest = 0x0106   // May only be needed for writes
    case ishProgramModeReply = 0x8106

    // Clone Operations (0x010A)
    case cloneReadRequest = 0x010A
    case cloneReadReply = 0x810A

    // PSDT Access (0x010B)
    case psdtAccessRequest = 0x010B
    case psdtAccessReply = 0x810B
    case psdtAccessBroadcast = 0xB10B

    // Radio Update Control (0x010C)
    case radioUpdateControlRequest = 0x010C
    case radioUpdateControlReply = 0x810C

    // Component Read (0x010E)
    case componentReadRequest = 0x010E
    case componentReadReply = 0x810E

    // Component Session (0x010F)
    case componentSessionRequest = 0x010F
    case componentSessionReply = 0x810F

    // Boot Mode Commands (0x0200-0x0203)
    case enterBootModeRequest = 0x0200
    case enterBootModeReply = 0x8200
    case readMemoryRequest = 0x0201
    case readMemoryReply = 0x8201
    case eraseFlashRequest = 0x0203
    case eraseFlashReply = 0x8203

    // Power Control (0x040A)
    case radioPowerRequest = 0x040A
    case radioPowerReply = 0x840A

    // Channel/Zone Selection (0x040D)
    case channelSelectRequest = 0x040D
    case channelSelectReply = 0x840D

    // Alarm (0x042E)
    case alarmStatusRequest = 0x042E
    case alarmStatusReply = 0x842E

    // Data Transfer (0x0446)
    case transferDataRequest = 0x0446
    case transferDataReply = 0x8446

    // Module Info (0x0461)
    case moduleInfoRequest = 0x0461
    case moduleInfoReply = 0x8461

    // Device Management
    case deviceInitStatusBroadcast = 0xB400

    /// Returns the expected reply opcode for a request.
    public var replyOpCode: XCMPOpCode? {
        XCMPOpCode(rawValue: rawValue | 0x8000)
    }

    /// Returns true if this is a broadcast message.
    public var isBroadcast: Bool {
        (rawValue & 0xF000) == 0xB000
    }
}

// MARK: - XCMP Status Types

/// Status types for RadioStatusRequest (0x000E).
public enum XCMPStatusType: UInt8 {
    case rssi = 0x02
    case lowBattery = 0x04
    case modelNumber = 0x07
    case serialNumber = 0x08
    case repeaterSerialNumber = 0x0B
    case callType = 0x0D
    case radioID = 0x0E
    case radioName = 0x0F
    case physicalSerialNumber = 0x4B
}

/// Version info types for VersionInfoRequest (0x000F).
public enum XCMPVersionType: UInt8 {
    case firmware = 0x00
    case codeplug = 0x0F
    case codeplugCPS = 0x41  // Used in CPS mode
    case bootloader = 0x50
}

// MARK: - Clone Data Types

/// Index types for CloneReadRequest.
/// These define the category of data being accessed.
public enum CloneIndexType: UInt16 {
    /// Zone-based index (used with zone ID)
    case zone = 0x8001
    /// Channel-based index (used with channel number within zone)
    case channel = 0x8002
    /// Contact index
    case contact = 0x8003
    /// Scan list index
    case scanList = 0x8004
    /// RX group list index
    case rxGroupList = 0x8005
    /// General radio setting (index is setting ID)
    case radioSetting = 0x0000
}

/// Data types for Contact CloneRead.
public enum ContactDataType: UInt8 {
    case name = 0x01
    case callType = 0x02       // 0=Private, 1=Group, 2=All Call
    case dmrID = 0x03          // 3-byte DMR ID
    case callReceiveTone = 0x04
    case callAlert = 0x05
}

/// Data types for Scan List CloneRead.
public enum ScanListDataType: UInt8 {
    case name = 0x01
    case memberCount = 0x02
    case memberList = 0x03     // List of channel references
    case priorityChannel1 = 0x04
    case priorityChannel2 = 0x05
    case talkbackEnabled = 0x06
    case holdTime = 0x07
}

/// Data types for RX Group List CloneRead.
public enum RxGroupDataType: UInt8 {
    case name = 0x01
    case memberCount = 0x02
    case memberList = 0x03     // List of contact indices
}

/// Data types for Radio General Settings CloneRead.
public enum RadioSettingDataType: UInt8 {
    // Identity
    case radioID = 0x01
    case radioAlias = 0x02
    case powerOnPassword = 0x03
    case introScreenLine1 = 0x04
    case introScreenLine2 = 0x05

    // Counts (for enumeration)
    case zoneCount = 0x10
    case contactCount = 0x11
    case scanListCount = 0x12
    case rxGroupCount = 0x13
    case textMessageCount = 0x14
    case emergencySystemCount = 0x15

    // Audio settings
    case voxEnabled = 0x20
    case voxSensitivity = 0x21
    case voxDelay = 0x22
    case keypadTones = 0x23
    case callAlertTone = 0x24
    case powerUpTone = 0x25
    case audioEnhancement = 0x26

    // Timing settings
    case totTime = 0x30
    case totResetTime = 0x31
    case groupCallHangTime = 0x32
    case privateCallHangTime = 0x33

    // Display settings
    case backlightTime = 0x40
    case backlightAuto = 0x41
    case defaultPowerLevel = 0x42

    // Signaling settings
    case radioCheckEnabled = 0x50
    case remoteMonitorEnabled = 0x51
    case callConfirmation = 0x52
    case emergencyAlertType = 0x53
    case emergencyDestinationID = 0x54

    // GPS settings
    case gpsEnabled = 0x60
    case gpsRevertChannel = 0x61
    case enhancedGNSS = 0x62

    // Lone Worker settings
    case loneWorkerEnabled = 0x70
    case loneWorkerResponseTime = 0x71
    case loneWorkerReminderTime = 0x72

    // Man Down settings
    case manDownEnabled = 0x80
    case manDownDelay = 0x81

    // Button assignments
    case topButtonShort = 0x90
    case topButtonLong = 0x91
    case sideButton1Short = 0x92
    case sideButton1Long = 0x93
    case sideButton2Short = 0x94
    case sideButton2Long = 0x95
}

/// Data types for CloneReadRequest that specify what data to retrieve.
/// These are used with the zone/channel clone read format.
public enum CloneDataType: UInt8 {
    // MARK: - Basic Channel Settings
    /// RX frequency (returns 4-byte value in 10Hz units)
    case rxFrequency = 0x01
    /// TX frequency
    case txFrequency = 0x02
    /// Channel type (analog/digital)
    case channelType = 0x03
    /// Timeslot (1 or 2 for DMR)
    case timeslot = 0x04
    /// Color code (0-15 for DMR)
    case colorCode = 0x05
    /// TX power level
    case txPower = 0x06
    /// Contact/talkgroup ID
    case contactID = 0x07
    /// Scan list assignment
    case scanListID = 0x08
    /// Admit criteria
    case admitCriteria = 0x09
    /// Squelch level
    case squelch = 0x0A
    /// Bandwidth (12.5/20/25 kHz)
    case bandwidth = 0x0B
    /// CTCSS/DCS encode tone
    case txTone = 0x0C
    /// CTCSS/DCS decode tone
    case rxTone = 0x0D
    /// Channel name (returns UTF-16 BE string)
    case channelName = 0x0F
    /// Channel alias/display name
    case channelAlias = 0x10

    // MARK: - Analog Settings
    /// RX squelch type (carrier, CTCSS, DCS, tight)
    case rxSquelchType = 0x11
    /// TX CTCSS frequency (in 0.1 Hz units)
    case txCTCSS = 0x12
    /// RX CTCSS frequency (in 0.1 Hz units)
    case rxCTCSS = 0x13
    /// TX DCS code (octal)
    case txDCS = 0x14
    /// RX DCS code (octal)
    case rxDCS = 0x15
    /// DCS invert flag
    case dcsInvert = 0x16
    /// Scramble enable
    case scrambleEnable = 0x17
    /// Voice emphasis
    case voiceEmphasis = 0x18

    // MARK: - Digital (DMR) Settings
    /// RX group list ID
    case rxGroupListID = 0x19
    /// TX contact type (individual/group/all)
    case txContactType = 0x1A
    /// Extended range direct mode
    case extendedRangeDirectMode = 0x1B
    /// Inbound color code (different from outbound)
    case inboundColorCode = 0x1C
    /// Outbound color code
    case outboundColorCode = 0x1D
    /// Dual capacity direct mode
    case dualCapacityDirectMode = 0x1E
    /// Timing leader preference
    case timingLeaderPreference = 0x1F

    // MARK: - Privacy/Encryption
    /// Privacy type (none, basic, enhanced, AES)
    case privacyType = 0x20
    /// Privacy key index
    case privacyKey = 0x21
    /// Privacy alias name
    case privacyAlias = 0x22
    /// Ignore RX clear voice
    case ignoreRxClearVoice = 0x23
    /// Fixed privacy key decryption
    case fixedPrivacyKeyDecryption = 0x24

    // MARK: - Signaling
    /// ARS enabled
    case arsEnabled = 0x25
    /// Enhanced GNSS enabled
    case enhancedGNSS = 0x26
    /// Lone worker enabled
    case loneWorker = 0x27
    /// Emergency alarm acknowledge
    case emergencyAlarmAck = 0x28
    /// TX interrupt type
    case txInterruptType = 0x29
    /// ARTS enabled
    case artsEnabled = 0x2A
    /// RAS alias
    case rasAlias = 0x2B

    // MARK: - Power & Timing
    /// RX only flag
    case rxOnly = 0x2C
    /// TOT timeout
    case totTimeout = 0x2D
    /// Allow talkaround
    case allowTalkaround = 0x2E
    /// Auto scan
    case autoScan = 0x2F

    // MARK: - MOTOTRBO Features
    /// MOTOTRBO link enabled
    case mototrboLink = 0x30
    /// Compressed UDP header
    case compressedUDPHeader = 0x31
    /// Text message type (DMR/MOTOTRBO)
    case textMessageType = 0x32
    /// Over-the-air battery management
    case otaBatteryManagement = 0x33
    /// Audio enhancement
    case audioEnhancement = 0x34
    /// Phone system name
    case phoneSystem = 0x35
    /// Window size
    case windowSize = 0x36

    // MARK: - Voice Announcements
    /// Voice announcement file
    case voiceAnnouncement = 0x37

    // MARK: - Zone Info
    /// Zone name
    case zoneName = 0x40
    /// Zone channel count
    case zoneChannelCount = 0x41
}

// MARK: - XCMP Error Codes

/// XCMP error codes returned in reply packets.
public enum XCMPErrorCode: UInt8 {
    case success = 0x00
    case failure = 0x01
    case invalidParameter = 0x02
    case reInitXNL = 0x03
    case notSupported = 0x04
    case busy = 0x05
}

// MARK: - PSDT Access (0x010B)

/// PSDT (Persistent Storage Data Table) access actions.
/// Used with XcmpPsdtAccess (0x010B) for codeplug operations.
public enum PsdtAccessAction: UInt8 {
    case none = 0x00
    case getStartAddress = 0x01    // Query start address of partition
    case getEndAddress = 0x02      // Query end address of partition
    case lock = 0x03               // Lock partition (prevent access)
    case unlock = 0x04             // Unlock partition (allow access)
    case erase = 0x05              // Erase partition contents
    case copy = 0x06               // Copy data between partitions
    case imageReorg = 0x07         // Reorganize partition image
}

/// PSDT access broadcast status values.
public enum PsdtAccessBroadcastStatus: UInt8 {
    case success = 0x00
    case transferInProgress = 0x02
    case failure = 0xFF
}

// MARK: - Component Session (0x010F)

/// Component session actions (can be combined as flags).
/// Used with XcmpComponentSession (0x010F) for programming session management.
public struct ComponentSessionActions: OptionSet, Sendable {
    public let rawValue: UInt16

    public init(rawValue: UInt16) {
        self.rawValue = rawValue
    }

    // Note: Use [] instead of .none for empty option set
    public static let reset = ComponentSessionActions(rawValue: 0x0001)
    public static let startSession = ComponentSessionActions(rawValue: 0x0002)
    public static let snapshot = ComponentSessionActions(rawValue: 0x0004)
    public static let validateCRC = ComponentSessionActions(rawValue: 0x0008)
    public static let unpackFiles = ComponentSessionActions(rawValue: 0x0010)
    public static let deploy = ComponentSessionActions(rawValue: 0x0020)
    public static let delayTOD = ComponentSessionActions(rawValue: 0x0040)
    public static let suppressPN = ComponentSessionActions(rawValue: 0x0080)
    public static let status = ComponentSessionActions(rawValue: 0x0100)
    public static let readWrite = ComponentSessionActions(rawValue: 0x0200)
    public static let createArchive = ComponentSessionActions(rawValue: 0x0400)
    public static let programmingIndicator = ComponentSessionActions(rawValue: 0x0800)
}

/// Component session reply result codes.
public enum ComponentSessionResult: UInt16 {
    case success = 0x0000
    case failure = 0x0001
    case invalidParameter = 0x0004
    case invalidSessionID = 0x0010
    case invalidArchive = 0x0011
    case busy = 0x0012
}

// MARK: - Radio Update Control (0x010C)

/// Radio update control actions.
public enum RadioUpdateControlAction: UInt8 {
    case none = 0x00
    case radioFirmwareActive = 0x01    // Check if firmware is active
    case radioCodeplugActive = 0x02    // Check if codeplug is active
    case radioUpdateFirmware = 0x03    // Initiate firmware update
    case radioUpdateCodeplug = 0x04    // Initiate codeplug update
    case radioValidateFirmware = 0x05  // Validate firmware
    case radioValidateCodeplug = 0x06  // Validate codeplug
    case radioDefaultAddrMode = 0x07   // Set default addressing mode
    case radioAbsAddrMode = 0x08       // Set absolute addressing mode
    case stopBGEraser = 0x09           // Stop background eraser
    case updateStatus = 0x0A           // Get update status
    case setDecomp = 0x0B              // Set decompression
}

// MARK: - Transfer Data (0x0446)

/// Transfer data types for XcmpTransferData.
public enum TransferDataType: UInt8 {
    case unknown0 = 0x00
    case unknown1 = 0x01
    case unknown2 = 0x02
    case unknown3 = 0x03
    case fxp = 0x04           // FXP protocol data
    case compressFile = 0x05  // Compressed file data
}

// MARK: - XCMP Packet

/// An XCMP packet that sits on top of XNL.
public struct XCMPPacket {
    public let opCode: XCMPOpCode
    public let data: Data

    public init(opCode: XCMPOpCode, data: Data = Data()) {
        self.opCode = opCode
        self.data = data
    }

    /// Encodes the XCMP packet to bytes.
    /// Format: [opcode(2)] [data...]
    public func encode() -> Data {
        var result = Data()
        result.append(UInt8(opCode.rawValue >> 8))
        result.append(UInt8(opCode.rawValue & 0xFF))
        result.append(data)
        return result
    }

    /// Decodes an XCMP packet from bytes.
    public static func decode(_ data: Data) -> XCMPPacket? {
        guard data.count >= 2 else { return nil }
        let opCodeValue = UInt16(data[0]) << 8 | UInt16(data[1])
        guard let opCode = XCMPOpCode(rawValue: opCodeValue) else {
            // Unknown opcode - still create packet with raw value
            return XCMPPacket(opCode: XCMPOpCode(rawValue: opCodeValue) ?? .radioStatusRequest, data: Data(data.dropFirst(2)))
        }
        return XCMPPacket(opCode: opCode, data: Data(data.dropFirst(2)))
    }

    // MARK: - Factory Methods (VERIFIED from CPS 2.0 Capture)

    /// Creates a SecurityKeyRequest (0x0012) - CPS sends this first after auth.
    /// Returns 16-byte session key in reply.
    public static func securityKeyRequest() -> XCMPPacket {
        XCMPPacket(opCode: .securityKeyRequest, data: Data())
    }

    /// Creates a ModelNumberRequest (0x0010) with param 0x00.
    public static func modelNumberRequest() -> XCMPPacket {
        XCMPPacket(opCode: .modelNumberRequest, data: Data([0x00]))
    }

    /// Creates a SerialNumberRequest (0x0011) with param 0x00.
    public static func serialNumberRequest() -> XCMPPacket {
        XCMPPacket(opCode: .serialNumberRequest, data: Data([0x00]))
    }

    /// Creates a CodeplugIdRequest (0x001F) with params 0x00 0x00.
    public static func codeplugIdRequest() -> XCMPPacket {
        XCMPPacket(opCode: .codeplugIdRequest, data: Data([0x00, 0x00]))
    }

    /// Creates a StatusFlagsRequest (0x003D) with params 0x00 0x00.
    public static func statusFlagsRequest() -> XCMPPacket {
        XCMPPacket(opCode: .statusFlagsRequest, data: Data([0x00, 0x00]))
    }

    /// Creates a CodeplugRead request (0x002E) for specific record IDs.
    /// Format: [count] 01 00 [record1] [record2] ...
    /// Each record: 09 01 04 80 [id:2] 00 01 00 00 00
    public static func codeplugReadRequest(recordIDs: [UInt16]) -> XCMPPacket {
        var data = Data()
        data.append(UInt8(recordIDs.count))  // Record count
        data.append(0x01)
        data.append(0x00)

        for recordID in recordIDs {
            data.append(0x09)
            data.append(0x01)
            data.append(0x04)
            data.append(0x80)
            data.append(UInt8(recordID >> 8))
            data.append(UInt8(recordID & 0xFF))
            data.append(0x00)
            data.append(0x01)
            data.append(0x00)
            data.append(0x00)
            data.append(0x00)
        }

        return XCMPPacket(opCode: .codeplugReadRequest, data: data)
    }

    // MARK: - Legacy Factory Methods

    /// Creates a RadioStatusRequest packet.
    public static func radioStatusRequest(_ statusType: XCMPStatusType) -> XCMPPacket {
        XCMPPacket(opCode: .radioStatusRequest, data: Data([statusType.rawValue]))
    }

    /// Creates a VersionInfoRequest packet.
    public static func versionInfoRequest(_ versionType: XCMPVersionType = .firmware) -> XCMPPacket {
        XCMPPacket(opCode: .versionInfoRequest, data: Data([versionType.rawValue]))
    }

    /// Creates a CPS unlock request packet.
    public static func cpsUnlockRequest() -> XCMPPacket {
        // The unlock command may need specific payload - need to capture from real CPS
        XCMPPacket(opCode: .cpsUnlockRequest, data: Data())
    }

    /// Creates a CPS read request packet.
    /// - Parameters:
    ///   - address: Memory address to read from
    ///   - length: Number of bytes to read
    public static func cpsReadRequest(address: UInt32, length: UInt16) -> XCMPPacket {
        var data = Data()
        // Address (4 bytes, big-endian)
        data.append(UInt8((address >> 24) & 0xFF))
        data.append(UInt8((address >> 16) & 0xFF))
        data.append(UInt8((address >> 8) & 0xFF))
        data.append(UInt8(address & 0xFF))
        // Length (2 bytes, big-endian)
        data.append(UInt8((length >> 8) & 0xFF))
        data.append(UInt8(length & 0xFF))
        return XCMPPacket(opCode: .cpsReadRequest, data: data)
    }

    /// Creates a CloneReadRequest packet using raw index type and data type.
    public static func cloneReadRequest(indexType: UInt16, index: UInt16, dataType: UInt16) -> XCMPPacket {
        var data = Data()
        data.append(UInt8(indexType >> 8))
        data.append(UInt8(indexType & 0xFF))
        data.append(UInt8(index >> 8))
        data.append(UInt8(index & 0xFF))
        data.append(UInt8(dataType >> 8))
        data.append(UInt8(dataType & 0xFF))
        return XCMPPacket(opCode: .cloneReadRequest, data: data)
    }

    /// Creates a CloneReadRequest for zone/channel data.
    /// This uses the RDAC-style format with zone and channel specifiers.
    /// - Parameters:
    ///   - zone: Zone number (0-based)
    ///   - channel: Channel number within zone (0-based)
    ///   - dataType: Type of data to retrieve (e.g., channel name)
    public static func cloneReadRequest(zone: UInt16, channel: UInt16, dataType: CloneDataType) -> XCMPPacket {
        var data = Data()
        // Zone index type (0x8001)
        data.append(0x80)
        data.append(0x01)
        // Zone number
        data.append(UInt8(zone >> 8))
        data.append(UInt8(zone & 0xFF))
        // Channel index type (0x8002)
        data.append(0x80)
        data.append(0x02)
        // Channel number
        data.append(UInt8(channel >> 8))
        data.append(UInt8(channel & 0xFF))
        // Data type
        data.append(0x00)
        data.append(dataType.rawValue)
        return XCMPPacket(opCode: .cloneReadRequest, data: data)
    }

    /// Creates a CloneReadRequest for zone-level data (like zone name).
    public static func cloneReadRequestZone(zone: UInt16, dataType: CloneDataType) -> XCMPPacket {
        var data = Data()
        // Zone index type (0x8001)
        data.append(0x80)
        data.append(0x01)
        // Zone number
        data.append(UInt8(zone >> 8))
        data.append(UInt8(zone & 0xFF))
        // Data type
        data.append(0x00)
        data.append(dataType.rawValue)
        return XCMPPacket(opCode: .cloneReadRequest, data: data)
    }

    /// Creates a CloneReadRequest for contact data.
    public static func cloneReadContact(index: UInt16, dataType: ContactDataType) -> XCMPPacket {
        var data = Data()
        // Contact index type (0x8003)
        data.append(0x80)
        data.append(0x03)
        // Contact index
        data.append(UInt8(index >> 8))
        data.append(UInt8(index & 0xFF))
        // Data type
        data.append(0x00)
        data.append(dataType.rawValue)
        return XCMPPacket(opCode: .cloneReadRequest, data: data)
    }

    /// Creates a CloneReadRequest for scan list data.
    public static func cloneReadScanList(index: UInt16, dataType: ScanListDataType) -> XCMPPacket {
        var data = Data()
        // Scan list index type (0x8004)
        data.append(0x80)
        data.append(0x04)
        // Scan list index
        data.append(UInt8(index >> 8))
        data.append(UInt8(index & 0xFF))
        // Data type
        data.append(0x00)
        data.append(dataType.rawValue)
        return XCMPPacket(opCode: .cloneReadRequest, data: data)
    }

    /// Creates a CloneReadRequest for RX group list data.
    public static func cloneReadRxGroup(index: UInt16, dataType: RxGroupDataType) -> XCMPPacket {
        var data = Data()
        // RX group index type (0x8005)
        data.append(0x80)
        data.append(0x05)
        // RX group index
        data.append(UInt8(index >> 8))
        data.append(UInt8(index & 0xFF))
        // Data type
        data.append(0x00)
        data.append(dataType.rawValue)
        return XCMPPacket(opCode: .cloneReadRequest, data: data)
    }

    /// Creates a CloneReadRequest for radio general settings.
    public static func cloneReadRadioSetting(dataType: RadioSettingDataType) -> XCMPPacket {
        var data = Data()
        // Radio setting index type (0x0000)
        data.append(0x00)
        data.append(0x00)
        // Setting ID is the data type
        data.append(0x00)
        data.append(dataType.rawValue)
        return XCMPPacket(opCode: .cloneReadRequest, data: data)
    }

    // MARK: - PSDT Access Packets (0x010B)

    /// Creates a PSDT access request packet.
    /// - Parameters:
    ///   - action: The PSDT action to perform
    ///   - sourcePartition: Source partition ID (max 4 ASCII chars, e.g., "CP", "ISH")
    ///   - targetPartition: Target partition ID (for copy operations)
    public static func psdtAccessRequest(action: PsdtAccessAction, sourcePartition: String, targetPartition: String = "") -> XCMPPacket {
        var data = Data()
        data.append(action.rawValue)

        // Source partition ID (4 bytes, ASCII, padded with nulls)
        let srcBytes = Array(sourcePartition.prefix(4).utf8)
        for i in 0..<4 {
            data.append(i < srcBytes.count ? srcBytes[i] : 0x00)
        }

        // Target partition ID (4 bytes, ASCII, padded with nulls)
        let tgtBytes = Array(targetPartition.prefix(4).utf8)
        for i in 0..<4 {
            data.append(i < tgtBytes.count ? tgtBytes[i] : 0x00)
        }

        return XCMPPacket(opCode: .psdtAccessRequest, data: data)
    }

    /// Creates a PSDT get start address request.
    public static func psdtGetStartAddress(partition: String) -> XCMPPacket {
        psdtAccessRequest(action: .getStartAddress, sourcePartition: partition)
    }

    /// Creates a PSDT get end address request.
    public static func psdtGetEndAddress(partition: String) -> XCMPPacket {
        psdtAccessRequest(action: .getEndAddress, sourcePartition: partition)
    }

    /// Creates a PSDT unlock request.
    public static func psdtUnlock(partition: String) -> XCMPPacket {
        psdtAccessRequest(action: .unlock, sourcePartition: partition)
    }

    /// Creates a PSDT lock request.
    public static func psdtLock(partition: String) -> XCMPPacket {
        psdtAccessRequest(action: .lock, sourcePartition: partition)
    }

    /// Creates a PSDT erase request.
    public static func psdtErase(partition: String) -> XCMPPacket {
        psdtAccessRequest(action: .erase, sourcePartition: partition)
    }

    // MARK: - Component Session Packets (0x010F)

    /// Creates a component session request packet.
    /// - Parameters:
    ///   - actions: The session actions to perform (can be combined)
    ///   - sessionID: Unique session identifier
    ///   - data: Optional additional data
    public static func componentSessionRequest(actions: ComponentSessionActions, sessionID: UInt16, data: UInt32? = nil) -> XCMPPacket {
        var payload = Data()

        // Actions (2 bytes, big-endian)
        payload.append(UInt8(actions.rawValue >> 8))
        payload.append(UInt8(actions.rawValue & 0xFF))

        // Session ID (2 bytes, big-endian)
        payload.append(UInt8(sessionID >> 8))
        payload.append(UInt8(sessionID & 0xFF))

        // Optional data (4 bytes, big-endian)
        if let data = data {
            payload.append(UInt8((data >> 24) & 0xFF))
            payload.append(UInt8((data >> 16) & 0xFF))
            payload.append(UInt8((data >> 8) & 0xFF))
            payload.append(UInt8(data & 0xFF))
        }

        return XCMPPacket(opCode: .componentSessionRequest, data: payload)
    }

    /// Creates a start session request for reading.
    public static func startReadSession(sessionID: UInt16) -> XCMPPacket {
        componentSessionRequest(
            actions: [.startSession, .readWrite],
            sessionID: sessionID
        )
    }

    /// Creates a start session request for writing.
    public static func startWriteSession(sessionID: UInt16) -> XCMPPacket {
        componentSessionRequest(
            actions: [.startSession, .readWrite, .programmingIndicator],
            sessionID: sessionID
        )
    }

    /// Creates a session reset request.
    public static func resetSession(sessionID: UInt16) -> XCMPPacket {
        componentSessionRequest(actions: .reset, sessionID: sessionID)
    }

    /// Creates a validate CRC request.
    public static func validateSessionCRC(sessionID: UInt16) -> XCMPPacket {
        componentSessionRequest(actions: .validateCRC, sessionID: sessionID)
    }

    /// Creates an unpack and deploy request.
    public static func unpackAndDeploy(sessionID: UInt16) -> XCMPPacket {
        componentSessionRequest(
            actions: [.unpackFiles, .deploy],
            sessionID: sessionID
        )
    }

    /// Creates a create archive request.
    public static func createArchive(sessionID: UInt16) -> XCMPPacket {
        componentSessionRequest(actions: .createArchive, sessionID: sessionID)
    }

    // MARK: - Radio Update Control Packets (0x010C)

    /// Creates a radio update control request.
    public static func radioUpdateControlRequest(action: RadioUpdateControlAction) -> XCMPPacket {
        XCMPPacket(opCode: .radioUpdateControlRequest, data: Data([action.rawValue]))
    }

    /// Creates a check codeplug active request.
    public static func checkCodeplugActive() -> XCMPPacket {
        radioUpdateControlRequest(action: .radioCodeplugActive)
    }

    /// Creates an initiate codeplug update request.
    public static func initiateCodeplugUpdate() -> XCMPPacket {
        radioUpdateControlRequest(action: .radioUpdateCodeplug)
    }

    /// Creates a validate codeplug request.
    public static func validateCodeplug() -> XCMPPacket {
        radioUpdateControlRequest(action: .radioValidateCodeplug)
    }

    // MARK: - Transfer Data Packets (0x0446)

    /// Creates a transfer data request packet.
    /// - Parameters:
    ///   - dataType: The type of data being transferred
    ///   - payload: The data payload
    public static func transferDataRequest(dataType: TransferDataType, payload: Data) -> XCMPPacket {
        var data = Data()
        data.append(dataType.rawValue)
        data.append(payload)
        return XCMPPacket(opCode: .transferDataRequest, data: data)
    }

    /// Creates a compressed file transfer request.
    public static func transferCompressedData(_ payload: Data) -> XCMPPacket {
        transferDataRequest(dataType: .compressFile, payload: payload)
    }

    // MARK: - Module Info Packets (0x0461)

    /// Creates a module info request.
    public static func moduleInfoRequest() -> XCMPPacket {
        XCMPPacket(opCode: .moduleInfoRequest, data: Data())
    }

    // MARK: - Codeplug Attribute Packets (0x0025)

    /// Creates a codeplug attribute request.
    public static func codeplugAttributeRequest() -> XCMPPacket {
        XCMPPacket(opCode: .codeplugAttributeRequest, data: Data())
    }
}

// MARK: - XCMP Reply Parsing

/// Parsed radio status reply.
public struct RadioStatusReply {
    public let statusType: XCMPStatusType
    public let errorCode: XCMPErrorCode
    public let data: Data

    /// Parses the data as a string (for model number, serial number, etc).
    public var stringValue: String? {
        String(data: data, encoding: .utf8)?.trimmingCharacters(in: .controlCharacters)
    }

    /// Parses the data as a radio ID (3 bytes).
    public var radioID: UInt32? {
        guard data.count >= 3 else { return nil }
        return UInt32(data[0]) << 16 | UInt32(data[1]) << 8 | UInt32(data[2])
    }
}

/// Parsed version info reply.
public struct VersionInfoReply {
    public let versionType: XCMPVersionType
    public let errorCode: XCMPErrorCode
    public let version: String
}

/// Parsed clone read reply.
public struct CloneReadReply {
    public let zone: UInt16
    public let channel: UInt16
    public let dataType: UInt16
    public let errorCode: XCMPErrorCode
    public let data: Data

    /// Parses the data as a UTF-16 BE string (used for channel names).
    public var stringValue: String? {
        String(data: data, encoding: .utf16BigEndian)?
            .trimmingCharacters(in: .controlCharacters)
            .trimmingCharacters(in: CharacterSet(["\0"]))
    }

    /// Parses the data as a 4-byte frequency in 10Hz units.
    public var frequencyHz: UInt32? {
        guard data.count >= 4 else { return nil }
        let raw = UInt32(data[0]) << 24 | UInt32(data[1]) << 16 | UInt32(data[2]) << 8 | UInt32(data[3])
        return raw * 10  // Convert from 10Hz units to Hz
    }

    /// Parses the data as a single byte value.
    public var byteValue: UInt8? {
        data.first
    }

    /// Parses the data as a 2-byte value.
    public var uint16Value: UInt16? {
        guard data.count >= 2 else { return nil }
        return UInt16(data[0]) << 8 | UInt16(data[1])
    }

    /// Parses the data as a 4-byte value.
    public var uint32Value: UInt32? {
        guard data.count >= 4 else { return nil }
        return UInt32(data[0]) << 24 | UInt32(data[1]) << 16 | UInt32(data[2]) << 8 | UInt32(data[3])
    }

    /// Initializes from raw XCMP reply data.
    public init?(from xcmpData: Data) {
        // CloneReadReply format (from Moto.Net analysis):
        // [3-4]: 0x8001 (zone index type)
        // [5-6]: zone number
        // [7-8]: 0x8002 (channel index type)
        // [9-10]: channel number
        // [11-12]: data type
        // [13-14]: data length
        // [15...]: data
        guard xcmpData.count >= 15 else { return nil }

        // Check for error code first (byte 0 after opcode removal)
        let errByte = xcmpData[0]
        self.errorCode = XCMPErrorCode(rawValue: errByte) ?? .failure

        // If error, no more data
        if errorCode != .success && xcmpData.count < 15 {
            self.zone = 0
            self.channel = 0
            self.dataType = 0
            self.data = Data()
            return
        }

        // Parse zone/channel format
        // Note: offset adjusted based on whether error code is included
        let offset = xcmpData.count >= 16 ? 1 : 0
        self.zone = UInt16(xcmpData[offset + 3]) << 8 | UInt16(xcmpData[offset + 4])
        self.channel = UInt16(xcmpData[offset + 7]) << 8 | UInt16(xcmpData[offset + 8])
        self.dataType = UInt16(xcmpData[offset + 9]) << 8 | UInt16(xcmpData[offset + 10])
        // Skip length bytes (11-12), get actual data
        self.data = Data(xcmpData.dropFirst(offset + 13))
    }
}

// MARK: - XCMP Client

/// XCMP client that communicates over an authenticated XNL connection.
public actor XCMPClient {
    private let xnlConnection: XNLConnection

    public init(xnlConnection: XNLConnection) {
        self.xnlConnection = xnlConnection
    }

    /// Sends an XCMP packet and waits for a reply.
    public func sendAndReceive(_ packet: XCMPPacket, timeout: TimeInterval = 5.0, debug: Bool = false) async throws -> XCMPPacket? {
        let xcmpData = packet.encode()
        guard let responseData = try await xnlConnection.sendXCMP(xcmpData, timeout: timeout, debug: debug) else {
            return nil
        }
        return XCMPPacket.decode(responseData)
    }

    // MARK: - VERIFIED CPS Protocol Methods

    /// Gets the security key (0x0012) - CPS calls this first after auth.
    /// Returns 16-byte session key.
    public func getSecurityKey(debug: Bool = false) async throws -> Data? {
        let request = XCMPPacket.securityKeyRequest()
        guard let reply = try await sendAndReceive(request, debug: debug) else { return nil }
        // Reply format: [result 1B] [key 16B]
        guard reply.data.count >= 17, reply.data[0] == 0x00 else { return nil }
        return Data(reply.data[1...16])
    }

    /// Gets model number using verified CPS protocol (0x0010).
    public func getModelNumberCPS(debug: Bool = false) async throws -> String? {
        let request = XCMPPacket.modelNumberRequest()
        guard let reply = try await sendAndReceive(request, debug: debug) else { return nil }
        // Reply format: [result 1B] [model string]
        guard reply.data.count > 1, reply.data[0] == 0x00 else { return nil }
        return String(data: Data(reply.data[1...]), encoding: .utf8)?
            .trimmingCharacters(in: .controlCharacters)
            .trimmingCharacters(in: CharacterSet(["\0"]))
    }

    /// Gets serial number using verified CPS protocol (0x0011).
    public func getSerialNumberCPS(debug: Bool = false) async throws -> String? {
        let request = XCMPPacket.serialNumberRequest()
        guard let reply = try await sendAndReceive(request, debug: debug) else { return nil }
        // Reply format: [result 1B] [serial string]
        guard reply.data.count > 1, reply.data[0] == 0x00 else { return nil }
        return String(data: Data(reply.data[1...]), encoding: .utf8)?
            .trimmingCharacters(in: .controlCharacters)
            .trimmingCharacters(in: CharacterSet(["\0"]))
    }

    /// Gets firmware version using verified CPS protocol (0x000F).
    /// - Parameter type: 0x00 for full version (R02.21.01.1001), 0x41 for build (211036)
    public func getFirmwareVersionCPS(type: UInt8 = 0x00, debug: Bool = false) async throws -> String? {
        let request = XCMPPacket(opCode: .versionInfoRequest, data: Data([type]))
        guard let reply = try await sendAndReceive(request, debug: debug) else { return nil }
        // Reply format: [result 1B] [version string]
        guard reply.data.count > 1, reply.data[0] == 0x00 else { return nil }
        return String(data: Data(reply.data[1...]), encoding: .utf8)?
            .trimmingCharacters(in: .controlCharacters)
            .trimmingCharacters(in: CharacterSet(["\0"]))
    }

    /// Gets codeplug ID using verified CPS protocol (0x001F).
    public func getCodeplugID(debug: Bool = false) async throws -> String? {
        let request = XCMPPacket.codeplugIdRequest()
        guard let reply = try await sendAndReceive(request, debug: debug) else { return nil }
        // Reply format: [result 1B] [codeplug ID string]
        guard reply.data.count > 1, reply.data[0] == 0x00 else { return nil }
        return String(data: Data(reply.data[1...]), encoding: .utf8)?
            .trimmingCharacters(in: .controlCharacters)
            .trimmingCharacters(in: CharacterSet(["\0"]))
    }

    /// Reads codeplug records using verified CPS protocol (0x002E).
    /// - Parameter recordIDs: List of record IDs to read
    /// - Returns: Raw response data containing all requested records
    public func readCodeplugRecords(_ recordIDs: [UInt16], debug: Bool = false) async throws -> Data? {
        let request = XCMPPacket.codeplugReadRequest(recordIDs: recordIDs)
        guard let reply = try await sendAndReceive(request, timeout: 10.0, debug: debug) else { return nil }
        return reply.data
    }

    /// Performs complete device identification using verified CPS protocol.
    public func identifyCPS(debug: Bool = false) async throws -> RadioIdentification {
        // Get security key first (CPS does this)
        _ = try await getSecurityKey(debug: debug)

        let model = try await getModelNumberCPS(debug: debug) ?? "Unknown"
        let serial = try await getSerialNumberCPS(debug: debug)
        let firmware = try await getFirmwareVersionCPS(type: 0x00, debug: debug)
        let codeplugID = try await getCodeplugID(debug: debug)

        return RadioIdentification(
            modelNumber: model,
            serialNumber: serial,
            firmwareVersion: firmware,
            radioFamily: guessRadioFamily(from: model),
            codeplugVersion: codeplugID,  // Codeplug ID from 0x001F
            radioID: nil  // CPS doesn't query radio ID during read
        )
    }

    // MARK: - Legacy Methods (may not work with all radios)

    /// Gets the radio model number (legacy method).
    public func getModelNumber() async throws -> String? {
        let request = XCMPPacket.radioStatusRequest(.modelNumber)
        guard let reply = try await sendAndReceive(request) else { return nil }
        return String(data: reply.data.dropFirst(), encoding: .utf8)?.trimmingCharacters(in: .controlCharacters)
    }

    /// Gets the radio serial number (legacy method).
    public func getSerialNumber() async throws -> String? {
        let request = XCMPPacket.radioStatusRequest(.serialNumber)
        guard let reply = try await sendAndReceive(request) else { return nil }
        return String(data: reply.data.dropFirst(), encoding: .utf8)?.trimmingCharacters(in: .controlCharacters)
    }

    /// Gets the radio ID (legacy method).
    public func getRadioID() async throws -> UInt32? {
        let request = XCMPPacket.radioStatusRequest(.radioID)
        guard let reply = try await sendAndReceive(request) else { return nil }
        // Skip error code byte, then read 3-byte radio ID
        guard reply.data.count >= 4 else { return nil }
        return UInt32(reply.data[1]) << 16 | UInt32(reply.data[2]) << 8 | UInt32(reply.data[3])
    }

    /// Gets firmware version (legacy method).
    public func getFirmwareVersion() async throws -> String? {
        let request = XCMPPacket.versionInfoRequest(.firmware)
        guard let reply = try await sendAndReceive(request) else { return nil }
        // Skip error code and version type bytes
        guard reply.data.count > 2 else { return nil }
        return String(data: reply.data.dropFirst(2), encoding: .utf8)?.trimmingCharacters(in: .controlCharacters)
    }

    /// Gets full radio identification (legacy method).
    public func identify() async throws -> RadioIdentification {
        let model = try await getModelNumber() ?? "Unknown"
        let serial = try await getSerialNumber()
        let firmware = try await getFirmwareVersion()
        let radioID = try await getRadioID()

        return RadioIdentification(
            modelNumber: model,
            serialNumber: serial,
            firmwareVersion: firmware,
            radioFamily: guessRadioFamily(from: model),
            radioID: radioID
        )
    }

    private func guessRadioFamily(from model: String) -> String? {
        let modelLower = model.lowercased()
        if modelLower.contains("xpr") { return "xpr" }
        if modelLower.contains("apx") { return "apx" }
        if modelLower.contains("sl") { return "sl" }
        if modelLower.contains("dp") { return "dp" }
        if modelLower.contains("dm") { return "dm" }
        return nil
    }

    // MARK: - Clone Read Operations

    /// Reads channel data from the radio using CloneRead.
    /// - Parameters:
    ///   - zone: Zone number (0-based)
    ///   - channel: Channel number within zone (0-based)
    ///   - dataType: Type of data to retrieve
    /// - Returns: CloneReadReply with the requested data
    public func readChannelData(zone: UInt16, channel: UInt16, dataType: CloneDataType) async throws -> CloneReadReply? {
        let request = XCMPPacket.cloneReadRequest(zone: zone, channel: channel, dataType: dataType)
        guard let reply = try await sendAndReceive(request) else { return nil }
        return CloneReadReply(from: reply.data)
    }

    /// Gets a channel name.
    /// - Parameters:
    ///   - zone: Zone number (0-based)
    ///   - channel: Channel number within zone (0-based)
    /// - Returns: Channel name as a string, or nil if not available
    public func getChannelName(zone: UInt16, channel: UInt16) async throws -> String? {
        guard let reply = try await readChannelData(zone: zone, channel: channel, dataType: .channelName) else {
            return nil
        }
        return reply.stringValue
    }

    /// Gets channel RX frequency.
    /// - Parameters:
    ///   - zone: Zone number (0-based)
    ///   - channel: Channel number within zone (0-based)
    /// - Returns: RX frequency in Hz
    public func getChannelRxFrequency(zone: UInt16, channel: UInt16) async throws -> UInt32? {
        guard let reply = try await readChannelData(zone: zone, channel: channel, dataType: .rxFrequency) else {
            return nil
        }
        return reply.frequencyHz
    }

    /// Gets channel TX frequency.
    public func getChannelTxFrequency(zone: UInt16, channel: UInt16) async throws -> UInt32? {
        guard let reply = try await readChannelData(zone: zone, channel: channel, dataType: .txFrequency) else {
            return nil
        }
        return reply.frequencyHz
    }

    /// Reads data using the generic CloneRead format.
    public func cloneRead(indexType: UInt16, index: UInt16, dataType: UInt16) async throws -> Data? {
        let request = XCMPPacket.cloneReadRequest(indexType: indexType, index: index, dataType: dataType)
        guard let reply = try await sendAndReceive(request) else { return nil }
        // Skip the header and return raw data
        guard reply.data.count > 13 else { return nil }
        return Data(reply.data.dropFirst(13))
    }

    // MARK: - Zone and Channel Reading

    /// Queries zone information using XCMP 0x0037.
    /// - Parameter queryType: 0x01 for zone count, 0x03 for zone list
    public func queryZones(queryType: UInt8 = 0x01, debug: Bool = false) async throws -> ZoneQueryResult? {
        // XCMP 0x0037: Zone/Feature Query
        // Format: 0x0037 [type] [subtype] [extra]
        let request = XCMPPacket(opCode: .featureSetRequest, data: Data([queryType, 0x01, 0x00]))
        guard let reply = try await sendAndReceive(request, timeout: 5.0, debug: debug) else { return nil }

        if debug {
            print("[ZONE] Query response: \(reply.data.map { String(format: "%02X", $0) }.joined(separator: " "))")
        }

        return ZoneQueryResult(from: reply.data)
    }

    /// Queries zone details including channel count per zone.
    public func queryZoneDetails(debug: Bool = false) async throws -> ZoneDetailsResult? {
        let request = XCMPPacket(opCode: .featureSetRequest, data: Data([0x01, 0x03, 0x00]))
        guard let reply = try await sendAndReceive(request, timeout: 5.0, debug: debug) else { return nil }

        if debug {
            print("[ZONE] Details response: \(reply.data.map { String(format: "%02X", $0) }.joined(separator: " "))")
        }

        return ZoneDetailsResult(from: reply.data)
    }

    /// Reads a complete channel's data using CloneRead.
    /// - Parameters:
    ///   - zone: Zone index (0-based)
    ///   - channel: Channel index within zone (0-based)
    /// - Returns: ChannelData with all available fields
    public func readCompleteChannel(zone: UInt16, channel: UInt16, debug: Bool = false) async throws -> ChannelData {
        var channelData = ChannelData(zoneIndex: Int(zone), channelIndex: Int(channel))

        // MARK: - Basic Settings (always read)

        // Channel Name
        if let nameReply = try await readChannelData(zone: zone, channel: channel, dataType: .channelName) {
            channelData.name = nameReply.stringValue ?? "CH\(channel + 1)"
        }

        // RX Frequency
        if let rxReply = try await readChannelData(zone: zone, channel: channel, dataType: .rxFrequency) {
            channelData.rxFrequencyHz = rxReply.frequencyHz ?? 0
        }

        // TX Frequency
        if let txReply = try await readChannelData(zone: zone, channel: channel, dataType: .txFrequency) {
            channelData.txFrequencyHz = txReply.frequencyHz ?? 0
        }

        // Channel Type (Analog/Digital)
        if let typeReply = try await readChannelData(zone: zone, channel: channel, dataType: .channelType) {
            channelData.isDigital = (typeReply.byteValue ?? 0) != 0
        }

        // TX Power
        if let powerReply = try await readChannelData(zone: zone, channel: channel, dataType: .txPower) {
            channelData.txPowerHigh = (powerReply.byteValue ?? 1) != 0
        }

        // Bandwidth
        if let bwReply = try await readChannelData(zone: zone, channel: channel, dataType: .bandwidth) {
            channelData.bandwidthWide = (bwReply.byteValue ?? 0) != 0
        }

        // MARK: - Digital (DMR) Settings

        if channelData.isDigital {
            // Time Slot
            if let tsReply = try await readChannelData(zone: zone, channel: channel, dataType: .timeslot) {
                channelData.timeSlot = Int(tsReply.byteValue ?? 1)
            }

            // Color Code
            if let ccReply = try await readChannelData(zone: zone, channel: channel, dataType: .colorCode) {
                channelData.colorCode = Int(ccReply.byteValue ?? 1)
            }

            // Contact ID
            if let contactReply = try await readChannelData(zone: zone, channel: channel, dataType: .contactID) {
                channelData.contactID = contactReply.uint32Value ?? 0
            }

            // RX Group List
            if let rxGroupReply = try await readChannelData(zone: zone, channel: channel, dataType: .rxGroupListID) {
                channelData.rxGroupListID = rxGroupReply.byteValue ?? 0
            }

            // Inbound Color Code
            if let inCCReply = try await readChannelData(zone: zone, channel: channel, dataType: .inboundColorCode) {
                channelData.inboundColorCode = Int(inCCReply.byteValue ?? 1)
            }

            // Outbound Color Code
            if let outCCReply = try await readChannelData(zone: zone, channel: channel, dataType: .outboundColorCode) {
                channelData.outboundColorCode = Int(outCCReply.byteValue ?? 1)
            }

            // Dual Capacity Direct Mode
            if let dcdmReply = try await readChannelData(zone: zone, channel: channel, dataType: .dualCapacityDirectMode) {
                channelData.dualCapacityDirectMode = (dcdmReply.byteValue ?? 0) != 0
            }

            // Timing Leader Preference
            if let tlpReply = try await readChannelData(zone: zone, channel: channel, dataType: .timingLeaderPreference) {
                channelData.timingLeaderPreference = Int(tlpReply.byteValue ?? 0)
            }

            // Extended Range Direct Mode
            if let erdmReply = try await readChannelData(zone: zone, channel: channel, dataType: .extendedRangeDirectMode) {
                channelData.extendedRangeDirectMode = (erdmReply.byteValue ?? 0) != 0
            }

            // Window Size
            if let wsReply = try await readChannelData(zone: zone, channel: channel, dataType: .windowSize) {
                channelData.windowSize = wsReply.byteValue ?? 1
            }

            // Compressed UDP Header
            if let udpReply = try await readChannelData(zone: zone, channel: channel, dataType: .compressedUDPHeader) {
                channelData.compressedUDPHeader = (udpReply.byteValue ?? 0) != 0
            }

            // Text Message Type
            if let tmtReply = try await readChannelData(zone: zone, channel: channel, dataType: .textMessageType) {
                channelData.textMessageType = Int(tmtReply.byteValue ?? 0)
            }
        }

        // MARK: - Analog Settings

        if !channelData.isDigital {
            // RX Squelch Type
            if let sqReply = try await readChannelData(zone: zone, channel: channel, dataType: .rxSquelchType) {
                channelData.rxSquelchType = Int(sqReply.byteValue ?? 0)
            }

            // TX CTCSS
            if let txCtcssReply = try await readChannelData(zone: zone, channel: channel, dataType: .txCTCSS) {
                channelData.txCTCSSHz = Double(txCtcssReply.uint16Value ?? 0) / 10.0
            }

            // RX CTCSS
            if let rxCtcssReply = try await readChannelData(zone: zone, channel: channel, dataType: .rxCTCSS) {
                channelData.rxCTCSSHz = Double(rxCtcssReply.uint16Value ?? 0) / 10.0
            }

            // TX DCS
            if let txDcsReply = try await readChannelData(zone: zone, channel: channel, dataType: .txDCS) {
                channelData.txDCSCode = txDcsReply.uint16Value ?? 0
            }

            // RX DCS
            if let rxDcsReply = try await readChannelData(zone: zone, channel: channel, dataType: .rxDCS) {
                channelData.rxDCSCode = rxDcsReply.uint16Value ?? 0
            }

            // DCS Invert
            if let dcsInvReply = try await readChannelData(zone: zone, channel: channel, dataType: .dcsInvert) {
                channelData.dcsInvert = (dcsInvReply.byteValue ?? 0) != 0
            }

            // Scramble Enable
            if let scrambleReply = try await readChannelData(zone: zone, channel: channel, dataType: .scrambleEnable) {
                channelData.scrambleEnabled = (scrambleReply.byteValue ?? 0) != 0
            }

            // Voice Emphasis
            if let veReply = try await readChannelData(zone: zone, channel: channel, dataType: .voiceEmphasis) {
                channelData.voiceEmphasis = (veReply.byteValue ?? 0) != 0
            }
        }

        // MARK: - Privacy Settings (both analog and digital)

        // Privacy Type
        if let ptReply = try await readChannelData(zone: zone, channel: channel, dataType: .privacyType) {
            channelData.privacyType = Int(ptReply.byteValue ?? 0)
        }

        // Privacy Key
        if let pkReply = try await readChannelData(zone: zone, channel: channel, dataType: .privacyKey) {
            channelData.privacyKey = pkReply.byteValue ?? 0
        }

        // Ignore RX Clear Voice
        if let ircvReply = try await readChannelData(zone: zone, channel: channel, dataType: .ignoreRxClearVoice) {
            channelData.ignoreRxClearVoice = (ircvReply.byteValue ?? 0) != 0
        }

        // MARK: - Signaling Settings

        // ARS Enabled
        if let arsReply = try await readChannelData(zone: zone, channel: channel, dataType: .arsEnabled) {
            channelData.arsEnabled = (arsReply.byteValue ?? 0) != 0
        }

        // Enhanced GNSS
        if let gnssReply = try await readChannelData(zone: zone, channel: channel, dataType: .enhancedGNSS) {
            channelData.enhancedGNSSEnabled = (gnssReply.byteValue ?? 0) != 0
        }

        // Lone Worker
        if let lwReply = try await readChannelData(zone: zone, channel: channel, dataType: .loneWorker) {
            channelData.loneWorker = (lwReply.byteValue ?? 0) != 0
        }

        // Emergency Alarm Ack
        if let eaaReply = try await readChannelData(zone: zone, channel: channel, dataType: .emergencyAlarmAck) {
            channelData.emergencyAlarmAck = (eaaReply.byteValue ?? 0) != 0
        }

        // TX Interrupt Type
        if let txiReply = try await readChannelData(zone: zone, channel: channel, dataType: .txInterruptType) {
            channelData.txInterruptType = Int(txiReply.byteValue ?? 0)
        }

        // ARTS Enabled
        if let artsReply = try await readChannelData(zone: zone, channel: channel, dataType: .artsEnabled) {
            channelData.artsEnabled = (artsReply.byteValue ?? 0) != 0
        }

        // MARK: - Power & Timing

        // RX Only
        if let rxOnlyReply = try await readChannelData(zone: zone, channel: channel, dataType: .rxOnly) {
            channelData.rxOnly = (rxOnlyReply.byteValue ?? 0) != 0
        }

        // TOT Timeout
        if let totReply = try await readChannelData(zone: zone, channel: channel, dataType: .totTimeout) {
            channelData.totTimeout = totReply.uint16Value ?? 60
        }

        // Allow Talkaround
        if let taReply = try await readChannelData(zone: zone, channel: channel, dataType: .allowTalkaround) {
            channelData.allowTalkaround = (taReply.byteValue ?? 1) != 0
        }

        // Auto Scan
        if let asReply = try await readChannelData(zone: zone, channel: channel, dataType: .autoScan) {
            channelData.autoScan = (asReply.byteValue ?? 0) != 0
        }

        // Scan List ID
        if let slReply = try await readChannelData(zone: zone, channel: channel, dataType: .scanListID) {
            channelData.scanListID = slReply.byteValue ?? 0
        }

        // MARK: - MOTOTRBO Features

        // MOTOTRBO Link
        if let mtlReply = try await readChannelData(zone: zone, channel: channel, dataType: .mototrboLink) {
            channelData.mototrboLinkEnabled = (mtlReply.byteValue ?? 0) != 0
        }

        // OTA Battery Management
        if let otaReply = try await readChannelData(zone: zone, channel: channel, dataType: .otaBatteryManagement) {
            channelData.otaBatteryManagement = (otaReply.byteValue ?? 0) != 0
        }

        // Audio Enhancement
        if let aeReply = try await readChannelData(zone: zone, channel: channel, dataType: .audioEnhancement) {
            channelData.audioEnhancement = (aeReply.byteValue ?? 0) != 0
        }

        if debug {
            print("[CHANNEL] Zone \(zone) CH \(channel): \(channelData.name) " +
                  "\(channelData.channelTypeDisplay) RX:\(channelData.rxFrequencyMHz) " +
                  "TX:\(channelData.txFrequencyMHz) CC:\(channelData.colorCode) TS:\(channelData.timeSlot)")
        }

        return channelData
    }

    /// Reads all channels for a zone.
    /// - Parameters:
    ///   - zone: Zone index (0-based)
    ///   - channelCount: Number of channels in this zone
    ///   - progress: Optional progress callback (0.0 to 1.0)
    public func readZoneChannels(
        zone: UInt16,
        channelCount: Int,
        progress: ((Double) -> Void)? = nil,
        debug: Bool = false
    ) async throws -> [ChannelData] {
        var channels: [ChannelData] = []

        for i in 0..<channelCount {
            let channelData = try await readCompleteChannel(zone: zone, channel: UInt16(i), debug: debug)
            channels.append(channelData)
            progress?(Double(i + 1) / Double(channelCount))
        }

        return channels
    }

    // MARK: - Zone Name Reading

    /// Reads a zone name.
    public func readZoneName(zone: UInt16, debug: Bool = false) async throws -> String? {
        let request = XCMPPacket.cloneReadRequestZone(zone: zone, dataType: .zoneName)
        guard let reply = try await sendAndReceive(request, debug: debug) else { return nil }
        guard let parsed = CloneReadReply(from: reply.data) else { return nil }
        return parsed.stringValue
    }

    // MARK: - Contact Reading

    /// Reads contact data using CloneRead.
    public func readContactData(index: UInt16, dataType: ContactDataType, debug: Bool = false) async throws -> CloneReadReply? {
        let request = XCMPPacket.cloneReadContact(index: index, dataType: dataType)
        guard let reply = try await sendAndReceive(request, debug: debug) else { return nil }
        return CloneReadReply(from: reply.data)
    }

    /// Reads a complete contact's data.
    public func readCompleteContact(index: UInt16, debug: Bool = false) async throws -> ContactReadResult? {
        // Read name first to check if contact exists
        guard let nameReply = try await readContactData(index: index, dataType: .name, debug: debug),
              let name = nameReply.stringValue, !name.isEmpty else {
            return nil
        }

        var result = ContactReadResult(index: Int(index), name: name)

        // Call Type
        if let typeReply = try await readContactData(index: index, dataType: .callType, debug: debug) {
            result.callType = Int(typeReply.byteValue ?? 1)
        }

        // DMR ID (3 bytes)
        if let idReply = try await readContactData(index: index, dataType: .dmrID, debug: debug) {
            if idReply.data.count >= 3 {
                result.dmrID = UInt32(idReply.data[0]) << 16 | UInt32(idReply.data[1]) << 8 | UInt32(idReply.data[2])
            } else if let val = idReply.uint32Value {
                result.dmrID = val
            }
        }

        // Call Receive Tone
        if let toneReply = try await readContactData(index: index, dataType: .callReceiveTone, debug: debug) {
            result.callReceiveTone = (toneReply.byteValue ?? 0) != 0
        }

        // Call Alert
        if let alertReply = try await readContactData(index: index, dataType: .callAlert, debug: debug) {
            result.callAlert = (alertReply.byteValue ?? 0) != 0
        }

        if debug {
            print("[CONTACT] \(index): \(result.name) ID:\(result.dmrID) Type:\(result.callTypeDisplay)")
        }

        return result
    }

    // MARK: - Scan List Reading

    /// Reads scan list data using CloneRead.
    public func readScanListData(index: UInt16, dataType: ScanListDataType, debug: Bool = false) async throws -> CloneReadReply? {
        let request = XCMPPacket.cloneReadScanList(index: index, dataType: dataType)
        guard let reply = try await sendAndReceive(request, debug: debug) else { return nil }
        return CloneReadReply(from: reply.data)
    }

    /// Reads a complete scan list's data.
    public func readCompleteScanList(index: UInt16, debug: Bool = false) async throws -> ScanListReadResult? {
        // Read name first to check if scan list exists
        guard let nameReply = try await readScanListData(index: index, dataType: .name, debug: debug),
              let name = nameReply.stringValue, !name.isEmpty else {
            return nil
        }

        var result = ScanListReadResult(index: Int(index), name: name)

        // Talkback Enabled
        if let talkbackReply = try await readScanListData(index: index, dataType: .talkbackEnabled, debug: debug) {
            result.talkbackEnabled = (talkbackReply.byteValue ?? 1) != 0
        }

        // Hold Time
        if let holdReply = try await readScanListData(index: index, dataType: .holdTime, debug: debug) {
            result.holdTime = holdReply.uint16Value ?? 500
        }

        // Member count
        if let countReply = try await readScanListData(index: index, dataType: .memberCount, debug: debug) {
            result.memberCount = Int(countReply.byteValue ?? 0)
        }

        // Member list (zone/channel pairs)
        if let listReply = try await readScanListData(index: index, dataType: .memberList, debug: debug) {
            // Parse member list - format is typically pairs of zone/channel indices
            let data = listReply.data
            var members: [(zoneIndex: Int, channelIndex: Int)] = []
            var offset = 0
            while offset + 1 < data.count {
                let zoneIdx = Int(data[offset])
                let chanIdx = Int(data[offset + 1])
                if zoneIdx == 0xFF && chanIdx == 0xFF { break } // End marker
                members.append((zoneIdx, chanIdx))
                offset += 2
            }
            result.members = members
        }

        if debug {
            print("[SCANLIST] \(index): \(result.name) Members:\(result.memberCount)")
        }

        return result
    }

    // MARK: - RX Group List Reading

    /// Reads RX group list data using CloneRead.
    public func readRxGroupData(index: UInt16, dataType: RxGroupDataType, debug: Bool = false) async throws -> CloneReadReply? {
        let request = XCMPPacket.cloneReadRxGroup(index: index, dataType: dataType)
        guard let reply = try await sendAndReceive(request, debug: debug) else { return nil }
        return CloneReadReply(from: reply.data)
    }

    /// Reads a complete RX group list's data.
    public func readCompleteRxGroup(index: UInt16, debug: Bool = false) async throws -> RxGroupReadResult? {
        // Read name first to check if RX group exists
        guard let nameReply = try await readRxGroupData(index: index, dataType: .name, debug: debug),
              let name = nameReply.stringValue, !name.isEmpty else {
            return nil
        }

        var result = RxGroupReadResult(index: Int(index), name: name)

        // Member count
        if let countReply = try await readRxGroupData(index: index, dataType: .memberCount, debug: debug) {
            result.memberCount = Int(countReply.byteValue ?? 0)
        }

        // Member list (contact indices)
        if let listReply = try await readRxGroupData(index: index, dataType: .memberList, debug: debug) {
            // Parse member list - format is typically single-byte contact indices
            let data = listReply.data
            var members: [Int] = []
            for byte in data {
                if byte == 0xFF { break } // End marker
                members.append(Int(byte))
            }
            result.contactIndices = members
        }

        if debug {
            print("[RXGROUP] \(index): \(result.name) Members:\(result.memberCount)")
        }

        return result
    }

    // MARK: - Radio Setting Reading

    /// Reads a radio general setting.
    public func readRadioSetting(dataType: RadioSettingDataType, debug: Bool = false) async throws -> CloneReadReply? {
        let request = XCMPPacket.cloneReadRadioSetting(dataType: dataType)
        guard let reply = try await sendAndReceive(request, debug: debug) else { return nil }
        return CloneReadReply(from: reply.data)
    }

    /// Reads the radio ID (DMR ID).
    public func readRadioID(debug: Bool = false) async throws -> UInt32? {
        guard let reply = try await readRadioSetting(dataType: .radioID, debug: debug) else { return nil }
        if reply.data.count >= 3 {
            return UInt32(reply.data[0]) << 16 | UInt32(reply.data[1]) << 8 | UInt32(reply.data[2])
        }
        return reply.uint32Value
    }

    /// Reads the radio alias/name.
    public func readRadioAlias(debug: Bool = false) async throws -> String? {
        guard let reply = try await readRadioSetting(dataType: .radioAlias, debug: debug) else { return nil }
        return reply.stringValue
    }

    /// Reads the total contact count from radio settings.
    public func readContactCount(debug: Bool = false) async throws -> Int? {
        guard let reply = try await readRadioSetting(dataType: .contactCount, debug: debug) else { return nil }
        return Int(reply.byteValue ?? 0)
    }

    /// Reads the total scan list count from radio settings.
    public func readScanListCount(debug: Bool = false) async throws -> Int? {
        guard let reply = try await readRadioSetting(dataType: .scanListCount, debug: debug) else { return nil }
        return Int(reply.byteValue ?? 0)
    }

    /// Reads the total RX group count from radio settings.
    public func readRxGroupCount(debug: Bool = false) async throws -> Int? {
        guard let reply = try await readRadioSetting(dataType: .rxGroupCount, debug: debug) else { return nil }
        return Int(reply.byteValue ?? 0)
    }

    // MARK: - Comprehensive General Settings Reading

    /// Reads all general radio settings into a GeneralSettingsResult.
    public func readGeneralSettings(debug: Bool = false) async throws -> GeneralSettingsResult {
        var result = GeneralSettingsResult()

        // Identity settings
        if let reply = try await readRadioSetting(dataType: .radioID, debug: debug) {
            if reply.data.count >= 3 {
                result.radioID = UInt32(reply.data[0]) << 16 | UInt32(reply.data[1]) << 8 | UInt32(reply.data[2])
            }
        }
        if let reply = try await readRadioSetting(dataType: .radioAlias, debug: debug) {
            result.radioAlias = reply.stringValue ?? ""
        }
        if let reply = try await readRadioSetting(dataType: .introScreenLine1, debug: debug) {
            result.introLine1 = reply.stringValue ?? ""
        }
        if let reply = try await readRadioSetting(dataType: .introScreenLine2, debug: debug) {
            result.introLine2 = reply.stringValue ?? ""
        }

        // Audio settings
        if let reply = try await readRadioSetting(dataType: .voxEnabled, debug: debug) {
            result.voxEnabled = (reply.byteValue ?? 0) != 0
        }
        if let reply = try await readRadioSetting(dataType: .voxSensitivity, debug: debug) {
            result.voxSensitivity = reply.byteValue ?? 3
        }
        if let reply = try await readRadioSetting(dataType: .voxDelay, debug: debug) {
            result.voxDelay = reply.uint16Value ?? 500
        }
        if let reply = try await readRadioSetting(dataType: .keypadTones, debug: debug) {
            result.keypadTones = (reply.byteValue ?? 1) != 0
        }
        if let reply = try await readRadioSetting(dataType: .callAlertTone, debug: debug) {
            result.callAlertTone = (reply.byteValue ?? 1) != 0
        }
        if let reply = try await readRadioSetting(dataType: .powerUpTone, debug: debug) {
            result.powerUpTone = (reply.byteValue ?? 1) != 0
        }

        // Timing settings
        if let reply = try await readRadioSetting(dataType: .totTime, debug: debug) {
            result.totTime = reply.uint16Value ?? 60
        }
        if let reply = try await readRadioSetting(dataType: .groupCallHangTime, debug: debug) {
            result.groupCallHangTime = reply.uint16Value ?? 5000
        }
        if let reply = try await readRadioSetting(dataType: .privateCallHangTime, debug: debug) {
            result.privateCallHangTime = reply.uint16Value ?? 5000
        }

        // Display settings
        if let reply = try await readRadioSetting(dataType: .backlightTime, debug: debug) {
            result.backlightTime = reply.byteValue ?? 5
        }
        if let reply = try await readRadioSetting(dataType: .defaultPowerLevel, debug: debug) {
            result.defaultPowerHigh = (reply.byteValue ?? 1) != 0
        }

        // Signaling settings
        if let reply = try await readRadioSetting(dataType: .radioCheckEnabled, debug: debug) {
            result.radioCheckEnabled = (reply.byteValue ?? 1) != 0
        }
        if let reply = try await readRadioSetting(dataType: .remoteMonitorEnabled, debug: debug) {
            result.remoteMonitorEnabled = (reply.byteValue ?? 0) != 0
        }
        if let reply = try await readRadioSetting(dataType: .callConfirmation, debug: debug) {
            result.callConfirmation = (reply.byteValue ?? 1) != 0
        }

        // GPS settings
        if let reply = try await readRadioSetting(dataType: .gpsEnabled, debug: debug) {
            result.gpsEnabled = (reply.byteValue ?? 0) != 0
        }
        if let reply = try await readRadioSetting(dataType: .enhancedGNSS, debug: debug) {
            result.enhancedGNSS = (reply.byteValue ?? 0) != 0
        }

        // Lone Worker settings
        if let reply = try await readRadioSetting(dataType: .loneWorkerEnabled, debug: debug) {
            result.loneWorkerEnabled = (reply.byteValue ?? 0) != 0
        }
        if let reply = try await readRadioSetting(dataType: .loneWorkerResponseTime, debug: debug) {
            result.loneWorkerResponseTime = reply.uint16Value ?? 30
        }

        // Man Down settings
        if let reply = try await readRadioSetting(dataType: .manDownEnabled, debug: debug) {
            result.manDownEnabled = (reply.byteValue ?? 0) != 0
        }

        if debug {
            print("[SETTINGS] Radio ID: \(result.radioID)")
            print("[SETTINGS] Alias: \(result.radioAlias)")
            print("[SETTINGS] VOX: \(result.voxEnabled ? "On" : "Off")")
            print("[SETTINGS] TOT: \(result.totTime)s")
            print("[SETTINGS] GPS: \(result.gpsEnabled ? "On" : "Off")")
        }

        return result
    }
}

// MARK: - General Settings Read Result

/// Result from reading general radio settings.
public struct GeneralSettingsResult: Sendable {
    // Identity
    public var radioID: UInt32 = 1
    public var radioAlias: String = ""
    public var introLine1: String = ""
    public var introLine2: String = ""

    // Audio
    public var voxEnabled: Bool = false
    public var voxSensitivity: UInt8 = 3
    public var voxDelay: UInt16 = 500
    public var keypadTones: Bool = true
    public var callAlertTone: Bool = true
    public var powerUpTone: Bool = true

    // Timing
    public var totTime: UInt16 = 60
    public var totResetTime: UInt8 = 0
    public var groupCallHangTime: UInt16 = 5000
    public var privateCallHangTime: UInt16 = 5000

    // Display
    public var backlightTime: UInt8 = 5
    public var defaultPowerHigh: Bool = true

    // Signaling
    public var radioCheckEnabled: Bool = true
    public var remoteMonitorEnabled: Bool = false
    public var callConfirmation: Bool = true
    public var emergencyAlertType: UInt8 = 0
    public var emergencyDestinationID: UInt32 = 0

    // GPS
    public var gpsEnabled: Bool = false
    public var enhancedGNSS: Bool = false

    // Lone Worker
    public var loneWorkerEnabled: Bool = false
    public var loneWorkerResponseTime: UInt16 = 30
    public var loneWorkerReminderTime: UInt16 = 300

    // Man Down
    public var manDownEnabled: Bool = false
    public var manDownDelay: UInt16 = 10

    public init() {}
}

// MARK: - Contact Read Result

/// Result from reading a contact.
public struct ContactReadResult {
    public var index: Int
    public var name: String
    public var callType: Int = 1  // 0=Private, 1=Group, 2=All Call
    public var dmrID: UInt32 = 0
    public var callReceiveTone: Bool = true
    public var callAlert: Bool = false

    public var callTypeDisplay: String {
        switch callType {
        case 0: return "Private"
        case 1: return "Group"
        case 2: return "All Call"
        default: return "Unknown"
        }
    }

    public init(index: Int, name: String) {
        self.index = index
        self.name = name
    }
}

// MARK: - Scan List Read Result

/// Result from reading a scan list.
public struct ScanListReadResult {
    public var index: Int
    public var name: String
    public var memberCount: Int = 0
    public var members: [(zoneIndex: Int, channelIndex: Int)] = []
    public var talkbackEnabled: Bool = true
    public var holdTime: UInt16 = 500

    public init(index: Int, name: String) {
        self.index = index
        self.name = name
    }
}

// MARK: - RX Group Read Result

/// Result from reading an RX group list.
public struct RxGroupReadResult {
    public var index: Int
    public var name: String
    public var memberCount: Int = 0
    public var contactIndices: [Int] = []

    public init(index: Int, name: String) {
        self.index = index
        self.name = name
    }
}

// MARK: - Zone Query Results

/// Result from zone query (0x0037).
public struct ZoneQueryResult {
    public let zoneCount: Int
    public let maxZones: Int
    public let rawData: Data

    public init?(from data: Data) {
        guard data.count >= 3 else { return nil }
        // Response format varies, try to extract zone info
        // Typical: [result] [zone_count] [max_zones] ...
        if data[0] == 0x00 || data[0] == 0x01 {
            // Success
            self.zoneCount = data.count > 1 ? Int(data[1]) : 0
            self.maxZones = data.count > 2 ? Int(data[2]) : 250
        } else {
            // Error or different format
            self.zoneCount = 0
            self.maxZones = 250
        }
        self.rawData = data
    }
}

/// Result from zone details query.
public struct ZoneDetailsResult {
    public let zones: [(name: String, channelCount: Int)]
    public let rawData: Data

    public init?(from data: Data) {
        self.rawData = data
        let zones: [(String, Int)] = []
        // Parse zone details from response
        // Format is radio-specific, may need adjustment
        self.zones = zones
    }
}

// MARK: - Channel Data

/// Parsed channel data from CloneRead operations.
/// Contains all configurable settings for a channel.
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

