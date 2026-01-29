import Foundation
import Network

/// Factory for creating radio programmers based on detected protocol.
/// Handles auto-detection of radio type and creates the appropriate programmer.
public enum RadioProgrammerFactory {

    /// Creates a programmer for the given host, auto-detecting the radio type.
    /// - Parameter host: The IP address of the radio (e.g., "192.168.10.1")
    /// - Returns: The appropriate programmer for the detected radio type
    /// - Throws: If connection fails or radio type cannot be determined
    public static func createProgrammer(for host: String) async throws -> any RadioFamilyProgrammer {
        // Try to detect the radio type by querying it
        let detection = try await detectRadioType(host: host)

        switch detection.protocolType {
        case .mototrbo:
            return MOTOTRBOProgrammer(host: host)

        case .astro:
            return ASTROProgrammer(host: host)

        case .tetra:
            return TETRAProgrammer(host: host)

        case .lte, .pbb:
            // LTE and PBB both use HTTP REST API
            return LTEProgrammer(baseURL: "http://\(host)")

        case .clpSerial, .cp200Serial:
            throw RadioProgrammerError.serialNotSupported(
                "Serial protocols require a serial port path, not IP address"
            )

        case .unknown:
            throw RadioProgrammerError.unknownRadioType(
                "Could not detect radio type from model: \(detection.modelNumber ?? "unknown")"
            )
        }
    }

    /// Creates a programmer for a known radio family.
    /// - Parameters:
    ///   - host: The IP address of the radio
    ///   - family: The known radio family (e.g., "xpr", "apx", "mtp")
    /// - Returns: The appropriate programmer for the specified family
    public static func createProgrammer(for host: String, family: String) throws -> any RadioFamilyProgrammer {
        guard let config = RadioProtocolRegistry.config(for: family) else {
            throw RadioProgrammerError.unknownRadioType("Unknown radio family: \(family)")
        }

        switch config.type {
        case .mototrbo:
            return MOTOTRBOProgrammer(host: host)

        case .astro:
            return ASTROProgrammer(host: host)

        case .tetra:
            return TETRAProgrammer(host: host)

        case .lte, .pbb:
            // LTE and PBB both use HTTP REST API
            return LTEProgrammer(baseURL: "http://\(host)")

        case .clpSerial, .cp200Serial:
            throw RadioProgrammerError.serialNotSupported(
                "Serial protocols require a serial port path"
            )

        case .unknown:
            throw RadioProgrammerError.unknownRadioType("Unsupported protocol type: \(config.type)")
        }
    }

    /// Detection result containing radio identification and protocol type.
    public struct RadioDetectionResult: Sendable {
        public let modelNumber: String?
        public let firmwareVersion: String?
        public let serialNumber: String?
        public let protocolType: RadioProtocolType
        public let family: String?
    }

    /// Detects the radio type by connecting and querying identification.
    /// Tries multiple protocols in order: MOTOTRBO → LTE/HTTP → TETRA
    /// - Parameter host: The IP address of the radio
    /// - Returns: Detection result with radio info and protocol type
    private static func detectRadioType(host: String) async throws -> RadioDetectionResult {
        var lastError: Error?

        // Try 1: MOTOTRBO protocol (XNL/XCMP on port 8002)
        // Most common for network-connected radios like XPR series
        do {
            let result = try await detectMOTOTRBO(host: host)
            return result
        } catch {
            lastError = error
        }

        // Try 2: LTE/PBB protocol (HTTP REST API)
        // Used by LTE radios (LEX series) and PBB devices
        do {
            let result = try await detectLTE(host: host)
            return result
        } catch {
            lastError = error
        }

        // Try 3: TETRA protocol (RP protocol)
        // Used by MTP/MTM series radios
        do {
            let result = try await detectTETRA(host: host)
            return result
        } catch {
            lastError = error
        }

        // All protocols failed
        throw RadioProgrammerError.connectionFailed(
            "Could not detect radio type. Tried MOTOTRBO, LTE/HTTP, TETRA protocols. Last error: \(lastError?.localizedDescription ?? "unknown")"
        )
    }

