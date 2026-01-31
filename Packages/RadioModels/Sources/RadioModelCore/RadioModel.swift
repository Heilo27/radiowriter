import Foundation
import RadioCore

/// Protocol defining a radio model's capabilities and data layout.
public protocol RadioModel: Sendable {
    /// Unique identifier for this radio model (e.g., "CLP1010").
    static var identifier: String { get }

    /// Human-readable display name (e.g., "CLP 1010").
    static var displayName: String { get }

    /// Radio family (e.g., "CLP").
    static var family: RadioFamily { get }

    /// Total codeplug size in bytes.
    static var codeplugSize: Int { get }

    /// Maximum number of channels supported.
    static var maxChannels: Int { get }

    /// Supported frequency band.
    static var frequencyBand: FrequencyBand { get }

    /// The tree of nodes and fields that define this radio's codeplug structure.
    static var nodes: [CodeplugNode] { get }

    /// All field definitions flattened from the node tree.
    static var allFields: [FieldDefinition] { get }

    /// Model number string as reported by the radio (for auto-identification).
    /// Example: "MDH02RDH9XA1AN" for XPR 3500e
    static var modelNumbers: [String] { get }

    /// Creates a new default codeplug for this model.
    static func createDefault() -> Codeplug

    /// Validates a complete codeplug for this model.
    static func validate(_ codeplug: Codeplug) -> [ValidationIssue]

    /// Applies inter-field dependencies after a value change.
    static func applyDependencies(field: String, in codeplug: Codeplug)
}

extension RadioModel {
    /// Default empty model numbers (radios that don't support auto-identification).
    public static var modelNumbers: [String] { [] }
}

extension RadioModel {
    public static var allFields: [FieldDefinition] {
        nodes.flatMap(\.allFields)
    }
}

/// A radio product family.
public enum RadioFamily: String, CaseIterable, Sendable {
    case apx = "APX"
    case clp = "CLP"
    case cp200 = "CP200"
    case dlrx = "DLR"
    case dtr = "DTR"
    case fiji = "SL300"
    case nome = "RM"
    case rdm = "RDM"
    case renoir = "RMU"
    case rmm = "RMM"
    case solo = "RDU"
    case sunb = "CLS"
    case vanu = "VL/RDU4100"
    case xpr = "XPR"
}

/// Frequency band specification.
public struct FrequencyBand: Sendable, Equatable {
    public let name: String
    public let lowerBound: Double // MHz
    public let upperBound: Double // MHz
    public let channelSpacing: Double // kHz

    public init(name: String, lowerBound: Double, upperBound: Double, channelSpacing: Double) {
        self.name = name
        self.lowerBound = lowerBound
        self.upperBound = upperBound
        self.channelSpacing = channelSpacing
    }

    public static let uhf = FrequencyBand(name: "UHF", lowerBound: 400.0, upperBound: 470.0, channelSpacing: 12.5)
    public static let vhf = FrequencyBand(name: "VHF", lowerBound: 136.0, upperBound: 174.0, channelSpacing: 12.5)
    public static let frs = FrequencyBand(name: "FRS", lowerBound: 462.5625, upperBound: 467.7125, channelSpacing: 12.5)
    public static let murs = FrequencyBand(name: "MURS", lowerBound: 151.82, upperBound: 154.6, channelSpacing: 11.25)
    public static let dtr900 = FrequencyBand(name: "900 MHz ISM", lowerBound: 902.0, upperBound: 928.0, channelSpacing: 12.5)
    public static let band700800 = FrequencyBand(name: "700/800 MHz", lowerBound: 764.0, upperBound: 870.0, channelSpacing: 12.5)
}

/// A validation issue found in a codeplug.
public struct ValidationIssue: Sendable, Identifiable {
    public let id = UUID()
    public let severity: Severity
    public let fieldID: String?
    public let message: String

    public init(severity: Severity, fieldID: String? = nil, message: String) {
        self.severity = severity
        self.fieldID = fieldID
        self.message = message
    }

    public enum Severity: Sendable {
        case error
        case warning
        case info
    }
}
