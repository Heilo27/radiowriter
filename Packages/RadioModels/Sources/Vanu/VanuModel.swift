import Foundation
import RadioCore
import RadioModelCore

/// VL50 — 1-watt UHF digital business radio with 8 channels and contacts.
public enum VL50: RadioModel {
    public static let identifier = "VL50"
    public static let displayName = "VL50"
    public static let family: RadioFamily = .vanu
    public static let codeplugSize = 4096
    public static let maxChannels = 8
    public static let frequencyBand: FrequencyBand = .uhf
    public static let nodes: [CodeplugNode] = VanuNodes.nodes(maxChannels: maxChannels)

    public static func createDefault() -> Codeplug {
        VanuDefaults.create(modelIdentifier: identifier, size: codeplugSize, maxChannels: maxChannels)
    }
    public static func validate(_ codeplug: Codeplug) -> [ValidationIssue] { [] }
    public static func applyDependencies(field: String, in codeplug: Codeplug) {}
}

/// RDU4100d — 4-watt UHF digital business radio with 6 channels and contacts.
public enum RDU4100d: RadioModel {
    public static let identifier = "RDU4100d"
    public static let displayName = "RDU 4100d"
    public static let family: RadioFamily = .vanu
    public static let codeplugSize = 4096
    public static let maxChannels = 6
    public static let frequencyBand: FrequencyBand = .uhf
    public static let nodes: [CodeplugNode] = VanuNodes.nodes(maxChannels: maxChannels)

    public static func createDefault() -> Codeplug {
        VanuDefaults.create(modelIdentifier: identifier, size: codeplugSize, maxChannels: maxChannels)
    }
    public static func validate(_ codeplug: Codeplug) -> [ValidationIssue] { [] }
    public static func applyDependencies(field: String, in codeplug: Codeplug) {}
}

// MARK: - Vanu Shared

enum VanuNodes {
    static func nodes(maxChannels: Int) -> [CodeplugNode] {
        var channelChildren: [CodeplugNode] = []
        for ch in 0..<maxChannels {
            channelChildren.append(CodeplugNode(
                id: "vanu.channel.\(ch)", name: "channel\(ch + 1)",
                displayName: "Channel \(ch + 1)", category: .channel,
                fields: [
                    VanuFields.channelMode(channel: ch),
                    VanuFields.channelContactName(channel: ch),
                ]
            ))
        }
        return [
            CodeplugNode(id: "vanu.general", name: "general", displayName: "General", category: .general, fields: [
                VanuFields.pin, VanuFields.numChannels, VanuFields.pinLockEnabled,
                VanuFields.radioName,
            ]),
            CodeplugNode(id: "vanu.audio", name: "audio", displayName: "Audio", category: .audio, fields: [
                VanuFields.vpEnabled, VanuFields.powerUpTone,
            ]),
            CodeplugNode(id: "vanu.channels", name: "channels", displayName: "Channels", category: .channel,
                         nodeType: .repeating(count: maxChannels, stride: VanuFields.channelStride), children: channelChildren),
            CodeplugNode(id: "vanu.contacts", name: "contacts", displayName: "Contacts", category: .contacts, fields: [
                VanuFields.directContactId,
            ]),
            CodeplugNode(id: "vanu.advanced", name: "advanced", displayName: "Advanced", category: .advanced, fields: [
                VanuFields.codeplugResetEnabled, VanuFields.programmingModeEnabled,
            ]),
        ]
    }
}

enum VanuDefaults {
    static func create(modelIdentifier: String, size: Int, maxChannels: Int) -> Codeplug {
        let codeplug = Codeplug(modelIdentifier: modelIdentifier, size: size)
        codeplug.setValue(.uint8(UInt8(maxChannels)), for: VanuFields.numChannels)
        codeplug.setValue(.string("0000"), for: VanuFields.pin)
        codeplug.clearModifications()
        return codeplug
    }
}
