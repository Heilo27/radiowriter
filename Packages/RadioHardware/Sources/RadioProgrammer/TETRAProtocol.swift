import Foundation

// MARK: - TETRA RP Protocol

/// TETRA Radio Programming (RP) protocol commands.
/// Used for TETRA radios (MTP, MTM series).
public enum TETRAOpcode: UInt8, Sendable {
    /// Radio status notification (Radio → CPS)
    case statusIndication = 0x00
    /// Request parameter version (CPS → Radio)
    case parameterVersionRequest = 0x01
    /// Confirm version report (Radio → CPS)
    case parameterVersionConfirm = 0x02
    /// Request radio reset (CPS → Radio)
    case resetRequest = 0x03
    /// Version report response (Radio → CPS)
    case parameterVersionReply = 0x04
    /// Command rejected (Radio → CPS)
    case rejectIndication = 0x05
    /// Request terminal ID (CPS → Radio)
    case terminalIDRequest = 0x06
    /// Terminal ID response (Radio → CPS)
    case terminalIDConfirm = 0x07
}

/// TETRA reset modes for the reset request command.
public enum TETRAResetMode: UInt8, Sendable {
    /// Normal operation mode
    case normal = 0x00
    /// Charging mode
    case charging = 0x01
    /// Programming mode
    case programming = 0x02
    /// RP protocol mode
    case rpMode = 0x03
}

/// TETRA SBEP (Subscriber Boot Execution Protocol) status codes.
public enum SBEPStatus: UInt8, Sendable {
    /// Command acknowledged
    case ack = 0x50
    /// Command not acknowledged
    case nack = 0x60
    /// Undefined status
    case undefined = 0x70
}

/// TETRA SBEP flags.
public struct SBEPFlags: OptionSet, Sendable {
    public let rawValue: UInt32
    public init(rawValue: UInt32) { self.rawValue = rawValue }

    /// No special flags
    public static let none = SBEPFlags([])
    /// A4S2 mode flag
    public static let a4s2 = SBEPFlags(rawValue: 0x00000001)
    /// Read with zero length
    public static let readLengthZero = SBEPFlags(rawValue: 0x00000002)
}

// MARK: - TETRA Data Transfer Opcodes (16-bit)

/// TETRA data transfer protocol opcodes.
public enum TETRADataOpcode: UInt16, Sendable {
    // Read operations
    case readDataRequest = 0xF511
    case readDataReply = 0xFF80
    case extendedReadRequest = 0xF741
    case extendedReadReply = 0xFFB0

    // Write operations
    case writeDataRequest = 0xFF17
    case extendedWriteRequest = 0xFF47
    case goodWriteReply = 0xF484
    case badWriteReply = 0xF485
    case extendedGoodWriteReply = 0xF5B4
    case extendedBadWriteReply = 0xF5B5

    // Utility operations
    case checksumRequest = 0xF612
    case checksumReply = 0xF381
    case extendedChecksumRequest = 0xF942
    case extendedChecksumReply = 0xF3B1
    case statusRequest = 0xF114
    case statusReply = 0xF583
    case extendedStatusRequest = 0xF144
    case extendedStatusReply = 0xF6B3
    case configurationRequest = 0xF113
    case configurationReply = 0xF482
    case unsupportedOpcodeReply = 0xF186
}

/// TETRA write status codes from the SM layer.
public enum TETRAWriteStatus: UInt8, Sendable {
    /// Write succeeded
    case good = 0x01
    /// Write failed
    case bad = 0x02
    /// Write status undefined
    case undefined = 0x03
}

// MARK: - TETRA Compression

/// TETRA compression algorithms.
public enum TETRACompression: UInt8, Sendable {
    /// No compression
    case none = 0x00
    /// LZRW3 algorithm
    case lzrw3 = 0x01
    /// FastLZ algorithm
    case fastlz = 0x02
    /// LZRW3A variant
    case lzrw3a = 0xFF
}

// MARK: - TETRA FDT (Flash Data Table)

