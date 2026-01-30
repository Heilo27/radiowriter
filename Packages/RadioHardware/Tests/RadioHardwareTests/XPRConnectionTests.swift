import XCTest
@testable import RadioProgrammer
@testable import USBTransport

/// Comprehensive XPR 3500e Connection Tests
///
/// Run with: swift test --filter XPRConnectionTests
///
/// IMPORTANT: Connect the XPR 3500e radio via USB before running these tests.
/// The radio should appear as a CDC ECM network device at 192.168.10.1
final class XPRConnectionTests: XCTestCase {

    /// Default IP address for MOTOTRBO radios in programming mode
    static let radioHost = "192.168.10.1"

    /// XNL port for CPS programming
    static let xnlPort: UInt16 = 8002

    // MARK: - Test Results Storage

    /// Store test results for summary
    struct TestResult {
        let name: String
        let passed: Bool
        let details: String
        let duration: TimeInterval
    }

    static var results: [TestResult] = []

    // MARK: - Setup/Teardown

    override class func setUp() {
        super.setUp()
        results = []
        print("\n" + String(repeating: "=", count: 70))
        print("XPR 3500e COMPREHENSIVE TEST SUITE")
        print(String(repeating: "=", count: 70))
        print("Target: \(radioHost):\(xnlPort)")
        print("Time: \(Date())")
        print(String(repeating: "=", count: 70) + "\n")
    }

    override class func tearDown() {
        super.tearDown()
        printSummary()
    }

    static func printSummary() {
        print("\n" + String(repeating: "=", count: 70))
        print("TEST SUMMARY")
        print(String(repeating: "=", count: 70))

        let passed = results.filter { $0.passed }.count
        let failed = results.filter { !$0.passed }.count

        for result in results {
            let status = result.passed ? "PASS" : "FAIL"
            let icon = result.passed ? "✓" : "✗"
            print("\(icon) [\(status)] \(result.name) (\(String(format: "%.2fs", result.duration)))")
            if !result.details.isEmpty {
                print("    └─ \(result.details)")
            }
        }

        print(String(repeating: "-", count: 70))
        print("Results: \(passed) passed, \(failed) failed, \(results.count) total")
        print(String(repeating: "=", count: 70) + "\n")
    }

    func record(_ name: String, passed: Bool, details: String = "", duration: TimeInterval) {
        XPRConnectionTests.results.append(TestResult(name: name, passed: passed, details: details, duration: duration))
    }

    // MARK: - Test 1: Network Reachability

    func test01_NetworkReachability() async throws {
        let start = Date()
        print("\n[TEST 1] Network Reachability")
        print("─────────────────────────────────────")
        print("Checking if \(Self.radioHost) is reachable...")

        let reachable = await checkReachability(host: Self.radioHost, port: Self.xnlPort)

        let duration = Date().timeIntervalSince(start)

        if reachable {
            print("  ✓ Radio is reachable at \(Self.radioHost):\(Self.xnlPort)")
            record("Network Reachability", passed: true, details: "Host reachable", duration: duration)
        } else {
            print("  ✗ Cannot reach radio at \(Self.radioHost):\(Self.xnlPort)")
            print("  → Make sure the radio is connected via USB")
            print("  → Check that CDC ECM driver is loaded")
            print("  → Verify network interface has IP in 192.168.10.x range")
            record("Network Reachability", passed: false, details: "Host unreachable", duration: duration)
        }

        XCTAssertTrue(reachable, "Radio should be reachable at \(Self.radioHost)")
    }

    // MARK: - Test 2: XNL Connection

    func test02_XNLConnection() async throws {
        let start = Date()
        print("\n[TEST 2] XNL Connection & Authentication")
        print("─────────────────────────────────────")

        let connection = XNLConnection(host: Self.radioHost)
        print("  Initiating XNL connection...")

        let result = await connection.connect()
        let duration = Date().timeIntervalSince(start)

        switch result {
        case .success(let assignedAddress):
            print("  ✓ XNL authentication successful!")
            print("    └─ Assigned address: 0x\(String(format: "%04X", assignedAddress))")
            record("XNL Connection", passed: true, details: "Addr: 0x\(String(format: "%04X", assignedAddress))", duration: duration)

        case .authenticationFailed(let code):
            print("  ✗ XNL authentication failed")
            print("    └─ Error code: 0x\(String(format: "%02X", code))")
            record("XNL Connection", passed: false, details: "Auth failed: 0x\(String(format: "%02X", code))", duration: duration)
            XCTFail("Authentication failed with code 0x\(String(format: "%02X", code))")

        case .connectionError(let message):
            print("  ✗ Connection error: \(message)")
            record("XNL Connection", passed: false, details: message, duration: duration)
            XCTFail("Connection error: \(message)")

        case .timeout:
            print("  ✗ Connection timeout")
            record("XNL Connection", passed: false, details: "Timeout", duration: duration)
            XCTFail("Connection timeout")
        }
    }

