import Foundation
import Darwin

/// XNL protocol opcodes for MOTOTRBO radios.
/// VERIFIED FROM CPS 2.0 CAPTURES: 2026-01-30
/// These opcodes are the low byte of the 2-byte opcode field (high byte is always 0x00)
public enum XNLOpCode: UInt8 {
    case masterStatusBroadcast = 0x02   // Radio → CPS: First packet after TCP connect
    case deviceMasterQuery = 0x04       // CPS → Radio: Query after receiving status
    case deviceSysMapBroadcast = 0x05   // Radio → CPS: Contains 8-byte auth seed
    case deviceAuthKey = 0x06           // CPS → Radio: Auth response (TEA encrypted)
    case deviceAuthKeyReply = 0x07      // Radio → CPS: Contains assigned address
    case deviceConnReply = 0x09         // Radio → CPS: Connection parameters
    case dataMessage = 0x0B             // Bidirectional: XCMP payload carrier
    case dataMessageAck = 0x0C          // ACK (but CPS doesn't send these!)
}

/// RCMP/XCMP command opcodes for radio programming.
/// Extracted from RcmpWrapper.dll and PcrSequenceManager.dll
public enum XCMPOpcode: UInt16 {
    // Radio info commands
    case radioStatus = 0x000E
    case radioStatusReply = 0x800E
    case versionInfo = 0x000F
    case versionInfoReply = 0x800F

    // Unlock/initialization commands (discovered 2026-01-29)
    case ishProgramMode = 0x0106        // Enter/exit programming mode
    case ishProgramModeReply = 0x8106
    case ishUnlockPartition = 0x0108
    case ishUnlockPartitionReply = 0x8108
    case readRadioKey = 0x0300
    case readRadioKeyReply = 0x8300
    case unlockSecurity = 0x0301
    case unlockSecurityReply = 0x8301

    // Codeplug access commands
    case psdtAccess = 0x010B
    case psdtAccessReply = 0x810B
    case componentSession = 0x010F
    case componentSessionReply = 0x810F
}

/// Partition IDs for MOTOTRBO radios.
/// From PcrProductFamilyMetadata.xml
public enum RadioPartition: UInt8 {
    case application = 128  // 0x80 - Main codeplug data
    case security = 129     // 0x81 - Security settings
    case tuning = 130       // 0x82 - Tuning/calibration
    case cfs = 135          // 0x87 - CFS data
}

/// Programming mode actions for RcmpIshProgramMode (0x0106).
/// From RcmpWrapper.dll
public enum ProgramModeAction: UInt8 {
    case exitProgramMode = 0x00
    case enterProgramMode = 0x01
    case enterCloneMode = 0x02
    case exitWithoutRadioReset = 0x03
    case enterOtapWriteMode = 0x04
    case enterOtapReadMode = 0x05
    case exitOtapModeWithChecksum = 0x06
    case enterRemoteProgrammingMode = 0x07
}

/// Connection result for XNL authentication.
public enum XNLConnectionResult {
    case success(assignedAddress: UInt16)
    case authenticationFailed(code: UInt8)
    case connectionError(String)
    case timeout
}

