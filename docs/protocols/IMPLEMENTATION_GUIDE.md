# XCMP/XNL Implementation Guide for macOS

**Target Device:** XPR 3500e via CDC ECM (192.168.10.1:4002)
**Language:** Swift
**Platform:** macOS

---

## Architecture Overview

```
┌─────────────────────────────────────────────┐
│           macOS Application                 │
├─────────────────────────────────────────────┤
│  Radio Manager (high-level API)             │
├─────────────────────────────────────────────┤
│  XCMP Client (application layer)            │
│  - Version queries                          │
│  - Status requests                          │
│  - Codeplug operations                      │
├─────────────────────────────────────────────┤
│  XNL Client (transport layer)               │
│  - Authentication                           │
│  - Transaction management                   │
│  - Packet routing                           │
├─────────────────────────────────────────────┤
│  UDP Socket (192.168.10.1:4002)             │
└─────────────────────────────────────────────┘
```

---

## Module Breakdown

### 1. XNLPacket (Data Structures)

```swift
import Foundation

// MARK: - XNL OpCodes

enum XNLOpCode: UInt16 {
    case masterStatusBroadcast   = 0x02
    case deviceMasterQuery       = 0x03
    case deviceAuthKeyRequest    = 0x04
    case deviceAuthKeyReply      = 0x05
    case deviceConnectionRequest = 0x06
    case deviceConnectionReply   = 0x07
    case deviceSysMapRequest     = 0x08
    case deviceSysMapBroadcast   = 0x09
    case dataMessage             = 0x0b
    case dataMessageAck          = 0x0c
}

// MARK: - XNL Address

struct XNLAddress: Equatable {
    let value: UInt16

    static let broadcast = XNLAddress(value: 0)

    init(value: UInt16) {
        self.value = value
    }

    init(data: Data, offset: Int = 0) {
        self.value = data.withUnsafeBytes { buffer in
            UInt16(bigEndian: buffer.load(fromByteOffset: offset, as: UInt16.self))
        }
    }

    func encode() -> Data {
        var value = self.value.bigEndian
        return Data(bytes: &value, count: 2)
    }
}

// MARK: - XNL Packet

struct XNLPacket {
    let opCode: XNLOpCode
    let isXCMP: Bool
    let flags: UInt8
    let destination: XNLAddress
    let source: XNLAddress
    let transactionID: UInt16
    let payload: Data

    init(opCode: XNLOpCode,
         isXCMP: Bool = false,
         flags: UInt8 = 0,
         destination: XNLAddress = .broadcast,
         source: XNLAddress = .broadcast,
         transactionID: UInt16 = 0,
         payload: Data = Data()) {
        self.opCode = opCode
        self.isXCMP = isXCMP
        self.flags = flags
        self.destination = destination
        self.source = source
        self.transactionID = transactionID
        self.payload = payload
    }

    // MARK: - Encoding

    func encode() -> Data {
        let length = UInt16(12 + payload.count)
        var data = Data()

        // Length (2 bytes, big-endian)
        data.append(contentsOf: [UInt8(length >> 8), UInt8(length & 0xFF)])

        // OpCode (2 bytes, big-endian)
        let opCodeValue = opCode.rawValue
        data.append(contentsOf: [UInt8(opCodeValue >> 8), UInt8(opCodeValue & 0xFF)])

        // Protocol (1 byte)
        data.append(isXCMP ? 0x01 : 0x00)

        // Flags (1 byte)
        data.append(flags)

        // Destination (2 bytes)
        data.append(destination.encode())

        // Source (2 bytes)
        data.append(source.encode())

        // Transaction ID (2 bytes, big-endian)
        data.append(contentsOf: [UInt8(transactionID >> 8), UInt8(transactionID & 0xFF)])

        // Payload length (2 bytes, big-endian)
        let payloadLength = UInt16(payload.count)
        data.append(contentsOf: [UInt8(payloadLength >> 8), UInt8(payloadLength & 0xFF)])

        // Payload
        data.append(payload)

        return data
    }

    // MARK: - Decoding

    static func decode(_ data: Data) throws -> XNLPacket {
        guard data.count >= 14 else {
            throw XNLError.invalidPacketSize
        }

        let length = UInt16(data[0]) << 8 | UInt16(data[1])
        guard data.count >= length + 2 else {
            throw XNLError.invalidPacketSize
        }

        let opCodeValue = UInt16(data[2]) << 8 | UInt16(data[3])
        guard let opCode = XNLOpCode(rawValue: opCodeValue) else {
            throw XNLError.unknownOpCode(opCodeValue)
        }

        let isXCMP = data[4] == 0x01
        let flags = data[5]
        let destination = XNLAddress(data: data, offset: 6)
        let source = XNLAddress(data: data, offset: 8)
        let transactionID = UInt16(data[10]) << 8 | UInt16(data[11])
        let payloadLength = UInt16(data[12]) << 8 | UInt16(data[13])

        let payload = data.subdata(in: 14..<Int(14 + payloadLength))

        return XNLPacket(
            opCode: opCode,
            isXCMP: isXCMP,
            flags: flags,
            destination: destination,
            source: source,
            transactionID: transactionID,
            payload: payload
        )
    }
}

enum XNLError: Error {
    case invalidPacketSize
    case unknownOpCode(UInt16)
    case authenticationFailed
    case connectionTimeout
}
```

