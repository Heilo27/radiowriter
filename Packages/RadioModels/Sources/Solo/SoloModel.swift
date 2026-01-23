import Foundation
import RadioCore
import RadioModelCore

/// RDU2020 — 2-watt UHF business radio with 2 channels.
public enum RDU2020: RadioModel {
    public static let identifier = "RDU2020"
    public static let displayName = "RDU 2020"
    public static let family: RadioFamily = .solo
    public static let codeplugSize = 4096
    public static let maxChannels = 2
    public static let frequencyBand: FrequencyBand = .uhf
    public static let nodes: [CodeplugNode] = SoloNodes.nodes(maxChannels: maxChannels)

    public static func createDefault() -> Codeplug {
        SoloDefaults.create(modelIdentifier: identifier, size: codeplugSize, maxChannels: maxChannels)
    }
    public static func validate(_ codeplug: Codeplug) -> [ValidationIssue] {
        SoloValidation.validate(codeplug, band: frequencyBand, maxChannels: maxChannels)
    }
    public static func applyDependencies(field: String, in codeplug: Codeplug) {
        SoloDependencies.apply(field: field, in: codeplug)
    }
}

/// RDU2080 — 2-watt UHF business radio with 8 channels and display.
public enum RDU2080: RadioModel {
    public static let identifier = "RDU2080"
    public static let displayName = "RDU 2080"
    public static let family: RadioFamily = .solo
    public static let codeplugSize = 4096
    public static let maxChannels = 8
    public static let frequencyBand: FrequencyBand = .uhf
    public static let nodes: [CodeplugNode] = SoloNodes.nodes(maxChannels: maxChannels)

    public static func createDefault() -> Codeplug {
        SoloDefaults.create(modelIdentifier: identifier, size: codeplugSize, maxChannels: maxChannels)
    }
    public static func validate(_ codeplug: Codeplug) -> [ValidationIssue] {
        SoloValidation.validate(codeplug, band: frequencyBand, maxChannels: maxChannels)
    }
    public static func applyDependencies(field: String, in codeplug: Codeplug) {
        SoloDependencies.apply(field: field, in: codeplug)
    }
}

/// RDU4100 — 4-watt UHF business radio with 10 channels.
public enum RDU4100: RadioModel {
    public static let identifier = "RDU4100"
    public static let displayName = "RDU 4100"
    public static let family: RadioFamily = .solo
    public static let codeplugSize = 4096
    public static let maxChannels = 10
    public static let frequencyBand: FrequencyBand = .uhf
    public static let nodes: [CodeplugNode] = SoloNodes.nodes(maxChannels: maxChannels)

    public static func createDefault() -> Codeplug {
        SoloDefaults.create(modelIdentifier: identifier, size: codeplugSize, maxChannels: maxChannels)
    }
    public static func validate(_ codeplug: Codeplug) -> [ValidationIssue] {
        SoloValidation.validate(codeplug, band: frequencyBand, maxChannels: maxChannels)
    }
    public static func applyDependencies(field: String, in codeplug: Codeplug) {
        SoloDependencies.apply(field: field, in: codeplug)
    }
}

/// RDU4160 — 4-watt UHF business radio with 16 channels.
public enum RDU4160: RadioModel {
    public static let identifier = "RDU4160"
    public static let displayName = "RDU 4160"
    public static let family: RadioFamily = .solo
    public static let codeplugSize = 4096
    public static let maxChannels = 16
    public static let frequencyBand: FrequencyBand = .uhf
    public static let nodes: [CodeplugNode] = SoloNodes.nodes(maxChannels: maxChannels)

    public static func createDefault() -> Codeplug {
        SoloDefaults.create(modelIdentifier: identifier, size: codeplugSize, maxChannels: maxChannels)
    }
    public static func validate(_ codeplug: Codeplug) -> [ValidationIssue] {
        SoloValidation.validate(codeplug, band: frequencyBand, maxChannels: maxChannels)
    }
    public static func applyDependencies(field: String, in codeplug: Codeplug) {
        SoloDependencies.apply(field: field, in: codeplug)
    }
}

// MARK: - Solo Shared

