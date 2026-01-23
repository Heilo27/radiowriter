import Foundation
import RadioCore
import RadioModelCore

/// RMU2040 — 2-watt UHF digital business radio with 4 channels and contacts.
public enum RMU2040: RadioModel {
    public static let identifier = "RMU2040"
    public static let displayName = "RMU 2040"
    public static let family: RadioFamily = .renoir
    public static let codeplugSize = 4096
    public static let maxChannels = 4
    public static let frequencyBand: FrequencyBand = .uhf
    public static let nodes: [CodeplugNode] = RenoirNodes.nodes(maxChannels: maxChannels)

    public static func createDefault() -> Codeplug {
        RenoirDefaults.create(modelIdentifier: identifier, size: codeplugSize, maxChannels: maxChannels)
    }
    public static func validate(_ codeplug: Codeplug) -> [ValidationIssue] { [] }
    public static func applyDependencies(field: String, in codeplug: Codeplug) {}
}

/// RMU2080 — 2-watt UHF digital business radio with 8 channels and contacts.
public enum RMU2080: RadioModel {
    public static let identifier = "RMU2080"
    public static let displayName = "RMU 2080"
    public static let family: RadioFamily = .renoir
    public static let codeplugSize = 4096
    public static let maxChannels = 8
    public static let frequencyBand: FrequencyBand = .uhf
    public static let nodes: [CodeplugNode] = RenoirNodes.nodes(maxChannels: maxChannels)

    public static func createDefault() -> Codeplug {
        RenoirDefaults.create(modelIdentifier: identifier, size: codeplugSize, maxChannels: maxChannels)
    }
    public static func validate(_ codeplug: Codeplug) -> [ValidationIssue] { [] }
    public static func applyDependencies(field: String, in codeplug: Codeplug) {}
}

/// RMV2080 — 2-watt VHF digital business radio with 8 channels and contacts.
public enum RMV2080: RadioModel {
    public static let identifier = "RMV2080"
    public static let displayName = "RMV 2080"
    public static let family: RadioFamily = .renoir
    public static let codeplugSize = 4096
    public static let maxChannels = 8
    public static let frequencyBand: FrequencyBand = .vhf
    public static let nodes: [CodeplugNode] = RenoirNodes.nodes(maxChannels: maxChannels)

    public static func createDefault() -> Codeplug {
        RenoirDefaults.create(modelIdentifier: identifier, size: codeplugSize, maxChannels: maxChannels)
    }
    public static func validate(_ codeplug: Codeplug) -> [ValidationIssue] { [] }
    public static func applyDependencies(field: String, in codeplug: Codeplug) {}
}

// MARK: - Renoir Shared

enum RenoirNodes {
    static func nodes(maxChannels: Int) -> [CodeplugNode] {
        var channelChildren: [CodeplugNode] = []
        for ch in 0..<maxChannels {
            channelChildren.append(CodeplugNode(
                id: "renoir.channel.\(ch)", name: "channel\(ch + 1)",
                displayName: "Channel \(ch + 1)", category: .channel,
                fields: [
                    RenoirFields.channelMode(channel: ch),
                    RenoirFields.channelContactName(channel: ch),
                ]
            ))
        }
        return [
            CodeplugNode(id: "renoir.general", name: "general", displayName: "General", category: .general, fields: [
                RenoirFields.pin, RenoirFields.numChannels, RenoirFields.pinLockEnabled,
                RenoirFields.radioName, RenoirFields.vibracallEnabled,
                RenoirFields.backlightTimer, RenoirFields.powerSaveMode,
                RenoirFields.homeChanIndex,
            ]),
            CodeplugNode(id: "renoir.audio", name: "audio", displayName: "Audio", category: .audio, fields: [
                RenoirFields.powerUpTone,
            ]),
            CodeplugNode(id: "renoir.channels", name: "channels", displayName: "Channels", category: .channel,
                         nodeType: .repeating(count: maxChannels, stride: RenoirFields.channelStride), children: channelChildren),
            CodeplugNode(id: "renoir.contacts", name: "contacts", displayName: "Contacts", category: .contacts, fields: [
                RenoirFields.directContactId,
            ]),
            CodeplugNode(id: "renoir.advanced", name: "advanced", displayName: "Advanced", category: .advanced, fields: [
                RenoirFields.codeplugResetEnabled, RenoirFields.managerMode,
            ]),
        ]
    }
}

enum RenoirDefaults {
    static func create(modelIdentifier: String, size: Int, maxChannels: Int) -> Codeplug {
        let codeplug = Codeplug(modelIdentifier: modelIdentifier, size: size)
        codeplug.setValue(.uint8(UInt8(maxChannels)), for: RenoirFields.numChannels)
        codeplug.setValue(.string("0000"), for: RenoirFields.pin)
        codeplug.clearModifications()
        return codeplug
    }
}
