import Foundation
import USBTransport

/// Protocol type identifying how to communicate with different radio families.
public enum RadioProtocolType: String, Sendable {
    /// Simple serial protocol for CLP, CLS, DLR series (older analog/basic radios)
    case clpSerial

    /// MOTOTRBO protocol for XPR, SL, DP, DM series (DMR digital radios)
    /// Uses XNL/XCMP over TCP port 8002
    case mototrbo

    /// ASTRO protocol for APX series (P25 radios)
    /// Uses ASTRO-specific sequence manager with PBA (Portable Bus Architecture)
    case astro

    /// TETRA protocol for MTM/MTP series (TETRA digital radios)
    /// Uses TETRA-specific sequence manager
    case tetra

    /// LTE protocol for LEX series (broadband LTE radios)
    /// Uses LTE-specific sequence manager
    case lte

    /// CP200 protocol for CP200 series
    case cp200Serial

    /// PBB protocol (likely Portable Broadband)
    case pbb

    /// Unknown/unsupported protocol
    case unknown
}

/// Protocol configuration for a radio family.
public struct RadioProtocolConfig: Sendable {
    public let type: RadioProtocolType
    public let connectionType: RadioConnectionPreference
    public let port: UInt16?
    public let baudRate: Int?
    public let requiresProgrammingMode: Bool
    public let programmingModeInstructions: String?

    public init(
        type: RadioProtocolType,
        connectionType: RadioConnectionPreference,
        port: UInt16? = nil,
        baudRate: Int? = nil,
        requiresProgrammingMode: Bool = false,
        programmingModeInstructions: String? = nil
    ) {
        self.type = type
        self.connectionType = connectionType
        self.port = port
        self.baudRate = baudRate
        self.requiresProgrammingMode = requiresProgrammingMode
        self.programmingModeInstructions = programmingModeInstructions
    }
}

/// Preferred connection type for a radio.
public enum RadioConnectionPreference: Sendable {
    case serial
    case network
    case either
}

/// Protocol configuration for each radio family.
public enum RadioProtocolRegistry {
    /// Protocol configurations by radio family.
    public static let configurations: [String: RadioProtocolConfig] = [
        // CLP Series - Simple serial protocol
        "clp": RadioProtocolConfig(
            type: .clpSerial,
            connectionType: .serial,
            baudRate: 115200,
            requiresProgrammingMode: false
        ),

        // CLS Series (Sunb) - Same as CLP
        "cls": RadioProtocolConfig(
            type: .clpSerial,
            connectionType: .serial,
            baudRate: 115200,
            requiresProgrammingMode: false
        ),

        // DLR Series - Similar to CLP
        "dlr": RadioProtocolConfig(
            type: .clpSerial,
            connectionType: .serial,
            baudRate: 115200,
            requiresProgrammingMode: false
        ),

        // XPR Series (MOTOTRBO) - Network CDC ECM
        // TCP ports: 8002 (XNL/CPS), 8501 (AT debug), 8502
        // Programming uses XNL/XCMP protocol on TCP 8002
        "xpr": RadioProtocolConfig(
            type: .mototrbo,
            connectionType: .network,
            port: 8002, // XNL/CPS port
            requiresProgrammingMode: false
        ),

        // SL Series (Fiji) - Network MOTOTRBO
        "sl": RadioProtocolConfig(
            type: .mototrbo,
            connectionType: .network,
            port: 8002,
            requiresProgrammingMode: false
        ),

        // DP Series - Network MOTOTRBO
        "dp": RadioProtocolConfig(
            type: .mototrbo,
            connectionType: .network,
            port: 8002,
            requiresProgrammingMode: false
        ),

        // DM Series - Network MOTOTRBO
        "dm": RadioProtocolConfig(
            type: .mototrbo,
            connectionType: .network,
            port: 8002,
            requiresProgrammingMode: false
        ),

        // APX Series - ASTRO protocol (P25)
        "apx": RadioProtocolConfig(
            type: .astro,
            connectionType: .network,
            port: 8002,
            requiresProgrammingMode: true,
            programmingModeInstructions: """
            APX radios require:
            1. Subscriber Programming Software (SPS) mode
            2. Connect via USB
            3. Radio may auto-detect CPS connection
            """
        ),

        // XTL Series - ASTRO protocol (P25)
        "xtl": RadioProtocolConfig(
            type: .astro,
            connectionType: .network,
            port: 8002,
            requiresProgrammingMode: true
        ),

        // MTP Series - TETRA protocol
        "mtp": RadioProtocolConfig(
            type: .tetra,
            connectionType: .network,
            port: 8002,
            requiresProgrammingMode: true,
            programmingModeInstructions: """
            TETRA radios require:
            1. TETRA CPS mode
            2. Connect via USB
            """
        ),

        // MTM Series - TETRA protocol
        "mtm": RadioProtocolConfig(
            type: .tetra,
            connectionType: .network,
            port: 8002,
            requiresProgrammingMode: true
        ),

        // LEX Series - LTE protocol
        "lex": RadioProtocolConfig(
            type: .lte,
            connectionType: .network,
            port: 8002,
            requiresProgrammingMode: true,
            programmingModeInstructions: """
            LTE radios require:
            1. LTE CPS mode
            2. Connect via USB
            """
        ),

        // CP200 Series - Serial
        "cp200": RadioProtocolConfig(
            type: .cp200Serial,
            connectionType: .serial,
            baudRate: 9600,
            requiresProgrammingMode: false
        ),

        // DTR Series - ISM band digital
        "dtr": RadioProtocolConfig(
            type: .clpSerial,
            connectionType: .serial,
            baudRate: 115200,
            requiresProgrammingMode: false
        ),
    ]

