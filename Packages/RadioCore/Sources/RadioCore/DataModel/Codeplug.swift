import Foundation

/// The central data structure representing a radio's complete configuration.
/// A codeplug contains the raw binary data and provides typed access to individual fields
/// based on the radio model's field definitions.
@Observable
public final class Codeplug: Identifiable, @unchecked Sendable {
    public let id: UUID
    public let modelIdentifier: String
    public var rawData: Data
    public private(set) var metadata: CodeplugMetadata
    private var modifiedFields: Set<String> = []

    public init(modelIdentifier: String, rawData: Data, metadata: CodeplugMetadata? = nil) {
        self.id = UUID()
        self.modelIdentifier = modelIdentifier
        self.rawData = rawData
        self.metadata = metadata ?? CodeplugMetadata()
    }

    /// Creates an empty codeplug with the given size.
    public convenience init(modelIdentifier: String, size: Int) {
        self.init(modelIdentifier: modelIdentifier, rawData: Data(count: size))
    }

    // MARK: - Field Access

    /// Gets the value of a field.
    public func getValue(for field: FieldDefinition) -> FieldValue {
        switch field.valueType {
        case .uint8:
            return .uint8(getByte(at: field.bitOffset))
        case .uint16:
            return .uint16(getUInt16(at: field.bitOffset, bitLength: field.bitLength))
        case .uint32:
            return .uint32(getUInt32(at: field.bitOffset, bitLength: field.bitLength))
        case .int8:
            return .int8(Int8(bitPattern: getByte(at: field.bitOffset)))
        case .int16:
            let raw = getUInt16(at: field.bitOffset, bitLength: field.bitLength)
            return .int16(Int16(bitPattern: raw))
        case .int32:
            let raw = getUInt32(at: field.bitOffset, bitLength: field.bitLength)
            return .int32(Int32(bitPattern: raw))
        case .bool:
            return .bool(getBit(at: field.bitOffset))
        case .string(let maxLength, let encoding):
            return .string(getString(at: field.byteOffset, maxLength: maxLength, encoding: encoding))
        case .bytes(let count):
            return .bytes(getBytes(at: field.byteOffset, count: count))
        case .enumeration:
            return .enumValue(getUInt16(at: field.bitOffset, bitLength: field.bitLength))
        case .bitField(let bitCount):
            return .bitField(getUInt32(at: field.bitOffset, bitLength: bitCount), bitCount: bitCount)
        }
    }

    /// Sets the value of a field. Returns validation result.
    @discardableResult
    public func setValue(_ value: FieldValue, for field: FieldDefinition) -> ConstraintResult {
        if let constraint = field.constraint {
            let result = constraint.validate(value)
            if !result.isValid { return result }
        }

        switch (field.valueType, value) {
        case (.uint8, .uint8(let byteValue)):
            setByte(byteValue, at: field.bitOffset)
        case (.uint16, .uint16(let uint16Value)):
            setUInt16(uint16Value, at: field.bitOffset, bitLength: field.bitLength)
        case (.uint32, .uint32(let uint32Value)):
            setUInt32(uint32Value, at: field.bitOffset, bitLength: field.bitLength)
        case (.int8, .int8(let int8Value)):
            setByte(UInt8(bitPattern: int8Value), at: field.bitOffset)
        case (.int16, .int16(let int16Value)):
            setUInt16(UInt16(bitPattern: int16Value), at: field.bitOffset, bitLength: field.bitLength)
        case (.int32, .int32(let int32Value)):
            setUInt32(UInt32(bitPattern: int32Value), at: field.bitOffset, bitLength: field.bitLength)
        case (.bool, .bool(let boolValue)):
            setBit(boolValue, at: field.bitOffset)
        case (.string(let maxLength, let encoding), .string(let stringValue)):
            setString(stringValue, at: field.byteOffset, maxLength: maxLength, encoding: encoding)
        case (.bytes, .bytes(let dataBytes)):
            setBytes(dataBytes, at: field.byteOffset)
        case (.enumeration, .enumValue(let enumValue)):
            setUInt16(enumValue, at: field.bitOffset, bitLength: field.bitLength)
        case (.bitField, .bitField(let bitValue, _)):
            setUInt32(bitValue, at: field.bitOffset, bitLength: field.bitLength)
        default:
            return .invalid("Type mismatch: cannot set \(value) for field type \(field.valueType)")
        }

        modifiedFields.insert(field.id)
        metadata.lastModified = Date()
        return .valid
    }

    /// Whether a field has been modified from its original value.
    public func isModified(_ fieldID: String) -> Bool {
        modifiedFields.contains(fieldID)
    }

    /// Whether the codeplug has any unsaved changes.
    public var hasUnsavedChanges: Bool {
        !modifiedFields.isEmpty
    }

