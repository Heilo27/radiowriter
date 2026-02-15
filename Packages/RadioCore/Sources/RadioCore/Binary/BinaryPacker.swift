import Foundation

/// Packs field values into a binary data buffer for radio programming.
public struct BinaryPacker: Sendable {
    private var data: Data
    private var bitPosition: Int

    public init(size: Int) {
        self.data = Data(count: size)
        self.bitPosition = 0
    }

    public init(data: Data) {
        self.data = data
        self.bitPosition = 0
    }

    /// The packed binary data.
    public var result: Data { data }

    /// Current bit position in the buffer.
    public var position: Int { bitPosition }

    // MARK: - Bit-Level Operations

    /// Sets the write position to a specific bit offset.
    public mutating func seek(toBit offset: Int) {
        bitPosition = offset
    }

    /// Sets the write position to a specific byte offset.
    public mutating func seek(toByte offset: Int) {
        bitPosition = offset * 8
    }

    /// Writes a single bit at the current position and advances.
    public mutating func writeBit(_ value: Bool) {
        let byteIndex = bitPosition / 8
        let bitIndex = 7 - (bitPosition % 8)
        guard byteIndex < data.count else { return }
        if value {
            data[byteIndex] |= (1 << bitIndex)
        } else {
            data[byteIndex] &= ~(1 << bitIndex)
        }
        bitPosition += 1
    }

    /// Writes multiple bits from a UInt32 value.
    public mutating func writeBits(_ value: UInt32, count: Int) {
        for i in 0..<count {
            let bit = (value >> (count - 1 - i)) & 1 == 1
            writeBit(bit)
        }
    }

    // MARK: - Byte-Level Operations

    /// Writes a UInt8 at the current byte-aligned position.
    public mutating func writeUInt8(_ value: UInt8) {
        if bitPosition % 8 == 0 {
            let byteIndex = bitPosition / 8
            guard byteIndex < data.count else { return }
            data[byteIndex] = value
            bitPosition += 8
        } else {
            writeBits(UInt32(value), count: 8)
        }
    }

    /// Writes a UInt16 in little-endian format.
    public mutating func writeUInt16LE(_ value: UInt16) {
        writeUInt8(UInt8(value & 0xFF))
        writeUInt8(UInt8(value >> 8))
    }

    /// Writes a UInt16 in big-endian format.
    public mutating func writeUInt16BE(_ value: UInt16) {
        writeUInt8(UInt8(value >> 8))
        writeUInt8(UInt8(value & 0xFF))
    }

    /// Writes a UInt32 in little-endian format.
    public mutating func writeUInt32LE(_ value: UInt32) {
        writeUInt8(UInt8(value & 0xFF))
        writeUInt8(UInt8((value >> 8) & 0xFF))
        writeUInt8(UInt8((value >> 16) & 0xFF))
        writeUInt8(UInt8(value >> 24))
    }

    /// Writes a UInt32 in big-endian format.
    public mutating func writeUInt32BE(_ value: UInt32) {
        writeUInt8(UInt8(value >> 24))
        writeUInt8(UInt8((value >> 16) & 0xFF))
        writeUInt8(UInt8((value >> 8) & 0xFF))
        writeUInt8(UInt8(value & 0xFF))
    }

    /// Writes raw bytes at the current position.
    public mutating func writeBytes(_ bytes: Data) {
        for byte in bytes {
            writeUInt8(byte)
        }
    }

    /// Writes a null-padded string.
    public mutating func writeString(_ string: String, fixedLength: Int, encoding: String.Encoding = .utf8) {
        var encoded = string.data(using: encoding) ?? Data()
        if encoded.count > fixedLength {
            encoded = encoded.prefix(fixedLength)
        }
        writeBytes(encoded)
        // Pad with zeros
        let padding = fixedLength - encoded.count
        if padding > 0 {
            writeBytes(Data(count: padding))
        }
    }

    /// Writes a field value at a specific bit offset.
    public mutating func writeField(_ value: FieldValue, definition: FieldDefinition) {
        seek(toBit: definition.bitOffset)
        switch value {
        case .uint8(let uint8Value):
            if definition.bitLength == 8 && bitPosition % 8 == 0 {
                writeUInt8(uint8Value)
            } else {
                writeBits(UInt32(uint8Value), count: definition.bitLength)
            }
        case .uint16(let uint16Value):
            writeBits(UInt32(uint16Value), count: definition.bitLength)
        case .uint32(let uint32Value):
            writeBits(uint32Value, count: definition.bitLength)
        case .int8(let int8Value):
            writeBits(UInt32(UInt8(bitPattern: int8Value)), count: definition.bitLength)
        case .int16(let int16Value):
            writeBits(UInt32(UInt16(bitPattern: int16Value)), count: definition.bitLength)
        case .int32(let int32Value):
            writeBits(UInt32(bitPattern: int32Value), count: definition.bitLength)
        case .bool(let boolValue):
            writeBit(boolValue)
        case .string(let stringValue):
            if case .string(let maxLen, let enc) = definition.valueType {
                writeString(stringValue, fixedLength: maxLen, encoding: enc)
            }
        case .bytes(let dataBytes):
            writeBytes(dataBytes)
        case .enumValue(let enumValue):
            writeBits(UInt32(enumValue), count: definition.bitLength)
        case .bitField(let bitValue, _):
            writeBits(bitValue, count: definition.bitLength)
        }
    }
}