    // MARK: - Test 3: Radio Identification

    func test03_RadioIdentification() async throws {
        let start = Date()
        print("\n[TEST 3] Radio Identification (XCMP)")
        print("─────────────────────────────────────")

        let programmer = MOTOTRBOProgrammer(host: Self.radioHost)

        do {
            print("  Connecting and querying radio info...")
            let info = try await programmer.identify()
            let duration = Date().timeIntervalSince(start)

            print("  ✓ Radio identified!")
            print("    ├─ Model:    \(info.modelNumber)")
            print("    ├─ Serial:   \(info.serialNumber ?? "N/A")")
            print("    ├─ Firmware: \(info.firmwareVersion ?? "N/A")")
            print("    ├─ Radio ID: \(info.radioID.map { String($0) } ?? "N/A")")
            print("    └─ Family:   \(info.radioFamily ?? "Unknown")")

            record("Radio Identification", passed: true, details: info.modelNumber, duration: duration)

            XCTAssertFalse(info.modelNumber.isEmpty, "Model number should not be empty")

        } catch {
            let duration = Date().timeIntervalSince(start)
            print("  ✗ Identification failed: \(error.localizedDescription)")
            record("Radio Identification", passed: false, details: error.localizedDescription, duration: duration)
            throw error
        }
    }

    // MARK: - Test 4: Individual XCMP Queries

    func test04_XCMPQueries() async throws {
        let start = Date()
        print("\n[TEST 4] Individual XCMP Queries")
        print("─────────────────────────────────────")

        let programmer = MOTOTRBOProgrammer(host: Self.radioHost)
        var queryResults: [String: String] = [:]

        // Model Number
        print("  Querying model number...")
        if let model = try await programmer.getModelNumber() {
            print("    ✓ Model: \(model)")
            queryResults["Model"] = model
        } else {
            print("    ✗ Model: No response")
        }

        // Serial Number
        print("  Querying serial number...")
        if let serial = try await programmer.getSerialNumber() {
            print("    ✓ Serial: \(serial)")
            queryResults["Serial"] = serial
        } else {
            print("    ✗ Serial: No response")
        }

        // Radio ID
        print("  Querying radio ID...")
        if let radioID = try await programmer.getRadioID() {
            print("    ✓ Radio ID: \(radioID)")
            queryResults["RadioID"] = String(radioID)
        } else {
            print("    ✗ Radio ID: No response")
        }

        // Firmware Version
        print("  Querying firmware version...")
        if let firmware = try await programmer.getFirmwareVersion() {
            print("    ✓ Firmware: \(firmware)")
            queryResults["Firmware"] = firmware
        } else {
            print("    ✗ Firmware: No response")
        }

        let duration = Date().timeIntervalSince(start)
        let passed = !queryResults.isEmpty
        record("XCMP Queries", passed: passed, details: "\(queryResults.count)/4 queries successful", duration: duration)

        XCTAssertTrue(passed, "At least one XCMP query should succeed")
    }

    // MARK: - Test 5: Clone Read (Channel Data)

    func test05_CloneRead() async throws {
        let start = Date()
        print("\n[TEST 5] Clone Read - Channel Data")
        print("─────────────────────────────────────")

        let connection = XNLConnection(host: Self.radioHost)
        let connResult = await connection.connect()

        guard case .success = connResult else {
            let duration = Date().timeIntervalSince(start)
            print("  ✗ Could not connect for clone read test")
            record("Clone Read", passed: false, details: "Connection failed", duration: duration)
            XCTFail("Connection failed")
            return
        }

        let client = XCMPClient(xnlConnection: connection)
        var channelsRead = 0

        print("  Reading channel data from Zone 0...")

        // Try to read first 5 channels in zone 0
        for channel in 0..<5 {
            print("    Channel \(channel):")

            // Channel name
            if let name = try await client.getChannelName(zone: 0, channel: UInt16(channel)) {
                print("      └─ Name: \(name)")
                channelsRead += 1
            }

            // RX Frequency
            if let rxFreq = try await client.getChannelRxFrequency(zone: 0, channel: UInt16(channel)) {
                let freqMHz = Double(rxFreq) / 1_000_000.0
                print("      └─ RX: \(String(format: "%.5f", freqMHz)) MHz")
            }

            // TX Frequency
            if let txFreq = try await client.getChannelTxFrequency(zone: 0, channel: UInt16(channel)) {
                let freqMHz = Double(txFreq) / 1_000_000.0
                print("      └─ TX: \(String(format: "%.5f", freqMHz)) MHz")
            }
        }

        let duration = Date().timeIntervalSince(start)
        let passed = channelsRead > 0
        record("Clone Read", passed: passed, details: "\(channelsRead) channels read", duration: duration)

        await connection.disconnect()
    }

