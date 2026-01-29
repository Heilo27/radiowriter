import Foundation
import Network

/// XNL protocol opcodes for MOTOTRBO radios.
public enum XNLOpCode: UInt8 {
    case masterStatusBroadcast = 0x02
    case deviceMasterQuery = 0x03
    case deviceAuthKeyRequest = 0x04
    case deviceAuthKeyReply = 0x05
    case deviceConnectionRequest = 0x06
    case deviceConnectionReply = 0x07
    case dataMessage = 0x08
    case dataMessageAck = 0x09
    case deviceSysMapBroadcast = 0x0B
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
public actor XNLConnection {

    /// Standard XNL port for CPS-mode programming.
    public static let defaultPort: UInt16 = 8002

    private let host: String
    private let port: UInt16
    private var connection: NWConnection?
    private let queue = DispatchQueue(label: "com.motorola.cps.xnl", qos: .userInitiated)

    private var masterAddress: UInt16 = 0
    private var myAddress: UInt16 = 0x0001
    private var assignedAddress: UInt16 = 0
    private var transactionID: UInt16 = 1

    public var isConnected: Bool {
        connection?.state == .ready
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
    /// - Returns: Result indicating success or failure reason.
    public func connect() async -> XNLConnectionResult {
        let nwHost = NWEndpoint.Host(host)
        let nwPort = NWEndpoint.Port(rawValue: port)!

        let parameters = NWParameters.tcp
        parameters.allowLocalEndpointReuse = true

        let conn = NWConnection(host: nwHost, port: nwPort, using: parameters)
        self.connection = conn

        // Wait for TCP connection
        do {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                conn.stateUpdateHandler = { state in
                    switch state {
                    case .ready:
                        continuation.resume()
                    case .failed(let error):
                        continuation.resume(throwing: error)
                    case .cancelled:
                        continuation.resume(throwing: NSError(domain: "XNL", code: -1, userInfo: [NSLocalizedDescriptionKey: "Connection cancelled"]))
                    default:
                        break
                    }
                }
                conn.start(queue: queue)
            }
        } catch {
            return .connectionError(error.localizedDescription)
        }

        // Perform XNL authentication
        return await authenticate()
    }

    /// Disconnects from the radio.
    public func disconnect() {
        connection?.cancel()
        connection = nil
        masterAddress = 0
        assignedAddress = 0
        transactionID = 1
    }

    // MARK: - Authentication Flow

    private func authenticate() async -> XNLConnectionResult {
        // Step 1: Send DeviceMasterQuery to trigger MasterStatusBroadcast
        let initPacket = buildXNLPacket(opcode: .deviceMasterQuery, dest: 0, src: 0, txID: 0)
        do {
            try await send(initPacket)
        } catch {
            return .connectionError("Failed to send init packet: \(error.localizedDescription)")
        }

        // Step 2: Wait for MasterStatusBroadcast
        guard let broadcastData = await receivePacket(timeout: 5.0),
              broadcastData.count >= 14,
              broadcastData[3] == XNLOpCode.masterStatusBroadcast.rawValue else {
            return .timeout
        }

        masterAddress = UInt16(broadcastData[8]) << 8 | UInt16(broadcastData[9])

        // Step 3: Send DeviceAuthKeyRequest
        let authReqPacket = buildXNLPacket(opcode: .deviceAuthKeyRequest, dest: masterAddress, src: myAddress, txID: nextTransactionID())
        do {
            try await send(authReqPacket)
        } catch {
            return .connectionError("Failed to send auth request: \(error.localizedDescription)")
        }

        // Step 4: Wait for DeviceAuthKeyReply
        // May receive another MasterStatusBroadcast first, so loop
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

        guard let replyData = authReply, replyData.count >= 24 else {
            return .timeout
        }

        // Extract challenge
        let tempAddress = UInt16(replyData[14]) << 8 | UInt16(replyData[15])
        let challenge = Data(replyData[16..<24])

        // Step 5: Encrypt challenge with TEA
        guard let encrypted = XNLEncryption.encrypt(challenge) else {
            return .connectionError("Failed to encrypt challenge")
        }

        // Step 6: Send DeviceConnectionRequest
        var connData = Data()
        connData.append(UInt8(tempAddress >> 8))
        connData.append(UInt8(tempAddress & 0xFF))
        connData.append(0x0A)  // Device type
        connData.append(0x00)  // Auth index (CPS mode)
        connData.append(contentsOf: encrypted)

        let connReqPacket = buildXNLPacket(opcode: .deviceConnectionRequest, dest: masterAddress, src: myAddress, txID: nextTransactionID(), data: connData)
        do {
            try await send(connReqPacket)
        } catch {
            return .connectionError("Failed to send connection request: \(error.localizedDescription)")
        }

        // Step 7: Wait for DeviceConnectionReply
        var connReply: Data?
        for _ in 0..<5 {
            guard let data = await receivePacket(timeout: 5.0), data.count >= 15 else {
                continue
            }
            if data[3] == XNLOpCode.deviceConnectionReply.rawValue {
                connReply = data
                break
            }
        }

        guard let connReplyData = connReply, connReplyData.count >= 15 else {
            return .timeout
        }

        let resultCode = connReplyData[14]
        if resultCode == 0x00 {
            // Success! Extract assigned address
            if connReplyData.count >= 17 {
                assignedAddress = UInt16(connReplyData[15]) << 8 | UInt16(connReplyData[16])
            } else {
                assignedAddress = myAddress
            }
            return .success(assignedAddress: assignedAddress)
        } else {
            return .authenticationFailed(code: resultCode)
        }
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

    // MARK: - Send/Receive

    private func send(_ data: Data) async throws {
        guard let conn = connection else {
            throw NSError(domain: "XNL", code: -1, userInfo: [NSLocalizedDescriptionKey: "Not connected"])
        }

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            conn.send(content: data, completion: .contentProcessed { error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            })
        }
    }

    private func receivePacket(timeout: TimeInterval) async -> Data? {
        guard let conn = connection else { return nil }

        return await withTaskGroup(of: Data?.self) { group in
            group.addTask {
                await withCheckedContinuation { continuation in
                    conn.receive(minimumIncompleteLength: 2, maximumLength: 1024) { data, _, _, _ in
                        continuation.resume(returning: data)
                    }
                }
            }

            group.addTask {
                try? await Task.sleep(for: .seconds(timeout))
                return nil
            }

            let result = await group.next() ?? nil
            group.cancelAll()
            return result
        }
    }

    // MARK: - Public API for XCMP Commands

    /// Sends an XCMP command and waits for response.
    /// - Parameters:
    ///   - xcmpData: The XCMP payload data
    ///   - timeout: Timeout in seconds
    /// - Returns: Response data or nil on timeout
    public func sendXCMP(_ xcmpData: Data, timeout: TimeInterval = 5.0) async throws -> Data? {
        guard isAuthenticated else {
            throw NSError(domain: "XNL", code: -1, userInfo: [NSLocalizedDescriptionKey: "Not authenticated"])
        }

        // Wrap XCMP in XNL DataMessage
        let packet = buildXNLPacket(opcode: .dataMessage, dest: masterAddress, src: assignedAddress, txID: nextTransactionID(), data: xcmpData)
        try await send(packet)

        // Wait for response (DataMessage or DataMessageAck)
        for _ in 0..<10 {
            guard let data = await receivePacket(timeout: timeout) else {
                return nil
            }
            if data.count >= 14 {
                let opcode = data[3]
                if opcode == XNLOpCode.dataMessage.rawValue || opcode == XNLOpCode.dataMessageAck.rawValue {
                    // Extract XCMP payload (skip XNL header)
                    if data.count > 14 {
                        return Data(data[14...])
                    }
                    return Data()
                }
            }
        }
        return nil
    }
}