/// TETRA FDT record types (magic numbers).
public enum TETRAFDTType: UInt32, Sendable {
    /// FDT record marker
    case fdtr = 0x46445452  // "FDTR"
    /// FDT radio parameters
    case ftrp = 0x46545250  // "FTRP"
    /// FDT firmware
    case fmwr = 0x464D5752  // "FMWR"
    /// Codeplug data
    case cplg = 0x43504C47  // "CPLG"
    /// Flash pack
    case fspk = 0x4653504B  // "FSPK"
    /// Encryption keys
    case keys = 0x4B455953  // "KEYS"
    /// Log data
    case logd = 0x4C4F4744  // "LOGD"
    /// Release info
    case reli = 0x52454C49  // "RELI"
}

/// TETRA FDT state values.
public enum TETRAFDTState: UInt32, Sendable {
    /// FDT ready for operations
    case ready = 0x00000000
}

// MARK: - TETRA Message Framing

/// TETRA message types for framing.
public enum TETRAMessageType: UInt8, Sendable {
    /// RP protocol message
    case rp = 0x00
    /// SBEP protocol message
    case sbep = 0x01
    /// AT command message
    case at = 0x02
}

/// TETRA AT command special characters.
public struct TETRAATCharacters {
    public static let cr: UInt8 = 0x0D       // Carriage return
    public static let lf: UInt8 = 0x0A       // Line feed
    public static let escape: UInt8 = 0x1B   // Escape
    public static let backspace: UInt8 = 0x08 // Backspace
    public static let space: UInt8 = 0x20    // Space
}

// MARK: - TETRA Message Builder

/// Builder for TETRA protocol messages.
public struct TETRAMessage: Sendable {

    /// Builds an RP protocol message.
    /// Format: [Length: 2 bytes] [Type: 1 byte] [Command: 1 byte] [Payload] [Checksum: 2 bytes]
    public static func rpMessage(command: TETRAOpcode, payload: Data = Data()) -> Data {
        var message = Data()

        // Payload length includes type + command + payload + checksum
        let payloadLength = UInt16(1 + 1 + payload.count + 2)
        message.append(UInt8(payloadLength >> 8))
        message.append(UInt8(payloadLength & 0xFF))

        // Message type (RP)
        message.append(TETRAMessageType.rp.rawValue)

        // RP command
        message.append(command.rawValue)

        // Payload
        message.append(payload)

        // Calculate and append checksum
        let checksum = calculateChecksum(Data(message.dropFirst(2)))  // Checksum excludes length bytes
        message.append(UInt8(checksum >> 8))
        message.append(UInt8(checksum & 0xFF))

        return message
    }

    /// Builds a data transfer message (read/write).
    /// Format: [Length: 2 bytes] [Opcode: 2 bytes] [Address: 4 bytes] [DataLength: 2 bytes] [Data?] [Checksum: 2 bytes]
    public static func dataMessage(opcode: TETRADataOpcode, address: UInt32, length: UInt16, data: Data? = nil) -> Data {
        var message = Data()

        // Calculate payload length
        var payloadLength = 2 + 4 + 2 + 2  // opcode + address + length + checksum
        if let data = data {
            payloadLength += data.count
        }

        // Length prefix
        message.append(UInt8(payloadLength >> 8))
        message.append(UInt8(payloadLength & 0xFF))

        // Opcode (big-endian)
        message.append(UInt8(opcode.rawValue >> 8))
        message.append(UInt8(opcode.rawValue & 0xFF))

        // Address (little-endian as per protocol)
        message.append(UInt8(address & 0xFF))
        message.append(UInt8((address >> 8) & 0xFF))
        message.append(UInt8((address >> 16) & 0xFF))
        message.append(UInt8((address >> 24) & 0xFF))

        // Length (little-endian)
        message.append(UInt8(length & 0xFF))
        message.append(UInt8(length >> 8))

        // Data (if writing)
        if let data = data {
            message.append(data)
        }

        // Calculate and append checksum
        let checksum = calculateChecksum(Data(message.dropFirst(2)))
        message.append(UInt8(checksum >> 8))
        message.append(UInt8(checksum & 0xFF))

        return message
    }

