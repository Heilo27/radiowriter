import Foundation

/// Defines the type and layout of a single field within a codeplug binary.
public struct FieldDefinition: Identifiable, Sendable {
    public let id: String
    public let name: String
    public let displayName: String
    public let category: FieldCategory
    public let valueType: FieldValueType
    public let bitOffset: Int
    public let bitLength: Int
    public let defaultValue: FieldValue
    public let constraint: FieldConstraint?
    public let dependencies: [String]
    public let isReadOnly: Bool
    public let helpText: String?

    public init(
        id: String,
        name: String,
        displayName: String,
        category: FieldCategory,
        valueType: FieldValueType,
        bitOffset: Int,
        bitLength: Int,
        defaultValue: FieldValue,
        constraint: FieldConstraint? = nil,
        dependencies: [String] = [],
        isReadOnly: Bool = false,
        helpText: String? = nil
    ) {
        self.id = id
        self.name = name
        self.displayName = displayName
        self.category = category
        self.valueType = valueType
        self.bitOffset = bitOffset
        self.bitLength = bitLength
        self.defaultValue = defaultValue
        self.constraint = constraint
        self.dependencies = dependencies
        self.isReadOnly = isReadOnly
        self.helpText = helpText
    }

    public var byteOffset: Int { bitOffset / 8 }
    public var byteLength: Int { (bitLength + 7) / 8 }
}

/// The storage type of a field.
public enum FieldValueType: Sendable {
    case uint8
    case uint16
    case uint32
    case int8
    case int16
    case int32
    case bool
    case string(maxLength: Int, encoding: String.Encoding)
    case bytes(count: Int)
    case enumeration([EnumOption])
    case bitField(bitCount: Int)
}

/// An option in an enumeration field.
public struct EnumOption: Sendable, Identifiable {
    public let id: UInt16
    public let name: String
    public let displayName: String

    public init(id: UInt16, name: String, displayName: String) {
        self.id = id
        self.name = name
        self.displayName = displayName
    }
}

/// Categories that organize fields in the sidebar.
public enum FieldCategory: String, CaseIterable, Sendable {
    case general = "General"
    case channel = "Channels"
    case audio = "Audio"
    case signaling = "Signaling"
    case scan = "Scan"
    case contacts = "Contacts"
    case bluetooth = "Bluetooth"
    case voicePrompts = "Voice Prompts"
    case advanced = "Advanced"
}
