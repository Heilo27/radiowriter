import Foundation

/// Unpacks binary data from a radio into typed field values.
public struct BinaryUnpacker: Sendable {
    private let data: Data
    private var bitPosition: Int

    public init(data: Data) {
        self.data = data
        self.bitPosition = 0
    }

    /// The underlying data.
    public var rawData: Data { data }

    /// Current bit position.
    public var position: Int { bitPosition }

    /// Total number of bits available.
    public var totalBits: Int { data.count * 8 }

    /// Whether there are more bits to read.
    public var hasMore: Bool { bitPosition < totalBits }

    // MARK: - Bit-Level Operations

    /// Sets the read position to a specific bit offset.
    public mutating func seek(toBit offset: Int) {
        bitPosition = offset
    }

    /// Sets the read position to a specific byte offset.
    public mutating func seek(toByte offset: Int) {
        bitPosition = offset * 8
    }

    /// Reads a single bit and advances the position.
    public mutating func readBit() -> Bool {
        let byteIndex = bitPosition / 8
        let bitIndex = 7 - (bitPosition % 8)
        guard byteIndex < data.count else { return false }
        bitPosition += 1
        return (data[byteIndex] >> bitIndex) & 1 == 1
    }

    /// Reads multiple bits as a UInt32.
    public mutating func readBits(count: Int) -> UInt32 {
        var result: UInt32 = 0
        for _ in 0..<count {
            result = (result << 1) | (readBit() ? 1 : 0)
        }
        return result
    }

    // MARK: - Byte-Level Operations

    /// Reads a UInt8 at the current position.
    public mutating func readUInt8() -> UInt8 {
        if bitPosition % 8 == 0 {
            let byteIndex = bitPosition / 8
            guard byteIndex < data.count else { return 0 }
            bitPosition += 8
            return data[byteIndex]
        }
        return UInt8(truncatingIfNeeded: readBits(count: 8))
    }

    /// Reads a UInt16 in little-endian format.
    public mutating func readUInt16LE() -> UInt16 {
        let low = UInt16(readUInt8())
        let high = UInt16(readUInt8())
        return (high << 8) | low
    }

    /// Reads a UInt16 in big-endian format.
    public mutating func readUInt16BE() -> UInt16 {
        let high = UInt16(readUInt8())
        let low = UInt16(readUInt8())
        return (high << 8) | low
    }

    /// Reads a UInt32 in little-endian format.
    public mutating func readUInt32LE() -> UInt32 {
        let b0 = UInt32(readUInt8())
        let b1 = UInt32(readUInt8())
        let b2 = UInt32(readUInt8())
        let b3 = UInt32(readUInt8())
        return b0 | (b1 << 8) | (b2 << 16) | (b3 << 24)
    }

    /// Reads a UInt32 in big-endian format.
    public mutating func readUInt32BE() -> UInt32 {
        let b3 = UInt32(readUInt8())
        let b2 = UInt32(readUInt8())
        let b1 = UInt32(readUInt8())
        let b0 = UInt32(readUInt8())
        return b0 | (b1 << 8) | (b2 << 16) | (b3 << 24)
    }

    /// Reads raw bytes.
    public mutating func readBytes(count: Int) -> Data {
        var result = Data(capacity: count)
        for _ in 0..<count {
            result.append(readUInt8())
        }
        return result
    }

    /// Reads a null-terminated string with a fixed buffer length.
    public mutating func readString(fixedLength: Int, encoding: String.Encoding = .utf8) -> String {
        let bytes = readBytes(count: fixedLength)
        let trimmed = bytes.prefix(while: { $0 != 0 })
        return String(data: Data(trimmed), encoding: encoding) ?? ""
    }

    /// Reads a field value based on its definition.
    public mutating func readField(definition: FieldDefinition) -> FieldValue {
        seek(toBit: definition.bitOffset)
        switch definition.valueType {
        case .uint8:
            if definition.bitLength == 8 && bitPosition % 8 == 0 {
                return .uint8(readUInt8())
            }
            return .uint8(UInt8(truncatingIfNeeded: readBits(count: definition.bitLength)))
        case .uint16:
            return .uint16(UInt16(truncatingIfNeeded: readBits(count: definition.bitLength)))
        case .uint32:
            return .uint32(readBits(count: definition.bitLength))
        case .int8:
            let raw = UInt8(truncatingIfNeeded: readBits(count: definition.bitLength))
            return .int8(Int8(bitPattern: raw))
        case .int16:
            let raw = UInt16(truncatingIfNeeded: readBits(count: definition.bitLength))
            return .int16(Int16(bitPattern: raw))
        case .int32:
            let raw = readBits(count: definition.bitLength)
            return .int32(Int32(bitPattern: raw))
        case .bool:
            return .bool(readBit())
        case .string(let maxLength, let encoding):
            return .string(readString(fixedLength: maxLength, encoding: encoding))
        case .bytes(let count):
            return .bytes(readBytes(count: count))
        case .enumeration:
            return .enumValue(UInt16(truncatingIfNeeded: readBits(count: definition.bitLength)))
        case .bitField(let bitCount):
            return .bitField(readBits(count: bitCount), bitCount: bitCount)
        }
    }
}
