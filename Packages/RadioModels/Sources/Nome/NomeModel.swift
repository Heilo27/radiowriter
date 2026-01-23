import Foundation
import RadioCore
import RadioModelCore

/// RM110 — 2-watt UHF business radio with 2 channels.
public enum RM110: RadioModel {
    public static let identifier = "RM110"
    public static let displayName = "RM 110"
    public static let family: RadioFamily = .nome
    public static let codeplugSize = 4096
    public static let maxChannels = 2
    public static let frequencyBand: FrequencyBand = .uhf
    public static let nodes: [CodeplugNode] = NomeNodes.nodes(maxChannels: maxChannels)

    public static func createDefault() -> Codeplug {
        NomeDefaults.create(modelIdentifier: identifier, size: codeplugSize, maxChannels: maxChannels)
    }
    public static func validate(_ codeplug: Codeplug) -> [ValidationIssue] {
        NomeValidation.validate(codeplug, band: frequencyBand, maxChannels: maxChannels)
    }
    public static func applyDependencies(field: String, in codeplug: Codeplug) {}
}

/// RM160 — 2-watt UHF business radio with 6 channels and display.
public enum RM160: RadioModel {
    public static let identifier = "RM160"
    public static let displayName = "RM 160"
    public static let family: RadioFamily = .nome
    public static let codeplugSize = 4096
    public static let maxChannels = 6
    public static let frequencyBand: FrequencyBand = .uhf
    public static let nodes: [CodeplugNode] = NomeNodes.nodes(maxChannels: maxChannels)

    public static func createDefault() -> Codeplug {
        NomeDefaults.create(modelIdentifier: identifier, size: codeplugSize, maxChannels: maxChannels)
    }
    public static func validate(_ codeplug: Codeplug) -> [ValidationIssue] {
        NomeValidation.validate(codeplug, band: frequencyBand, maxChannels: maxChannels)
    }
    public static func applyDependencies(field: String, in codeplug: Codeplug) {}
}

/// RM410 — 4-watt VHF business radio with 4 channels.
public enum RM410: RadioModel {
    public static let identifier = "RM410"
    public static let displayName = "RM 410"
    public static let family: RadioFamily = .nome
    public static let codeplugSize = 4096
    public static let maxChannels = 4
    public static let frequencyBand: FrequencyBand = .vhf
    public static let nodes: [CodeplugNode] = NomeNodes.nodes(maxChannels: maxChannels)

    public static func createDefault() -> Codeplug {
        NomeDefaults.create(modelIdentifier: identifier, size: codeplugSize, maxChannels: maxChannels)
    }
    public static func validate(_ codeplug: Codeplug) -> [ValidationIssue] {
        NomeValidation.validate(codeplug, band: frequencyBand, maxChannels: maxChannels)
    }
    public static func applyDependencies(field: String, in codeplug: Codeplug) {}
}

/// RM460 — 4-watt VHF business radio with 8 channels.
public enum RM460: RadioModel {
    public static let identifier = "RM460"
    public static let displayName = "RM 460"
    public static let family: RadioFamily = .nome
    public static let codeplugSize = 4096
    public static let maxChannels = 8
    public static let frequencyBand: FrequencyBand = .vhf
    public static let nodes: [CodeplugNode] = NomeNodes.nodes(maxChannels: maxChannels)

    public static func createDefault() -> Codeplug {
        NomeDefaults.create(modelIdentifier: identifier, size: codeplugSize, maxChannels: maxChannels)
    }
    public static func validate(_ codeplug: Codeplug) -> [ValidationIssue] {
        NomeValidation.validate(codeplug, band: frequencyBand, maxChannels: maxChannels)
    }
    public static func applyDependencies(field: String, in codeplug: Codeplug) {}
}

// MARK: - Nome Shared

enum NomeNodes {
    static func nodes(maxChannels: Int) -> [CodeplugNode] {
        var channelChildren: [CodeplugNode] = []
        for ch in 0..<maxChannels {
            channelChildren.append(CodeplugNode(
                id: "nome.channel.\(ch)", name: "channel\(ch + 1)",
                displayName: "Channel \(ch + 1)", category: .channel,
                fields: [
                    NomeFields.channelName(channel: ch),
                    NomeFields.channelRxFreq(channel: ch),
                    NomeFields.channelTxFreq(channel: ch),
                    NomeFields.channelRxBandwidth(channel: ch),
                    NomeFields.channelTxBandwidth(channel: ch),
                    NomeFields.channelTxPower(channel: ch),
                    NomeFields.channelRxCode(channel: ch),
                    NomeFields.channelTxCode(channel: ch),
                    NomeFields.channelScrambleCode(channel: ch),
                    NomeFields.channelDisabled(channel: ch),
                ]
            ))
        }
        return [
            CodeplugNode(id: "nome.general", name: "general", displayName: "General", category: .general, fields: [
                NomeFields.numberOfChannels, NomeFields.quietMode,
                NomeFields.batterySaveDisabled, NomeFields.presetChannel1, NomeFields.presetChannel2,
            ]),
            CodeplugNode(id: "nome.audio", name: "audio", displayName: "Audio", category: .audio, fields: [
                NomeFields.lastCallTone,
            ]),
            CodeplugNode(id: "nome.channels", name: "channels", displayName: "Channels", category: .channel,
                         nodeType: .repeating(count: maxChannels, stride: NomeFields.channelStride), children: channelChildren),
            CodeplugNode(id: "nome.signaling", name: "signaling", displayName: "Signaling", category: .signaling, fields: [
                NomeFields.scrambleDisabled,
            ]),
            CodeplugNode(id: "nome.advanced", name: "advanced", displayName: "Advanced", category: .advanced, fields: [
                NomeFields.codeplugResetDisabled,
            ]),
        ]
    }
}

enum NomeDefaults {
    static func create(modelIdentifier: String, size: Int, maxChannels: Int) -> Codeplug {
        let codeplug = Codeplug(modelIdentifier: modelIdentifier, size: size)
        codeplug.setValue(.uint8(UInt8(maxChannels)), for: NomeFields.numberOfChannels)
        for ch in 0..<maxChannels {
            codeplug.setValue(.string("CH\(ch + 1)"), for: NomeFields.channelName(channel: ch))
        }
        codeplug.clearModifications()
        return codeplug
    }
}

enum NomeValidation {
    static func validate(_ codeplug: Codeplug, band: FrequencyBand, maxChannels: Int) -> [ValidationIssue] {
        var issues: [ValidationIssue] = []
        for ch in 0..<maxChannels {
            let rxField = NomeFields.channelRxFreq(channel: ch)
            if let raw = codeplug.getValue(for: rxField).intValue {
                let mhz = Double(raw) / 10000.0
                if mhz != 0 && (mhz < band.lowerBound || mhz > band.upperBound) {
                    issues.append(ValidationIssue(severity: .error, fieldID: rxField.id,
                        message: "Channel \(ch + 1) RX: \(mhz) MHz outside \(band.name) band"))
                }
            }
            let txField = NomeFields.channelTxFreq(channel: ch)
            if let raw = codeplug.getValue(for: txField).intValue {
                let mhz = Double(raw) / 10000.0
                if mhz != 0 && (mhz < band.lowerBound || mhz > band.upperBound) {
                    issues.append(ValidationIssue(severity: .error, fieldID: txField.id,
                        message: "Channel \(ch + 1) TX: \(mhz) MHz outside \(band.name) band"))
                }
            }
        }
        return issues
    }
}
