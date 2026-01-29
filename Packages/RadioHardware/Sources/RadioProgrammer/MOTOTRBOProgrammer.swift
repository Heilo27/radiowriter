import Foundation
import Network
import USBTransport

/// Programmer for MOTOTRBO radios (XPR, SL, DP, DM series).
/// Uses TCP/IP communication over CDC ECM network interface.
/// Implements XNL authentication and XCMP protocol for radio operations.
public actor MOTOTRBOProgrammer: RadioFamilyProgrammer {
    private let host: String
    private var xnlConnection: XNLConnection?
    private var xcmpClient: XCMPClient?
    private let queue = DispatchQueue(label: "com.cps.mototrbo", qos: .userInitiated)

    /// Known MOTOTRBO ports
    public struct Ports {
        /// XNL/XCMP CPS programming port (TCP)
        public static let xnlCPS: UInt16 = 8002

        /// AT debug interface
        public static let atDebug: UInt16 = 8501

        /// XCMP/XNL repeater mode (UDP)
        public static let xcmpRepeater: UInt16 = 4002

        /// IP Site Connect (IPSC)
        public static let ipsc: UInt16 = 50000
    }

    public init(host: String) {
        self.host = host
    }

    // MARK: - Connection Management

    /// Connects to the radio using XNL protocol with TEA authentication.
    public func connect() async throws {
        let connection = XNLConnection(host: host)
        let result = await connection.connect()

        switch result {
        case .success(let assignedAddress):
            self.xnlConnection = connection
            self.xcmpClient = XCMPClient(xnlConnection: connection)
            print("MOTOTRBO connected, XNL address: 0x\(String(format: "%04X", assignedAddress))")

        case .authenticationFailed(let code):
            throw MOTOTRBOError.protocolError("XNL authentication failed (code: 0x\(String(format: "%02X", code)))")

        case .connectionError(let message):
            throw MOTOTRBOError.connectionFailed(message)

        case .timeout:
            throw MOTOTRBOError.timeout
        }
    }

    /// Disconnects from the radio.
    public func disconnect() async {
        await xnlConnection?.disconnect()
        xnlConnection = nil
        xcmpClient = nil
    }

    /// Returns whether the connection is established and authenticated.
    public var isConnected: Bool {
        get async {
            guard let conn = xnlConnection else { return false }
            return await conn.isAuthenticated
        }
    }

    // MARK: - RadioFamilyProgrammer

    /// Identifies the connected MOTOTRBO radio using XCMP protocol.
    public func identify() async throws -> RadioIdentification {
        // Connect if not already connected
        if !(await isConnected) {
            try await connect()
        }

        guard let client = xcmpClient else {
            throw MOTOTRBOError.notImplemented("XCMP client not initialized")
        }

        // Use XCMP to get radio info
        return try await client.identify()
    }

    /// Reads the complete codeplug from the radio.
    ///
    /// Uses XCMP protocol to read codeplug data in blocks.
    public func readCodeplug(progress: @Sendable (Double) -> Void) async throws -> Data {
        // Ensure connected
        if !(await isConnected) {
            try await connect()
        }

        guard let client = xcmpClient else {
            throw MOTOTRBOError.notImplemented("XCMP client not initialized")
        }

        // TODO: Implement codeplug read using XCMP
        // The process is:
        // 1. Send CPS unlock command (0x0100)
        // 2. Read codeplug blocks using CPS read command (0x0104)
        // 3. Assemble blocks into complete codeplug

        progress(0.0)

        // For now, throw not implemented until we capture the exact protocol
        throw MOTOTRBOError.notImplemented(
            "XCMP codeplug read protocol needs to be captured from real CPS. " +
            "XNL authentication works - need XCMP command sequence."
        )
    }

    /// Writes a codeplug to the radio.
    public func writeCodeplug(_ data: Data, progress: @Sendable (Double) -> Void) async throws {
        // Ensure connected
        if !(await isConnected) {
            try await connect()
        }

        guard let client = xcmpClient else {
            throw MOTOTRBOError.notImplemented("XCMP client not initialized")
        }

        // TODO: Implement codeplug write using XCMP
        progress(0.0)

        throw MOTOTRBOError.notImplemented(
            "XCMP codeplug write protocol needs to be captured from real CPS. " +
            "XNL authentication works - need XCMP command sequence."
        )
    }

    /// Verifies the written codeplug matches the source.
    public func verify(expected: Data, progress: @Sendable (Double) -> Void) async throws -> Bool {
        // Read back and compare
        let actual = try await readCodeplug(progress: progress)
        return actual == expected
    }

    // MARK: - XCMP Commands

    /// Gets the radio model number via XCMP.
    public func getModelNumber() async throws -> String? {
        guard let client = xcmpClient else {
            try await connect()
            guard let c = xcmpClient else { return nil }
            return try await c.getModelNumber()
        }
        return try await client.getModelNumber()
    }

    /// Gets the radio serial number via XCMP.
    public func getSerialNumber() async throws -> String? {
        guard let client = xcmpClient else {
            try await connect()
            guard let c = xcmpClient else { return nil }
            return try await c.getSerialNumber()
        }
        return try await client.getSerialNumber()
    }

    /// Gets the radio ID via XCMP.
    public func getRadioID() async throws -> UInt32? {
        guard let client = xcmpClient else {
            try await connect()
            guard let c = xcmpClient else { return nil }
            return try await c.getRadioID()
        }
        return try await client.getRadioID()
    }

    /// Gets the firmware version via XCMP.
    public func getFirmwareVersion() async throws -> String? {
        guard let client = xcmpClient else {
            try await connect()
            guard let c = xcmpClient else { return nil }
            return try await c.getFirmwareVersion()
        }
        return try await client.getFirmwareVersion()
    }

    // MARK: - AT Debug Commands (Legacy)

    /// Sends an AT command and returns the response.
    /// Uses the AT debug interface on port 8501.
    public func sendATCommand(_ command: String) async throws -> String {
        let connection = try await connectTCP(to: Ports.atDebug)
        defer { connection.cancel() }

        // Read welcome banner
        _ = try await readUntilPrompt(connection: connection)

        // Send command
        try await send(command + "\r\n", to: connection)

        // Read response
        return try await readUntilPrompt(connection: connection)
    }

    /// Gets the list of available AT commands.
    public func getATHelp() async throws -> String {
        return try await sendATCommand("?")
    }

    // MARK: - TCP Connection Helpers

    private func connectTCP(to port: UInt16) async throws -> NWConnection {
        let nwHost = NWEndpoint.Host(host)
        let nwPort = NWEndpoint.Port(rawValue: port)!

        let parameters = NWParameters.tcp
        let connection = NWConnection(host: nwHost, port: nwPort, using: parameters)

        return try await withCheckedThrowingContinuation { continuation in
            connection.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    continuation.resume(returning: connection)
                case .failed(let error):
                    continuation.resume(throwing: MOTOTRBOError.connectionFailed(error.localizedDescription))
                case .cancelled:
                    continuation.resume(throwing: MOTOTRBOError.connectionFailed("Connection cancelled"))
                default:
                    break
                }
            }
            connection.start(queue: queue)
        }
    }

    private func send(_ string: String, to connection: NWConnection) async throws {
        let data = Data(string.utf8)
        return try await withCheckedThrowingContinuation { continuation in
            connection.send(content: data, completion: .contentProcessed { error in
                if let error = error {
                    continuation.resume(throwing: MOTOTRBOError.sendFailed(error.localizedDescription))
                } else {
                    continuation.resume()
                }
            })
        }
    }

    private func readUntilPrompt(connection: NWConnection, timeout: TimeInterval = 3.0) async throws -> String {
        var buffer = Data()
        let deadline = Date().addingTimeInterval(timeout)

        while Date() < deadline {
            let data = try await receive(from: connection, count: 1024, timeout: 0.5)
            buffer.append(data)

            // Check for AT_Debug> prompt
            if let str = String(data: buffer, encoding: .utf8),
               str.contains("AT_Debug>") {
                return str
            }
        }

        return String(data: buffer, encoding: .utf8) ?? ""
    }

    private func receive(from connection: NWConnection, count: Int, timeout: TimeInterval) async throws -> Data {
        return try await withThrowingTaskGroup(of: Data.self) { group in
            group.addTask {
                try await withCheckedThrowingContinuation { continuation in
                    connection.receive(minimumIncompleteLength: 1, maximumLength: count) { data, _, _, error in
                        if let error = error {
                            continuation.resume(throwing: MOTOTRBOError.receiveFailed(error.localizedDescription))
                        } else {
                            continuation.resume(returning: data ?? Data())
                        }
                    }
                }
            }

            group.addTask {
                try await Task.sleep(for: .seconds(timeout))
                return Data()
            }

            let result = try await group.next() ?? Data()
            group.cancelAll()
            return result
        }
    }
}

/// Errors specific to MOTOTRBO programming.
public enum MOTOTRBOError: Error, LocalizedError {
    case connectionFailed(String)
    case sendFailed(String)
    case receiveFailed(String)
    case timeout
    case notImplemented(String)
    case protocolError(String)
    case authenticationFailed(String)

    public var errorDescription: String? {
        switch self {
        case .connectionFailed(let msg): return "Connection failed: \(msg)"
        case .sendFailed(let msg): return "Send failed: \(msg)"
        case .receiveFailed(let msg): return "Receive failed: \(msg)"
        case .timeout: return "Communication timeout"
        case .notImplemented(let msg): return "Not implemented: \(msg)"
        case .protocolError(let msg): return "Protocol error: \(msg)"
        case .authenticationFailed(let msg): return "Authentication failed: \(msg)"
        }
    }
}
