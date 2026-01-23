import Foundation
import RadioCore
import RadioModelCore

/// DLR1020 — 2-watt 900 MHz digital business radio with 2 channels.
public enum DLR1020: RadioModel {
    public static let identifier = "DLR1020"
    public static let displayName = "DLR 1020"
    public static let family: RadioFamily = .dlrx
    public static let codeplugSize = 4096
    public static let maxChannels = 2
    public static let frequencyBand: FrequencyBand = .dtr900
    public static let nodes: [CodeplugNode] = DLRxNodes.nodes(maxChannels: maxChannels)

    public static func createDefault() -> Codeplug {
        DLRxDefaults.create(modelIdentifier: identifier, size: codeplugSize, maxChannels: maxChannels)
    }
    public static func validate(_ codeplug: Codeplug) -> [ValidationIssue] { [] }
    public static func applyDependencies(field: String, in codeplug: Codeplug) {}
}

/// DLR1060 — 1-watt 900 MHz digital business radio with 6 channels.
public enum DLR1060: RadioModel {
    public static let identifier = "DLR1060"
    public static let displayName = "DLR 1060"
    public static let family: RadioFamily = .dlrx
    public static let codeplugSize = 4096
    public static let maxChannels = 6
    public static let frequencyBand: FrequencyBand = .dtr900
    public static let nodes: [CodeplugNode] = DLRxNodes.nodes(maxChannels: maxChannels)

    public static func createDefault() -> Codeplug {
        DLRxDefaults.create(modelIdentifier: identifier, size: codeplugSize, maxChannels: maxChannels)
    }
    public static func validate(_ codeplug: Codeplug) -> [ValidationIssue] { [] }
    public static func applyDependencies(field: String, in codeplug: Codeplug) {}
}

// MARK: - DLRx Shared

enum DLRxNodes {
    static func nodes(maxChannels: Int) -> [CodeplugNode] {
        var channelChildren: [CodeplugNode] = []
        for ch in 0..<maxChannels {
            channelChildren.append(CodeplugNode(
                id: "dlrx.channel.\(ch)", name: "channel\(ch + 1)",
                displayName: "Channel \(ch + 1)", category: .channel,
                fields: [DLRxFields.channelMode(channel: ch), DLRxFields.channelContactName(channel: ch)]
            ))
        }
        return [
            CodeplugNode(id: "dlrx.general", name: "general", displayName: "General", category: .general, fields: [
                DLRxFields.pin, DLRxFields.numChannels, DLRxFields.vpUserMode,
                DLRxFields.powerUpTone, DLRxFields.pinLockEnabled,
            ]),
            CodeplugNode(id: "dlrx.channels", name: "channels", displayName: "Channels", category: .channel,
                         nodeType: .repeating(count: maxChannels, stride: 256), children: channelChildren),
            CodeplugNode(id: "dlrx.contacts", name: "contacts", displayName: "Contacts", category: .contacts, fields: [
                DLRxFields.directContactId, DLRxFields.favContactCount,
            ]),
            CodeplugNode(id: "dlrx.advanced", name: "advanced", displayName: "Advanced", category: .advanced, fields: [
                DLRxFields.wifiEnabled, DLRxFields.wifiSSID,
            ]),
        ]
    }
}

enum DLRxDefaults {
    static func create(modelIdentifier: String, size: Int, maxChannels: Int) -> Codeplug {
        let codeplug = Codeplug(modelIdentifier: modelIdentifier, size: size)
        codeplug.setValue(.uint8(UInt8(maxChannels)), for: DLRxFields.numChannels)
        codeplug.setValue(.string("0000"), for: DLRxFields.pin)
        codeplug.clearModifications()
        return codeplug
    }
}
