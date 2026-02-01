import Foundation

/// Standard radio constants for CTCSS tones, DCS codes, DMR parameters, etc.
public struct RadioConstants: Sendable {

    // MARK: - CTCSS/PL Tones

    /// Standard EIA CTCSS (Continuous Tone-Coded Squelch System) tones in Hz.
    /// Also known as PL (Private Line) tones.
    /// Index 0 is reserved for "None" (0.0 Hz).
    public static let ctcssTones: [Double] = [
        0.0,    // None
        67.0, 69.3, 71.9, 74.4, 77.0, 79.7, 82.5, 85.4, 88.5, 91.5,
        94.8, 97.4, 100.0, 103.5, 107.2, 110.9, 114.8, 118.8, 123.0, 127.3,
        131.8, 136.5, 141.3, 146.2, 150.0, 151.4, 156.7, 159.8, 162.2, 165.5,
        167.9, 171.3, 173.8, 177.3, 179.9, 183.5, 186.2, 189.9, 192.8, 196.6,
        199.5, 203.5, 206.5, 210.7, 218.1, 225.7, 229.1, 233.6, 241.8, 250.3, 254.1
    ]

    /// Finds the closest CTCSS tone to a given frequency.
    /// - Parameter frequency: The frequency to match in Hz
    /// - Returns: The closest standard CTCSS tone, or 0.0 if frequency is <= 0
    public static func closestCTCSSTone(to frequency: Double) -> Double {
        guard frequency > 0 else { return 0.0 }
        return ctcssTones.dropFirst().min(by: { abs($0 - frequency) < abs($1 - frequency) }) ?? 0.0
    }

    /// Validates that a CTCSS tone is in the standard list.
    /// - Parameter tone: The tone frequency in Hz
    /// - Returns: true if the tone is 0.0 (None) or matches a standard tone
    public static func isValidCTCSS(_ tone: Double) -> Bool {
        if tone == 0.0 { return true }
        return ctcssTones.contains { abs($0 - tone) < 0.05 }
    }

    /// Formats a CTCSS tone for display.
    public static func formatCTCSSTone(_ tone: Double) -> String {
        if tone <= 0 { return "None" }
        return String(format: "%.1f Hz", tone)
    }

    // MARK: - DCS Codes

    /// Standard DCS (Digital-Coded Squelch) codes in octal notation.
    /// Also known as DPL (Digital Private Line) codes.
    /// These are stored as decimal representations of octal codes.
    public static let dcsCodes: [Int] = [
        0,    // None
        // 0xx series
        023, 025, 026, 031, 032, 036, 043, 047, 051, 053, 054, 065, 071, 072, 073, 074,
        // 1xx series
        114, 115, 116, 122, 125, 131, 132, 134, 143, 145, 152, 155, 156, 162, 165, 172, 174,
        // 2xx series
        205, 212, 223, 225, 226, 243, 244, 245, 246, 251, 252, 255, 261, 263, 265, 266, 271,
        // 3xx series
        306, 311, 315, 325, 331, 332, 343, 346, 351, 356, 364, 365, 371,
        // 4xx series
        411, 412, 413, 423, 431, 432, 445, 446, 452, 454, 455, 462, 464, 465, 466,
        // 5xx series
        503, 506, 516, 523, 526, 532, 546, 565,
        // 6xx series
        606, 612, 624, 627, 631, 632, 654, 662, 664,
        // 7xx series
        703, 712, 723, 731, 732, 734, 743, 754
    ]

    /// Formats a DCS code for display.
    /// - Parameters:
    ///   - code: The DCS code (stored as decimal representation of octal)
    ///   - inverted: Whether to use inverted polarity
    /// - Returns: Formatted string like "D023N" or "D023I", or "None" if code is 0
    public static func formatDCSCode(_ code: Int, inverted: Bool = false) -> String {
        if code <= 0 { return "None" }
        let polarity = inverted ? "I" : "N"
        return String(format: "D%03o%@", code, polarity)
    }

    /// Validates that a DCS code is in the standard list.
    /// - Parameter code: The DCS code to validate
    /// - Returns: true if the code is 0 (None) or matches a standard code
    public static func isValidDCS(_ code: Int) -> Bool {
        dcsCodes.contains(code)
    }

