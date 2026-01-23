import Foundation
import RadioCore
import RadioModelCore

/// CLS1110 — 1-watt UHF business radio with 1 channel.
public enum CLS1110: RadioModel {
    public static let identifier = "CLS1110"
    public static let displayName = "CLS 1110"
    public static let family: RadioFamily = .fiji
    public static let codeplugSize = 2048
    public static let maxChannels = 1
    public static let frequencyBand: FrequencyBand = .uhf
    public static let nodes: [CodeplugNode] = FijiNodes.nodes(maxChannels: maxChannels)

    public static func createDefault() -> Codeplug {
        FijiDefaults.create(modelIdentifier: identifier, size: codeplugSize, maxChannels: maxChannels)
    }
    public static func validate(_ codeplug: Codeplug) -> [ValidationIssue] { [] }
    public static func applyDependencies(field: String, in codeplug: Codeplug) {}
}

/// CLS1410 — 1-watt UHF business radio with 4 channels.
public enum CLS1410: RadioModel {
    public static let identifier = "CLS1410"
    public static let displayName = "CLS 1410"
    public static let family: RadioFamily = .fiji
    public static let codeplugSize = 2048
    public static let maxChannels = 4
    public static let frequencyBand: FrequencyBand = .uhf
    public static let nodes: [CodeplugNode] = FijiNodes.nodes(maxChannels: maxChannels)

    public static func createDefault() -> Codeplug {
        FijiDefaults.create(modelIdentifier: identifier, size: codeplugSize, maxChannels: maxChannels)
    }
    public static func validate(_ codeplug: Codeplug) -> [ValidationIssue] { [] }
    public static func applyDependencies(field: String, in codeplug: Codeplug) {}
}

/// VLR150 — 1-watt UHF business radio with 10 channels (Brazil).
public enum VLR150: RadioModel {
    public static let identifier = "VLR150"
    public static let displayName = "VLR 150"
    public static let family: RadioFamily = .fiji
    public static let codeplugSize = 2048
    public static let maxChannels = 10
    public static let frequencyBand: FrequencyBand = .uhf
    public static let nodes: [CodeplugNode] = FijiNodes.nodes(maxChannels: maxChannels)

    public static func createDefault() -> Codeplug {
        FijiDefaults.create(modelIdentifier: identifier, size: codeplugSize, maxChannels: maxChannels)
    }
    public static func validate(_ codeplug: Codeplug) -> [ValidationIssue] { [] }
    public static func applyDependencies(field: String, in codeplug: Codeplug) {}
}

// MARK: - Fiji Shared

enum FijiNodes {
    static func nodes(maxChannels: Int) -> [CodeplugNode] {
        var channelChildren: [CodeplugNode] = []
        for ch in 0..<maxChannels {
            channelChildren.append(CodeplugNode(
                id: "fiji.channel.\(ch)", name: "channel\(ch + 1)",
                displayName: "Channel \(ch + 1)", category: .channel,
                fields: [
                    FijiFields.channelFrequencyIndex(channel: ch),
                    FijiFields.channelCode(channel: ch),
                    FijiFields.channelScrambleCode(channel: ch),
                    FijiFields.channelBandwidth(channel: ch),
                ]
            ))
        }
        return [
            CodeplugNode(id: "fiji.general", name: "general", displayName: "General", category: .general, fields: [
                FijiFields.numberOfChannels, FijiFields.keypadLock,
                FijiFields.backlightEnabled, FijiFields.codeplugResetEnabled,
                FijiFields.batteryType, FijiFields.batterySaveDisabled,
            ]),
            CodeplugNode(id: "fiji.audio", name: "audio", displayName: "Audio", category: .audio, fields: [
                FijiFields.callTone, FijiFields.keypadBeep, FijiFields.rogerBeep,
                FijiFields.voxLevel, FijiFields.micGain,
            ]),
            CodeplugNode(id: "fiji.channels", name: "channels", displayName: "Channels", category: .channel,
                         nodeType: .repeating(count: maxChannels, stride: FijiFields.channelStride), children: channelChildren),
            CodeplugNode(id: "fiji.signaling", name: "signaling", displayName: "Signaling", category: .signaling, fields: [
                FijiFields.reverseBurst,
            ]),
        ]
    }
}

enum FijiDefaults {
    static func create(modelIdentifier: String, size: Int, maxChannels: Int) -> Codeplug {
        let codeplug = Codeplug(modelIdentifier: modelIdentifier, size: size)
        codeplug.setValue(.uint8(UInt8(maxChannels)), for: FijiFields.numberOfChannels)
        codeplug.clearModifications()
        return codeplug
    }
}
