import Foundation

/// Transforms raw binary values to/from user-facing display values.
/// For example, a raw frequency value of 4625 might display as "462.5625 MHz".
public protocol ValueTransform: Sendable {
    associatedtype RawValue
    associatedtype DisplayValue

    /// Converts a raw binary value to a display value.
    func toDisplay(_ raw: RawValue) -> DisplayValue

    /// Converts a display value back to a raw binary value.
    func toRaw(_ display: DisplayValue) -> RawValue
}

/// Transforms a frequency stored as a UInt32 (in 100 Hz units) to a MHz string.
public struct FrequencyTransform: ValueTransform {
    public init() {}

    public func toDisplay(_ raw: UInt32) -> String {
        let mhz = Double(raw) / 10000.0
        return String(format: "%.4f", mhz)
    }

    public func toRaw(_ display: String) -> UInt32 {
        guard let mhz = Double(display) else { return 0 }
        let scaled = mhz * 10000.0
        // Guard against overflow - UInt32 max is ~429496.7295 MHz (way above any radio frequency)
        guard scaled >= 0, scaled <= Double(UInt32.max) else { return 0 }
        return UInt32(scaled)
    }
}

/// Transforms a raw power level enum to a display string.
public struct PowerLevelTransform: ValueTransform {
    public let levels: [(raw: UInt8, display: String)]

    public init(levels: [(raw: UInt8, display: String)]) {
        self.levels = levels
    }

    public func toDisplay(_ raw: UInt8) -> String {
        levels.first(where: { $0.raw == raw })?.display ?? "Unknown"
    }

    public func toRaw(_ display: String) -> UInt8 {
        levels.first(where: { $0.display == display })?.raw ?? 0
    }
}

/// Transforms a CTCSS tone code index to frequency.
public struct CTCSSToneTransform: ValueTransform {
    public static let standardTones: [Double] = [
        67.0, 69.3, 71.9, 74.4, 77.0, 79.7, 82.5, 85.4, 88.5, 91.5,
        94.8, 97.4, 100.0, 103.5, 107.2, 110.9, 114.8, 118.8, 123.0, 127.3,
        131.8, 136.5, 141.3, 146.2, 151.4, 156.7, 159.8, 162.2, 165.5, 167.9,
        171.3, 173.8, 177.3, 179.9, 183.5, 186.2, 189.9, 192.8, 196.6, 199.5,
        203.5, 206.5, 210.7, 218.1, 225.7, 229.1, 233.6, 241.8, 250.3, 254.1
    ]

    public init() {}

    public func toDisplay(_ raw: UInt8) -> String {
        guard raw < Self.standardTones.count else { return "None" }
        return String(format: "%.1f Hz", Self.standardTones[Int(raw)])
    }

    public func toRaw(_ display: String) -> UInt8 {
        let freq = Double(display.replacingOccurrences(of: " Hz", with: "")) ?? 0
        return UInt8(Self.standardTones.firstIndex(where: { abs($0 - freq) < 0.05 }) ?? 0)
    }
}

/// Inverted boolean transform for "Disable*" fields.
/// CPS stores these as the opposite of the UI checkbox state.
/// UI shows "Quiet Mode: ON" → Binary stores `false`
public struct InvertedBoolTransform: ValueTransform {
    public init() {}

    public func toDisplay(_ raw: Bool) -> Bool {
        !raw
    }

    public func toRaw(_ display: Bool) -> Bool {
        !display
    }
}

/// Version transform for 3-byte version encoding.
/// Binary format: [ASCII char][major][minor] → Display: "R03.00"
public struct VersionTransform: ValueTransform {
    public init() {}

    public func toDisplay(_ raw: (UInt8, UInt8, UInt8)) -> String {
        let prefix = Character(UnicodeScalar(raw.0))
        return "\(prefix)\(String(format: "%02d", raw.1)).\(String(format: "%02d", raw.2))"
    }

    public func toRaw(_ display: String) -> (UInt8, UInt8, UInt8) {
        guard display.count >= 5 else { return (0x52, 0, 0) } // Default "R"
        let prefix = display.first?.asciiValue ?? 0x52
        let parts = display.dropFirst().split(separator: ".")
        let major = UInt8(parts.first ?? "0") ?? 0
        let minor = UInt8(parts.count > 1 ? parts[1] : "0") ?? 0
        return (prefix, major, minor)
    }
}

/// Pass-through transform that doesn't modify values.
public struct IdentityTransform<T>: ValueTransform {
    public init() {}

    public func toDisplay(_ raw: T) -> T { raw }
    public func toRaw(_ display: T) -> T { display }
}

/// Linear scaling transform (e.g., volume 0-15 to 0-100%).
public struct LinearScaleTransform: ValueTransform {
    public let rawRange: ClosedRange<Int>
    public let displayRange: ClosedRange<Double>
    public let suffix: String

    public init(rawRange: ClosedRange<Int>, displayRange: ClosedRange<Double>, suffix: String = "") {
        self.rawRange = rawRange
        self.displayRange = displayRange
        self.suffix = suffix
    }

    public func toDisplay(_ raw: Int) -> String {
        let ratio = Double(raw - rawRange.lowerBound) / Double(rawRange.upperBound - rawRange.lowerBound)
        let display = displayRange.lowerBound + ratio * (displayRange.upperBound - displayRange.lowerBound)
        return String(format: "%.0f%@", display, suffix)
    }

    public func toRaw(_ display: String) -> Int {
        let cleaned = display.replacingOccurrences(of: suffix, with: "")
        guard let value = Double(cleaned) else { return rawRange.lowerBound }
        let ratio = (value - displayRange.lowerBound) / (displayRange.upperBound - displayRange.lowerBound)
        return rawRange.lowerBound + Int(ratio * Double(rawRange.upperBound - rawRange.lowerBound))
    }
}
