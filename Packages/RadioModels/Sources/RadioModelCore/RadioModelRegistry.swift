import Foundation
import RadioCore

/// Registry of all available radio models.
/// Models are registered at compile time for type safety.
public enum RadioModelRegistry {
    private static var models: [String: any RadioModel.Type] = [:]

    /// Registers a radio model type.
    public static func register<T: RadioModel>(_ type: T.Type) {
        models[T.identifier] = type
    }

    /// Returns the model type for a given identifier.
    public static func model(for identifier: String) -> (any RadioModel.Type)? {
        models[identifier]
    }

    /// All registered model identifiers.
    public static var allIdentifiers: [String] {
        Array(models.keys).sorted()
    }

    /// All registered models grouped by family.
    public static var byFamily: [RadioFamily: [any RadioModel.Type]] {
        var result: [RadioFamily: [any RadioModel.Type]] = [:]
        for model in models.values {
            result[model.family, default: []].append(model)
        }
        return result
    }

    /// Creates a new default codeplug for the given model identifier.
    public static func createDefaultCodeplug(for identifier: String) -> Codeplug? {
        guard let model = models[identifier] else { return nil }
        return model.createDefault()
    }
}

/// Model information for display in the UI.
public struct RadioModelInfo: Identifiable, Sendable {
    public let id: String
    public let displayName: String
    public let family: RadioFamily
    public let maxChannels: Int
    public let frequencyBand: FrequencyBand
    public let imageName: String?

    public init(from model: any RadioModel.Type) {
        self.id = model.identifier
        self.displayName = model.displayName
        self.family = model.family
        self.maxChannels = model.maxChannels
        self.frequencyBand = model.frequencyBand
        self.imageName = nil
    }
}
