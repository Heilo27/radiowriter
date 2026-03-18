import Foundation
import RadioCore

/// Registry of all available radio models.
/// Models are registered at compile time for type safety.
public enum RadioModelRegistry {
    private static let lock = NSLock()
    private static var models: [String: any RadioModel.Type] = [:]

    /// Registers a radio model type.
    public static func register<T: RadioModel>(_ type: T.Type) {
        lock.withLock {
            models[T.identifier] = type
        }
    }

    /// Returns the model type for a given identifier.
    public static func model(for identifier: String) -> (any RadioModel.Type)? {
        lock.withLock {
            models[identifier]
        }
    }

    /// All registered model identifiers.
    public static var allIdentifiers: [String] {
        lock.withLock {
            Array(models.keys).sorted()
        }
    }

    /// All registered models grouped by family.
    public static var byFamily: [RadioFamily: [any RadioModel.Type]] {
        lock.withLock {
            var result: [RadioFamily: [any RadioModel.Type]] = [:]
            for model in models.values {
                result[model.family, default: []].append(model)
            }
            return result
        }
    }

    /// Creates a new default codeplug for the given model identifier.
    public static func createDefaultCodeplug(for identifier: String) -> Codeplug? {
        lock.withLock {
            guard let model = models[identifier] else { return nil }
            return model.createDefault()
        }
    }
}

/// Model information for display in the UI.
public struct RadioModelInfo: Identifiable, Sendable {
    public struct Capabilities: Sendable {
        public let canRead: Bool
        public let canWrite: Bool
        public let canVerifyWrite: Bool
        public let isExperimental: Bool

        public init(canRead: Bool, canWrite: Bool, canVerifyWrite: Bool, isExperimental: Bool) {
            self.canRead = canRead
            self.canWrite = canWrite
            self.canVerifyWrite = canVerifyWrite
            self.isExperimental = isExperimental
        }
    }

    public let id: String
    public let displayName: String
    public let family: RadioFamily
    public let maxChannels: Int
    public let frequencyBand: FrequencyBand
    public let imageName: String?
    public let capabilities: Capabilities

    public init(from model: any RadioModel.Type) {
        self.id = model.identifier
        self.displayName = model.displayName
        self.family = model.family
        self.maxChannels = model.maxChannels
        self.frequencyBand = model.frequencyBand
        self.imageName = nil
        self.capabilities = Self.capabilities(for: model.family)
    }

    private static func capabilities(for family: RadioFamily) -> Capabilities {
        switch family {
        case .xpr:
            // XPR read path is available; parsed->binary write path is still in progress.
            return Capabilities(canRead: true, canWrite: false, canVerifyWrite: false, isExperimental: true)
        case .clp:
            return Capabilities(canRead: true, canWrite: true, canVerifyWrite: false, isExperimental: false)
        case .apx:
            return Capabilities(canRead: false, canWrite: false, canVerifyWrite: false, isExperimental: true)
        case .cp200, .dlrx, .dtr, .fiji, .nome, .rdm, .renoir, .rmm, .solo, .sunb, .vanu:
            return Capabilities(canRead: true, canWrite: true, canVerifyWrite: false, isExperimental: true)
        }
    }
}