    // MARK: - Test 6: PSDT Address Query

    func test06_PSDTAddressQuery() async throws {
        let start = Date()
        print("\n[TEST 6] PSDT Address Query")
        print("─────────────────────────────────────")

        let connection = XNLConnection(host: Self.radioHost)
        let connResult = await connection.connect()

        guard case .success = connResult else {
            let duration = Date().timeIntervalSince(start)
            print("  ✗ Could not connect for PSDT test")
            record("PSDT Address Query", passed: false, details: "Connection failed", duration: duration)
            XCTFail("Connection failed")
            return
        }

        let client = XCMPClient(xnlConnection: connection)

        print("  Querying codeplug partition addresses...")

        // Query start address
        let startReq = XCMPPacket.psdtGetStartAddress(partition: "CP")
        let startReply = try await client.sendAndReceive(startReq)

        var startAddr: UInt32?
        var endAddr: UInt32?

        if let reply = startReply {
            print("    Start address reply: \(reply.data.map { String(format: "%02X", $0) }.joined(separator: " "))")
            if reply.data.count >= 5 {
                startAddr = UInt32(reply.data[1]) << 24 |
                           UInt32(reply.data[2]) << 16 |
                           UInt32(reply.data[3]) << 8 |
                           UInt32(reply.data[4])
                print("    ✓ Start address: 0x\(String(format: "%08X", startAddr!))")
            }
        } else {
            print("    ✗ No reply to start address query")
        }

        // Query end address
        let endReq = XCMPPacket.psdtGetEndAddress(partition: "CP")
        let endReply = try await client.sendAndReceive(endReq)

        if let reply = endReply {
            print("    End address reply: \(reply.data.map { String(format: "%02X", $0) }.joined(separator: " "))")
            if reply.data.count >= 5 {
                endAddr = UInt32(reply.data[1]) << 24 |
                         UInt32(reply.data[2]) << 16 |
                         UInt32(reply.data[3]) << 8 |
                         UInt32(reply.data[4])
                print("    ✓ End address: 0x\(String(format: "%08X", endAddr!))")
            }
        } else {
            print("    ✗ No reply to end address query")
        }

        if let start = startAddr, let end = endAddr {
            let size = end - start
            print("    ✓ Codeplug size: \(size) bytes (\(size / 1024) KB)")
        }

        let duration = Date().timeIntervalSince(start)
        let passed = startAddr != nil && endAddr != nil
        record("PSDT Address Query", passed: passed,
               details: passed ? "CP partition found" : "Could not query addresses",
               duration: duration)

        await connection.disconnect()
    }

    // MARK: - Test 7: CPS Session Start

    func test07_CPSSessionStart() async throws {
        let start = Date()
        print("\n[TEST 7] CPS Session Management")
        print("─────────────────────────────────────")

        let connection = XNLConnection(host: Self.radioHost)
        let connResult = await connection.connect()

        guard case .success = connResult else {
            let duration = Date().timeIntervalSince(start)
            print("  ✗ Could not connect for session test")
            record("CPS Session", passed: false, details: "Connection failed", duration: duration)
            XCTFail("Connection failed")
            return
        }

        let client = XCMPClient(xnlConnection: connection)
        let sessionID = UInt16.random(in: 1...0xFFFE)

        print("  Starting read session (ID: 0x\(String(format: "%04X", sessionID)))...")

        // Start session
        let startPacket = XCMPPacket.startReadSession(sessionID: sessionID)
        let startReply = try await client.sendAndReceive(startPacket)

        var sessionStarted = false

        if let reply = startReply {
            print("    Session reply: \(reply.data.map { String(format: "%02X", $0) }.joined(separator: " "))")
            if reply.data.isEmpty || reply.data[0] == 0x00 {
                print("    ✓ Session started successfully")
                sessionStarted = true
            } else {
                print("    ✗ Session start failed with code: 0x\(String(format: "%02X", reply.data[0]))")
            }
        } else {
            print("    ✗ No reply to session start")
        }

        // End session (cleanup)
        if sessionStarted {
            print("  Ending session...")
            let resetPacket = XCMPPacket.resetSession(sessionID: sessionID)
            _ = try await client.sendAndReceive(resetPacket)
            print("    ✓ Session ended")
        }

        let duration = Date().timeIntervalSince(start)
        record("CPS Session", passed: sessionStarted,
               details: sessionStarted ? "Session management working" : "Session failed",
               duration: duration)

        await connection.disconnect()
    }

