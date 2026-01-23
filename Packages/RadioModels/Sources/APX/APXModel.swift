import Foundation
import RadioCore
import RadioModelCore

/// APX900 — 700/800 MHz P25 Phase I/II portable radio, 512 channels.
public enum APX900: RadioModel {
    public static let identifier = "APX900"
    public static let displayName = "APX 900"
    public static let family: RadioFamily = .apx
    public static let codeplugSize = 262144
    public static let maxChannels = 512
    public static let frequencyBand: FrequencyBand = .band700800
    public static let nodes: [CodeplugNode] = APXNodes.nodes(maxChannels: 32, maxZones: 16, hasTrunking: true)

    public static func createDefault() -> Codeplug {
        APXDefaults.create(modelIdentifier: identifier, size: codeplugSize, maxChannels: 16, band: frequencyBand)
    }
    public static func validate(_ codeplug: Codeplug) -> [ValidationIssue] {
        APXValidation.validate(codeplug, band: frequencyBand, maxChannels: 32)
    }
    public static func applyDependencies(field: String, in codeplug: Codeplug) {}
}

/// APX4000 — Multi-band P25 portable, 2048 channels, VHF/UHF/700/800.
public enum APX4000UHF: RadioModel {
    public static let identifier = "APX4000-UHF"
    public static let displayName = "APX 4000 (UHF)"
    public static let family: RadioFamily = .apx
    public static let codeplugSize = 524288
    public static let maxChannels = 2048
    public static let frequencyBand: FrequencyBand = .uhf
    public static let nodes: [CodeplugNode] = APXNodes.nodes(maxChannels: 48, maxZones: 32, hasTrunking: true)

    public static func createDefault() -> Codeplug {
        APXDefaults.create(modelIdentifier: identifier, size: codeplugSize, maxChannels: 16, band: frequencyBand)
    }
    public static func validate(_ codeplug: Codeplug) -> [ValidationIssue] {
        APXValidation.validate(codeplug, band: frequencyBand, maxChannels: 48)
    }
    public static func applyDependencies(field: String, in codeplug: Codeplug) {}
}

/// APX4000 (VHF) — Multi-band P25 portable, 2048 channels.
public enum APX4000VHF: RadioModel {
    public static let identifier = "APX4000-VHF"
    public static let displayName = "APX 4000 (VHF)"
    public static let family: RadioFamily = .apx
    public static let codeplugSize = 524288
    public static let maxChannels = 2048
    public static let frequencyBand: FrequencyBand = .vhf
    public static let nodes: [CodeplugNode] = APXNodes.nodes(maxChannels: 48, maxZones: 32, hasTrunking: true)

    public static func createDefault() -> Codeplug {
        APXDefaults.create(modelIdentifier: identifier, size: codeplugSize, maxChannels: 16, band: frequencyBand)
    }
    public static func validate(_ codeplug: Codeplug) -> [ValidationIssue] {
        APXValidation.validate(codeplug, band: frequencyBand, maxChannels: 48)
    }
    public static func applyDependencies(field: String, in codeplug: Codeplug) {}
}

/// APX6000 — Multi-band P25 portable with full display, 2048 channels, GPS, Bluetooth.
public enum APX6000UHF: RadioModel {
    public static let identifier = "APX6000-UHF"
    public static let displayName = "APX 6000 (UHF)"
    public static let family: RadioFamily = .apx
    public static let codeplugSize = 524288
    public static let maxChannels = 2048
    public static let frequencyBand: FrequencyBand = .uhf
    public static let nodes: [CodeplugNode] = APXNodes.nodes(maxChannels: 64, maxZones: 64, hasTrunking: true)

    public static func createDefault() -> Codeplug {
        APXDefaults.create(modelIdentifier: identifier, size: codeplugSize, maxChannels: 16, band: frequencyBand)
    }
    public static func validate(_ codeplug: Codeplug) -> [ValidationIssue] {
        APXValidation.validate(codeplug, band: frequencyBand, maxChannels: 64)
    }
    public static func applyDependencies(field: String, in codeplug: Codeplug) {}
}

/// APX6000 (VHF) — Multi-band P25 portable with full display.
public enum APX6000VHF: RadioModel {
    public static let identifier = "APX6000-VHF"
    public static let displayName = "APX 6000 (VHF)"
    public static let family: RadioFamily = .apx
    public static let codeplugSize = 524288
    public static let maxChannels = 2048
    public static let frequencyBand: FrequencyBand = .vhf
    public static let nodes: [CodeplugNode] = APXNodes.nodes(maxChannels: 64, maxZones: 64, hasTrunking: true)

    public static func createDefault() -> Codeplug {
        APXDefaults.create(modelIdentifier: identifier, size: codeplugSize, maxChannels: 16, band: frequencyBand)
    }
    public static func validate(_ codeplug: Codeplug) -> [ValidationIssue] {
        APXValidation.validate(codeplug, band: frequencyBand, maxChannels: 64)
    }
    public static func applyDependencies(field: String, in codeplug: Codeplug) {}
}

/// APX6000 (700/800) — Multi-band P25 portable for public safety.
public enum APX6000_700: RadioModel {
    public static let identifier = "APX6000-700"
    public static let displayName = "APX 6000 (700/800)"
    public static let family: RadioFamily = .apx
    public static let codeplugSize = 524288
    public static let maxChannels = 2048
    public static let frequencyBand: FrequencyBand = .band700800
    public static let nodes: [CodeplugNode] = APXNodes.nodes(maxChannels: 64, maxZones: 64, hasTrunking: true)

