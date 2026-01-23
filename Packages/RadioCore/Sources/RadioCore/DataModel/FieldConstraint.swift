import Foundation

/// Defines validation rules for field values.
public enum FieldConstraint: Sendable {
    case range(min: Int, max: Int)
    case enumValues(Set<UInt16>)
    case stringLength(min: Int, max: Int)
    case regex(String)
    case custom(id: String)

    /// Validates a value against this constraint.
    public func validate(_ value: FieldValue) -> ConstraintResult {
        switch self {
        case .range(let min, let max):
            guard let intVal = value.intValue else {
                return .invalid("Expected numeric value")
            }
            if intVal < min || intVal > max {
                return .invalid("Value \(intVal) out of range [\(min)...\(max)]")
            }
            return .valid

        case .enumValues(let allowed):
            guard let intVal = value.intValue else {
                return .invalid("Expected numeric value")
            }
            if !allowed.contains(UInt16(intVal)) {
                return .invalid("Value not in allowed set")
            }
            return .valid

        case .stringLength(let min, let max):
            guard let str = value.stringValue else {
                return .invalid("Expected string value")
            }
            if str.count < min || str.count > max {
                return .invalid("String length \(str.count) out of range [\(min)...\(max)]")
            }
            return .valid

        case .regex(let pattern):
            guard let str = value.stringValue else {
                return .invalid("Expected string value")
            }
            guard str.range(of: pattern, options: .regularExpression) != nil else {
                return .invalid("Value does not match pattern")
            }
            return .valid

        case .custom:
            // Custom constraints are validated by the radio model
            return .valid
        }
    }
}

/// Result of constraint validation.
public enum ConstraintResult: Sendable, Equatable {
    case valid
    case invalid(String)
    case warning(String)

    public var isValid: Bool {
        if case .valid = self { return true }
        return false
    }

    public var message: String? {
        switch self {
        case .valid: return nil
        case .invalid(let msg): return msg
        case .warning(let msg): return msg
        }
    }
}