    /// Returns the protocol configuration for a radio family.
    public static func config(for family: String) -> RadioProtocolConfig? {
        configurations[family.lowercased()]
    }

    /// Detects the radio family from a model number string.
    /// - Parameter modelNumber: The radio's model number (e.g., "H02RDH9VA1AN")
    /// - Returns: The detected radio family or nil if unknown
    public static func detectFamily(from modelNumber: String) -> String? {
        let model = modelNumber.uppercased()

        // MOTOTRBO families (XPR, SL, DP, DM)
        // XPR models typically start with: H02, H98, H99, M27, AAH, etc.
        if model.hasPrefix("H02") || model.hasPrefix("H98") || model.hasPrefix("H99") ||
           model.hasPrefix("M27") || model.hasPrefix("AAH") {
            // Further distinguish by model code patterns
            if model.contains("RD") { return "xpr" }  // XPR portable
            if model.contains("RM") { return "dm" }   // DM mobile
        }

        // ASTRO families (APX, XTL)
        if model.hasPrefix("APX") || model.hasPrefix("H78") || model.hasPrefix("H45") ||
           model.hasPrefix("M25") {
            return "apx"
        }

        // TETRA families (MTP, MTM)
        if model.hasPrefix("MTP") || model.hasPrefix("MTM") ||
           model.hasPrefix("H55") || model.hasPrefix("H56") {
            return "mtp"
        }

        // LTE families (LEX)
        if model.hasPrefix("LEX") || model.hasPrefix("H69") {
            return "lex"
        }

        // CLP/CLS/DLR families
        if model.hasPrefix("CLP") || model.hasPrefix("CLS") ||
           model.hasPrefix("DLR") || model.hasPrefix("DTR") {
            return model.hasPrefix("CLP") ? "clp" :
                   model.hasPrefix("CLS") ? "cls" :
                   model.hasPrefix("DLR") ? "dlr" : "dtr"
        }

        // CP200 series
        if model.hasPrefix("CP") {
            return "cp200"
        }

        return nil
    }

    /// Detects the protocol type from a model number string.
    /// - Parameter modelNumber: The radio's model number
    /// - Returns: The detected protocol type
    public static func detectProtocol(from modelNumber: String) -> RadioProtocolType {
        guard let family = detectFamily(from: modelNumber),
              let config = configurations[family] else {
            return .unknown
        }
        return config.type
    }
}

/// Radio identification response from querying a connected radio.
public struct RadioIdentification: Sendable {
    public let modelNumber: String
    public let serialNumber: String?
    public let firmwareVersion: String?
    public let radioFamily: String?
    public let codeplugVersion: String?
    public let radioID: UInt32?

    public init(
        modelNumber: String,
        serialNumber: String? = nil,
        firmwareVersion: String? = nil,
        radioFamily: String? = nil,
        codeplugVersion: String? = nil,
        radioID: UInt32? = nil
    ) {
        self.modelNumber = modelNumber
        self.serialNumber = serialNumber
        self.firmwareVersion = firmwareVersion
        self.radioFamily = radioFamily
        self.codeplugVersion = codeplugVersion
        self.radioID = radioID
    }
}

/// Protocol for radio-family-specific programmers.
public protocol RadioFamilyProgrammer: Actor {
    /// Attempts to identify the connected radio.
    func identify() async throws -> RadioIdentification

    /// Reads the complete codeplug from the radio.
    func readCodeplug(progress: @Sendable (Double) -> Void) async throws -> Data

    /// Writes a codeplug to the radio.
    func writeCodeplug(_ data: Data, progress: @Sendable (Double) -> Void) async throws

    /// Verifies the written codeplug matches the source.
    func verify(expected: Data, progress: @Sendable (Double) -> Void) async throws -> Bool
}
