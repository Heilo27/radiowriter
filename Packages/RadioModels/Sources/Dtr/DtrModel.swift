import Foundation
import RadioCore
import RadioModelCore

/// DTR410 — 1-watt 900 MHz digital business radio with 10 channels, contacts, and messaging.
public enum DTR410: RadioModel {
    public static let identifier = "DTR410"
    public static let displayName = "DTR 410"
    public static let family: RadioFamily = .dtr
    public static let codeplugSize = 8192
    public static let maxChannels = 10
    public static let frequencyBand: FrequencyBand = .dtr900
    public static let nodes: [CodeplugNode] = DtrNodes.nodes(maxChannels: maxChannels)

    public static func createDefault() -> Codeplug {
        DtrDefaults.create(modelIdentifier: identifier, size: codeplugSize, maxChannels: maxChannels)
    }
    public static func validate(_ codeplug: Codeplug) -> [ValidationIssue] { [] }
    public static func applyDependencies(field: String, in codeplug: Codeplug) {}
}

/// DTR620 — 1-watt 900 MHz digital radio with display, 10 channels, and text messaging.
public enum DTR620: RadioModel {
    public static let identifier = "DTR620"
    public static let displayName = "DTR 620"
    public static let family: RadioFamily = .dtr
    public static let codeplugSize = 8192
    public static let maxChannels = 10
    public static let frequencyBand: FrequencyBand = .dtr900
    public static let nodes: [CodeplugNode] = DtrNodes.nodes(maxChannels: maxChannels)

    public static func createDefault() -> Codeplug {
        DtrDefaults.create(modelIdentifier: identifier, size: codeplugSize, maxChannels: maxChannels)
    }
    public static func validate(_ codeplug: Codeplug) -> [ValidationIssue] { [] }
    public static func applyDependencies(field: String, in codeplug: Codeplug) {}
}

/// DTR700 — 1-watt 900 MHz digital radio with full display, 10 channels, and text messaging.
public enum DTR700: RadioModel {
    public static let identifier = "DTR700"
    public static let displayName = "DTR 700"
    public static let family: RadioFamily = .dtr
    public static let codeplugSize = 8192
    public static let maxChannels = 10
    public static let frequencyBand: FrequencyBand = .dtr900
    public static let nodes: [CodeplugNode] = DtrNodes.nodes(maxChannels: maxChannels)

    public static func createDefault() -> Codeplug {
        DtrDefaults.create(modelIdentifier: identifier, size: codeplugSize, maxChannels: maxChannels)
    }
    public static func validate(_ codeplug: Codeplug) -> [ValidationIssue] { [] }
    public static func applyDependencies(field: String, in codeplug: Codeplug) {}
}

/// DTR550 — 1-watt 900 MHz digital radio with 10 channels (no display).
public enum DTR550: RadioModel {
    public static let identifier = "DTR550"
    public static let displayName = "DTR 550"
    public static let family: RadioFamily = .dtr
    public static let codeplugSize = 8192
    public static let maxChannels = 10
    public static let frequencyBand: FrequencyBand = .dtr900
    public static let nodes: [CodeplugNode] = DtrNodes.nodes(maxChannels: maxChannels)

    public static func createDefault() -> Codeplug {
        DtrDefaults.create(modelIdentifier: identifier, size: codeplugSize, maxChannels: maxChannels)
    }
    public static func validate(_ codeplug: Codeplug) -> [ValidationIssue] { [] }
    public static func applyDependencies(field: String, in codeplug: Codeplug) {}
}

/// DTR600 — 1-watt 900 MHz digital radio with 30 channels and full display.
public enum DTR600: RadioModel {
    public static let identifier = "DTR600"
    public static let displayName = "DTR 600"
    public static let family: RadioFamily = .dtr
    public static let codeplugSize = 16384
    public static let maxChannels = 30
    public static let frequencyBand: FrequencyBand = .dtr900
    public static let nodes: [CodeplugNode] = DtrNodes.nodes(maxChannels: maxChannels)

    public static func createDefault() -> Codeplug {
        DtrDefaults.create(modelIdentifier: identifier, size: codeplugSize, maxChannels: maxChannels)
    }
    public static func validate(_ codeplug: Codeplug) -> [ValidationIssue] { [] }
    public static func applyDependencies(field: String, in codeplug: Codeplug) {}
}

/// DTR650 — 1-watt 900 MHz digital radio with display, 10 channels, and text messaging.
public enum DTR650: RadioModel {
    public static let identifier = "DTR650"
    public static let displayName = "DTR 650"
    public static let family: RadioFamily = .dtr
    public static let codeplugSize = 8192
    public static let maxChannels = 10
    public static let frequencyBand: FrequencyBand = .dtr900
    public static let nodes: [CodeplugNode] = DtrNodes.nodes(maxChannels: maxChannels)

    public static func createDefault() -> Codeplug {
        DtrDefaults.create(modelIdentifier: identifier, size: codeplugSize, maxChannels: maxChannels)
    }
    public static func validate(_ codeplug: Codeplug) -> [ValidationIssue] { [] }
    public static func applyDependencies(field: String, in codeplug: Codeplug) {}
}

// MARK: - DTR Shared

enum DtrNodes {
    static func nodes(maxChannels: Int) -> [CodeplugNode] {
        var channelChildren: [CodeplugNode] = []
        for ch in 0..<maxChannels {
            channelChildren.append(CodeplugNode(
                id: "dtr.channel.\(ch)", name: "channel\(ch + 1)",
                displayName: "Channel \(ch + 1)", category: .channel,
                fields: [
                    DtrFields.channelMode(channel: ch),
                    DtrFields.channelContactName(channel: ch),
                    DtrFields.channelRinger(channel: ch),
                ]
            ))
        }
        return [
            CodeplugNode(id: "dtr.general", name: "general", displayName: "General", category: .general, fields: [
                DtrFields.pin, DtrFields.numChannels, DtrFields.pinLockEnabled,
                DtrFields.backlightTimer, DtrFields.contrast,
            ]),
            CodeplugNode(id: "dtr.audio", name: "audio", displayName: "Audio", category: .audio, fields: [
                DtrFields.vpUserMode, DtrFields.powerUpTone,
            ]),
            CodeplugNode(id: "dtr.channels", name: "channels", displayName: "Channels", category: .channel,
                         nodeType: .repeating(count: maxChannels, stride: DtrFields.channelStride), children: channelChildren),
            CodeplugNode(id: "dtr.contacts", name: "contacts", displayName: "Contacts", category: .contacts, fields: [
                DtrFields.directContactId, DtrFields.maxContacts,
            ]),
        ]
    }
}

enum DtrDefaults {
    static func create(modelIdentifier: String, size: Int, maxChannels: Int) -> Codeplug {
        let codeplug = Codeplug(modelIdentifier: modelIdentifier, size: size)
        codeplug.setValue(.uint8(UInt8(maxChannels)), for: DtrFields.numChannels)
        codeplug.setValue(.string("00000"), for: DtrFields.pin)
        codeplug.clearModifications()
        return codeplug
    }
}
