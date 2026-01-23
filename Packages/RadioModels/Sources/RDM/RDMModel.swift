import Foundation
import RadioCore
import RadioModelCore

/// RDM2020 — 2-watt MURS business radio with 2 channels for retail environments.
public enum RDM2020: RadioModel {
    public static let identifier = "RDM2020"
    public static let displayName = "RDM 2020"
    public static let family: RadioFamily = .rdm
    public static let codeplugSize = 2048
    public static let maxChannels = 2
    public static let frequencyBand: FrequencyBand = .murs
    public static let nodes: [CodeplugNode] = RDMNodes.nodes(maxChannels: maxChannels)

    public static func createDefault() -> Codeplug {
        RDMDefaults.create(modelIdentifier: identifier, size: codeplugSize, maxChannels: maxChannels)
    }
    public static func validate(_ codeplug: Codeplug) -> [ValidationIssue] {
        RDMValidation.validate(codeplug, maxChannels: maxChannels)
    }
    public static func applyDependencies(field: String, in codeplug: Codeplug) {}
}

/// RDM2070d — 2-watt MURS business radio with 7 channels, display, and digital capabilities.
public enum RDM2070d: RadioModel {
    public static let identifier = "RDM2070d"
    public static let displayName = "RDM 2070d"
    public static let family: RadioFamily = .rdm
    public static let codeplugSize = 4096
    public static let maxChannels = 7
    public static let frequencyBand: FrequencyBand = .murs
    public static let nodes: [CodeplugNode] = RDMNodes.nodes(maxChannels: maxChannels)

    public static func createDefault() -> Codeplug {
        RDMDefaults.create(modelIdentifier: identifier, size: codeplugSize, maxChannels: maxChannels)
    }
    public static func validate(_ codeplug: Codeplug) -> [ValidationIssue] {
        RDMValidation.validate(codeplug, maxChannels: maxChannels)
    }
    public static func applyDependencies(field: String, in codeplug: Codeplug) {}
}

// MARK: - RDM Shared

enum RDMNodes {
    static func nodes(maxChannels: Int) -> [CodeplugNode] {
        var channelChildren: [CodeplugNode] = []
        for ch in 0..<maxChannels {
            channelChildren.append(CodeplugNode(
                id: "rdm.channel.\(ch)", name: "channel\(ch + 1)",
                displayName: "Channel \(ch + 1)", category: .channel,
                fields: [
                    RDMFields.channelFrequency(channel: ch),
                    RDMFields.channelName(channel: ch),
                    RDMFields.channelTxPower(channel: ch),
                    RDMFields.channelTxCode(channel: ch),
                    RDMFields.channelRxCode(channel: ch),
                ]
            ))
        }
        return [
            CodeplugNode(id: "rdm.general", name: "general", displayName: "General", category: .general, fields: [
                RDMFields.radioAlias, RDMFields.numberOfChannels, RDMFields.defaultChannel,
            ]),
            CodeplugNode(id: "rdm.audio", name: "audio", displayName: "Audio", category: .audio, fields: [
                RDMFields.volumeLevel, RDMFields.voxEnabled, RDMFields.voxSensitivity,
                RDMFields.keyBeepEnabled,
            ]),
            CodeplugNode(id: "rdm.channels", name: "channels", displayName: "Channels", category: .channel,
                         nodeType: .repeating(count: maxChannels, stride: RDMFields.channelStride), children: channelChildren),
            CodeplugNode(id: "rdm.signaling", name: "signaling", displayName: "Signaling", category: .signaling, fields: [
                RDMFields.scrambleEnabled,
            ]),
            CodeplugNode(id: "rdm.advanced", name: "advanced", displayName: "Advanced", category: .advanced, fields: [
                RDMFields.totTimeout, RDMFields.batterySaveEnabled,
            ]),
        ]
    }
}

enum RDMDefaults {
    /// Standard MURS frequencies in 100 Hz units.
    static let mursFrequencies: [UInt32] = [
        1518200, // 151.820 MHz - MURS 1
        1518800, // 151.880 MHz - MURS 2
        1519400, // 151.940 MHz - MURS 3
        1545700, // 154.570 MHz - MURS 4
        1546000, // 154.600 MHz - MURS 5
        1518200, // MURS 1 (repeated for 6+ channel models)
        1518800, // MURS 2 (repeated)
    ]

    static func create(modelIdentifier: String, size: Int, maxChannels: Int) -> Codeplug {
        let codeplug = Codeplug(modelIdentifier: modelIdentifier, size: size)
        codeplug.setValue(.uint8(UInt8(maxChannels)), for: RDMFields.numberOfChannels)
        codeplug.setValue(.uint8(5), for: RDMFields.volumeLevel)
        for ch in 0..<maxChannels {
            let freq = ch < mursFrequencies.count ? mursFrequencies[ch] : mursFrequencies[ch % 5]
            codeplug.setValue(.uint32(freq), for: RDMFields.channelFrequency(channel: ch))
            codeplug.setValue(.string("MURS\(ch + 1)"), for: RDMFields.channelName(channel: ch))
        }
        codeplug.clearModifications()
        return codeplug
    }
}

enum RDMValidation {
    static func validate(_ codeplug: Codeplug, maxChannels: Int) -> [ValidationIssue] {
        var issues: [ValidationIssue] = []
        let band = FrequencyBand.murs
        for ch in 0..<maxChannels {
            let field = RDMFields.channelFrequency(channel: ch)
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
