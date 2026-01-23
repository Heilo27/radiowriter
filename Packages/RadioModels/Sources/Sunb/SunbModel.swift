import Foundation
import RadioCore
import RadioModelCore

/// CLS1450CB — 1-watt UHF business radio (CLS series) with 4 channels.
public enum CLS1450CB: RadioModel {
    public static let identifier = "CLS1450CB"
    public static let displayName = "CLS 1450CB"
    public static let family: RadioFamily = .sunb
    public static let codeplugSize = 2048
    public static let maxChannels = 4
    public static let frequencyBand: FrequencyBand = .uhf
    public static let nodes: [CodeplugNode] = SunbNodes.nodes(maxChannels: maxChannels)

    public static func createDefault() -> Codeplug {
        SunbDefaults.create(modelIdentifier: identifier, size: codeplugSize, maxChannels: maxChannels)
    }
    public static func validate(_ codeplug: Codeplug) -> [ValidationIssue] {
        SunbValidation.validate(codeplug, band: frequencyBand, maxChannels: maxChannels)
    }
    public static func applyDependencies(field: String, in codeplug: Codeplug) {
        SunbDependencies.apply(field: field, in: codeplug)
    }
}

/// CLS1450CH — 1-watt UHF business radio (CLS series) with 8 channels.
public enum CLS1450CH: RadioModel {
    public static let identifier = "CLS1450CH"
    public static let displayName = "CLS 1450CH"
    public static let family: RadioFamily = .sunb
    public static let codeplugSize = 2048
    public static let maxChannels = 8
    public static let frequencyBand: FrequencyBand = .uhf
    public static let nodes: [CodeplugNode] = SunbNodes.nodes(maxChannels: maxChannels)

    public static func createDefault() -> Codeplug {
        SunbDefaults.create(modelIdentifier: identifier, size: codeplugSize, maxChannels: maxChannels)
    }
    public static func validate(_ codeplug: Codeplug) -> [ValidationIssue] {
        SunbValidation.validate(codeplug, band: frequencyBand, maxChannels: maxChannels)
    }
    public static func applyDependencies(field: String, in codeplug: Codeplug) {
        SunbDependencies.apply(field: field, in: codeplug)
    }
}

// MARK: - Sunb Shared

enum SunbNodes {
    static func nodes(maxChannels: Int) -> [CodeplugNode] {
        var channelChildren: [CodeplugNode] = []
        for ch in 0..<maxChannels {
            channelChildren.append(CodeplugNode(
                id: "sunb.channel.\(ch)", name: "channel\(ch + 1)",
                displayName: "Channel \(ch + 1)", category: .channel,
                fields: [
                    SunbFields.channelName(channel: ch),
                    SunbFields.channelRxFreq(channel: ch),
                    SunbFields.channelTxFreq(channel: ch),
                    SunbFields.channelRxBandwidth(channel: ch),
                    SunbFields.channelTxBandwidth(channel: ch),
                    SunbFields.channelTxCode(channel: ch),
                    SunbFields.channelRxCode(channel: ch),
                    SunbFields.channelScrambleCode(channel: ch),
                    SunbFields.channelScanList(channel: ch),
                    SunbFields.channelDisabled(channel: ch),
                    SunbFields.channelRepeaterRxOnly(channel: ch),
                ]
            ))
        }
        return [
            CodeplugNode(id: "sunb.general", name: "general", displayName: "General", category: .general, fields: [
                SunbFields.numberOfChannels, SunbFields.txPowerMode, SunbFields.txTimeoutTimer,
                SunbFields.pttHoldEnabled,
            ]),
            CodeplugNode(id: "sunb.audio", name: "audio", displayName: "Audio", category: .audio, fields: [
                SunbFields.keypadBeep, SunbFields.powerUpTone, SunbFields.vpEnabled,
            ]),
            CodeplugNode(id: "sunb.channels", name: "channels", displayName: "Channels", category: .channel,
                         nodeType: .repeating(count: maxChannels, stride: SunbFields.channelStride), children: channelChildren),
            CodeplugNode(id: "sunb.signaling", name: "signaling", displayName: "Signaling", category: .signaling, fields: [
                SunbFields.scrambleEnabled,
            ]),
            CodeplugNode(id: "sunb.scan", name: "scan", displayName: "Scan", category: .scan, fields: [
                SunbFields.scanListVisible,
            ]),
            CodeplugNode(id: "sunb.advanced", name: "advanced", displayName: "Advanced", category: .advanced, fields: [
                SunbFields.codeplugResetEnabled,
            ]),
        ]
    }
}

enum SunbDefaults {
    static func create(modelIdentifier: String, size: Int, maxChannels: Int) -> Codeplug {
        let codeplug = Codeplug(modelIdentifier: modelIdentifier, size: size)
        codeplug.setValue(.uint8(UInt8(maxChannels)), for: SunbFields.numberOfChannels)
        for ch in 0..<maxChannels {
            codeplug.setValue(.string("CH\(ch + 1)"), for: SunbFields.channelName(channel: ch))
        }
        codeplug.clearModifications()
        return codeplug
    }
}

enum SunbValidation {
    static func validate(_ codeplug: Codeplug, band: FrequencyBand, maxChannels: Int) -> [ValidationIssue] {
        var issues: [ValidationIssue] = []
        for ch in 0..<maxChannels {
            let rxField = SunbFields.channelRxFreq(channel: ch)
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

enum SunbDependencies {
    static func apply(field: String, in codeplug: Codeplug) {
        if field == SunbFields.scrambleEnabled.id {
            let enabled = codeplug.getValue(for: SunbFields.scrambleEnabled).boolValue ?? false
            if !enabled {
                let numCh = codeplug.getValue(for: SunbFields.numberOfChannels).intValue ?? 4
                for ch in 0..<numCh {
                    codeplug.setValue(.uint8(0), for: SunbFields.channelScrambleCode(channel: ch))
                }
            }
        }
    }
}