enum SoloNodes {
    static func nodes(maxChannels: Int) -> [CodeplugNode] {
        var channelChildren: [CodeplugNode] = []
        for ch in 0..<maxChannels {
            channelChildren.append(CodeplugNode(
                id: "solo.channel.\(ch)", name: "channel\(ch + 1)",
                displayName: "Channel \(ch + 1)", category: .channel,
                fields: [
                    SoloFields.channelName(channel: ch),
                    SoloFields.channelRxFreq(channel: ch),
                    SoloFields.channelTxFreq(channel: ch),
                    SoloFields.channelRxBandwidth(channel: ch),
                    SoloFields.channelTxBandwidth(channel: ch),
                    SoloFields.channelTxCode(channel: ch),
                    SoloFields.channelRxCode(channel: ch),
                    SoloFields.channelScrambleCode(channel: ch),
                    SoloFields.channelScanList(channel: ch),
                    SoloFields.channelDisabled(channel: ch),
                    SoloFields.channelRepeaterRxOnly(channel: ch),
                ]
            ))
        }
        return [
            CodeplugNode(id: "solo.general", name: "general", displayName: "General", category: .general, fields: [
                SoloFields.numberOfChannels, SoloFields.txPowerMode, SoloFields.txTimeoutTimer,
                SoloFields.pttHoldEnabled, SoloFields.backlightTimer, SoloFields.password,
            ]),
            CodeplugNode(id: "solo.audio", name: "audio", displayName: "Audio", category: .audio, fields: [
                SoloFields.keypadBeep, SoloFields.powerUpTone, SoloFields.vpEnabled,
            ]),
            CodeplugNode(id: "solo.channels", name: "channels", displayName: "Channels", category: .channel,
                         nodeType: .repeating(count: maxChannels, stride: SoloFields.channelStride), children: channelChildren),
            CodeplugNode(id: "solo.signaling", name: "signaling", displayName: "Signaling", category: .signaling, fields: [
                SoloFields.scrambleEnabled,
            ]),
            CodeplugNode(id: "solo.wrx", name: "wrx", displayName: "Weather Radio", category: .general, fields: [
                SoloFields.wrxAlertEnabled, SoloFields.wrxAlertChannel,
            ]),
            CodeplugNode(id: "solo.advanced", name: "advanced", displayName: "Advanced", category: .advanced, fields: [
                SoloFields.codeplugResetEnabled,
            ]),
        ]
    }
}

enum SoloDefaults {
    static func create(modelIdentifier: String, size: Int, maxChannels: Int) -> Codeplug {
        let codeplug = Codeplug(modelIdentifier: modelIdentifier, size: size)
        codeplug.setValue(.uint8(UInt8(maxChannels)), for: SoloFields.numberOfChannels)
        for ch in 0..<maxChannels {
            codeplug.setValue(.string("CH\(ch + 1)"), for: SoloFields.channelName(channel: ch))
        }
        codeplug.clearModifications()
        return codeplug
    }
}

enum SoloValidation {
    static func validate(_ codeplug: Codeplug, band: FrequencyBand, maxChannels: Int) -> [ValidationIssue] {
        var issues: [ValidationIssue] = []
        for ch in 0..<maxChannels {
            let rxField = SoloFields.channelRxFreq(channel: ch)
            if let raw = codeplug.getValue(for: rxField).intValue {
                let mhz = Double(raw) / 10000.0
                if mhz != 0 && (mhz < band.lowerBound || mhz > band.upperBound) {
                    issues.append(ValidationIssue(severity: .error, fieldID: rxField.id,
                        message: "Channel \(ch + 1) RX: \(mhz) MHz outside \(band.name) band"))
                }
            }
        }
        return issues
    }
}

enum SoloDependencies {
    static func apply(field: String, in codeplug: Codeplug) {
        if field == SoloFields.scrambleEnabled.id {
            let enabled = codeplug.getValue(for: SoloFields.scrambleEnabled).boolValue ?? false
            if !enabled {
                let numCh = codeplug.getValue(for: SoloFields.numberOfChannels).intValue ?? 4
                for ch in 0..<numCh {
                    codeplug.setValue(.uint8(0), for: SoloFields.channelScrambleCode(channel: ch))
                }
            }
        }
    }
}