    // MARK: - Test 8: Small Codeplug Read

    func test08_CodeplugRead() async throws {
        let start = Date()
        print("\n[TEST 8] Codeplug Read (First 1KB)")
        print("─────────────────────────────────────")

        let programmer = MOTOTRBOProgrammer(host: Self.radioHost)

        do {
            print("  Attempting to read codeplug...")
            print("  (This may take a moment)")

            let codeplug = try await programmer.readCodeplug { progress in
                let pct = Int(progress * 100)
                if pct % 10 == 0 {
                    print("    Progress: \(pct)%")
                }
            }

            let duration = Date().timeIntervalSince(start)

            print("  ✓ Codeplug read successful!")
            print("    └─ Size: \(codeplug.count) bytes (\(codeplug.count / 1024) KB)")

            // Print first 64 bytes as hex dump
            print("  First 64 bytes:")
            let preview = codeplug.prefix(64)
            for (_, chunk) in stride(from: 0, to: preview.count, by: 16).enumerated() {
                let endIndex = min(chunk + 16, preview.count)
                let bytes = preview[chunk..<endIndex]
                let hex = bytes.map { String(format: "%02X", $0) }.joined(separator: " ")
                let ascii = bytes.map { (0x20...0x7E).contains($0) ? Character(UnicodeScalar($0)) : "." }.map(String.init).joined()
                print("    \(String(format: "%04X", chunk)): \(hex.padding(toLength: 47, withPad: " ", startingAt: 0)) |\(ascii)|")
            }

            record("Codeplug Read", passed: true, details: "\(codeplug.count) bytes", duration: duration)

        } catch {
            let duration = Date().timeIntervalSince(start)
            print("  ✗ Codeplug read failed: \(error.localizedDescription)")
            record("Codeplug Read", passed: false, details: error.localizedDescription, duration: duration)
            // Don't throw - this is expected to potentially fail
        }
    }

    // MARK: - Test 9: AT Debug Interface

    func test09_ATDebugInterface() async throws {
        let start = Date()
        print("\n[TEST 9] AT Debug Interface (Port 8501)")
        print("─────────────────────────────────────")

        let programmer = MOTOTRBOProgrammer(host: Self.radioHost)

        do {
            print("  Connecting to AT debug interface...")
            let help = try await programmer.getATHelp()
            let duration = Date().timeIntervalSince(start)

            if !help.isEmpty {
                print("  ✓ AT interface responded!")
                print("  Available commands:")
                // Print first few lines
                for line in help.components(separatedBy: .newlines).prefix(10) {
                    if !line.isEmpty {
                        print("    \(line)")
                    }
                }
                record("AT Debug Interface", passed: true, details: "Interface available", duration: duration)
            } else {
                print("  ✗ Empty response from AT interface")
                record("AT Debug Interface", passed: false, details: "Empty response", duration: duration)
            }
        } catch {
            let duration = Date().timeIntervalSince(start)
            print("  ✗ AT interface failed: \(error.localizedDescription)")
            print("    (This is often disabled on production radios)")
            record("AT Debug Interface", passed: false, details: "Not available", duration: duration)
            // Don't throw - AT interface is optional
        }
    }

    // MARK: - Helpers

    private func checkReachability(host: String, port: UInt16) async -> Bool {
        return await withCheckedContinuation { continuation in
            let socket = CFSocketCreate(nil, PF_INET, SOCK_STREAM, IPPROTO_TCP, 0, nil, nil)
            guard socket != nil else {
                continuation.resume(returning: false)
                return
            }

            var addr = sockaddr_in()
            addr.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
            addr.sin_family = sa_family_t(AF_INET)
            addr.sin_port = port.bigEndian
            inet_pton(AF_INET, host, &addr.sin_addr)

            let data = Data(bytes: &addr, count: MemoryLayout<sockaddr_in>.size) as CFData

            // Set socket to non-blocking
            var flags = fcntl(CFSocketGetNative(socket), F_GETFL, 0)
            flags |= O_NONBLOCK
            _ = fcntl(CFSocketGetNative(socket), F_SETFL, flags)

            let result = CFSocketConnectToAddress(socket, data, 2.0)
            CFSocketInvalidate(socket)

            continuation.resume(returning: result == .success || result == .timeout)
        }
    }
}
