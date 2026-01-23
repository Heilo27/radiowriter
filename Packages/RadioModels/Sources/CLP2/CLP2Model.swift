import Foundation
import RadioCore
import RadioModelCore

/// CLP1100 — 8-channel UHF business radio with Bluetooth.
public enum CLP1100: RadioModel {
    public static let identifier = "CLP1100"
    public static let displayName = "CLP 1100"
    public static let family: RadioFamily = .clp
    public static let codeplugSize = 2048
    public static let maxChannels = 8
    public static let frequencyBand: FrequencyBand = .uhf

    public static let nodes: [CodeplugNode] = CLP2Nodes.nodes(maxChannels: maxChannels)

    public static func createDefault() -> Codeplug {
        CLP2Defaults.create(modelIdentifier: identifier, size: codeplugSize, maxChannels: maxChannels)
    }

    public static func validate(_ codeplug: Codeplug) -> [ValidationIssue] {
        CLP2Validation.validate(codeplug, band: frequencyBand, maxChannels: maxChannels)
    }

    public static func applyDependencies(field: String, in codeplug: Codeplug) {
        CLP2Dependencies.apply(field: field, in: codeplug)
    }
}

/// CLP1140 — 4-channel UHF with Bluetooth and display.
public enum CLP1140: RadioModel {
    public static let identifier = "CLP1140"
    public static let displayName = "CLP 1140"
    public static let family: RadioFamily = .clp
    public static let codeplugSize = 2048
    public static let maxChannels = 4
    public static let frequencyBand: FrequencyBand = .uhf

    public static let nodes: [CodeplugNode] = CLP2Nodes.nodes(maxChannels: maxChannels)

    public static func createDefault() -> Codeplug {
        CLP2Defaults.create(modelIdentifier: identifier, size: codeplugSize, maxChannels: maxChannels)
    }

    public static func validate(_ codeplug: Codeplug) -> [ValidationIssue] {
        CLP2Validation.validate(codeplug, band: frequencyBand, maxChannels: maxChannels)
    }

    public static func applyDependencies(field: String, in codeplug: Codeplug) {
        CLP2Dependencies.apply(field: field, in: codeplug)
    }
}

/// CLP1160 — 6-channel UHF with Bluetooth and display.
public enum CLP1160: RadioModel {
    public static let identifier = "CLP1160"
    public static let displayName = "CLP 1160"
    public static let family: RadioFamily = .clp
    public static let codeplugSize = 2048
    public static let maxChannels = 6
    public static let frequencyBand: FrequencyBand = .uhf

    public static let nodes: [CodeplugNode] = CLP2Nodes.nodes(maxChannels: maxChannels)

    public static func createDefault() -> Codeplug {
        CLP2Defaults.create(modelIdentifier: identifier, size: codeplugSize, maxChannels: maxChannels)
    }

    public static func validate(_ codeplug: Codeplug) -> [ValidationIssue] {
        CLP2Validation.validate(codeplug, band: frequencyBand, maxChannels: maxChannels)
    }

    public static func applyDependencies(field: String, in codeplug: Codeplug) {
        CLP2Dependencies.apply(field: field, in: codeplug)
    }
}
