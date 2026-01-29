import Foundation

// MARK: - XCMP OpCodes

/// XCMP protocol operation codes for MOTOTRBO radios.
/// Request codes have the high bit clear, reply codes have 0x8000 OR'd.
public enum XCMPOpCode: UInt16 {
    // Status and Info
    case radioStatusRequest = 0x000E
    case radioStatusReply = 0x800E
    case versionInfoRequest = 0x000F
    case versionInfoReply = 0x800F

    // CPS Operations
    case cpsUnlockRequest = 0x0100       // Unlock for codeplug access
    case cpsUnlockReply = 0x8100
    case cpsReadRequest = 0x0104         // Read codeplug data
    case cpsReadReply = 0x8104
    case cpsWriteRequest = 0x0105        // Write codeplug data (assumed)
    case cpsWriteReply = 0x8105

    // Clone Operations
    case cloneReadRequest = 0x010A
    case cloneReadReply = 0x810A

    // Device Management
    case deviceInitStatusBroadcast = 0xB400
    case tanapaNumberRequest = 0x001F
    case tanapaNumberReply = 0x801F

    // Channel/Zone Selection
    case channelSelectRequest = 0x040D
    case channelSelectReply = 0x840D

    // Power Control
    case radioPowerRequest = 0x040A
    case radioPowerReply = 0x840A

    // Alarm
    case alarmStatusRequest = 0x042E
    case alarmStatusReply = 0x842E

    /// Returns the expected reply opcode for a request.
    public var replyOpCode: XCMPOpCode? {
        XCMPOpCode(rawValue: rawValue | 0x8000)
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
    /// General radio setting (index is setting ID)
    case radioSetting = 0x0000
}

/// Data types for CloneReadRequest that specify what data to retrieve.
/// These are used with the zone/channel clone read format.
public enum CloneDataType: UInt8 {
    /// Channel name (returns UTF-16 BE string)
    case channelName = 0x0F
    /// Channel alias/display name
    case channelAlias = 0x10
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

    // MARK: - Factory Methods

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
    public func sendAndReceive(_ packet: XCMPPacket, timeout: TimeInterval = 5.0) async throws -> XCMPPacket? {
        let xcmpData = packet.encode()
        guard let responseData = try await xnlConnection.sendXCMP(xcmpData, timeout: timeout) else {
            return nil
        }
        return XCMPPacket.decode(responseData)
    }

    /// Gets the radio model number.
    public func getModelNumber() async throws -> String? {
        let request = XCMPPacket.radioStatusRequest(.modelNumber)
        guard let reply = try await sendAndReceive(request) else { return nil }
        return String(data: reply.data.dropFirst(), encoding: .utf8)?.trimmingCharacters(in: .controlCharacters)
    }

    /// Gets the radio serial number.
    public func getSerialNumber() async throws -> String? {
        let request = XCMPPacket.radioStatusRequest(.serialNumber)
        guard let reply = try await sendAndReceive(request) else { return nil }
        return String(data: reply.data.dropFirst(), encoding: .utf8)?.trimmingCharacters(in: .controlCharacters)
    }

    /// Gets the radio ID.
    public func getRadioID() async throws -> UInt32? {
        let request = XCMPPacket.radioStatusRequest(.radioID)
        guard let reply = try await sendAndReceive(request) else { return nil }
        // Skip error code byte, then read 3-byte radio ID
        guard reply.data.count >= 4 else { return nil }
        return UInt32(reply.data[1]) << 16 | UInt32(reply.data[2]) << 8 | UInt32(reply.data[3])
    }

    /// Gets firmware version.
    public func getFirmwareVersion() async throws -> String? {
        let request = XCMPPacket.versionInfoRequest(.firmware)
        guard let reply = try await sendAndReceive(request) else { return nil }
        // Skip error code and version type bytes
        guard reply.data.count > 2 else { return nil }
        return String(data: reply.data.dropFirst(2), encoding: .utf8)?.trimmingCharacters(in: .controlCharacters)
    }

    /// Gets full radio identification.
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
}