    /// Builds a Terminal ID request message.
    public static func terminalIDRequest() -> Data {
        return rpMessage(command: .terminalIDRequest)
    }

    /// Builds a Version Report request message.
    public static func versionReportRequest() -> Data {
        return rpMessage(command: .parameterVersionRequest)
    }

    /// Builds a Reset request message.
    public static func resetRequest(mode: TETRAResetMode) -> Data {
        return rpMessage(command: .resetRequest, payload: Data([mode.rawValue]))
    }

    /// Builds a Read Data request message.
    public static func readRequest(address: UInt32, length: UInt16, extended: Bool = false) -> Data {
        let opcode: TETRADataOpcode = extended ? .extendedReadRequest : .readDataRequest
        return dataMessage(opcode: opcode, address: address, length: length)
    }

    /// Builds a Write Data request message.
    public static func writeRequest(address: UInt32, data: Data, extended: Bool = false) -> Data {
        let opcode: TETRADataOpcode = extended ? .extendedWriteRequest : .writeDataRequest
        return dataMessage(opcode: opcode, address: address, length: UInt16(data.count), data: data)
    }

    /// Builds a Checksum request message.
    public static func checksumRequest(address: UInt32, length: UInt16, extended: Bool = false) -> Data {
        let opcode: TETRADataOpcode = extended ? .extendedChecksumRequest : .checksumRequest
        return dataMessage(opcode: opcode, address: address, length: length)
    }

    /// Builds a Status request message.
    public static func statusRequest(extended: Bool = false) -> Data {
        let opcode: TETRADataOpcode = extended ? .extendedStatusRequest : .statusRequest
        // Status request doesn't need address/length
        var message = Data()
        let payloadLength: UInt16 = 4  // opcode + checksum
        message.append(UInt8(payloadLength >> 8))
        message.append(UInt8(payloadLength & 0xFF))
        message.append(UInt8(opcode.rawValue >> 8))
        message.append(UInt8(opcode.rawValue & 0xFF))
        let checksum = calculateChecksum(Data(message.dropFirst(2)))
        message.append(UInt8(checksum >> 8))
        message.append(UInt8(checksum & 0xFF))
        return message
    }

    /// Builds a Configuration request message.
    public static func configurationRequest() -> Data {
        var message = Data()
        let payloadLength: UInt16 = 4  // opcode + checksum
        message.append(UInt8(payloadLength >> 8))
        message.append(UInt8(payloadLength & 0xFF))
        let opcode = TETRADataOpcode.configurationRequest
        message.append(UInt8(opcode.rawValue >> 8))
        message.append(UInt8(opcode.rawValue & 0xFF))
        let checksum = calculateChecksum(Data(message.dropFirst(2)))
        message.append(UInt8(checksum >> 8))
        message.append(UInt8(checksum & 0xFF))
        return message
    }

    /// Calculates the TETRA checksum (16-bit XOR complement).
    public static func calculateChecksum(_ data: Data) -> UInt16 {
        var sum: UInt16 = 0
        for byte in data {
            sum = (sum &+ UInt16(byte)) & 0xFFFF
        }
        return sum ^ 0xFFFF
    }

    /// Validates the checksum of a received message.
    public static func validateChecksum(_ message: Data) -> Bool {
        guard message.count >= 4 else { return false }

        // Extract message body (without length prefix and checksum)
        let bodyEnd = message.count - 2
        let body = Data(message[2..<bodyEnd])

        // Extract received checksum
        let receivedChecksum = UInt16(message[bodyEnd]) << 8 | UInt16(message[bodyEnd + 1])

        // Calculate expected checksum
        let expectedChecksum = calculateChecksum(body)

        return receivedChecksum == expectedChecksum
    }
}

// MARK: - TETRA Response Parser