    /// Clears all modification tracking (e.g., after save).
    public func clearModifications() {
        modifiedFields.removeAll()
    }

    // MARK: - Bit-Level Access

    private func getBit(at bitOffset: Int) -> Bool {
        let byteIndex = bitOffset / 8
        let bitIndex = 7 - (bitOffset % 8)
        guard byteIndex < rawData.count else { return false }
        return (rawData[byteIndex] >> bitIndex) & 1 == 1
    }

    private func setBit(_ value: Bool, at bitOffset: Int) {
        let byteIndex = bitOffset / 8
        let bitIndex = 7 - (bitOffset % 8)
        guard byteIndex < rawData.count else { return }
        if value {
            rawData[byteIndex] |= (1 << bitIndex)
        } else {
            rawData[byteIndex] &= ~(1 << bitIndex)
        }
    }

    private func getByte(at bitOffset: Int) -> UInt8 {
        let byteIndex = bitOffset / 8
        guard byteIndex < rawData.count else { return 0 }
        if bitOffset % 8 == 0 {
            return rawData[byteIndex]
        }
        return UInt8(truncatingIfNeeded: getUInt32(at: bitOffset, bitLength: 8))
    }

    private func setByte(_ value: UInt8, at bitOffset: Int) {
        let byteIndex = bitOffset / 8
        guard byteIndex < rawData.count else { return }
        if bitOffset % 8 == 0 {
            rawData[byteIndex] = value
        } else {
            setUInt32(UInt32(value), at: bitOffset, bitLength: 8)
        }
    }

    private func getUInt16(at bitOffset: Int, bitLength: Int) -> UInt16 {
        UInt16(truncatingIfNeeded: getUInt32(at: bitOffset, bitLength: bitLength))
    }

    private func setUInt16(_ value: UInt16, at bitOffset: Int, bitLength: Int) {
        setUInt32(UInt32(value), at: bitOffset, bitLength: bitLength)
    }

    private func getUInt32(at bitOffset: Int, bitLength: Int) -> UInt32 {
        var result: UInt32 = 0
        for i in 0..<bitLength {
            if getBit(at: bitOffset + i) {
                result |= 1 << (bitLength - 1 - i)
            }
        }
        return result
    }

    private func setUInt32(_ value: UInt32, at bitOffset: Int, bitLength: Int) {
        for i in 0..<bitLength {
            let bit = (value >> (bitLength - 1 - i)) & 1 == 1
            setBit(bit, at: bitOffset + i)
        }
    }

    private func getString(at byteOffset: Int, maxLength: Int, encoding: String.Encoding) -> String {
        guard byteOffset + maxLength <= rawData.count else { return "" }
        let slice = rawData[byteOffset..<(byteOffset + maxLength)]
        let trimmed = slice.prefix(while: { $0 != 0 })
        return String(data: Data(trimmed), encoding: encoding) ?? ""
    }

    private func setString(_ value: String, at byteOffset: Int, maxLength: Int, encoding: String.Encoding) {
        guard byteOffset + maxLength <= rawData.count else { return }
        var encoded = value.data(using: encoding) ?? Data()
        if encoded.count > maxLength {
            encoded = encoded.prefix(maxLength)
        }
        encoded.append(contentsOf: Array(repeating: UInt8(0), count: maxLength - encoded.count))
        rawData.replaceSubrange(byteOffset..<(byteOffset + maxLength), with: encoded)
    }

    private func getBytes(at byteOffset: Int, count: Int) -> Data {
        guard byteOffset + count <= rawData.count else { return Data(count: count) }
        return Data(rawData[byteOffset..<(byteOffset + count)])
    }

    private func setBytes(_ data: Data, at byteOffset: Int) {
        guard byteOffset + data.count <= rawData.count else { return }
        rawData.replaceSubrange(byteOffset..<(byteOffset + data.count), with: data)
    }
}

/// Metadata associated with a codeplug file.
public struct CodeplugMetadata: Sendable, Codable {
    public var radioSerialNumber: String?
    public var radioModelName: String?
    public var firmwareVersion: String?
    public var lastReadDate: Date?
    public var lastModified: Date
    public var createdDate: Date
    public var notes: String?

    public init(
        radioSerialNumber: String? = nil,
        radioModelName: String? = nil,
        firmwareVersion: String? = nil,
        lastReadDate: Date? = nil,
        notes: String? = nil
    ) {
        self.radioSerialNumber = radioSerialNumber
        self.radioModelName = radioModelName
        self.firmwareVersion = firmwareVersion
        self.lastReadDate = lastReadDate
        self.lastModified = Date()
        self.createdDate = Date()
        self.notes = notes
    }
}