/// XNL connection for MOTOTRBO radios.
/// Handles TCP connection on port 8002 and TEA-based authentication.
/// Uses raw BSD sockets with TCP_NODELAY for reliable communication.
/// NWConnection was found to not work reliably with the radio protocol.
public actor XNLConnection {

    /// Standard XNL port for CPS-mode programming.
    public static let defaultPort: UInt16 = 8002

    private let host: String
    private let port: UInt16
    private var socketFD: Int32 = -1

    private var masterAddress: UInt16 = 0
    private var myAddress: UInt16 = 0x0001
    private var assignedAddress: UInt16 = 0
    private var transactionID: UInt16 = 1

    /// Session prefix extracted from XNL_KEY (DeviceConnectionReply).
    /// This becomes the high byte of XCMP transaction IDs.
    /// CPS capture shows: session 1 used 0x03, session 2 used 0x18.
    private var xcmpSessionPrefix: UInt8 = 0x03

    /// Sequence counter for XCMP commands (low byte of transaction ID).
    private var xcmpSequence: UInt8 = 0

    /// Device ID for XCMP commands (from XNL_KEY bytes 16-17).
    /// This is the TARGET device for XCMP commands, NOT our assigned address.
    /// CPS capture shows: session 1 used 0x0002, session 2 used 0x0018.
    private var xcmpDeviceID: UInt16 = 0x0002

    /// Message ID counter for XNL DataMessage packets (byte 5 in packet structure).
    /// CPS increments this with each DataMessage sent: 0x02, 0x03, 0x04...
    /// CRITICAL: This must increment for multi-command sessions to work!
    /// Note: Uses wrapping arithmetic to handle overflow after 255 commands gracefully.
    private var xnlMessageID: UInt8 = 1  // Starts at 1, so first command uses 0x02

    public var isConnected: Bool {
        socketFD >= 0
    }

    public var isAuthenticated: Bool {
        assignedAddress != 0
    }

    public init(host: String, port: UInt16 = XNLConnection.defaultPort) {
        self.host = host
        self.port = port
    }

    // MARK: - Connection

    /// Connects to the radio and performs XNL authentication.
    /// - Parameter debug: Print debug output for init handshake
    /// - Returns: Result indicating success or failure reason.
    public func connect(debug: Bool = false) async -> XNLConnectionResult {
        // Create TCP socket
        let sock = socket(AF_INET, SOCK_STREAM, 0)
        guard sock >= 0 else {
            return .connectionError("Failed to create socket")
        }

        // CRITICAL: Set TCP_NODELAY to disable Nagle's algorithm
        // Without this, small packets are buffered and the radio times out.
        // This was discovered through testing - NWConnection doesn't work reliably
        // even with noDelay=true, but raw BSD sockets do.
        var nodelay: Int32 = 1
        setsockopt(sock, IPPROTO_TCP, TCP_NODELAY, &nodelay, socklen_t(MemoryLayout<Int32>.size))

        // CRITICAL: Set SO_NOSIGPIPE to prevent SIGPIPE from crashing the app
        // when the connection is closed unexpectedly. Without this, writing to
        // a broken socket sends SIGPIPE which terminates the process.
        var nosigpipe: Int32 = 1
        setsockopt(sock, SOL_SOCKET, SO_NOSIGPIPE, &nosigpipe, socklen_t(MemoryLayout<Int32>.size))

        // Connect to radio
        var addr = sockaddr_in()
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_port = in_port_t(port).bigEndian
        addr.sin_addr.s_addr = inet_addr(host)

        let result = withUnsafePointer(to: &addr) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                Darwin.connect(sock, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }

        guard result == 0 else {
            close(sock)
            return .connectionError("Failed to connect: errno \(errno)")
        }

        self.socketFD = sock

        // Perform XNL authentication
        let authResult = await authenticate()

        // If authentication succeeded, handle the XCMP init broadcast handshake
        // CRITICAL: This handshake is required before RCMP commands will work!
        if case .success = authResult {
            await handleInitBroadcast(debug: debug)
        }

        return authResult
    }

    /// Handles the XCMP initialization handshake after XNL authentication.
    /// The radio sends DeviceInitStatusBroadcast (0xB400) and expects a response
    /// before programming commands will work.
    ///
    /// CRITICAL: Without this handshake, RCMP commands will timeout!
    ///
    /// Protocol flow (from DLL analysis):
    /// 1. Radio → CPS: B400 with InitComplete=0x00 (needs client info)
    /// 2. CPS → Radio: B400 with our client info (mirror radio's txID)
    /// 3. Radio → CPS: DataMessageAck
    /// 4. Radio → CPS: B400 with InitComplete=0x02 (transitioning)
    /// 5. Radio → CPS: B400 with InitComplete=0x01 (READY)
    /// 6. NOW XCMP commands can be sent
    ///
    /// CPS captures show ~546ms delay before first XCMP command.
    private func handleInitBroadcast(debug: Bool = false) async {
        if debug { print("[INIT] Waiting for DeviceInitStatusBroadcast (0xB400)...") }

        var sentOurResponse = false
        var receivedInitComplete = false

        // Wait for DeviceInitStatusBroadcast handshake to complete
        // PROTOCOL NOTE: CPS does NOT send XNL ACKs (0x0C) - relies on TCP for reliability
        for attempt in 0..<50 {  // Increased attempts to handle full handshake
            guard let data = await receivePacket(timeout: 0.5) else {
                // If we've already sent our response, check if we should proceed
                if sentOurResponse {
                    if receivedInitComplete {
                        if debug { print("[INIT] Handshake complete, proceeding...") }
                        return
                    }
                    // Give radio time to send InitComplete broadcasts
                    if attempt > 10 {
                        if debug { print("[INIT] Timeout waiting for InitComplete, proceeding anyway...") }
                        return
                    }
                }
                if debug && attempt % 5 == 0 { print("[INIT] Waiting for broadcast (attempt \(attempt + 1))") }
                continue
            }

            // Handle DataMessageAck - just skip (radio sends these)
            if data.count >= 4 && data[3] == XNLOpCode.dataMessageAck.rawValue {
                if debug { print("[INIT] Received ACK from radio") }
                continue
            }

            // Skip DevSysMapBroadcast (XNL opcode 0x09)
            if data.count >= 4 && data[3] == XNLOpCode.deviceSysMapBroadcast.rawValue {
                if debug { print("[INIT] Skipping DevSysMapBroadcast") }
                continue
            }

            // Check if it's a DataMessage with XCMP payload
            guard data.count >= 16,
                  data[3] == XNLOpCode.dataMessage.rawValue,
                  data[4] == 0x01  // XCMP flag
            else {
                if debug { print("[INIT] Received non-XCMP packet, skipping...") }
                continue
            }

            // CPS does NOT send XNL ACKs - relies on TCP for reliability!
            // The protocol document explicitly states this.
            let rxTxID = UInt16(data[10]) << 8 | UInt16(data[11])
            let srcAddr = UInt16(data[8]) << 8 | UInt16(data[9])

            if debug { print("[INIT] Received DataMessage txID 0x\(String(format: "%04X", rxTxID)) from 0x\(String(format: "%04X", srcAddr)) (no ACK per CPS protocol)") }

            // Extract XCMP opcode (bytes 14-15)
            let xcmpOpcode = UInt16(data[14]) << 8 | UInt16(data[15])

            // Handle DeviceInitStatusBroadcast (0xB400)
            if xcmpOpcode == 0xB400 {
                if debug {
                    print("[INIT] Received DeviceInitStatusBroadcast")
                    print("[INIT] Full packet: \(data.map { String(format: "%02X", $0) }.joined(separator: " "))")
                }

                // Extract the radio's transaction ID (bytes 10-11)
                // CRITICAL: CPS mirrors this txID in its B400 response!
                let radioTxID = UInt16(data[10]) << 8 | UInt16(data[11])

                // Check initComplete byte (XCMP payload structure: opcode 2B + version 3B + entityType 1B + initComplete 1B)
                // XCMP payload starts at packet offset 14, so initComplete is at offset 14 + 6 = 20
                if data.count >= 21 {
                    let initComplete = data[20]
                    if debug { print("[INIT] InitComplete: 0x\(String(format: "%02X", initComplete)), radioTxID: 0x\(String(format: "%04X", radioTxID))") }

                    if initComplete == 0x00 && !sentOurResponse {
                        // Radio wants us to respond - send our DeviceInitStatusBroadcast
                        if debug { print("[INIT] InitComplete=0, sending response (mirroring txID 0x\(String(format: "%04X", radioTxID)))...") }

                        // Build our response: opcode + version(3) + entityType(1) + initComplete(1) + status...
                        // CRITICAL: CPS uses version 00 00 00, NOT the radio's version!
                        var response = Data()
                        response.append(0xB4)
                        response.append(0x00)
                        response.append(0x00)  // majorVersion = 0x00 (CPS verified)
                        response.append(0x00)  // minorVersion = 0x00 (CPS verified)
                        response.append(0x00)  // revVersion = 0x00
                        response.append(0x00)  // EntityType: 0
                        response.append(0x00)  // InitComplete: 0 (STATUS mode)
                        response.append(0x0A)  // DeviceType: IPPeripheral
                        response.append(0x00)  // Status high
                        response.append(0x00)  // Status low
                        response.append(0x00)  // Descriptor length: 0

                        if debug { print("[INIT] Sending to master (0x\(String(format: "%04X", masterAddress))): \(response.map { String(format: "%02X", $0) }.joined(separator: " "))") }

                        // CRITICAL: Mirror the radio's txID in our response (CPS verified)
                        try? await sendXCMPToMaster(response, mirrorTxID: radioTxID, debug: debug)
                        sentOurResponse = true
                        // Continue loop to wait for InitComplete != 0x00

                    } else if initComplete == 0x01 || initComplete == 0x02 {
                        // InitComplete != 0x00 means radio is transitioning (0x02) or ready (0x01)
                        if debug { print("[INIT] InitComplete=0x\(String(format: "%02X", initComplete)) - \(initComplete == 0x01 ? "READY" : "transitioning")") }
                        receivedInitComplete = true
                        if initComplete == 0x01 {
                            // Radio is fully ready
                            if debug { print("[INIT] Radio initialization complete!") }
                            // CPS waits ~546ms after auth before first command - add a small delay
                            try? await Task.sleep(for: .milliseconds(100))
                            return
                        }
                        // Continue loop for 0x02 (transitioning) to wait for 0x01
                    }
                }
                continue
            }

            // Skip other broadcasts (0xB410, etc.)
            if xcmpOpcode & 0xF000 == 0xB000 {
                if debug { print("[INIT] Skipping broadcast 0x\(String(format: "%04X", xcmpOpcode))") }
                continue
            }
        }

        if debug { print("[INIT] Init broadcast handling complete (attempts exhausted)") }
        // Add delay similar to CPS behavior even if we didn't see InitComplete=0x01
        try? await Task.sleep(for: .milliseconds(100))
    }

    /// Disconnects from the radio.
    public func disconnect() {
        if socketFD >= 0 {
            close(socketFD)
            socketFD = -1
        }
        masterAddress = 0
        assignedAddress = 0
        transactionID = 1
        xcmpSessionPrefix = 0x03  // Default
        xcmpSequence = 0
        xcmpDeviceID = 0x0002     // Default
        xnlMessageID = 1          // Reset for new session
    }

    // MARK: - Authentication Flow
    // VERIFIED FROM CPS 2.0 CAPTURES: 2026-01-30
    // Flow: Radio sends first, CPS responds

    private func authenticate() async -> XNLConnectionResult {
        // Step 1: WAIT for MasterStatusBroadcast (radio sends first!)
        // CPS capture: 00 13 00 02 00 00 00 00 00 06 00 00 00 07 00 00 00 02 01 01 01
        guard let broadcastData = await receivePacket(timeout: 5.0),
              broadcastData.count >= 14,
              broadcastData[3] == XNLOpCode.masterStatusBroadcast.rawValue else {
            return .timeout
        }

        masterAddress = UInt16(broadcastData[8]) << 8 | UInt16(broadcastData[9])

        // Step 2: Send DEV_MASTER_QUERY (opcode 0x04)
        // CPS capture: 00 0c 00 04 00 00 00 06 00 00 00 00 00 00
        let queryPacket = buildXNLPacket(opcode: .deviceMasterQuery, dest: masterAddress, src: 0, txID: 0)
        do {
            try await send(queryPacket)
        } catch {
            return .connectionError("Failed to send master query: \(error.localizedDescription)")
        }

        // Step 3: Wait for DEV_SYSMAP_BRDCST (opcode 0x05) containing auth seed
        // CPS capture: 00 16 00 05 00 00 00 00 00 06 00 00 00 0a ff fe [8-byte seed]
        var sysMapData: Data?
        for _ in 0..<5 {
            guard let data = await receivePacket(timeout: 5.0), data.count >= 14 else {
                continue
            }
            if data[3] == XNLOpCode.deviceSysMapBroadcast.rawValue {
                sysMapData = data
                break
            }
        }

        guard let seedPacket = sysMapData, seedPacket.count >= 22 else {
            return .timeout
        }

        // Extract session prefix and seed from SYSMAP_BRDCST
        // Format: ... 00 0a ff [prefix] [8-byte seed]
        // Offset 14 is payload start, ff is at 14, prefix at 15, seed at 16-23
        let sessionPrefix = seedPacket[15]
        let seed = Data(seedPacket[16..<24])

        // Step 4: Encrypt seed with TEA algorithm
        guard let authResponse = XNLEncryption.encrypt(seed) else {
            return .connectionError("Failed to encrypt auth seed")
        }

        // Step 5: Send DEV_AUTH_KEY (opcode 0x06)
        // CPS capture: 00 18 00 06 00 08 00 06 ff fe 00 00 00 0c 00 00 0a 00 [8-byte auth]
        // Build packet with flags=0x0008, dest=masterAddress, src=ff[prefix]
        var authPacket = Data()
        let authLen: UInt16 = 24  // Total packet length
        authPacket.append(UInt8(authLen >> 8))
        authPacket.append(UInt8(authLen & 0xFF))
        authPacket.append(0x00)  // High byte of opcode
        authPacket.append(XNLOpCode.deviceAuthKey.rawValue)  // 0x06
        authPacket.append(0x00)  // Flags high byte
        authPacket.append(0x08)  // Flags low byte (0x0008 = auth)
        authPacket.append(UInt8(masterAddress >> 8))  // Dest high
        authPacket.append(UInt8(masterAddress & 0xFF))  // Dest low
        authPacket.append(0xFF)  // Src high (ff prefix)
        authPacket.append(sessionPrefix)  // Src low (session prefix)
        authPacket.append(0x00)  // TxID high
        authPacket.append(0x00)  // TxID low
        authPacket.append(0x00)  // Payload length high
        authPacket.append(0x0C)  // Payload length low (12 bytes)
        // Payload: 00 00 0a 00 [8-byte auth response]
        authPacket.append(0x00)
        authPacket.append(0x00)
        authPacket.append(0x0A)  // Device type
        authPacket.append(0x00)
        authPacket.append(contentsOf: authResponse)

        do {
            try await send(authPacket)
        } catch {
            return .connectionError("Failed to send auth key: \(error.localizedDescription)")
        }

        // Step 6: Wait for AUTH_KEY_REPLY (opcode 0x07)
        // CPS capture: 00 1a 00 07 00 08 ff fe 00 06 00 00 00 0e 01 03 00 02 ...
        var authReply: Data?
        for _ in 0..<5 {
            guard let data = await receivePacket(timeout: 5.0), data.count >= 14 else {
                continue
            }
            if data[3] == XNLOpCode.deviceAuthKeyReply.rawValue {
                authReply = data
                break
            }
        }

        guard let replyData = authReply, replyData.count >= 18 else {
            return .timeout
        }

        // AUTH_KEY_REPLY format (from CPS capture):
        // byte 14: Result code (0x01 = success)
        // byte 15: Session prefix (becomes high byte of XCMP txID)
        // bytes 16-17: Assigned address
        let resultCode = replyData[14]
        if resultCode != 0x01 {
            return .authenticationFailed(code: resultCode)
        }

        // Extract session prefix (byte 15) for XCMP transaction IDs
        // CPS capture: session prefix 0x03 → txIDs: 0x0301, 0x0302...
        xcmpSessionPrefix = replyData[15]
        xcmpSequence = 0
        xnlMessageID = 1  // Reset; first XCMP command will use 0x02

        // Extract our assigned address (bytes 16-17, big endian)
        // This is used as our source address in packets (ACKs, etc.)
        assignedAddress = UInt16(replyData[16]) << 8 | UInt16(replyData[17])

        // Device ID for XCMP commands (same value in CPS captures)
        // CPS capture 1: 0x0002, CPS capture 2: 0x0018
        xcmpDeviceID = assignedAddress

        // Step 7: Wait for CONN_REPLY (opcode 0x09)
        // CPS capture: 00 1d 00 09 00 00 00 00 00 06 00 00 00 11 ...
        var connReply: Data?
        for _ in 0..<5 {
            guard let data = await receivePacket(timeout: 5.0), data.count >= 14 else {
                continue
            }
            if data[3] == XNLOpCode.deviceConnReply.rawValue {
                connReply = data
                break
            }
        }

        guard connReply != nil else {
            // CONN_REPLY not critical for operation, proceed anyway
            return .success(assignedAddress: assignedAddress)
        }

        return .success(assignedAddress: assignedAddress)
    }

    // MARK: - Packet Building

    private func buildXNLPacket(opcode: XNLOpCode, dest: UInt16 = 0, src: UInt16 = 0, txID: UInt16 = 0, data: Data = Data()) -> Data {
        let totalLen = UInt16(12 + data.count)
        let dataLen = UInt16(data.count)

        var pkt = Data()
        pkt.append(UInt8(totalLen >> 8))
        pkt.append(UInt8(totalLen & 0xFF))
        pkt.append(0x00)  // Reserved
        pkt.append(opcode.rawValue)
        pkt.append(0x00)  // XCMP flag
        pkt.append(0x00)  // Flags
        pkt.append(UInt8(dest >> 8))
        pkt.append(UInt8(dest & 0xFF))
        pkt.append(UInt8(src >> 8))
        pkt.append(UInt8(src & 0xFF))
        pkt.append(UInt8(txID >> 8))
        pkt.append(UInt8(txID & 0xFF))
        pkt.append(UInt8(dataLen >> 8))
        pkt.append(UInt8(dataLen & 0xFF))
        pkt.append(data)
        return pkt
    }

    private func nextTransactionID() -> UInt16 {
        let id = transactionID
        transactionID += 1
        return id
    }

    /// Returns the next XCMP transaction ID using CPS-verified format.
    /// Format: [sessionPrefix:1][sequence:1] where sessionPrefix is from XNL_KEY offset 15.
    /// CPS capture shows:
    ///   Session 1: 0x0301, 0x0302, 0x0303...
    ///   Session 2: 0x1801, 0x1802, 0x1803...
    private func nextXCMPTransactionID() -> UInt16 {
        xcmpSequence += 1
        return UInt16(xcmpSessionPrefix) << 8 | UInt16(xcmpSequence)
    }

    // MARK: - Send/Receive

    // NOTE: CPS does NOT send XNL ACKs (0x0C) - relies on TCP for reliability.
    // The buildAckPacket method was removed based on protocol analysis.

    private func send(_ data: Data, debug: Bool = false) async throws {
        guard socketFD >= 0 else {
            throw NSError(domain: "XNL", code: -1, userInfo: [NSLocalizedDescriptionKey: "Not connected"])
        }

        if debug { print("[SEND] Attempting to send \(data.count) bytes...") }

        var bytes = [UInt8](data)
        var totalSent = 0

        // Loop to handle partial sends - TCP may not send all bytes at once
        while totalSent < bytes.count {
            let remaining = bytes.count - totalSent
            let sent = bytes.withUnsafeMutableBufferPointer { buffer in
                Darwin.send(socketFD, buffer.baseAddress! + totalSent, remaining, 0)
            }

            if sent < 0 {
                let err = errno
                if debug { print("[SEND] ERROR: errno \(err) after \(totalSent) bytes") }

                // Handle connection closed/broken pipe
                if err == EPIPE || err == ECONNRESET || err == ENOTCONN {
                    // Mark connection as closed
                    close(socketFD)
                    socketFD = -1
                    throw NSError(domain: "XNL", code: Int(err), userInfo: [NSLocalizedDescriptionKey: "Connection closed by radio"])
                }

                throw NSError(domain: "XNL", code: Int(err), userInfo: [NSLocalizedDescriptionKey: "Send failed: errno \(err)"])
            }

            if sent == 0 {
                // Connection closed gracefully
                close(socketFD)
                socketFD = -1
                throw NSError(domain: "XNL", code: -1, userInfo: [NSLocalizedDescriptionKey: "Connection closed"])
            }

            totalSent += sent

            if debug && sent < remaining {
                print("[SEND] Partial send: \(sent)/\(remaining) bytes, continuing...")
            }
        }

        if debug { print("[SEND] Success - \(totalSent) bytes sent") }
    }

    private func receivePacket(timeout: TimeInterval) async -> Data? {
        guard socketFD >= 0 else { return nil }

        // Set receive timeout
        var tv = timeval()
        tv.tv_sec = Int(timeout)
        tv.tv_usec = Int32((timeout - Double(Int(timeout))) * 1_000_000)
        setsockopt(socketFD, SOL_SOCKET, SO_RCVTIMEO, &tv, socklen_t(MemoryLayout<timeval>.size))

        var buffer = [UInt8](repeating: 0, count: 1024)
        let n = recv(socketFD, &buffer, 1024, 0)

        if n > 0 {
            return Data(buffer[0..<n])
        }
        return nil
    }

    // MARK: - Public API for XCMP Commands

    /// Drains any pending messages from the radio.
    /// Used before sending a new command to clear any retransmissions from previous commands
    /// and to handle any B400 broadcasts that might be pending.
    ///
    /// PROTOCOL NOTE: CPS does NOT send XNL ACKs (0x0C) - relies on TCP for reliability.
    /// We simply consume pending messages without ACKing them.
    ///
    /// This is critical for reliable command sequencing - the radio may have
    /// queued responses or broadcasts that need to be processed before we send
    /// a new command.
    private func drainPendingMessages(debug: Bool = false) async {
        var cleanIterations = 0
        var messagesConsumed = 0
        let startTime = Date()
        let maxDrainTime: TimeInterval = 2.0  // Maximum total drain time

        if debug { print("[DRAIN] Starting drain...") }

        // Check for any pending data - continue until we have 3 clean reads
        // or we've consumed 10 messages (to avoid infinite loop)
        for iteration in 0..<20 {
            // Safety: don't drain for more than maxDrainTime total
            if Date().timeIntervalSince(startTime) > maxDrainTime {
                if debug { print("[DRAIN] Total time limit reached, proceeding...") }
                return
            }

            if debug { print("[DRAIN] Iteration \(iteration), waiting for data...") }

            guard let data = await receivePacket(timeout: 0.15) else {
                cleanIterations += 1
                if debug { print("[DRAIN] Clean read \(cleanIterations)/3 (iteration \(iteration))") }
                // After 3 clean reads in a row, we're done
                if cleanIterations >= 3 {
                    if debug { print("[DRAIN] Complete after \(messagesConsumed) messages, \(cleanIterations) clean reads") }
                    return
                }
                continue
            }

            if debug { print("[DRAIN] Received \(data.count) bytes") }

            // Reset clean counter when we receive data
            cleanIterations = 0
            messagesConsumed += 1

            // Limit how many messages we drain to avoid getting stuck
            if messagesConsumed > 10 {
                if debug { print("[DRAIN] Limit reached, proceeding...") }
                return
            }

            if data.count >= 14 {
                let opcode = data[3]
                let rxTxID = UInt16(data[10]) << 8 | UInt16(data[11])

                // Just log what we're draining - no ACKs sent (CPS protocol)
                if opcode == XNLOpCode.dataMessage.rawValue {
                    if debug {
                        // Check if it's a B4xx broadcast
                        if data.count >= 16 {
                            let xcmpOpcode = UInt16(data[14]) << 8 | UInt16(data[15])
                            if xcmpOpcode & 0xF000 == 0xB000 {
                                print("[DRAIN] Consumed broadcast 0x\(String(format: "%04X", xcmpOpcode)) txID 0x\(String(format: "%04X", rxTxID))")
                            } else {
                                print("[DRAIN] Consumed stale response 0x\(String(format: "%04X", xcmpOpcode)) txID 0x\(String(format: "%04X", rxTxID))")
                            }
                        } else {
                            print("[DRAIN] Consumed message txID 0x\(String(format: "%04X", rxTxID))")
                        }
                    }
                } else if opcode == XNLOpCode.dataMessageAck.rawValue {
                    // Just a stray ACK from radio, ignore
                    if debug { print("[DRAIN] Ignored stray ACK txID 0x\(String(format: "%04X", rxTxID))") }
                } else if debug {
                    print("[DRAIN] Discarded message opcode 0x\(String(format: "%02X", opcode))")
                }
            }
        }

        if debug { print("[DRAIN] Max iterations reached after \(messagesConsumed) messages") }
    }

    /// Sends an XCMP broadcast without waiting for a response.
    /// Used for DeviceInitStatusBroadcast responses.
    /// - Parameters:
    ///   - xcmpData: The XCMP payload data
    ///   - debug: Print debug info
    private func sendXCMPBroadcast(_ xcmpData: Data, debug: Bool = false) async throws {
        guard isAuthenticated else {
            throw NSError(domain: "XNL", code: -1, userInfo: [NSLocalizedDescriptionKey: "Not authenticated"])
        }

        // Wrap XCMP in XNL DataMessage with XCMP flag set
        // Send to address 0 (broadcast)
        var packet = buildXNLPacket(opcode: .dataMessage, dest: 0, src: assignedAddress, txID: nextTransactionID(), data: xcmpData)
        // Set XCMP flag (byte 4) to indicate XCMP payload
        packet[4] = 0x01

        if debug {
            print("[XNL TX BROADCAST] \(packet.map { String(format: "%02X", $0) }.joined(separator: " "))")
        }

        try await send(packet)
        // Don't wait for response - broadcasts don't get replies
    }

    /// Sends an XCMP packet to the master (control unit) without waiting for a response.
    /// Used for DeviceInitStatusBroadcast responses during initialization.
    /// - Parameters:
    ///   - xcmpData: The XCMP payload data
    ///   - mirrorTxID: Optional transaction ID to mirror (CPS mirrors radio's txID for B400 responses)
    ///   - debug: Print debug info
    private func sendXCMPToMaster(_ xcmpData: Data, mirrorTxID: UInt16? = nil, debug: Bool = false) async throws {
        guard isAuthenticated else {
            throw NSError(domain: "XNL", code: -1, userInfo: [NSLocalizedDescriptionKey: "Not authenticated"])
        }

        // Use mirrored txID if provided, otherwise generate new one
        let txID = mirrorTxID ?? nextTransactionID()

        // Wrap XCMP in XNL DataMessage with XCMP flag set
        // Send to master address (control unit), not broadcast!
        var packet = buildXNLPacket(opcode: .dataMessage, dest: masterAddress, src: assignedAddress, txID: txID, data: xcmpData)
        // Set XCMP flag (byte 4) to indicate XCMP payload
        packet[4] = 0x01

        if debug {
            print("[XNL TX TO MASTER] \(packet.map { String(format: "%02X", $0) }.joined(separator: " "))")
        }

        try await send(packet)
        // Don't wait for response - init broadcasts don't get direct replies
    }

    /// Sends an XCMP command and waits for response.
    /// - Parameters:
    ///   - xcmpData: The XCMP payload data
    ///   - timeout: Timeout in seconds
    ///   - debug: Print debug info
    /// - Returns: Response data or nil on timeout
    public func sendXCMP(_ xcmpData: Data, timeout: TimeInterval = 5.0, debug: Bool = false) async throws -> Data? {
        guard isAuthenticated else {
            throw NSError(domain: "XNL", code: -1, userInfo: [NSLocalizedDescriptionKey: "Not authenticated"])
        }

        // Check connection state
        if debug {
            if socketFD >= 0 {
                print("[XNL] Connection state: connected (fd=\(socketFD))")
            } else {
                print("[XNL] WARNING: not connected!")
            }
        }

        // NOTE: Python doesn't drain before commands - just sends immediately

        // Add delay before sending - CPS shows ~546ms after auth
        // Testing longer delays to see if radio needs more processing time
        try? await Task.sleep(for: .milliseconds(500))

        // Build XCMP packet using STANDARD XNL structure (like Python build_xnl)
        // CRITICAL FIX: The earlier "CPS structure" interpretation was WRONG!
        // CPS uses standard XNL packet structure where bytes 6-7 are DEST (not flags)
        // and bytes 8-9 are SRC (not device ID).
        //
        // Standard XNL DataMessage structure:
        //   Bytes 0-1:  Length (total packet length excluding length field itself)
        //   Bytes 2-3:  Opcode (0x000B for DataMessage)
        //   Byte 4:     XCMP flag (0x01 for XCMP messages)
        //   Byte 5:     Flags (0x00 per Python)
        //   Bytes 6-7:  Destination address (master/radio address)
        //   Bytes 8-9:  Source address (our assigned address)
        //   Bytes 10-11: TxID (session_prefix + sequence)
        //   Bytes 12-13: Payload length
        //   Bytes 14+:  XCMP payload
        //
        // Python: build_xnl(0x0B, master, my_addr, tx_id, 1, xcmp_data, 0)
        // Format: struct.pack('>HBBBBHHHH', total_len, 0, opcode, xcmp_flag, flags, dest, src, tx_id, data_len)

        let ourTxID = nextXCMPTransactionID()
        let payloadLen = UInt16(xcmpData.count)
        let totalLen = UInt16(12 + xcmpData.count)  // Header (excluding length field) + payload

        // CRITICAL: Increment message ID for each DataMessage we send
        // CPS traffic shows byte 5 incrementing: 0x02, 0x03, 0x04, 0x05...
        // This is essential for multi-command sessions!
        // Use wrapping arithmetic (&+=) to handle overflow after 255 gracefully
        xnlMessageID &+= 1
        let messageID = xnlMessageID

        var packet = Data()
        packet.append(UInt8(totalLen >> 8))         // Length high (byte 0)
        packet.append(UInt8(totalLen & 0xFF))       // Length low (byte 1)
        packet.append(0x00)                         // Reserved (byte 2)
        packet.append(XNLOpCode.dataMessage.rawValue)  // Opcode (byte 3) = 0x0B
        packet.append(0x01)                         // XCMP flag (byte 4) = 1 for XCMP
        packet.append(messageID)                    // Message ID (byte 5) = incrementing: 0x02, 0x03, 0x04...
        packet.append(UInt8(masterAddress >> 8))    // Dest high (byte 6) - master/radio
        packet.append(UInt8(masterAddress & 0xFF))  // Dest low (byte 7)
        packet.append(UInt8(assignedAddress >> 8))  // Src high (byte 8) - our address
        packet.append(UInt8(assignedAddress & 0xFF))// Src low (byte 9)
        packet.append(UInt8(ourTxID >> 8))          // TxID high (byte 10) - session prefix
        packet.append(UInt8(ourTxID & 0xFF))        // TxID low (byte 11) - sequence
        packet.append(UInt8(payloadLen >> 8))       // Payload length high (byte 12)
        packet.append(UInt8(payloadLen & 0xFF))     // Payload length low (byte 13)
        packet.append(xcmpData)                     // XCMP payload (byte 14+)

        if debug {
            print("[XNL TX] \(packet.map { String(format: "%02X", $0) }.joined(separator: " ")) (xcmpTxID=0x\(String(format: "%04X", ourTxID)), msgID=0x\(String(format: "%02X", messageID)), session=0x\(String(format: "%02X", xcmpSessionPrefix)))")
        }

        try await send(packet, debug: debug)

        // Wait for response
        // Radio sends: 1) DataMessageAck (0x0C) - just an acknowledgment, no data
        //              2) DataMessage (0x0B) - actual XCMP response with payload
        // We need to skip the ACK and wait for the actual response with MATCHING txID
        // NOTE: Radio sends many B400 broadcasts during initialization, plus may retransmit
        // previous responses, so we need many attempts to wait through all of them.
        var receivedOurAck = false

        if debug { print("[XNL] Waiting for response (total timeout=\(timeout)s)...") }

        // Use shorter per-receive timeout (0.5s like Python) with multiple attempts
        // Total wait time is controlled by number of attempts * per-receive timeout
        let perReceiveTimeout = 0.5
        let maxAttempts = Int(timeout / perReceiveTimeout) + 10  // Extra attempts for processing

        for attempt in 0..<maxAttempts {
            if debug { print("[XNL RX] Attempt \(attempt + 1)/\(maxAttempts), waiting...") }
            guard let data = await receivePacket(timeout: perReceiveTimeout) else {
                if debug { print("[XNL RX] Timeout (attempt \(attempt + 1))") }
                // Only return nil after exhausting all attempts
                if attempt >= maxAttempts - 1 {
                    return nil
                }
                continue  // Try again
            }

            if debug {
                print("[XNL RX] \(data.map { String(format: "%02X", $0) }.joined(separator: " "))")
            }

            if data.count >= 14 {
                let opcode = data[3]
                let xcmpFlag = data[4]
                let rxTxID = UInt16(data[10]) << 8 | UInt16(data[11])

                if debug {
                    print("         Opcode: 0x\(String(format: "%02X", opcode)), XCMP flag: \(xcmpFlag), txID: 0x\(String(format: "%04X", rxTxID))")
                }

                // Handle DataMessageAck (0x0C)
                if opcode == XNLOpCode.dataMessageAck.rawValue {
                    if rxTxID == ourTxID {
                        if debug { print("         (ACK for our request, waiting for response...)") }
                        receivedOurAck = true
                    } else {
                        if debug { print("         (ACK for different txID, skipping...)") }
                    }
                    continue  // Keep waiting for actual DataMessage response
                }

                // Skip DevSysMapBroadcast (0x09) - system broadcast, not our response
                if opcode == XNLOpCode.deviceSysMapBroadcast.rawValue {
                    if debug { print("         (SysMapBroadcast, skipping...)") }
                    continue
                }

                // DataMessage (0x0B) contains XCMP payload
                if opcode == XNLOpCode.dataMessage.rawValue {
                    // Standard XNL structure:
                    // Byte 4: XCMP flag
                    // Byte 5: Flags
                    // Bytes 6-7: Destination address
                    // Bytes 8-9: Source address

                    // CRITICAL: CPS does NOT send XNL ACKs - relies on TCP for reliability!
                    // The protocol document explicitly states this. Sending ACKs may confuse the radio.
                    if debug {
                        let destAddr = UInt16(data[6]) << 8 | UInt16(data[7])
                        let srcAddr = UInt16(data[8]) << 8 | UInt16(data[9])
                        print("         (DataMessage from 0x\(String(format: "%04X", srcAddr)) to 0x\(String(format: "%04X", destAddr)), no ACK per CPS protocol)")
                    }

                    // Check if it's a broadcast XCMP message (0xBxxx opcodes)
                    if data.count > 14 {
                        let xcmpOpcode = UInt16(data[14]) << 8 | UInt16(data[15])
                        if xcmpOpcode & 0xF000 == 0xB000 {
                            if debug { print("         (XCMP broadcast 0x\(String(format: "%04X", xcmpOpcode)), skipping...)") }
                            continue
                        }
                    }

                    // CRITICAL: Check if this response matches our request's transaction ID
                    // The radio may send responses for previous requests if they were queued
                    if rxTxID != ourTxID {
                        if debug { print("         (Response for different txID 0x\(String(format: "%04X", rxTxID)), expected 0x\(String(format: "%04X", ourTxID)), skipping...)") }
                        continue
                    }

                    // Extract XCMP payload (skip XNL header: 14 bytes)
                    if data.count > 14 {
                        let xcmpPayload = Data(data[14...])
                        if debug { print("         XCMP payload: \(xcmpPayload.map { String(format: "%02X", $0) }.joined(separator: " "))") }

                        // Add delay after receiving response before returning
                        // Testing longer delays to see if radio needs processing time
                        try? await Task.sleep(for: .milliseconds(500))

                        return xcmpPayload
                    }
                    return Data()
                }
            }
        }

        if debug {
            if receivedOurAck {
                print("[XNL] Radio ACKed our command but never sent response - possible protocol issue")
            } else {
                print("[XNL] No ACK or response received")
            }
        }
        return nil
    }

    // MARK: - Radio Initialization Sequence

    /// Result of the radio initialization sequence.
    public enum InitializationResult {
        case success
        case enterProgramModeFailed(code: UInt8)
        case readRadioKeyFailed(code: UInt8)
        case unlockSecurityFailed(code: UInt8)
        case unlockPartitionFailed(code: UInt8)
        case notAuthenticated
        case timeout
    }

    /// Performs the complete initialization sequence required before PSDT access.
    /// Must be called after successful XNL authentication.
    ///
    /// Sequence:
    /// 0. Enter programming mode (0x0106) - CRITICAL for radio to accept RCMP commands
    /// 1. Read radio key (0x0300)
    /// 2. Encrypt key using LFSR algorithm
    /// 3. Unlock security (0x0301)
    /// 4. Unlock partition (0x0108)
    ///
    /// - Parameter partition: Partition to unlock (default: application)
    /// - Parameter debug: Print debug output
    /// - Returns: Result indicating success or failure reason
    public func initialize(partition: RadioPartition = .application, debug: Bool = false) async -> InitializationResult {
        guard isAuthenticated else {
            return .notAuthenticated
        }

        if debug {
            print("[INIT] Starting radio initialization sequence...")
        }

        // Step 0: Enter programming mode - REQUIRED before RCMP commands work
        if debug { print("[INIT] Step 0: Entering programming mode (0x0106)...") }
        let enterProgramCmd = Data([
            UInt8(XCMPOpcode.ishProgramMode.rawValue >> 8),
            UInt8(XCMPOpcode.ishProgramMode.rawValue & 0xFF),
            ProgramModeAction.enterProgramMode.rawValue  // 0x01
        ])

        guard let programResponse = try? await sendXCMP(enterProgramCmd, timeout: 5.0, debug: debug) else {
            if debug { print("[INIT] Failed to enter programming mode: timeout") }
            return .timeout
        }

        // Check response: [opcode 2B] [error 1B]
        if programResponse.count >= 3 {
            let programError = programResponse[2]
            if programError != 0x00 {
                if debug { print("[INIT] Enter programming mode failed with error: 0x\(String(format: "%02X", programError))") }
                return .enterProgramModeFailed(code: programError)
            }
        }
        if debug { print("[INIT] Programming mode entered successfully") }

        // Step 1: Read radio key
        if debug { print("[INIT] Step 1: Reading radio key (0x0300)...") }
        let readKeyCmd = Data([
            UInt8(XCMPOpcode.readRadioKey.rawValue >> 8),
            UInt8(XCMPOpcode.readRadioKey.rawValue & 0xFF)
        ])

        guard let keyResponse = try? await sendXCMP(readKeyCmd, timeout: 5.0, debug: debug) else {
            if debug { print("[INIT] Failed to read radio key: timeout") }
            return .timeout
        }

        // Check response: [opcode 2B] [error 1B] [key 32B]
        if keyResponse.count < 35 {
            if debug { print("[INIT] Invalid key response length: \(keyResponse.count)") }
            return .readRadioKeyFailed(code: 0xFF)
        }

        let keyError = keyResponse[2]
        if keyError != 0x00 {
            if debug { print("[INIT] Read radio key failed with error: 0x\(String(format: "%02X", keyError))") }
            return .readRadioKeyFailed(code: keyError)
        }

        let radioKey = Data(keyResponse[3..<35])
        if debug {
            print("[INIT] Radio key: \(radioKey.map { String(format: "%02X", $0) }.joined(separator: " "))")
        }

        // Step 2: Encrypt the radio key
        guard let encryptedKey = XNLEncryption.encryptRadioKey(radioKey) else {
            if debug { print("[INIT] Failed to encrypt radio key") }
            return .readRadioKeyFailed(code: 0xFE)
        }

        if debug {
            print("[INIT] Encrypted key: \(encryptedKey.map { String(format: "%02X", $0) }.joined(separator: " "))")
        }

        // Step 3: Unlock security
        if debug { print("[INIT] Step 2: Unlocking security (0x0301)...") }
        var unlockCmd = Data([
            UInt8(XCMPOpcode.unlockSecurity.rawValue >> 8),
            UInt8(XCMPOpcode.unlockSecurity.rawValue & 0xFF)
        ])
        unlockCmd.append(encryptedKey)

        guard let unlockResponse = try? await sendXCMP(unlockCmd, timeout: 5.0, debug: debug) else {
            if debug { print("[INIT] Failed to unlock security: timeout") }
            return .timeout
        }

        // Check response: [opcode 2B] [error 1B]
        if unlockResponse.count < 3 {
            if debug { print("[INIT] Invalid unlock response length: \(unlockResponse.count)") }
            return .unlockSecurityFailed(code: 0xFF)
        }

        let unlockError = unlockResponse[2]
        if unlockError != 0x00 {
            if debug { print("[INIT] Unlock security failed with error: 0x\(String(format: "%02X", unlockError))") }
            return .unlockSecurityFailed(code: unlockError)
        }

        if debug { print("[INIT] Security unlocked successfully") }

        // Step 4: Unlock partition
        if debug { print("[INIT] Step 3: Unlocking partition 0x\(String(format: "%02X", partition.rawValue)) (0x0108)...") }
        let partitionCmd = Data([
            UInt8(XCMPOpcode.ishUnlockPartition.rawValue >> 8),
            UInt8(XCMPOpcode.ishUnlockPartition.rawValue & 0xFF),
            partition.rawValue
        ])

        guard let partitionResponse = try? await sendXCMP(partitionCmd, timeout: 5.0, debug: debug) else {
            if debug { print("[INIT] Failed to unlock partition: timeout") }
            return .timeout
        }

        // Check response: [opcode 2B] [error 1B]
        if partitionResponse.count < 3 {
            if debug { print("[INIT] Invalid partition response length: \(partitionResponse.count)") }
            return .unlockPartitionFailed(code: 0xFF)
        }

        let partitionError = partitionResponse[2]
        if partitionError != 0x00 {
            if debug { print("[INIT] Unlock partition failed with error: 0x\(String(format: "%02X", partitionError))") }
            return .unlockPartitionFailed(code: partitionError)
        }

        if debug {
            print("[INIT] Partition unlocked successfully")
            print("[INIT] Initialization complete! Radio is ready for PSDT access.")
        }

        return .success
    }
}