/// Parser for TETRA protocol responses.
public struct TETRAResponse: Sendable {
    public let opcode: UInt16
    public let payload: Data
    public let isValid: Bool

    /// Parses an RP protocol response.
    public static func parseRP(_ data: Data) -> TETRAResponse? {
        guard data.count >= 6 else { return nil }  // min: length(2) + type(1) + command(1) + checksum(2)

        let isValid = TETRAMessage.validateChecksum(data)
        let messageType = data[2]

        guard messageType == TETRAMessageType.rp.rawValue else { return nil }

        let command = data[3]
        let payloadEnd = data.count - 2
        let payload = data.count > 6 ? Data(data[4..<payloadEnd]) : Data()

        return TETRAResponse(opcode: UInt16(command), payload: payload, isValid: isValid)
    }

    /// Parses a data transfer response.
    public static func parseData(_ data: Data) -> TETRAResponse? {
        guard data.count >= 6 else { return nil }  // min: length(2) + opcode(2) + checksum(2)

        let isValid = TETRAMessage.validateChecksum(data)
        let opcode = UInt16(data[2]) << 8 | UInt16(data[3])

        let payloadEnd = data.count - 2
        let payload = data.count > 6 ? Data(data[4..<payloadEnd]) : Data()

        return TETRAResponse(opcode: opcode, payload: payload, isValid: isValid)
    }

    /// Checks if this is a successful write response.
    public var isWriteSuccess: Bool {
        return opcode == TETRADataOpcode.goodWriteReply.rawValue ||
               opcode == TETRADataOpcode.extendedGoodWriteReply.rawValue
    }

    /// Checks if this is a failed write response.
    public var isWriteFailure: Bool {
        return opcode == TETRADataOpcode.badWriteReply.rawValue ||
               opcode == TETRADataOpcode.extendedBadWriteReply.rawValue
    }

    /// Checks if this is an unsupported opcode response.
    public var isUnsupportedOpcode: Bool {
        return opcode == TETRADataOpcode.unsupportedOpcodeReply.rawValue
    }

    /// Checks if this is a read data response.
    public var isReadResponse: Bool {
        return opcode == TETRADataOpcode.readDataReply.rawValue ||
               opcode == TETRADataOpcode.extendedReadReply.rawValue
    }

    /// Checks if this is a checksum response.
    public var isChecksumResponse: Bool {
        return opcode == TETRADataOpcode.checksumReply.rawValue ||
               opcode == TETRADataOpcode.extendedChecksumReply.rawValue
    }
}

// MARK: - TETRA Errors

/// Errors specific to TETRA protocol communication.
public enum TETRAError: Error, LocalizedError {
    case connectionFailed(String)
    case authenticationFailed(String)
    case commandRejected(reason: String)
    case checksumMismatch
    case unsupportedOpcode
    case writeFailure(address: UInt32)
    case readFailure(address: UInt32)
    case timeout
    case invalidResponse
    case notImplemented(String)
    case badBattery
    case programmingModeRequired

    public var errorDescription: String? {
        switch self {
        case .connectionFailed(let msg): return "TETRA connection failed: \(msg)"
        case .authenticationFailed(let msg): return "TETRA authentication failed: \(msg)"
        case .commandRejected(let reason): return "TETRA command rejected: \(reason)"
        case .checksumMismatch: return "TETRA checksum mismatch"
        case .unsupportedOpcode: return "TETRA opcode not supported by radio"
        case .writeFailure(let addr): return "TETRA write failed at address 0x\(String(format: "%08X", addr))"
        case .readFailure(let addr): return "TETRA read failed at address 0x\(String(format: "%08X", addr))"
        case .timeout: return "TETRA communication timeout"
        case .invalidResponse: return "TETRA invalid response format"
        case .notImplemented(let msg): return "TETRA not implemented: \(msg)"
        case .badBattery: return "TETRA radio battery voltage too low for programming"
        case .programmingModeRequired: return "TETRA radio must be in programming mode"
        }
    }
}
