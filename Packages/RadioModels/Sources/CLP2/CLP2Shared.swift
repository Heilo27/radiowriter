import Foundation
import RadioCore
import RadioModelCore

// MARK: - Shared node builder for CLP2 family

enum CLP2Nodes {
    static func nodes(maxChannels: Int) -> [CodeplugNode] {
        var channelChildren: [CodeplugNode] = []
        for ch in 0..<maxChannels {
            channelChildren.append(CodeplugNode(
                id: "clp2.channel.\(ch)", name: "channel\(ch + 1)",
                displayName: "Channel \(ch + 1)", category: .channel,
                fields: [
                    CLP2Fields.channelFrequency(channel: ch),
                    CLP2Fields.channelName(channel: ch),
                    CLP2Fields.channelBandwidth(channel: ch),
                    CLP2Fields.channelTxCode(channel: ch),
                    CLP2Fields.channelRxCode(channel: ch),
                    CLP2Fields.channelScrambleCode(channel: ch),
                    CLP2Fields.channelScanList(channel: ch),
                ]
            ))
        }

        return [
            CodeplugNode(id: "clp2.general", name: "general", displayName: "General", category: .general, fields: [
                CLP2Fields.numberOfChannels, CLP2Fields.txPowerMode, CLP2Fields.txTimeoutTimer,
                CLP2Fields.pttHoldEnabled, CLP2Fields.ledPattern, CLP2Fields.codeplugResetEnabled,
            ]),
            CodeplugNode(id: "clp2.channels", name: "channels", displayName: "Channels", category: .channel,
                         nodeType: .repeating(count: maxChannels, stride: CLP2Fields.channelStride), children: channelChildren),
            CodeplugNode(id: "clp2.audio", name: "audio", displayName: "Audio", category: .audio, fields: [
                CLP2Fields.alertToneEnabled, CLP2Fields.powerUpTone, CLP2Fields.vpUserModeEnabled,
                CLP2Fields.muteHeadsetVolume,
            ]),
            CodeplugNode(id: "clp2.signaling", name: "signaling", displayName: "Signaling", category: .signaling, fields: [
                CLP2Fields.scrambleEnabled,
            ]),
            CodeplugNode(id: "clp2.bluetooth", name: "bluetooth", displayName: "Bluetooth", category: .bluetooth, fields: [
                CLP2Fields.btAlwaysConnect, CLP2Fields.btPairingPin,
                CLP2Fields.btSidetoneEnabled, CLP2Fields.btVoxLevel, CLP2Fields.btMicGain,
            ]),
        ]
    }
}

// MARK: - Shared defaults

enum CLP2Defaults {
    static func create(modelIdentifier: String, size: Int, maxChannels: Int) -> Codeplug {
        let codeplug = Codeplug(modelIdentifier: modelIdentifier, size: size)
        codeplug.setValue(.uint8(UInt8(maxChannels)), for: CLP2Fields.numberOfChannels)
        let frsFreqs: [UInt32] = [4625625, 4625875, 4626125, 4626375, 4626625, 4626875, 4627125, 4627375]
        for ch in 0..<min(maxChannels, frsFreqs.count) {
            codeplug.setValue(.uint32(frsFreqs[ch]), for: CLP2Fields.channelFrequency(channel: ch))
            codeplug.setValue(.string("CH\(ch + 1)"), for: CLP2Fields.channelName(channel: ch))
        }
        codeplug.clearModifications()
        return codeplug
    }
}

// MARK: - Shared validation

enum CLP2Validation {
    static func validate(_ codeplug: Codeplug, band: FrequencyBand, maxChannels: Int) -> [ValidationIssue] {
        var issues: [ValidationIssue] = []
        for ch in 0..<maxChannels {
            let field = CLP2Fields.channelFrequency(channel: ch)
            if let raw = codeplug.getValue(for: field).intValue {
                let mhz = Double(raw) / 10000.0
                if mhz != 0 && (mhz < band.lowerBound || mhz > band.upperBound) {
                    issues.append(ValidationIssue(severity: .error, fieldID: field.id,
                        message: "Channel \(ch + 1): \(mhz) MHz outside \(band.name) band"))
                }
            }
        }
        return issues
    }
}

// MARK: - Shared dependencies

enum CLP2Dependencies {
    static func apply(field: String, in codeplug: Codeplug) {
        if field == CLP2Fields.scrambleEnabled.id {
            let enabled = codeplug.getValue(for: CLP2Fields.scrambleEnabled).boolValue ?? false
            if !enabled {
                let numCh = codeplug.getValue(for: CLP2Fields.numberOfChannels).intValue ?? 4
                for ch in 0..<numCh {
                    codeplug.setValue(.uint8(0), for: CLP2Fields.channelScrambleCode(channel: ch))
                }
            }
        }
    }
}
