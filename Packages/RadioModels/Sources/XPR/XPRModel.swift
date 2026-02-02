import Foundation
import RadioCore
import RadioModelCore

/// XPR3300e — 16-channel UHF/VHF DMR portable, basic MOTOTRBO radio.
public enum XPR3300eUHF: RadioModel {
    public static let identifier = "XPR3300e-UHF"
    public static let displayName = "XPR 3300e (UHF)"
    public static let family: RadioFamily = .xpr
    public static let codeplugSize = 32768
    public static let maxChannels = 16
    public static let frequencyBand: FrequencyBand = .uhf
    public static let nodes: [CodeplugNode] = XPRNodes.nodes(maxChannels: maxChannels, maxZones: 2, hasGPS: false)

    public static func createDefault() -> Codeplug {
        XPRDefaults.create(modelIdentifier: identifier, size: codeplugSize, maxChannels: maxChannels, band: frequencyBand)
    }
    public static func validate(_ codeplug: Codeplug) -> [ValidationIssue] {
        XPRValidation.validate(codeplug, band: frequencyBand, maxChannels: maxChannels)
    }
    public static func applyDependencies(field: String, in codeplug: Codeplug) {}
}

/// XPR3300e (VHF) — 16-channel VHF DMR portable, basic MOTOTRBO radio.
public enum XPR3300eVHF: RadioModel {
    public static let identifier = "XPR3300e-VHF"
    public static let displayName = "XPR 3300e (VHF)"
    public static let family: RadioFamily = .xpr
    public static let codeplugSize = 32768
    public static let maxChannels = 16
    public static let frequencyBand: FrequencyBand = .vhf
    public static let nodes: [CodeplugNode] = XPRNodes.nodes(maxChannels: maxChannels, maxZones: 2, hasGPS: false)

    public static func createDefault() -> Codeplug {
        XPRDefaults.create(modelIdentifier: identifier, size: codeplugSize, maxChannels: maxChannels, band: frequencyBand)
    }
    public static func validate(_ codeplug: Codeplug) -> [ValidationIssue] {
        XPRValidation.validate(codeplug, band: frequencyBand, maxChannels: maxChannels)
    }
    public static func applyDependencies(field: String, in codeplug: Codeplug) {}
}

/// XPR3500e (UHF) — 128-channel UHF DMR portable with display.
public enum XPR3500eUHF: RadioModel {
    public static let identifier = "XPR3500e-UHF"
    public static let displayName = "XPR 3500e (UHF)"
    public static let family: RadioFamily = .xpr
    public static let codeplugSize = 65536
    public static let maxChannels = 128
    public static let frequencyBand: FrequencyBand = .uhf
    public static let nodes: [CodeplugNode] = XPRNodes.nodes(maxChannels: maxChannels, maxZones: 16, hasGPS: false)
    /// Model numbers reported by XPR 3500e UHF radios (e.g., H02RDH9VA1AN)
    public static let modelNumbers: [String] = ["H02RDH9VA1AN", "AAH02RDH9VA1AN"]

    public static func createDefault() -> Codeplug {
        XPRDefaults.create(modelIdentifier: identifier, size: codeplugSize, maxChannels: maxChannels, band: frequencyBand)
    }
    public static func validate(_ codeplug: Codeplug) -> [ValidationIssue] {
        XPRValidation.validate(codeplug, band: frequencyBand, maxChannels: maxChannels)
    }
    public static func applyDependencies(field: String, in codeplug: Codeplug) {}
}

/// XPR3500e (VHF) — 128-channel VHF DMR portable with display.
public enum XPR3500eVHF: RadioModel {
    public static let identifier = "XPR3500e-VHF"
    public static let displayName = "XPR 3500e (VHF)"
    public static let family: RadioFamily = .xpr
    public static let codeplugSize = 65536
    public static let maxChannels = 128
    public static let frequencyBand: FrequencyBand = .vhf
    public static let nodes: [CodeplugNode] = XPRNodes.nodes(maxChannels: maxChannels, maxZones: 16, hasGPS: false)