    // MARK: - DMR Parameters

    /// DMR Color Codes (0-15).
    public static let colorCodes: [Int] = Array(0...15)

    /// DMR Timeslots.
    public static let timeslots: [Int] = [1, 2]

    // MARK: - Zone/Channel Limits

    /// Maximum number of channels per zone (MOTOTRBO standard).
    public static let maxChannelsPerZone = 16

    // MARK: - Frequency Ranges

    /// VHF frequency range in Hz.
    public static let vhfRange: ClosedRange<UInt32> = 136_000_000...174_000_000

    /// UHF frequency range in Hz.
    public static let uhfRange: ClosedRange<UInt32> = 400_000_000...527_000_000

    /// Default frequency for new UHF channels (Hz).
    public static let defaultUHFFrequency: UInt32 = 450_000_000

    /// Default frequency for new VHF channels (Hz).
    public static let defaultVHFFrequency: UInt32 = 150_000_000

    /// Validates that a frequency is within a valid radio band.
    /// - Parameter hz: Frequency in Hz
    /// - Returns: true if the frequency is within VHF or UHF range
    public static func isValidFrequency(_ hz: UInt32) -> Bool {
        vhfRange.contains(hz) || uhfRange.contains(hz)
    }

    /// Returns the appropriate default frequency for a given band.
    /// - Parameter currentHz: Current frequency to determine band
    /// - Returns: Default frequency for the detected band (UHF if ambiguous)
    public static func defaultFrequency(forBand currentHz: UInt32? = nil) -> UInt32 {
        if let current = currentHz, vhfRange.contains(current) {
            return defaultVHFFrequency
        }
        return defaultUHFFrequency
    }

    // MARK: - Frequency Steps

    /// Common frequency step sizes used in radio programming.
    public enum FrequencyStep: Int, CaseIterable, Sendable {
        case step5kHz = 5000
        case step6_25kHz = 6250
        case step12_5kHz = 12500
        case step25kHz = 25000

        public var displayName: String {
            switch self {
            case .step5kHz: return "5 kHz"
            case .step6_25kHz: return "6.25 kHz"
            case .step12_5kHz: return "12.5 kHz"
            case .step25kHz: return "25 kHz"
            }
        }

        public var hertz: Int { rawValue }
    }

    // MARK: - Power Levels

    public enum PowerLevel: String, CaseIterable, Sendable {
        case low = "Low"
        case high = "High"

        public var isHigh: Bool { self == .high }
    }

    // MARK: - Bandwidth

    public enum Bandwidth: String, CaseIterable, Sendable {
        case narrow = "12.5 kHz"
        case wide = "25 kHz"

        public var isWide: Bool { self == .wide }
    }

    // MARK: - Squelch Types

    public enum SquelchType: Int, CaseIterable, Sendable {
        case carrier = 0
        case ctcssDcs = 1
        case tight = 2

        public var displayName: String {
            switch self {
            case .carrier: return "Carrier"
            case .ctcssDcs: return "CTCSS/DCS"
            case .tight: return "Tight"
            }
        }
    }

    // MARK: - Privacy Types

    public enum PrivacyType: Int, CaseIterable, Sendable {
        case none = 0
        case basic = 1
        case enhanced = 2
        case aes256 = 3

        public var displayName: String {
            switch self {
            case .none: return "None"
            case .basic: return "Basic"
            case .enhanced: return "Enhanced"
            case .aes256: return "AES-256"
            }
        }
    }

    // MARK: - Contact Types

    public enum ContactType: Int, CaseIterable, Sendable {
        case privateCall = 0
        case groupCall = 1
        case allCall = 2

        public var displayName: String {
            switch self {
            case .privateCall: return "Private Call"
            case .groupCall: return "Group Call"
            case .allCall: return "All Call"
            }
        }
    }

    // MARK: - Timing Leader

    public enum TimingLeader: Int, CaseIterable, Sendable {
        case either = 0
        case preferred = 1
        case followed = 2

        public var displayName: String {
            switch self {
            case .either: return "Either"
            case .preferred: return "Preferred"
            case .followed: return "Followed"
            }
        }
    }
}