    /// Attempts MOTOTRBO protocol detection.
    private static func detectMOTOTRBO(host: String) async throws -> RadioDetectionResult {
        let mototrbo = MOTOTRBOProgrammer(host: host)

        do {
            let identification = try await mototrbo.identify()
            await mototrbo.disconnect()

            // Detect family from model number
            let family = RadioProtocolRegistry.detectFamily(from: identification.modelNumber)
            let protocolType = family != nil ?
                RadioProtocolRegistry.detectProtocol(from: identification.modelNumber) :
                .mototrbo  // Default to MOTOTRBO if we got a response

            return RadioDetectionResult(
                modelNumber: identification.modelNumber,
                firmwareVersion: identification.firmwareVersion,
                serialNumber: identification.serialNumber,
                protocolType: protocolType,
                family: family ?? "xpr"
            )
        } catch {
            await mototrbo.disconnect()
            throw error
        }
    }

    /// Attempts LTE/HTTP protocol detection.
    private static func detectLTE(host: String) async throws -> RadioDetectionResult {
        let lte = LTEProgrammer(baseURL: "http://\(host)")

        do {
            // Try to get device inventory without authentication first
            let identification = try await lte.identify()

            // Detect family from model
            let family = RadioProtocolRegistry.detectFamily(from: identification.modelNumber)
            let protocolType: RadioProtocolType = family != nil ?
                RadioProtocolRegistry.detectProtocol(from: identification.modelNumber) :
                .lte  // Default to LTE if we got a response

            return RadioDetectionResult(
                modelNumber: identification.modelNumber,
                firmwareVersion: identification.firmwareVersion,
                serialNumber: identification.serialNumber,
                protocolType: protocolType,
                family: family ?? "lex"
            )
        } catch {
            throw error
        }
    }

    /// Attempts TETRA protocol detection.
    private static func detectTETRA(host: String) async throws -> RadioDetectionResult {
        let tetra = TETRAProgrammer(host: host)

        do {
            let identification = try await tetra.identify()
            await tetra.disconnect()

            // Detect family from model
            let family = RadioProtocolRegistry.detectFamily(from: identification.modelNumber)

            return RadioDetectionResult(
                modelNumber: identification.modelNumber,
                firmwareVersion: identification.firmwareVersion,
                serialNumber: identification.serialNumber,
                protocolType: .tetra,
                family: family ?? "mtp"
            )
        } catch {
            await tetra.disconnect()
            throw error
        }
    }
}

/// Errors from the radio programmer factory.
public enum RadioProgrammerError: Error, LocalizedError {
    case connectionFailed(String)
    case unknownRadioType(String)
    case serialNotSupported(String)
    case protocolMismatch(String)

    public var errorDescription: String? {
        switch self {
        case .connectionFailed(let msg): return "Connection failed: \(msg)"
        case .unknownRadioType(let msg): return "Unknown radio type: \(msg)"
        case .serialNotSupported(let msg): return "Serial not supported: \(msg)"
        case .protocolMismatch(let msg): return "Protocol mismatch: \(msg)"
        }
    }
}

// MARK: - Placeholder Programmers for Other Protocols

/// Programmer for ASTRO radios (APX, XTL series - P25).
/// Uses ASTRO-specific sequence manager with PBA (Portable Bus Architecture).
public actor ASTROProgrammer: RadioFamilyProgrammer {
    private let host: String
    private var xnlConnection: XNLConnection?

    public init(host: String) {
        self.host = host
    }

    public func identify() async throws -> RadioIdentification {
        // ASTRO radios may use similar XNL authentication but different XCMP commands
        // Connect using XNL first
        let connection = XNLConnection(host: host)
        let result = await connection.connect()

        switch result {
        case .success:
            self.xnlConnection = connection
            // TODO: Use ASTRO-specific identification commands
            // For now, return a placeholder
            return RadioIdentification(
                modelNumber: "ASTRO",
                radioFamily: "apx"
            )

        case .authenticationFailed(let code):
            throw MOTOTRBOError.protocolError("ASTRO XNL authentication failed (code: 0x\(String(format: "%02X", code)))")

        case .connectionError(let message):
            throw MOTOTRBOError.connectionFailed(message)

        case .timeout:
            throw MOTOTRBOError.timeout
        }
    }

    public func readCodeplug(progress: @Sendable (Double) -> Void) async throws -> Data {
        throw MOTOTRBOError.notImplemented("ASTRO codeplug read not yet implemented")
    }

    public func writeCodeplug(_ data: Data, progress: @Sendable (Double) -> Void) async throws {
        throw MOTOTRBOError.notImplemented("ASTRO codeplug write not yet implemented")
    }

    public func verify(expected: Data, progress: @Sendable (Double) -> Void) async throws -> Bool {
        throw MOTOTRBOError.notImplemented("ASTRO verify not yet implemented")
    }
}

