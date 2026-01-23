import Foundation
import RadioCore
import RadioModelCore

/// RMM2050 — 25-watt VHF MURS mobile radio with 8 channels.
public enum RMM2050: RadioModel {
    public static let identifier = "RMM2050"
    public static let displayName = "RMM 2050"
    public static let family: RadioFamily = .rmm
    public static let codeplugSize = 4096
    public static let maxChannels = 8
    public static let frequencyBand: FrequencyBand = .murs
    public static let nodes: [CodeplugNode] = RMMNodes.nodes(maxChannels: maxChannels)

    public static func createDefault() -> Codeplug {
        RMMDefaults.create(modelIdentifier: identifier, size: codeplugSize, maxChannels: maxChannels)
    }
    public static func validate(_ codeplug: Codeplug) -> [ValidationIssue] {
        RMMValidation.validate(codeplug, maxChannels: maxChannels)
    }
    public static func applyDependencies(field: String, in codeplug: Codeplug) {}
}

// MARK: - RMM Shared

enum RMMNodes {
    static func nodes(maxChannels: Int) -> [CodeplugNode] {
        var channelChildren: [CodeplugNode] = []
        for ch in 0..<maxChannels {
            channelChildren.append(CodeplugNode(
                id: "rmm.channel.\(ch)", name: "channel\(ch + 1)",
                displayName: "Channel \(ch + 1)", category: .channel,
                fields: [
                    RMMFields.channelFrequency(channel: ch),
                    RMMFields.channelName(channel: ch),
                    RMMFields.channelTxPower(channel: ch),
                    RMMFields.channelBandwidth(channel: ch),
                    RMMFields.channelTxCode(channel: ch),
                    RMMFields.channelRxCode(channel: ch),
                ]
            ))
        }
        return [
            CodeplugNode(id: "rmm.general", name: "general", displayName: "General", category: .general, fields: [
                RMMFields.numberOfChannels, RMMFields.defaultChannel, RMMFields.powerOnChannel,
            ]),
            CodeplugNode(id: "rmm.audio", name: "audio", displayName: "Audio", category: .audio, fields: [
                RMMFields.volumeLevel, RMMFields.keyBeepEnabled, RMMFields.toneVolume,
            ]),
            CodeplugNode(id: "rmm.channels", name: "channels", displayName: "Channels", category: .channel,
                         nodeType: .repeating(count: maxChannels, stride: RMMFields.channelStride), children: channelChildren),
            CodeplugNode(id: "rmm.signaling", name: "signaling", displayName: "Signaling", category: .signaling, fields: [
                RMMFields.scramblerEnabled,
            ]),
            CodeplugNode(id: "rmm.advanced", name: "advanced", displayName: "Advanced", category: .advanced, fields: [
                RMMFields.totTimeout, RMMFields.squelchLevel,
            ]),
        ]
    }
}

enum RMMDefaults {
    static let mursFrequencies: [UInt32] = [
        1518200, 1518800, 1519400, 1545700, 1546000,
        1518200, 1518800, 1519400,
    ]

    static func create(modelIdentifier: String, size: Int, maxChannels: Int) -> Codeplug {
        let codeplug = Codeplug(modelIdentifier: modelIdentifier, size: size)
        codeplug.setValue(.uint8(UInt8(maxChannels)), for: RMMFields.numberOfChannels)
        codeplug.setValue(.uint8(5), for: RMMFields.volumeLevel)
        for ch in 0..<maxChannels {
            let freq = ch < mursFrequencies.count ? mursFrequencies[ch] : mursFrequencies[ch % 5]
            codeplug.setValue(.uint32(freq), for: RMMFields.channelFrequency(channel: ch))
            codeplug.setValue(.string("MURS\(ch + 1)"), for: RMMFields.channelName(channel: ch))
        }
        codeplug.clearModifications()
        return codeplug
    }
}

enum RMMValidation {
    static func validate(_ codeplug: Codeplug, maxChannels: Int) -> [ValidationIssue] {
        var issues: [ValidationIssue] = []
        let band = FrequencyBand.murs
        for ch in 0..<maxChannels {
            let field = RMMFields.channelFrequency(channel: ch)
            if let raw = codeplug.getValue(for: field).intValue {
                let mhz = Double(raw) / 10000.0
                if mhz != 0 && (mhz < band.lowerBound || mhz > band.upperBound) {
                    issues.append(ValidationIssue(severity: .error, fieldID: field.id,
                        message: "Channel \(ch + 1): \(mhz) MHz outside MURS band"))
                }
            }
        }
        return issues
    }
}
