import Foundation
import USBTransport

/// Protocol type identifying how to communicate with different radio families.
public enum RadioProtocolType: String, Sendable {
    /// Simple serial protocol for CLP, CLS, DLR series (older analog/basic radios)
    case clpSerial

    /// MOTOTRBO protocol for XPR, SL, DP, DM series (DMR digital radios)
    case mototrbo

    /// ASTRO protocol for APX series (P25 radios)
    case astro

    /// CP200 protocol for CP200 series
    case cp200Serial

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
        // TCP ports: 8002, 8501 (AT debug), 8502
        // UDP ports: 4002 (XCMP/XNL), 4005, 5016, 5017, 50000-50002 (IPSC)
        // Programming uses XCMP/XNL protocol on UDP 4002 (requires auth keys)
        // Port 8501 provides AT debug interface with VER command for identification
        "xpr": RadioProtocolConfig(
            type: .mototrbo,
            connectionType: .network,
            port: 8501, // AT debug interface - use for identification
            requiresProgrammingMode: false
        ),

        // SL Series (Fiji) - Network
        "sl300": RadioProtocolConfig(
            type: .mototrbo,
            connectionType: .network,
            port: 50000,
            requiresProgrammingMode: true
        ),

        // APX Series - ASTRO protocol
        "apx": RadioProtocolConfig(
            type: .astro,
            connectionType: .network,
            port: 50000,
            requiresProgrammingMode: true,
            programmingModeInstructions: """
            APX radios require:
            1. Subscriber Programming Software (SPS) mode
            2. Connect via USB
            3. Radio may auto-detect CPS connection
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