/// Programmer for TETRA radios (MTP, MTM series).
/// Uses RP (Radio Programming) protocol with SBEP for boot operations.
///
/// Protocol layers:
/// - RP Protocol: High-level programming commands
/// - SBEP Protocol: Boot/firmware operations
/// - Data Transfer: Block read/write with checksums
public actor TETRAProgrammer: RadioFamilyProgrammer {
    private let host: String
    private let port: UInt16
    private var connection: NWConnection?
    private var isInProgrammingMode = false
    private var terminalID: String?

    /// Default TETRA programming port (same as MOTOTRBO)
    public static let defaultPort: UInt16 = 8002

    public init(host: String, port: UInt16 = TETRAProgrammer.defaultPort) {
        self.host = host
        self.port = port
    }

    // MARK: - Connection Management

    /// Connects to the TETRA radio and establishes programming session.
    public func connect() async throws {
        let nwHost = NWEndpoint.Host(host)
        let nwPort = NWEndpoint.Port(rawValue: port)!

        let parameters = NWParameters.tcp
        let conn = NWConnection(host: nwHost, port: nwPort, using: parameters)

        // Wait for connection
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            conn.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    continuation.resume()
                case .failed(let error):
                    continuation.resume(throwing: TETRAError.connectionFailed(error.localizedDescription))
                case .cancelled:
                    continuation.resume(throwing: TETRAError.connectionFailed("Connection cancelled"))
                default:
                    break
                }
            }
            conn.start(queue: .global(qos: .userInitiated))
        }

        self.connection = conn

        // Perform RP authentication sequence
        try await authenticate()
    }

    /// Disconnects from the radio.
    public func disconnect() async {
        // If in programming mode, reset to normal
        if isInProgrammingMode {
            try? await resetToNormalMode()
        }

        connection?.cancel()
        connection = nil
        isInProgrammingMode = false
        terminalID = nil
    }

    // MARK: - RP Protocol Authentication

    /// Performs the RP authentication sequence.
    /// 1. Terminal ID Request → Confirm
    /// 2. Version Report Request → Confirm → Reply
    private func authenticate() async throws {
        guard let conn = connection else {
            throw TETRAError.connectionFailed("Not connected")
        }

        // Step 1: Request Terminal ID
        let terminalIDReq = TETRAMessage.terminalIDRequest()
        try await send(terminalIDReq, to: conn)

        let terminalIDResp = try await receive(from: conn, timeout: 5.0)
        guard let response = TETRAResponse.parseRP(terminalIDResp),
              response.opcode == TETRAOpcode.terminalIDConfirm.rawValue else {
            throw TETRAError.authenticationFailed("Terminal ID request failed")
        }

        // Extract terminal ID from response
        if let idString = String(data: response.payload, encoding: .utf8) {
            self.terminalID = idString
        }

        // Step 2: Request Version Report
        let versionReq = TETRAMessage.versionReportRequest()
        try await send(versionReq, to: conn)

        // Expect VersionConfirm followed by VersionReply
        let versionConfirm = try await receive(from: conn, timeout: 5.0)
        guard let confirmResponse = TETRAResponse.parseRP(versionConfirm),
              confirmResponse.opcode == TETRAOpcode.parameterVersionConfirm.rawValue else {
            throw TETRAError.authenticationFailed("Version report confirm failed")
        }

        let versionReply = try await receive(from: conn, timeout: 5.0)
        guard let replyResponse = TETRAResponse.parseRP(versionReply),
              replyResponse.opcode == TETRAOpcode.parameterVersionReply.rawValue else {
            throw TETRAError.authenticationFailed("Version report reply failed")
        }
    }

    /// Enters programming mode.
    private func enterProgrammingMode() async throws {
        guard let conn = connection else {
            throw TETRAError.connectionFailed("Not connected")
        }

        let resetReq = TETRAMessage.resetRequest(mode: .programming)
        try await send(resetReq, to: conn)

        let statusResp = try await receive(from: conn, timeout: 10.0)
        guard let response = TETRAResponse.parseRP(statusResp) else {
            throw TETRAError.invalidResponse
        }

        // Check for rejection
        if response.opcode == TETRAOpcode.rejectIndication.rawValue {
            // Check rejection reason
            if response.payload.count > 0 {
                throw TETRAError.commandRejected(reason: "Code: 0x\(String(format: "%02X", response.payload[0]))")
            }
            throw TETRAError.commandRejected(reason: "Unknown")
        }

        guard response.opcode == TETRAOpcode.statusIndication.rawValue else {
            throw TETRAError.programmingModeRequired
        }

        isInProgrammingMode = true
    }

    /// Resets to normal mode.
    private func resetToNormalMode() async throws {
        guard let conn = connection else { return }

        let resetReq = TETRAMessage.resetRequest(mode: .normal)
        try await send(resetReq, to: conn)

        // Wait for status indication
        _ = try? await receive(from: conn, timeout: 5.0)
        isInProgrammingMode = false
    }

    // MARK: - RadioFamilyProgrammer

    public func identify() async throws -> RadioIdentification {
        // Connect if not connected
        if connection == nil {
            try await connect()
        }

        return RadioIdentification(
            modelNumber: terminalID ?? "TETRA",
            radioFamily: "mtp"
        )
    }

    /// Reads the complete codeplug from the TETRA radio.
    ///
    /// Uses extended read commands (0xF741) for larger transfers.
    /// Sequence: EnterProgrammingMode → ReadFDT → ReadDataBlocks → ResetToNormal
    public func readCodeplug(progress: @Sendable (Double) -> Void) async throws -> Data {
        // Ensure we have a connection
        if connection == nil {
            try await connect()
        }

        guard let conn = connection else {
            throw TETRAError.connectionFailed("Failed to establish connection")
        }

        progress(0.0)

        // Enter programming mode if not already
        if !isInProgrammingMode {
            try await enterProgrammingMode()
        }

        progress(0.1)

        // Request configuration to get memory layout
        let configReq = TETRAMessage.configurationRequest()
        try await send(configReq, to: conn)

        let configResp = try await receive(from: conn, timeout: 5.0)
        guard TETRAResponse.parseData(configResp) != nil else {
            throw TETRAError.invalidResponse
        }

        // TODO: Parse memory map from configuration response
        // For now, use typical TETRA codeplug addresses
        let startAddress: UInt32 = 0x00010000
        let endAddress: UInt32 = 0x00100000  // 960KB typical size

        progress(0.2)

        // Read data in blocks
        var codeplugData = Data()
        let blockSize: UInt16 = 1024
        var currentAddress = startAddress
        let totalBytes = endAddress - startAddress
        var bytesRead: UInt32 = 0

        while currentAddress < endAddress {
            let remaining = endAddress - currentAddress
            let readSize = min(UInt16(remaining), blockSize)

            // Use extended read for larger block support
            let readReq = TETRAMessage.readRequest(address: currentAddress, length: readSize, extended: true)
            try await send(readReq, to: conn)

            let readResp = try await receive(from: conn, timeout: 10.0)
            guard let response = TETRAResponse.parseData(readResp) else {
                throw TETRAError.invalidResponse
            }

            guard response.isReadResponse else {
                throw TETRAError.readFailure(address: currentAddress)
            }

            if !response.isValid {
                throw TETRAError.checksumMismatch
            }

            codeplugData.append(response.payload)
            currentAddress += UInt32(readSize)
            bytesRead += UInt32(readSize)

            // Update progress (0.2 to 0.9)
            let readProgress = 0.2 + (0.7 * Double(bytesRead) / Double(totalBytes))
            progress(readProgress)
        }

        progress(0.95)

        // Reset to normal mode
        try await resetToNormalMode()

        progress(1.0)

        return codeplugData
    }

    /// Writes a codeplug to the TETRA radio.
    ///
    /// Uses extended write commands (0xFF47) for larger transfers.
    /// Sequence: EnterProgrammingMode → WriteDataBlocks → VerifyChecksums → ResetToNormal
    public func writeCodeplug(_ data: Data, progress: @Sendable (Double) -> Void) async throws {
        // Ensure we have a connection
        if connection == nil {
            try await connect()
        }

        guard let conn = connection else {
            throw TETRAError.connectionFailed("Failed to establish connection")
        }

        progress(0.0)

        // Enter programming mode
        if !isInProgrammingMode {
            try await enterProgrammingMode()
        }

        progress(0.1)

        // Write data in blocks
        let startAddress: UInt32 = 0x00010000
        let blockSize = 512
        var currentAddress = startAddress
        var offset = 0
        let totalBytes = data.count

        while offset < data.count {
            let remaining = data.count - offset
            let writeSize = min(remaining, blockSize)
            let blockData = data[offset..<(offset + writeSize)]

            // Use extended write
            let writeReq = TETRAMessage.writeRequest(address: currentAddress, data: Data(blockData), extended: true)
            try await send(writeReq, to: conn)

            let writeResp = try await receive(from: conn, timeout: 10.0)
            guard let response = TETRAResponse.parseData(writeResp) else {
                throw TETRAError.invalidResponse
            }

            guard response.isWriteSuccess else {
                throw TETRAError.writeFailure(address: currentAddress)
            }

            currentAddress += UInt32(writeSize)
            offset += writeSize

            // Update progress (0.1 to 0.8)
            let writeProgress = 0.1 + (0.7 * Double(offset) / Double(totalBytes))
            progress(writeProgress)
        }

        progress(0.85)

        // Verify checksum
        let checksumReq = TETRAMessage.checksumRequest(address: startAddress, length: UInt16(min(data.count, 65535)), extended: true)
        try await send(checksumReq, to: conn)

        let checksumResp = try await receive(from: conn, timeout: 10.0)
        guard let response = TETRAResponse.parseData(checksumResp),
              response.isChecksumResponse else {
            throw TETRAError.invalidResponse
        }

        progress(0.95)

        // Reset to normal mode
        try await resetToNormalMode()

        progress(1.0)
    }

    /// Verifies the written codeplug matches the expected data.
    public func verify(expected: Data, progress: @Sendable (Double) -> Void) async throws -> Bool {
        let actual = try await readCodeplug(progress: progress)
        return actual == expected
    }

    // MARK: - Network Helpers

    private func send(_ data: Data, to connection: NWConnection) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            connection.send(content: data, completion: .contentProcessed { error in
                if let error = error {
                    continuation.resume(throwing: TETRAError.connectionFailed(error.localizedDescription))
                } else {
                    continuation.resume()
                }
            })
        }
    }

    private func receive(from connection: NWConnection, timeout: TimeInterval) async throws -> Data {
        return try await withThrowingTaskGroup(of: Data.self) { group in
            group.addTask {
                try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Data, Error>) in
                    connection.receive(minimumIncompleteLength: 1, maximumLength: 4096) { data, _, _, error in
                        if let error = error {
                            continuation.resume(throwing: TETRAError.connectionFailed(error.localizedDescription))
                        } else if let data = data {
                            continuation.resume(returning: data)
                        } else {
                            continuation.resume(throwing: TETRAError.invalidResponse)
                        }
                    }
                }
            }

            group.addTask {
                try await Task.sleep(for: .seconds(timeout))
                throw TETRAError.timeout
            }

            let result = try await group.next()!
            group.cancelAll()
            return result
        }
    }
}