### 2. XNLClient (Connection Manager)

```swift
import Foundation
import Network

class XNLClient {
    private let radioAddress: String
    private let radioPort: UInt16
    private var connection: NWConnection?

    private var masterAddress: XNLAddress?
    private var assignedAddress: XNLAddress?
    private var transactionID: UInt16 = 0
    private var flags: UInt8 = 0

    private var packetHandler: ((XNLPacket) -> Void)?

    init(radioAddress: String = "192.168.10.1", radioPort: UInt16 = 4002) {
        self.radioAddress = radioAddress
        self.radioPort = radioPort
    }

    // MARK: - Connection

    func connect(completion: @escaping (Result<Void, Error>) -> Void) {
        let endpoint = NWEndpoint.hostPort(
            host: NWEndpoint.Host(radioAddress),
            port: NWEndpoint.Port(rawValue: radioPort)!
        )

        connection = NWConnection(to: endpoint, using: .udp)

        connection?.stateUpdateHandler = { [weak self] state in
            switch state {
            case .ready:
                self?.startReceiving()
                self?.initializeXNL(completion: completion)
            case .failed(let error):
                completion(.failure(error))
            default:
                break
            }
        }

        connection?.start(queue: .main)
    }

    func disconnect() {
        connection?.cancel()
        connection = nil
    }

    // MARK: - XNL Initialization

    private func initializeXNL(completion: @escaping (Result<Void, Error>) -> Void) {
        // Step 1: Send Master Query (optional, can also just wait for broadcast)
        let queryPacket = XNLPacket(opCode: .deviceMasterQuery)
        send(queryPacket)

        // Step 2: Wait for MasterStatusBroadcast
        var broadcastReceived = false
        var authKeyReceived = false

        packetHandler = { [weak self] packet in
            guard let self = self else { return }

            switch packet.opCode {
            case .masterStatusBroadcast:
                if !broadcastReceived {
                    broadcastReceived = true
                    self.masterAddress = packet.source
                    self.requestAuthKey()
                }

            case .deviceAuthKeyReply:
                if !authKeyReceived {
                    authKeyReceived = true
                    self.handleAuthKeyReply(packet, completion: completion)
                }

            case .deviceConnectionReply:
                self.handleConnectionReply(packet, completion: completion)

            default:
                break
            }
        }
    }

    private func requestAuthKey() {
        guard let master = masterAddress else { return }

        let packet = XNLPacket(
            opCode: .deviceAuthKeyRequest,
            destination: master
        )
        send(packet)
    }

    private func handleAuthKeyReply(_ packet: XNLPacket, completion: @escaping (Result<Void, Error>) -> Void) {
        guard packet.payload.count >= 10 else {
            completion(.failure(XNLError.authenticationFailed))
            return
        }

        // Extract temporary address (bytes 0-1)
        let tempAddress = XNLAddress(data: packet.payload, offset: 0)

        // Extract challenge (bytes 2-9, 8 bytes)
        let challenge = packet.payload.subdata(in: 2..<10)

        // Encrypt challenge
        do {
            let encrypted = try XNLEncryption.encrypt(challenge, type: .controlStation)
            sendConnectionRequest(tempAddress: tempAddress, encryptedKey: encrypted)
        } catch {
            completion(.failure(error))
        }
    }

    private func sendConnectionRequest(tempAddress: XNLAddress, encryptedKey: Data) {
        guard let master = masterAddress else { return }

        var payload = Data()

        // Connection address (2 bytes) - 0x0000 for new connection
        payload.append(contentsOf: [0x00, 0x00])

        // Connection type (1 byte) - 0x0A typical
        payload.append(0x0A)

        // Authentication index (1 byte) - 0x01 for control station
        payload.append(0x01)

        // Encrypted key (8 bytes)
        payload.append(encryptedKey)

        let packet = XNLPacket(
            opCode: .deviceConnectionRequest,
            destination: master,
            source: tempAddress,
            payload: payload
        )

        send(packet)
    }

    private func handleConnectionReply(_ packet: XNLPacket, completion: @escaping (Result<Void, Error>) -> Void) {
        guard packet.payload.count >= 4 else {
            completion(.failure(XNLError.authenticationFailed))
            return
        }

        // Result code (byte 0)
        let resultCode = packet.payload[0]
        guard resultCode == 0x01 else {
            completion(.failure(XNLError.authenticationFailed))
            return
        }

        // Assigned XNL ID (bytes 2-3)
        assignedAddress = XNLAddress(data: packet.payload, offset: 2)

        completion(.success(()))
    }

    // MARK: - Send/Receive

    func send(_ packet: XNLPacket) {
        let data = packet.encode()
        connection?.send(content: data, completion: .contentProcessed { error in
            if let error = error {
                print("Send error: \\(error)")
            }
        })
    }

    private func startReceiving() {
        connection?.receiveMessage { [weak self] data, _, _, error in
            if let data = data {
                do {
                    let packet = try XNLPacket.decode(data)
                    self?.packetHandler?(packet)
                } catch {
                    print("Decode error: \\(error)")
                }
            }

            // Continue receiving
            self?.startReceiving()
        }
    }

    // MARK: - Data Messages

    func sendDataPacket(_ xcmpData: Data, completion: @escaping (Result<XNLPacket, Error>) -> Void) {
        guard let source = assignedAddress, let dest = masterAddress else {
            completion(.failure(XNLError.authenticationFailed))
            return
        }

        let packet = XNLPacket(
            opCode: .dataMessage,
            isXCMP: true,
            flags: flags,
            destination: dest,
            source: source,
            transactionID: transactionID,
            payload: xcmpData
        )

        transactionID += 1
        flags = (flags + 1) % 8

        send(packet)

        // Wait for reply (simplified - should have timeout/retry logic)
        // In production, use transaction ID matching
    }
}
```