    public static func createDefault() -> Codeplug {
        APXDefaults.create(modelIdentifier: identifier, size: codeplugSize, maxChannels: 16, band: frequencyBand)
    }
    public static func validate(_ codeplug: Codeplug) -> [ValidationIssue] {
        APXValidation.validate(codeplug, band: frequencyBand, maxChannels: 64)
    }
    public static func applyDependencies(field: String, in codeplug: Codeplug) {}
}

/// APX8000 — All-band P25 flagship portable, 4096 channels, all bands.
public enum APX8000: RadioModel {
    public static let identifier = "APX8000"
    public static let displayName = "APX 8000"
    public static let family: RadioFamily = .apx
    public static let codeplugSize = 1048576
    public static let maxChannels = 4096
    public static let frequencyBand: FrequencyBand = .band700800 // primary; supports all bands
    public static let nodes: [CodeplugNode] = APXNodes.nodes(maxChannels: 64, maxZones: 128, hasTrunking: true)

    public static func createDefault() -> Codeplug {
        APXDefaults.create(modelIdentifier: identifier, size: codeplugSize, maxChannels: 16, band: frequencyBand)
    }
    public static func validate(_ codeplug: Codeplug) -> [ValidationIssue] {
        // APX8000 is multi-band, skip strict band checking
        []
    }
    public static func applyDependencies(field: String, in codeplug: Codeplug) {}
}

// MARK: - APX Shared

enum APXNodes {
    static func nodes(maxChannels: Int, maxZones: Int, hasTrunking: Bool) -> [CodeplugNode] {
        let displayChannels = min(maxChannels, 64)
        var channelChildren: [CodeplugNode] = []
        for ch in 0..<displayChannels {
            channelChildren.append(CodeplugNode(
                id: "apx.channel.\(ch)", name: "channel\(ch + 1)",
                displayName: "Channel \(ch + 1)", category: .channel,
                fields: [
                    APXFields.channelName(channel: ch),
                    APXFields.channelRxFreq(channel: ch),
                    APXFields.channelTxFreq(channel: ch),
                    APXFields.channelTxPower(channel: ch),
                    APXFields.channelBandwidth(channel: ch),
                    APXFields.channelMode(channel: ch),
                    APXFields.channelNAC(channel: ch),
                    APXFields.channelEncryption(channel: ch),
                    APXFields.channelTalkgroup(channel: ch),
                ]
            ))
        }

        var result: [CodeplugNode] = [
            CodeplugNode(id: "apx.general", name: "general", displayName: "General", category: .general, fields: [
                APXFields.radioId, APXFields.radioAlias, APXFields.numberOfChannels,
                APXFields.defaultZone, APXFields.backlightTimer, APXFields.introScreenText,
            ]),
            CodeplugNode(id: "apx.audio", name: "audio", displayName: "Audio", category: .audio, fields: [
                APXFields.volumeLevel, APXFields.keyBeepEnabled, APXFields.alertToneVolume,
            ]),
            CodeplugNode(id: "apx.channels", name: "channels", displayName: "Channels", category: .channel,
                         nodeType: .repeating(count: displayChannels, stride: APXFields.channelStride), children: channelChildren),
            CodeplugNode(id: "apx.signaling", name: "signaling", displayName: "Signaling", category: .signaling, fields: [
                APXFields.emergencyEnabled, APXFields.emergencyType,
                APXFields.manDownEnabled, APXFields.manDownTimer,
            ]),
            CodeplugNode(id: "apx.scan", name: "scan", displayName: "Scan", category: .scan, fields: [
                APXFields.scanAutoStart, APXFields.priorityScanEnabled,
            ]),
            CodeplugNode(id: "apx.advanced", name: "advanced", displayName: "Advanced", category: .advanced, fields: [
                APXFields.totTimeout, APXFields.encryptionType,
                APXFields.gpsEnabled, APXFields.gpsReportInterval,
                APXFields.otaEnabled, APXFields.passwordEnabled,
            ]),
        ]

        if hasTrunking {
            result.append(CodeplugNode(id: "apx.trunking", name: "trunking", displayName: "Trunking", category: .advanced, fields: [
                APXFields.trunkingEnabled, APXFields.systemType, APXFields.wacn, APXFields.systemId,
            ]))
        }

        return result
    }
}

enum APXDefaults {
    static func create(modelIdentifier: String, size: Int, maxChannels: Int, band: FrequencyBand) -> Codeplug {
        let codeplug = Codeplug(modelIdentifier: modelIdentifier, size: size)
        codeplug.setValue(.uint8(UInt8(min(maxChannels, 255))), for: APXFields.numberOfChannels)
        codeplug.setValue(.uint8(5), for: APXFields.volumeLevel)
        codeplug.setValue(.uint32(1), for: APXFields.radioId)
        codeplug.setValue(.string("APX"), for: APXFields.radioAlias)

        let baseFreq: UInt32
        switch band {
        case .uhf: baseFreq = 4500000
        case .vhf: baseFreq = 1500000
        default: baseFreq = 7700000 // 770 MHz for 700/800 band
        }

        for ch in 0..<min(maxChannels, 16) {
            let freq = baseFreq + UInt32(ch) * 1250
            codeplug.setValue(.uint32(freq), for: APXFields.channelRxFreq(channel: ch))
            codeplug.setValue(.uint32(freq), for: APXFields.channelTxFreq(channel: ch))
            codeplug.setValue(.string("CH\(ch + 1)"), for: APXFields.channelName(channel: ch))
        }
        codeplug.clearModifications()
        return codeplug
    }
}

enum APXValidation {
    static func validate(_ codeplug: Codeplug, band: FrequencyBand, maxChannels: Int) -> [ValidationIssue] {
        var issues: [ValidationIssue] = []
        for ch in 0..<maxChannels {
            let rxField = APXFields.channelRxFreq(channel: ch)
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