/// Programmer for LTE/PBB radios (LEX series and other broadband devices).
/// Uses HTTP REST API for all communication - completely different from XNL/XCMP.
///
/// Transport: HTTP/HTTPS over WiFi or LTE network
/// Content Types: application/json, application/octet-stream
///
/// Key differences from PCR radios:
/// - Network-based (WiFi/LTE) instead of USB serial
/// - REST API with JSON instead of binary protocols
/// - File collection uploads instead of block-by-block transfers
/// - Session-based authentication with password
public actor LTEProgrammer: RadioFamilyProgrammer {
    private let baseURL: String
    private let httpClient: LTEURLSessionClient
    private var session: LTESession?
    private var deviceInventory: LTEDeviceInventory?
    private var isAuthenticated = false

    /// Creates an LTE programmer with a base URL.
    /// - Parameter baseURL: The base URL of the radio (e.g., "http://192.168.10.1")
    public init(baseURL: String) {
        self.baseURL = baseURL
        self.httpClient = LTEURLSessionClient(baseURL: baseURL)
    }

    /// Convenience initializer from host address.
    /// - Parameter host: The IP address or hostname of the radio
    public init(host: String) {
        let url = host.hasPrefix("http") ? host : "http://\(host)"
        self.baseURL = url
        self.httpClient = LTEURLSessionClient(baseURL: url)
    }

    // MARK: - Authentication

    /// Authenticates with the radio using the device password.
    /// - Parameter password: The programming password (empty string for no password)
    /// - Returns: Device inventory on success
    @discardableResult
    public func authenticate(password: String = "") async throws -> LTEDeviceInventory {
        let request = LTERequest.authenticate(password: password)
        let (data, _) = try await httpClient.send(request)

        guard let response = try? JSONDecoder().decode(LTEPasswordResponse.self, from: data) else {
            throw LTEError.decodingError("Failed to decode password response")
        }

        guard response.isSuccess, let inventory = response.deviceInventory else {
            throw LTEError.authenticationFailed
        }

        self.deviceInventory = inventory
        self.isAuthenticated = true
        return inventory
    }

    /// Opens a programming session.
    private func openSession(operation: LTERadioOperation) async throws {
        self.session = LTESession(operation: operation)
    }

    /// Closes the current session.
    private func closeSession(pendingDeploy: Bool = false) async throws {
        guard let session = session else { return }

        let request = LTERequest.terminateSession(sessionID: Int(session.sessionID))
        _ = try? await httpClient.send(request)

        self.session = nil
    }

    // MARK: - RadioFamilyProgrammer

    public func identify() async throws -> RadioIdentification {
        // Try to get device inventory without authentication first
        let request = LTERequest.getDeviceInventory()

        do {
            let (data, _) = try await httpClient.send(request)

            if let inventory = try? JSONDecoder().decode(LTEDeviceInventory.self, from: data) {
                self.deviceInventory = inventory
                return RadioIdentification(
                    modelNumber: inventory.model ?? "LTE",
                    serialNumber: inventory.serial,
                    firmwareVersion: inventory.firmware,
                    radioFamily: "lex",
                    codeplugVersion: inventory.codeplugVersion
                )
            }
        } catch LTEError.unauthorized, LTEError.authenticationFailed {
            // Need to authenticate first
            _ = try await authenticate(password: "")
            if let inventory = deviceInventory {
                return RadioIdentification(
                    modelNumber: inventory.model ?? "LTE",
                    serialNumber: inventory.serial,
                    firmwareVersion: inventory.firmware,
                    radioFamily: "lex",
                    codeplugVersion: inventory.codeplugVersion
                )
            }
        }

        return RadioIdentification(
            modelNumber: "LTE",
            radioFamily: "lex"
        )
    }

    /// Reads the complete codeplug from the LTE radio.
    ///
    /// Uses HTTP file collection download.
    /// Sequence: Authenticate → OpenSession → DownloadFileCollection → CloseSession
    public func readCodeplug(progress: @Sendable (Double) -> Void) async throws -> Data {
        progress(0.0)

        // Authenticate if needed
        if !isAuthenticated {
            _ = try await authenticate(password: "")
        }

        progress(0.1)

        // Open read session
        try await openSession(operation: .read)

        progress(0.2)

        // First, try to download LMR codeplug (for hybrid LTE/LMR radios)
        do {
            let lmrRequest = LTERequest.downloadLMRCodeplug()
            let (data, _) = try await httpClient.send(lmrRequest)

            progress(0.9)

            try await closeSession(pendingDeploy: false)

            progress(1.0)
            return data
        } catch {
            // LMR codeplug not available, try generic file collection
        }

        progress(0.3)

        // Download codeplug via file collection
        let fileRequest = LTERequest.downloadFileCollection(fileName: "codeplug.manifest")
        let (data, _) = try await httpClient.send(fileRequest)

        progress(0.9)

        try await closeSession(pendingDeploy: false)

        progress(1.0)

        return data
    }

    /// Writes a codeplug to the LTE radio.
    ///
    /// Uses HTTP file collection upload.
    /// Sequence: Authenticate → OpenSession → UploadFileCollection → WaitForJob → CloseSession
    public func writeCodeplug(_ data: Data, progress: @Sendable (Double) -> Void) async throws {
        progress(0.0)

        // Authenticate if needed
        if !isAuthenticated {
            _ = try await authenticate(password: "")
        }

        progress(0.1)

        // Open write session
        try await openSession(operation: .write)

        progress(0.2)

        // Try LMR codeplug upload first (for hybrid radios)
        do {
            let lmrRequest = LTERequest.uploadLMRCodeplug(data: data)
            let (responseData, _) = try await httpClient.send(lmrRequest)

            // Check for job ID in response
            if let jobResponse = try? JSONDecoder().decode(LTEJobStatus.self, from: responseData) {
                // Wait for job completion
                try await waitForJob(jobID: jobResponse.jobID, progress: { jobProgress in
                    // Map job progress to 0.3-0.9
                    progress(0.3 + (0.6 * jobProgress))
                })
            }

            progress(0.95)

            try await closeSession(pendingDeploy: true)

            progress(1.0)
            return
        } catch {
            // LMR not available, try generic upload
        }

        progress(0.3)

        // Upload via file collection
        let uploadRequest = LTERequest.uploadFileCollection(data: data)
        let (responseData, _) = try await httpClient.send(uploadRequest)

        // Check if this returns a job to track
        if let jobResponse = try? JSONDecoder().decode(LTEJobStatus.self, from: responseData) {
            try await waitForJob(jobID: jobResponse.jobID, progress: { jobProgress in
                progress(0.3 + (0.6 * jobProgress))
            })
        }

        progress(0.95)

        try await closeSession(pendingDeploy: true)

        progress(1.0)
    }

    /// Verifies the written codeplug matches the expected data.
    public func verify(expected: Data, progress: @Sendable (Double) -> Void) async throws -> Bool {
        let actual = try await readCodeplug(progress: progress)
        return actual == expected
    }

    // MARK: - Job Management

    /// Waits for a background job to complete.
    private func waitForJob(jobID: String, progress: @Sendable (Double) -> Void, timeout: TimeInterval = 120) async throws {
        let startTime = Date()
        var lastProgress = 0.0

        while Date().timeIntervalSince(startTime) < timeout {
            let request = LTERequest.getJobStatus(jobID: jobID)
            let (data, _) = try await httpClient.send(request)

            guard let status = try? JSONDecoder().decode(LTEJobStatus.self, from: data) else {
                throw LTEError.decodingError("Failed to decode job status")
            }

            if status.isComplete {
                progress(1.0)
                return
            }

            if status.isFailed {
                throw LTEError.jobFailed(status.error ?? "Unknown error")
            }

            // Update progress
            if let jobProgress = status.progress, jobProgress > lastProgress {
                lastProgress = jobProgress
                progress(jobProgress)
            }

            // Wait before polling again
            try await Task.sleep(for: .milliseconds(500))
        }

        throw LTEError.timeout
    }

    // MARK: - Additional LTE Operations

    /// Gets the list of installed applications.
    public func getApplications() async throws -> [LTEApplicationEntry] {
        let request = LTERequest.getAppInventory()
        let (data, _) = try await httpClient.send(request)

        guard let response = try? JSONDecoder().decode(LTEAppInventoryResponse.self, from: data) else {
            throw LTEError.decodingError("Failed to decode app inventory")
        }

        return response.applications ?? []
    }

    /// Gets the list of active licenses.
    public func getLicenses() async throws -> [LTELicenseEntry] {
        let request = LTERequest.getLicenseInventory()
        let (data, _) = try await httpClient.send(request)

        guard let response = try? JSONDecoder().decode(LTELicenseInventoryResponse.self, from: data) else {
            throw LTEError.decodingError("Failed to decode license inventory")
        }

        return response.licenses ?? []
    }

    /// Activates features using feature codes.
    public func activateFeatures(featureCodes: [String]) async throws {
        guard let inventory = deviceInventory else {
            _ = try await identify()
            guard let inv = deviceInventory else {
                throw LTEError.invalidResponse
            }

            let request = LTEFeatureActivationRequest(
                firmwareVersion: inv.firmware ?? "",
                serialNumber: inv.serial ?? "",
                featureCodeIDs: featureCodes
            )

            let body = try JSONEncoder().encode(request)
            let httpRequest = LTERequest(endpoint: .licenseInventory, method: .POST, body: body)
            _ = try await httpClient.send(httpRequest)
            return
        }

        let request = LTEFeatureActivationRequest(
            firmwareVersion: inventory.firmware ?? "",
            serialNumber: inventory.serial ?? "",
            featureCodeIDs: featureCodes
        )

        let body = try JSONEncoder().encode(request)
        let httpRequest = LTERequest(endpoint: .licenseInventory, method: .POST, body: body)
        _ = try await httpClient.send(httpRequest)
    }

    /// Performs a factory reset.
    public func factoryReset() async throws {
        let request = LTERequest.factoryReset()
        _ = try await httpClient.send(request)
    }
}
