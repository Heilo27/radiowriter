import Foundation

/// Represents the value of a single field in a codeplug.
public enum FieldValue: Equatable, Sendable, Codable {
    case uint8(UInt8)
    case uint16(UInt16)
    case uint32(UInt32)
    case int8(Int8)
    case int16(Int16)
    case int32(Int32)
    case bool(Bool)
    case string(String)
    case bytes(Data)
    case enumValue(UInt16)
    case bitField(UInt32, bitCount: Int)

    public var intValue: Int? {
        switch self {
        case .uint8(let value): return Int(value)
        case .uint16(let value): return Int(value)
        case .uint32(let value): return Int(value)
        case .int8(let value): return Int(value)
        case .int16(let value): return Int(value)
        case .int32(let value): return Int(value)
        case .bool(let value): return value ? 1 : 0
        case .enumValue(let value): return Int(value)
        case .bitField(let value, _): return Int(value)
        case .string, .bytes: return nil
        }
    }

    public var stringValue: String? {
        if case .string(let str) = self { return str }
        return nil
    }

    public var boolValue: Bool? {
        if case .bool(let boolVal) = self { return boolVal }
        return nil
    }

    public var dataValue: Data? {
        if case .bytes(let data) = self { return data }
        return nil
    }
}
