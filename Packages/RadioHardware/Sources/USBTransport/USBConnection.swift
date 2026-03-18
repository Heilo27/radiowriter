import Foundation
import RadioCore

/// Protocol for USB communication with a radio.
public protocol USBConnection: Actor {
    /// Whether the connection is currently open.
    var isConnected: Bool { get }

    /// Opens the connection to the radio.
    func connect() async throws

    /// Closes the connection.
    func disconnect() async

    /// Sends raw bytes to the radio.
    func send(_ data: Data) async throws

    /// Receives bytes from the radio with a timeout.
    func receive(count: Int, timeout: TimeInterval) async throws -> Data

    /// Sends a command and waits for a response.
    func sendCommand(_ command: Data, responseLength: Int, timeout: TimeInterval) async throws -> Data
}

/// Errors during USB communication.
public enum USBError: Error, LocalizedError {
    case notConnected
    case connectionFailed(String)
    case timeout
    case readError(String)
    case writeError(String)
    case deviceNotFound
    case permissionDenied

    public var errorDescription: String? {
        switch self {
        case .notConnected: return "Radio is not connected"
        case .connectionFailed: return "Could not open the connection to the radio"
        case .timeout: return "The radio stopped responding"
        case .readError: return "Could not read data from the radio"
        case .writeError: return "Could not send data to the radio"
        case .deviceNotFound: return "No radio found on this port"
        case .permissionDenied: return "Permission denied to access the radio port"
        }
    }

    public var recoverySuggestion: String? {
        switch self {
        case .notConnected:
            return "Connect the USB cable and make sure the radio is powered on, then try again."
        case .connectionFailed:
            return "Unplug and reconnect the USB cable. If this is a serial radio, confirm the port path is correct in System Settings > Privacy & Security > Files and Folders."
        case .timeout:
            return "The radio may have gone to sleep or disconnected. Reconnect the USB cable and power cycle the radio, then try again."
        case .readError:
            return "Try a different USB cable or USB port. If the problem persists, restart the radio."
        case .writeError:
            return "Try a different USB cable or USB port. Make sure the radio is in programming mode and not locked."
        case .deviceNotFound:
            return "Connect the Motorola programming cable and make sure the radio is powered on. The cable's driver (FTDI) must be installed — visit ftdichip.com if needed."
        case .permissionDenied:
            return "Open System Settings > Privacy & Security > Files and Folders and grant RadioWriter access to the serial port, then try again."
        }
    }
}

/// Connection type for detected radios.
public enum RadioConnectionType: Sendable, Equatable {
    case serial(path: String)
    case network(ip: String, interface: String)
}

/// Information about a connected USB device.
public struct USBDeviceInfo: Sendable, Identifiable, Equatable {
    public let id: String
    public let vendorID: UInt16
    public let productID: UInt16
    public let serialNumber: String?
    public let portPath: String
    public let displayName: String
    public let connectionType: RadioConnectionType

    public init(
        id: String,
        vendorID: UInt16,
        productID: UInt16,
        serialNumber: String?,
        portPath: String,
        displayName: String,
        connectionType: RadioConnectionType? = nil
    ) {
        self.id = id
        self.vendorID = vendorID
        self.productID = productID
        self.serialNumber = serialNumber
        self.portPath = portPath
        self.displayName = displayName
        self.connectionType = connectionType ?? .serial(path: portPath)
    }

    /// FTDI vendor ID used by Motorola programming cables.
    public static let ftdiVendorID: UInt16 = 0x0403
    /// Common FTDI product IDs.
    public static let ftdiProductIDs: Set<UInt16> = [0x6001, 0x6010, 0x6011, 0x6014, 0x6015]

    /// Motorola Solutions vendor ID for direct USB radios.
    public static let motorolaVendorID: UInt16 = 0x0CAD // 3245 decimal
    /// Common Motorola radio product IDs (CDC ECM devices).
    public static let motorolaProductIDs: Set<UInt16> = [0x1022, 0x1021, 0x1020] // APX, XPR, etc.
}
