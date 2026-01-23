import Foundation
import RadioCore
import RadioModelCore

/// CLP1010 radio model — basic 1-watt UHF business radio.
/// 1 channel, no display, CTCSS/DPL signaling.
public enum CLP1010: RadioModel {
    public static let identifier = "CLP1010"
    public static let displayName = "CLP 1010"
    public static let family: RadioFamily = .clp
    public static let codeplugSize = 256
    public static let maxChannels = 1
    public static let frequencyBand: FrequencyBand = .uhf

    public static let nodes: [CodeplugNode] = [
        generalNode,
        channelNode,
        audioNode,
        signalingNode,
    ]

    public static func createDefault() -> Codeplug {
        let codeplug = Codeplug(modelIdentifier: identifier, size: codeplugSize)
        // Set default frequency to 462.5625 (FRS channel 1)
        codeplug.setValue(.uint32(4625625), for: CLPFields.channel1Frequency)
        codeplug.setValue(.uint8(1), for: CLPFields.txPower)
        codeplug.setValue(.uint8(5), for: CLPFields.volumeLevel)
        codeplug.setValue(.bool(false), for: CLPFields.voxEnabled)
        codeplug.setValue(.uint8(0), for: CLPFields.ctcssTxTone)
        codeplug.setValue(.uint8(0), for: CLPFields.ctcssRxTone)
        codeplug.clearModifications()
        return codeplug
    }

    public static func validate(_ codeplug: Codeplug) -> [ValidationIssue] {
        var issues: [ValidationIssue] = []

        let freq = codeplug.getValue(for: CLPFields.channel1Frequency)
        if let raw = freq.intValue {
            let mhz = Double(raw) / 10000.0
            if mhz < frequencyBand.lowerBound || mhz > frequencyBand.upperBound {
                issues.append(ValidationIssue(
                    severity: .error,
                    fieldID: CLPFields.channel1Frequency.id,
                    message: "Frequency \(mhz) MHz is outside the UHF band"
                ))
            }
        }

        return issues
    }

    public static func applyDependencies(field: String, in codeplug: Codeplug) {
        // CLP1010 has minimal dependencies
        if field == CLPFields.voxEnabled.id {
            let voxEnabled = codeplug.getValue(for: CLPFields.voxEnabled).boolValue ?? false
            if !voxEnabled {
                codeplug.setValue(.uint8(0), for: CLPFields.voxSensitivity)
            }
        }
    }
}

/// CLP1040 radio model — 4-channel UHF business radio.
public enum CLP1040: RadioModel {
    public static let identifier = "CLP1040"
    public static let displayName = "CLP 1040"
    public static let family: RadioFamily = .clp
    public static let codeplugSize = 512
    public static let maxChannels = 4
    public static let frequencyBand: FrequencyBand = .uhf

    public static let nodes: [CodeplugNode] = [
        generalNode,
        channelsNode,
        audioNode,
        signalingNode,
    ]

    public static func createDefault() -> Codeplug {
        let codeplug = Codeplug(modelIdentifier: identifier, size: codeplugSize)
        // Set default FRS frequencies for channels 1-4
        let frsFreqs: [UInt32] = [4625625, 4625875, 4626125, 4626375]
        for (i, freq) in frsFreqs.enumerated() {
            let field = CLPFields.channelFrequency(channel: i)
            codeplug.setValue(.uint32(freq), for: field)
        }
        codeplug.setValue(.uint8(1), for: CLPFields.txPower)
        codeplug.setValue(.uint8(5), for: CLPFields.volumeLevel)
        codeplug.clearModifications()
        return codeplug
    }

    public static func validate(_ codeplug: Codeplug) -> [ValidationIssue] {
        var issues: [ValidationIssue] = []

        for ch in 0..<maxChannels {
            let field = CLPFields.channelFrequency(channel: ch)
            let freq = codeplug.getValue(for: field)
            if let raw = freq.intValue {
                let mhz = Double(raw) / 10000.0
                if mhz < frequencyBand.lowerBound || mhz > frequencyBand.upperBound {
                    issues.append(ValidationIssue(
                        severity: .error,
                        fieldID: field.id,
                        message: "Channel \(ch + 1): Frequency \(mhz) MHz is outside the UHF band"
                    ))
                }
            }
        }

        return issues
    }

    public static func applyDependencies(field: String, in codeplug: Codeplug) {
        CLP1010.applyDependencies(field: field, in: codeplug)
    }
}
