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
    /// Uses XCMP protocol with PSDT access to read codeplug data.
    /// Sequence based on Specter analysis of MOTOTRBO CPS DLLs:
    /// 1. Start component session (0x010F)
    /// 2. Query PSDT partition addresses (0x010B)
    /// 3. Read data blocks using component read (0x010E)
    /// 4. Create archive (0x010F with CreateArchive flag)
    /// 5. End session (0x010F with Reset flag)
    public func readCodeplug(progress: @Sendable (Double) -> Void) async throws -> Data {
        // Ensure connected
        if !(await isConnected) {
            try await connect()
        }

        guard let client = xcmpClient else {
            throw MOTOTRBOError.notImplemented("XCMP client not initialized")
        }

        progress(0.0)

        // Generate session ID
        let sessionID = UInt16.random(in: 1...0xFFFE)

        // Step 1: Start read session
        let startPacket = XCMPPacket.startReadSession(sessionID: sessionID)
        guard let startReply = try await client.sendAndReceive(startPacket) else {
            throw MOTOTRBOError.protocolError("No reply to session start request")
        }

        // Check for success
        if startReply.data.count > 0 && startReply.data[0] != 0x00 {
            let errorCode = startReply.data[0]
            throw MOTOTRBOError.protocolError("Session start failed with error: 0x\(String(format: "%02X", errorCode))")
        }

        progress(0.1)

        // Step 2: Query codeplug partition addresses
        let getStartAddr = XCMPPacket.psdtGetStartAddress(partition: "CP")
        guard let startAddrReply = try await client.sendAndReceive(getStartAddr) else {
            throw MOTOTRBOError.protocolError("No reply to PSDT start address query")
        }

        let getEndAddr = XCMPPacket.psdtGetEndAddress(partition: "CP")
        guard let endAddrReply = try await client.sendAndReceive(getEndAddr) else {
            throw MOTOTRBOError.protocolError("No reply to PSDT end address query")
        }

        // Parse addresses from replies (4 bytes each, big-endian)
        guard startAddrReply.data.count >= 5, endAddrReply.data.count >= 5 else {
            throw MOTOTRBOError.protocolError("Invalid PSDT address reply format")
        }

        let startAddress = UInt32(startAddrReply.data[1]) << 24 |
                          UInt32(startAddrReply.data[2]) << 16 |
                          UInt32(startAddrReply.data[3]) << 8 |
                          UInt32(startAddrReply.data[4])

        let endAddress = UInt32(endAddrReply.data[1]) << 24 |
                        UInt32(endAddrReply.data[2]) << 16 |
                        UInt32(endAddrReply.data[3]) << 8 |
                        UInt32(endAddrReply.data[4])

        let codeplugSize = Int(endAddress - startAddress)
        guard codeplugSize > 0 && codeplugSize < 50_000_000 else {  // Sanity check: < 50MB
            throw MOTOTRBOError.protocolError("Invalid codeplug size: \(codeplugSize)")
        }

        progress(0.2)

        // Step 3: Unlock PSDT partition
        let unlockPacket = XCMPPacket.psdtUnlock(partition: "CP")
        _ = try await client.sendAndReceive(unlockPacket)

        progress(0.25)

        // Step 4: Read data in blocks
        var codeplugData = Data()
        let blockSize: UInt16 = 1024  // Read 1KB at a time
        var currentAddress = startAddress
        let totalBlocks = (codeplugSize + Int(blockSize) - 1) / Int(blockSize)
        var blocksRead = 0

        while currentAddress < endAddress {
            let bytesRemaining = endAddress - currentAddress
            let readSize = min(UInt16(bytesRemaining), blockSize)

            let readPacket = XCMPPacket.cpsReadRequest(address: currentAddress, length: readSize)
            guard let readReply = try await client.sendAndReceive(readPacket, timeout: 10.0) else {
                throw MOTOTRBOError.protocolError("No reply to CPS read request at address 0x\(String(format: "%08X", currentAddress))")
            }

            // Check for error
            if readReply.data.count < 2 || readReply.data[0] != 0x00 {
                throw MOTOTRBOError.protocolError("CPS read failed at address 0x\(String(format: "%08X", currentAddress))")
            }

            // Skip error code byte, append data
            codeplugData.append(Data(readReply.data.dropFirst()))
            currentAddress += UInt32(readSize)
            blocksRead += 1

            // Update progress (0.25 to 0.9 for data transfer)
            let transferProgress = 0.25 + (0.65 * Double(blocksRead) / Double(totalBlocks))
            progress(transferProgress)
        }

        progress(0.9)

        // Step 5: Create archive (optional, for proper CPS format)
        let archivePacket = XCMPPacket.createArchive(sessionID: sessionID)
        _ = try await client.sendAndReceive(archivePacket)

        progress(0.95)

        // Step 6: End session
        let resetPacket = XCMPPacket.resetSession(sessionID: sessionID)
        _ = try await client.sendAndReceive(resetPacket)

        progress(1.0)

        return codeplugData
    }

    /// Writes a codeplug to the radio.
    ///
    /// Uses XCMP protocol with PSDT access to write codeplug data.
    /// Sequence based on Specter analysis of MOTOTRBO CPS DLLs:
    /// 1. Start component session with write flags (0x010F)
    /// 2. Unlock PSDT partition (0x010B)
    /// 3. Optionally erase partition (0x010B with Erase action)
    /// 4. Transfer data blocks (0x0446)
    /// 5. Validate CRC (0x010F with ValidateCRC flag)
    /// 6. Unpack and deploy (0x010F with UnpackFiles | Deploy flags)
    /// 7. Lock PSDT partition (0x010B)
    /// 8. End session (0x010F with Reset flag)
    public func writeCodeplug(_ data: Data, progress: @Sendable (Double) -> Void) async throws {
        // Ensure connected
        if !(await isConnected) {
            try await connect()
        }

        guard let client = xcmpClient else {
            throw MOTOTRBOError.notImplemented("XCMP client not initialized")
        }

        progress(0.0)

        // Generate session ID
        let sessionID = UInt16.random(in: 1...0xFFFE)

        // Step 1: Start write session (with programming indicator)
        let startPacket = XCMPPacket.startWriteSession(sessionID: sessionID)
        guard let startReply = try await client.sendAndReceive(startPacket) else {
            throw MOTOTRBOError.protocolError("No reply to write session start request")
        }

        // Check for success
        if startReply.data.count > 0 && startReply.data[0] != 0x00 {
            let errorCode = startReply.data[0]
            throw MOTOTRBOError.protocolError("Write session start failed with error: 0x\(String(format: "%02X", errorCode))")
        }

        progress(0.05)

        // Step 2: Initiate codeplug update
        let updatePacket = XCMPPacket.initiateCodeplugUpdate()
        _ = try await client.sendAndReceive(updatePacket)

        progress(0.1)

        // Step 3: Unlock PSDT partition
        let unlockPacket = XCMPPacket.psdtUnlock(partition: "CP")
        guard let unlockReply = try await client.sendAndReceive(unlockPacket) else {
            throw MOTOTRBOError.protocolError("No reply to PSDT unlock request")
        }

        if unlockReply.data.count > 0 && unlockReply.data[0] != 0x00 {
            throw MOTOTRBOError.protocolError("PSDT unlock failed")
        }

        progress(0.15)

        // Step 4: Transfer data in blocks
        let blockSize = 512  // Write 512 bytes at a time
        let totalBlocks = (data.count + blockSize - 1) / blockSize
        var blocksSent = 0

        for offset in stride(from: 0, to: data.count, by: blockSize) {
            let endIndex = min(offset + blockSize, data.count)
            let blockData = Data(data[offset..<endIndex])

            let transferPacket = XCMPPacket.transferCompressedData(blockData)
            guard let transferReply = try await client.sendAndReceive(transferPacket, timeout: 10.0) else {
                throw MOTOTRBOError.protocolError("No reply to data transfer at offset \(offset)")
            }

            if transferReply.data.count > 0 && transferReply.data[0] != 0x00 {
                throw MOTOTRBOError.protocolError("Data transfer failed at offset \(offset)")
            }

            blocksSent += 1
            // Progress: 0.15 to 0.75 for data transfer
            let transferProgress = 0.15 + (0.60 * Double(blocksSent) / Double(totalBlocks))
            progress(transferProgress)
        }

        progress(0.75)

        // Step 5: Validate CRC
        let validatePacket = XCMPPacket.validateSessionCRC(sessionID: sessionID)
        guard let validateReply = try await client.sendAndReceive(validatePacket, timeout: 30.0) else {
            throw MOTOTRBOError.protocolError("No reply to CRC validation request")
        }

        if validateReply.data.count > 0 && validateReply.data[0] != 0x00 {
            throw MOTOTRBOError.protocolError("CRC validation failed")
        }

        progress(0.80)

        // Step 6: Unpack and deploy
        let deployPacket = XCMPPacket.unpackAndDeploy(sessionID: sessionID)
        guard let deployReply = try await client.sendAndReceive(deployPacket, timeout: 60.0) else {
            throw MOTOTRBOError.protocolError("No reply to deploy request")
        }

        if deployReply.data.count > 0 && deployReply.data[0] != 0x00 {
            throw MOTOTRBOError.protocolError("Deploy failed")
        }

        progress(0.90)

        // Step 7: Validate codeplug
        let validateCPPacket = XCMPPacket.validateCodeplug()
        _ = try await client.sendAndReceive(validateCPPacket)

        progress(0.92)

        // Step 8: Lock PSDT partition
        let lockPacket = XCMPPacket.psdtLock(partition: "CP")
        _ = try await client.sendAndReceive(lockPacket)

        progress(0.95)

        // Step 9: End session
        let resetPacket = XCMPPacket.resetSession(sessionID: sessionID)
        _ = try await client.sendAndReceive(resetPacket)

        progress(1.0)
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