### 3. XCMPClient (Application Layer)

```swift
import Foundation

enum XCMPOpCode: UInt16 {
    case deviceInitStatusBroadcast = 0xB400
    case radioStatusRequest        = 0x000E
    case radioStatusReply          = 0x800E
    case versionInfoRequest        = 0x000F
    case versionInfoReply          = 0x800F
    case cloneReadRequest          = 0x010A
    case cloneReadReply            = 0x810A
}

struct XCMPPacket {
    let opCode: XCMPOpCode
    let data: Data

    func encode() -> Data {
        var result = Data()

        // OpCode (2 bytes, big-endian)
        let opCodeValue = opCode.rawValue
        result.append(contentsOf: [UInt8(opCodeValue >> 8), UInt8(opCodeValue & 0xFF)])

        // Data
        result.append(data)

        return result
    }

    static func decode(_ data: Data) throws -> XCMPPacket {
        guard data.count >= 2 else {
            throw XCMPError.invalidPacketSize
        }

        let opCodeValue = UInt16(data[0]) << 8 | UInt16(data[1])
        guard let opCode = XCMPOpCode(rawValue: opCodeValue) else {
            throw XCMPError.unknownOpCode(opCodeValue)
        }

        let payload = data.subdata(in: 2..<data.count)

        return XCMPPacket(opCode: opCode, data: payload)
    }
}

enum XCMPError: Error {
    case invalidPacketSize
    case unknownOpCode(UInt16)
}

class XCMPClient {
    private let xnlClient: XNLClient

    init(xnlClient: XNLClient) {
        self.xnlClient = xnlClient
    }

    // MARK: - Commands

    func getVersionInfo(completion: @escaping (Result<String, Error>) -> Void) {
        let xcmpPacket = XCMPPacket(opCode: .versionInfoRequest, data: Data())
        let xcmpData = xcmpPacket.encode()

        xnlClient.sendDataPacket(xcmpData) { result in
            switch result {
            case .success(let replyPacket):
                // Parse version info from replyPacket.payload
                // This is simplified - actual parsing needed
                completion(.success("Version info"))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    func readCodeplug(zone: UInt16, channel: UInt16, dataType: UInt8, completion: @escaping (Result<Data, Error>) -> Void) {
        var data = Data()

        // Format 1: Zone/Channel read
        data.append(0x80)
        data.append(0x01)
        data.append(contentsOf: [UInt8(zone >> 8), UInt8(zone & 0xFF)])
        data.append(0x80)
        data.append(0x02)
        data.append(contentsOf: [UInt8(channel >> 8), UInt8(channel & 0xFF)])
        data.append(0x00)
        data.append(dataType)

        let xcmpPacket = XCMPPacket(opCode: .cloneReadRequest, data: data)
        let xcmpData = xcmpPacket.encode()

        xnlClient.sendDataPacket(xcmpData) { result in
            switch result {
            case .success(let replyPacket):
                // Parse codeplug data from replyPacket.payload
                do {
                    let xcmpReply = try XCMPPacket.decode(replyPacket.payload)
                    guard xcmpReply.opCode == .cloneReadReply else {
                        completion(.failure(XCMPError.unknownOpCode(xcmpReply.opCode.rawValue)))
                        return
                    }

                    // Extract data (skip header, get payload)
                    let codeplugData = xcmpReply.data.subdata(in: 15..<xcmpReply.data.count)
                    completion(.success(codeplugData))
                } catch {
                    completion(.failure(error))
                }
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
}
```

