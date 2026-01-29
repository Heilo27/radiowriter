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

    /// Creates a CloneReadRequest packet.
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
}

