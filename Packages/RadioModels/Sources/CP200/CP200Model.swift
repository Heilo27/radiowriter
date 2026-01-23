import Foundation
import RadioCore
import RadioModelCore

/// CP200d (UHF) — 4-watt UHF commercial portable radio with 16 channels, analog/digital.
public enum CP200dUHF: RadioModel {
    public static let identifier = "CP200d-UHF"
    public static let displayName = "CP200d (UHF)"
    public static let family: RadioFamily = .cp200
    public static let codeplugSize = 16384
    public static let maxChannels = 16
    public static let frequencyBand: FrequencyBand = .uhf
    public static let nodes: [CodeplugNode] = CP200Nodes.nodes(maxChannels: maxChannels, band: frequencyBand)

    public static func createDefault() -> Codeplug {
        CP200Defaults.create(modelIdentifier: identifier, size: codeplugSize, maxChannels: maxChannels, band: frequencyBand)
    }
    public static func validate(_ codeplug: Codeplug) -> [ValidationIssue] {
        CP200Validation.validate(codeplug, band: frequencyBand, maxChannels: maxChannels)
    }
    public static func applyDependencies(field: String, in codeplug: Codeplug) {
        CP200Dependencies.apply(field: field, in: codeplug)
    }
}

/// CP200d (VHF) — 5-watt VHF commercial portable radio with 16 channels, analog/digital.
public enum CP200dVHF: RadioModel {
    public static let identifier = "CP200d-VHF"
    public static let displayName = "CP200d (VHF)"
    public static let family: RadioFamily = .cp200
    public static let codeplugSize = 16384
    public static let maxChannels = 16
    public static let frequencyBand: FrequencyBand = .vhf
    public static let nodes: [CodeplugNode] = CP200Nodes.nodes(maxChannels: maxChannels, band: frequencyBand)

    public static func createDefault() -> Codeplug {
        CP200Defaults.create(modelIdentifier: identifier, size: codeplugSize, maxChannels: maxChannels, band: frequencyBand)
    }
    public static func validate(_ codeplug: Codeplug) -> [ValidationIssue] {
        CP200Validation.validate(codeplug, band: frequencyBand, maxChannels: maxChannels)
    }
    public static func applyDependencies(field: String, in codeplug: Codeplug) {
        CP200Dependencies.apply(field: field, in: codeplug)
    }
}

// MARK: - CP200 Shared

enum CP200Nodes {
    static func nodes(maxChannels: Int, band: FrequencyBand) -> [CodeplugNode] {
        var channelChildren: [CodeplugNode] = []
        for ch in 0..<maxChannels {
            channelChildren.append(CodeplugNode(
                id: "cp200.channel.\(ch)", name: "channel\(ch + 1)",
                displayName: "Channel \(ch + 1)", category: .channel,
                fields: [
                    CP200Fields.channelName(channel: ch),
                    CP200Fields.channelRxFreq(channel: ch),
                    CP200Fields.channelTxFreq(channel: ch),
                    CP200Fields.channelTxPower(channel: ch),
                    CP200Fields.channelBandwidth(channel: ch),
                    CP200Fields.channelMode(channel: ch),
                    CP200Fields.channelColorCode(channel: ch),
                    CP200Fields.channelRxCode(channel: ch),
                    CP200Fields.channelTxCode(channel: ch),
                    CP200Fields.channelScanAdd(channel: ch),
                ]
            ))
        }

        var scanChildren: [CodeplugNode] = []
        scanChildren.append(CodeplugNode(
            id: "cp200.scanlist.0", name: "scanList1",
            displayName: "Scan List 1", category: .scan,
            fields: [CP200Fields.scanListName(list: 0), CP200Fields.scanListPriority1(list: 0), CP200Fields.scanListPriority2(list: 0)]
        ))

        return [
            CodeplugNode(id: "cp200.general", name: "general", displayName: "General", category: .general, fields: [
                CP200Fields.radioId, CP200Fields.radioAlias, CP200Fields.numberOfChannels,
                CP200Fields.powerOnChannel, CP200Fields.backlightTimer,
            ]),
            CodeplugNode(id: "cp200.audio", name: "audio", displayName: "Audio", category: .audio, fields: [
                CP200Fields.volumeLevel, CP200Fields.voxEnabled, CP200Fields.voxSensitivity,
                CP200Fields.keyBeepEnabled, CP200Fields.toneVolume,
            ]),
            CodeplugNode(id: "cp200.channels", name: "channels", displayName: "Channels", category: .channel,
                         nodeType: .repeating(count: maxChannels, stride: CP200Fields.channelStride), children: channelChildren),
            CodeplugNode(id: "cp200.signaling", name: "signaling", displayName: "Signaling", category: .signaling, fields: [
                CP200Fields.mdc1200Id, CP200Fields.mdc1200Enabled,
            ]),
            CodeplugNode(id: "cp200.scan", name: "scan", displayName: "Scan", category: .scan, children: scanChildren),
            CodeplugNode(id: "cp200.advanced", name: "advanced", displayName: "Advanced", category: .advanced, fields: [
                CP200Fields.totTimeout, CP200Fields.squelchLevel, CP200Fields.loneWorkerEnabled,
                CP200Fields.loneWorkerTimer, CP200Fields.emergencyEnabled,
            ]),
        ]
    }
}

enum CP200Defaults {
    static func create(modelIdentifier: String, size: Int, maxChannels: Int, band: FrequencyBand) -> Codeplug {
        let codeplug = Codeplug(modelIdentifier: modelIdentifier, size: size)
        codeplug.setValue(.uint8(UInt8(maxChannels)), for: CP200Fields.numberOfChannels)
        codeplug.setValue(.uint8(5), for: CP200Fields.volumeLevel)
        codeplug.setValue(.uint32(1), for: CP200Fields.radioId)

        let baseFreq: UInt32 = band == .uhf ? 4500000 : 1500000
        for ch in 0..<maxChannels {
            let freq = baseFreq + UInt32(ch) * 1250 // 12.5 kHz spacing
            codeplug.setValue(.uint32(freq), for: CP200Fields.channelRxFreq(channel: ch))
            codeplug.setValue(.uint32(freq), for: CP200Fields.channelTxFreq(channel: ch))
            codeplug.setValue(.string("CH\(ch + 1)"), for: CP200Fields.channelName(channel: ch))
        }
        codeplug.clearModifications()
        return codeplug
    }
}

enum CP200Validation {
    static func validate(_ codeplug: Codeplug, band: FrequencyBand, maxChannels: Int) -> [ValidationIssue] {
        var issues: [ValidationIssue] = []
        for ch in 0..<maxChannels {
            let rxField = CP200Fields.channelRxFreq(channel: ch)
            if let raw = codeplug.getValue(for: rxField).intValue {
                let mhz = Double(raw) / 10000.0
                if mhz != 0 && (mhz < band.lowerBound || mhz > band.upperBound) {
                    issues.append(ValidationIssue(severity: .error, fieldID: rxField.id,
                        message: "Channel \(ch + 1) RX: \(mhz) MHz outside \(band.name) band"))
                }
            }
            let txField = CP200Fields.channelTxFreq(channel: ch)
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

enum CP200Dependencies {
    static func apply(field: String, in codeplug: Codeplug) {
        if field == CP200Fields.voxEnabled.id {
            let voxEnabled = codeplug.getValue(for: CP200Fields.voxEnabled).boolValue ?? false
            if !voxEnabled {
                codeplug.setValue(.uint8(0), for: CP200Fields.voxSensitivity)
            }
        }
    }
}