---

## Usage Example

```swift
import Foundation

let xnlClient = XNLClient(radioAddress: "192.168.10.1", radioPort: 4002)

xnlClient.connect { result in
    switch result {
    case .success:
        print("XNL connected!")

        let xcmpClient = XCMPClient(xnlClient: xnlClient)

        // Get version info
        xcmpClient.getVersionInfo { result in
            switch result {
            case .success(let version):
                print("Radio version: \\(version)")
            case .failure(let error):
                print("Error: \\(error)")
            }
        }

        // Read channel name (zone 0, channel 1, dataType 0x0F)
        xcmpClient.readCodeplug(zone: 0, channel: 1, dataType: 0x0F) { result in
            switch result {
            case .success(let data):
                if let name = String(data: data, encoding: .utf8) {
                    print("Channel name: \\(name)")
                }
            case .failure(let error):
                print("Error: \\(error)")
            }
        }

    case .failure(let error):
        print("Connection failed: \\(error)")
    }
}

// Keep app running
RunLoop.main.run()
```

---

## Missing Pieces

### 1. Encryption Constants

You must obtain the 6 constants for `XNLEncryption.encrypt()`. See `ENCRYPTION_DETAILS.md` for options.

### 2. XCMP Response Handling

The example above is simplified. In production:
- Match responses by transaction ID
- Implement timeout/retry logic
- Handle all XCMP error codes
- Queue multiple requests properly

### 3. DeviceInitStatusBroadcast

After connection, radio sends this. You may need to respond if init is not complete.

### 4. Data Message Acknowledgment

Radio expects `DataMessageAck` (0x0c) for reliability. Implement this for production.

---

## Testing Strategy

### 1. Packet Capture
- Use Wireshark with xcmp-xnl-dissector
- Compare your packets to CPS packets
- Verify encryption output matches

### 2. Incremental Testing
- Step 1: Verify UDP socket works
- Step 2: Receive MasterStatusBroadcast
- Step 3: Test encryption with known challenge
- Step 4: Complete authentication handshake
- Step 5: Send simple XCMP commands

### 3. Error Handling
- Test timeout scenarios
- Test invalid encryption
- Test reconnection after disconnect

---

## Next Steps

1. Implement the XNL packet encoding/decoding
2. Obtain encryption constants
3. Implement the authentication handshake
4. Add XCMP command layer
5. Build UI for radio operations
6. Add error handling and retry logic
7. Implement codeplug parsing
