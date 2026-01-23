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
        case .uint8(let v): return Int(v)
        case .uint16(let v): return Int(v)
        case .uint32(let v): return Int(v)
        case .int8(let v): return Int(v)
        case .int16(let v): return Int(v)
        case .int32(let v): return Int(v)
        case .bool(let v): return v ? 1 : 0
        case .enumValue(let v): return Int(v)
        case .bitField(let v, _): return Int(v)
        case .string, .bytes: return nil
        }
    }

    public var stringValue: String? {
        if case .string(let s) = self { return s }
        return nil
    }

    public var boolValue: Bool? {
        if case .bool(let b) = self { return b }
        return nil
    }

    public var dataValue: Data? {
        if case .bytes(let d) = self { return d }
        return nil
    }
}