    public static func createDefault() -> Codeplug {
        XPRDefaults.create(modelIdentifier: identifier, size: codeplugSize, maxChannels: maxChannels, band: frequencyBand)
    }
    public static func validate(_ codeplug: Codeplug) -> [ValidationIssue] {
        XPRValidation.validate(codeplug, band: frequencyBand, maxChannels: maxChannels)
    }
    public static func applyDependencies(field: String, in codeplug: Codeplug) {}
}

/// XPR7350e (UHF) — 32-channel UHF DMR portable with GPS and Bluetooth.
public enum XPR7350eUHF: RadioModel {
    public static let identifier = "XPR7350e-UHF"
    public static let displayName = "XPR 7350e (UHF)"
    public static let family: RadioFamily = .xpr
    public static let codeplugSize = 131072
    public static let maxChannels = 32
    public static let frequencyBand: FrequencyBand = .uhf
    public static let nodes: [CodeplugNode] = XPRNodes.nodes(maxChannels: maxChannels, maxZones: 8, hasGPS: true)

    public static func createDefault() -> Codeplug {
        XPRDefaults.create(modelIdentifier: identifier, size: codeplugSize, maxChannels: maxChannels, band: frequencyBand)
    }
    public static func validate(_ codeplug: Codeplug) -> [ValidationIssue] {
        XPRValidation.validate(codeplug, band: frequencyBand, maxChannels: maxChannels)
    }
    public static func applyDependencies(field: String, in codeplug: Codeplug) {}
}

/// XPR7550e (UHF) — 1000-channel UHF DMR portable, full display, GPS, Bluetooth, WiFi.
public enum XPR7550eUHF: RadioModel {
    public static let identifier = "XPR7550e-UHF"
    public static let displayName = "XPR 7550e (UHF)"
    public static let family: RadioFamily = .xpr
    public static let codeplugSize = 262144
    public static let maxChannels = 1000
    public static let frequencyBand: FrequencyBand = .uhf
    public static let nodes: [CodeplugNode] = XPRNodes.nodes(maxChannels: min(maxChannels, 64), maxZones: 128, hasGPS: true)

    public static func createDefault() -> Codeplug {
        XPRDefaults.create(modelIdentifier: identifier, size: codeplugSize, maxChannels: min(maxChannels, 16), band: frequencyBand)
    }
    public static func validate(_ codeplug: Codeplug) -> [ValidationIssue] {
        XPRValidation.validate(codeplug, band: frequencyBand, maxChannels: min(maxChannels, 64))
    }
    public static func applyDependencies(field: String, in codeplug: Codeplug) {}
}

/// XPR7550e (VHF) — 1000-channel VHF DMR portable, full display, GPS, Bluetooth, WiFi.
public enum XPR7550eVHF: RadioModel {
    public static let identifier = "XPR7550e-VHF"
    public static let displayName = "XPR 7550e (VHF)"
    public static let family: RadioFamily = .xpr
    public static let codeplugSize = 262144
    public static let maxChannels = 1000
    public static let frequencyBand: FrequencyBand = .vhf
    public static let nodes: [CodeplugNode] = XPRNodes.nodes(maxChannels: min(maxChannels, 64), maxZones: 128, hasGPS: true)

    public static func createDefault() -> Codeplug {
        XPRDefaults.create(modelIdentifier: identifier, size: codeplugSize, maxChannels: min(maxChannels, 16), band: frequencyBand)
    }
    public static func validate(_ codeplug: Codeplug) -> [ValidationIssue] {
        XPRValidation.validate(codeplug, band: frequencyBand, maxChannels: min(maxChannels, 64))
    }
    public static func applyDependencies(field: String, in codeplug: Codeplug) {}
}

// MARK: - XPR Shared

enum XPRNodes {
    static func nodes(maxChannels: Int, maxZones: Int, hasGPS: Bool) -> [CodeplugNode] {
        let displayChannels = min(maxChannels, 64)
        var channelChildren: [CodeplugNode] = []
        for ch in 0..<displayChannels {
            channelChildren.append(CodeplugNode(
                id: "xpr.channel.\(ch)", name: "channel\(ch + 1)",
                displayName: "Channel \(ch + 1)", category: .channel,
                fields: [
                    XPRFields.channelName(channel: ch),
                    XPRFields.channelRxFreq(channel: ch),
                    XPRFields.channelTxFreq(channel: ch),
                    XPRFields.channelTxPower(channel: ch),
                    XPRFields.channelBandwidth(channel: ch),
                    XPRFields.channelMode(channel: ch),
                    XPRFields.channelColorCode(channel: ch),
                    XPRFields.channelTimeSlot(channel: ch),
                    XPRFields.channelContactName(channel: ch),
                    XPRFields.channelRxGroupList(channel: ch),
                ]
            ))
        }

        var result: [CodeplugNode] = [
            CodeplugNode(id: "xpr.general", name: "general", displayName: "General", category: .general, fields: [
                XPRFields.radioId, XPRFields.radioAlias, XPRFields.numberOfChannels,
                XPRFields.powerOnChannel, XPRFields.backlightTimer, XPRFields.introScreenText,
            ]),
            CodeplugNode(id: "xpr.audio", name: "audio", displayName: "Audio", category: .audio, fields: [
                XPRFields.volumeLevel, XPRFields.voxEnabled, XPRFields.voxSensitivity, XPRFields.keyBeepEnabled,
            ]),
            CodeplugNode(id: "xpr.channels", name: "channels", displayName: "Channels", category: .channel,
                         nodeType: .repeating(count: displayChannels, stride: XPRFields.channelStride), children: channelChildren),
            CodeplugNode(id: "xpr.contacts", name: "contacts", displayName: "Contacts", category: .contacts, fields: [
                XPRFields.maxContacts, XPRFields.contactsCount,
            ]),
            CodeplugNode(id: "xpr.signaling", name: "signaling", displayName: "Signaling", category: .signaling, fields: [
                XPRFields.emergencyAlarmType, XPRFields.txInterruptEnabled,
            ]),
            CodeplugNode(id: "xpr.scan", name: "scan", displayName: "Scan", category: .scan, fields: [
                XPRFields.scanAutoStart, XPRFields.scanTalkback,
            ]),
            CodeplugNode(id: "xpr.advanced", name: "advanced", displayName: "Advanced", category: .advanced, fields: [
                XPRFields.totTimeout, XPRFields.loneWorkerEnabled, XPRFields.loneWorkerTimer,
                XPRFields.passwordEnabled, XPRFields.encryptionEnabled,
            ]),
        ]

        if hasGPS {
            result.append(CodeplugNode(id: "xpr.gps", name: "gps", displayName: "GPS", category: .advanced, fields: [
                XPRFields.gpsEnabled, XPRFields.gpsReportInterval,
            ]))
        }

        return result
    }
}

enum XPRDefaults {
    static func create(modelIdentifier: String, size: Int, maxChannels: Int, band: FrequencyBand) -> Codeplug {
        let codeplug = Codeplug(modelIdentifier: modelIdentifier, size: size)
        codeplug.setValue(.uint8(UInt8(min(maxChannels, 16))), for: XPRFields.numberOfChannels)
        codeplug.setValue(.uint8(5), for: XPRFields.volumeLevel)
        codeplug.setValue(.uint32(1), for: XPRFields.radioId)
        codeplug.setValue(.string("Radio"), for: XPRFields.radioAlias)

        let baseFreq: UInt32 = band == .uhf ? 4500000 : 1500000
        let channelsToInit = min(maxChannels, 16)
        for ch in 0..<channelsToInit {
            let freq = baseFreq + UInt32(ch) * 1250
            codeplug.setValue(.uint32(freq), for: XPRFields.channelRxFreq(channel: ch))
            codeplug.setValue(.uint32(freq), for: XPRFields.channelTxFreq(channel: ch))
            codeplug.setValue(.string("CH\(ch + 1)"), for: XPRFields.channelName(channel: ch))
        }
        codeplug.clearModifications()
        return codeplug
    }
}

enum XPRValidation {
    static func validate(_ codeplug: Codeplug, band: FrequencyBand, maxChannels: Int) -> [ValidationIssue] {
        var issues: [ValidationIssue] = []
        for ch in 0..<maxChannels {
            let rxField = XPRFields.channelRxFreq(channel: ch)
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
