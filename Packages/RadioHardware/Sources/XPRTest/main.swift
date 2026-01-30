//
// XPR 3500e Test Tool
// Run: swift run XPRTest [--host 192.168.10.1] [--verbose]
//

import Foundation
import RadioProgrammer

// MARK: - Helpers

extension Data {
    var hex: String {
        self.map { String(format: "%02X", $0) }.joined(separator: " ")
    }
}

@main
struct XPRTest {
    static var verbose = false

    static func main() async {
        printBanner()

        // Parse arguments
        let args = CommandLine.arguments
        var host = "192.168.10.1"
        var debugMode = false

        for (index, arg) in args.enumerated() {
            if arg == "--host" && index + 1 < args.count {
                host = args[index + 1]
            }
            if arg == "--verbose" || arg == "-v" {
                verbose = true
            }
            if arg == "--debug" || arg == "-d" {
                debugMode = true
            }
            if arg == "--help" || arg == "-h" {
                printUsage()
                return
            }
        }

        if debugMode {
            await XPRDebug.runDebug(host: host)
            return
        }

        print("Target: \(host):8002")
        print(String(repeating: "─", count: 60))
        print()

        await runTests(host: host)
    }

    static func printBanner() {
        print()
        print(String(repeating: "═", count: 60))
        print("  XPR 3500e COMPREHENSIVE TEST TOOL")
        print("  Motorola MOTOTRBO Protocol Tester")
        print(String(repeating: "═", count: 60))
        print()
    }

    static func printUsage() {
        print("""
        Usage: XPRTest [options]

        Options:
          --host <ip>    Radio IP address (default: 192.168.10.1)
          --verbose, -v  Enable verbose output
          --debug, -d    Run debug mode (raw packet capture)
          --help, -h     Show this help

        Example:
          swift run XPRTest --host 192.168.10.1 --verbose
          swift run XPRTest --debug
        """)
    }

    static func runTests(host: String) async {
        var passed = 0
        var failed = 0

        // Test 1: Network Connectivity
        print("[1/8] Testing Network Connectivity...")
        if await testNetwork(host: host) {
            passed += 1
        } else {
            failed += 1
            print("  └─ FATAL: Cannot reach radio. Aborting.")
            printSummary(passed: passed, failed: failed)
            return
        }

        // Test 2: XNL Connection
        print("\n[2/8] Testing XNL Connection & Authentication...")
        let connection = XNLConnection(host: host)
        if await testXNLConnection(connection) {
            passed += 1
        } else {
            failed += 1
            print("  └─ FATAL: XNL authentication failed. Aborting.")
            printSummary(passed: passed, failed: failed)
            return
        }

        // Test 3: Radio Identification
        print("\n[3/8] Testing Radio Identification...")
        let programmer = MOTOTRBOProgrammer(host: host)
        if await testIdentification(programmer) {
            passed += 1
        } else {
            failed += 1
        }

        // Test 4: Individual Queries
        print("\n[4/8] Testing Individual XCMP Queries...")
        if await testIndividualQueries(programmer) {
            passed += 1
        } else {
            failed += 1
        }

        // Test 5: Clone Read
        print("\n[5/8] Testing Clone Read (Channel Data)...")
        if await testCloneRead(host: host) {
            passed += 1
        } else {
            failed += 1
        }

        // Test 6: PSDT Addresses
        print("\n[6/8] Testing PSDT Address Query...")
        if await testPSDTAddresses(host: host) {
            passed += 1
        } else {
            failed += 1
        }

        // Test 7: Session Management
        print("\n[7/8] Testing CPS Session Management...")
        if await testSessionManagement(host: host) {
            passed += 1
        } else {
            failed += 1
        }

        // Test 8: Codeplug Read
        print("\n[8/8] Testing Codeplug Read...")
        if await testCodeplugRead(programmer) {
            passed += 1
        } else {
            failed += 1
        }

        printSummary(passed: passed, failed: failed)
    }

    // MARK: - Test Functions

    static func testNetwork(host: String) async -> Bool {
        // Simple TCP connection test
        let connection = XNLConnection(host: host)
        let result = await connection.connect()

        switch result {
        case .success:
            print("  ✓ Network: Radio reachable at \(host)")
            await connection.disconnect()
            return true
        case .connectionError(let msg):
            print("  ✗ Network: \(msg)")
            return false
        case .timeout:
            print("  ✗ Network: Connection timeout")
            return false
        case .authenticationFailed:
            // Connection worked, auth is a separate test
            print("  ✓ Network: Radio reachable (auth pending)")
            return true
        }
    }

    static func testXNLConnection(_ connection: XNLConnection) async -> Bool {
        let result = await connection.connect()

        switch result {
        case .success(let addr):
            print("  ✓ XNL Auth: Success")
            print("    └─ Assigned Address: 0x\(String(format: "%04X", addr))")
            return true
        case .authenticationFailed(let code):
            print("  ✗ XNL Auth: Failed (code: 0x\(String(format: "%02X", code)))")
            return false
        case .connectionError(let msg):
            print("  ✗ XNL Auth: \(msg)")
            return false
        case .timeout:
            print("  ✗ XNL Auth: Timeout")
            return false
        }
    }

    static func testIdentification(_ programmer: MOTOTRBOProgrammer) async -> Bool {
        do {
            let info = try await programmer.identify()
            print("  ✓ Identification: Success")
            print("    ├─ Model:    \(info.modelNumber)")
            print("    ├─ Serial:   \(info.serialNumber ?? "N/A")")
            print("    ├─ Firmware: \(info.firmwareVersion ?? "N/A")")
            print("    ├─ Radio ID: \(info.radioID.map { String($0) } ?? "N/A")")
            print("    └─ Family:   \(info.radioFamily ?? "Unknown")")
            return true
        } catch {
            print("  ✗ Identification: \(error.localizedDescription)")
            return false
        }
    }

    static func testIndividualQueries(_ programmer: MOTOTRBOProgrammer) async -> Bool {
        var success = 0

        if let model = try? await programmer.getModelNumber() {
            if verbose { print("    ✓ Model: \(model)") }
            success += 1
        }

        if let serial = try? await programmer.getSerialNumber() {
            if verbose { print("    ✓ Serial: \(serial)") }
            success += 1
        }

        if let id = try? await programmer.getRadioID() {
            if verbose { print("    ✓ Radio ID: \(id)") }
            success += 1
        }

        if let fw = try? await programmer.getFirmwareVersion() {
            if verbose { print("    ✓ Firmware: \(fw)") }
            success += 1
        }

        print("  \(success > 0 ? "✓" : "✗") Queries: \(success)/4 successful")
        return success > 0
    }

    static func testCloneRead(host: String) async -> Bool {
        let connection = XNLConnection(host: host)
        guard case .success = await connection.connect() else {
            print("  ✗ Clone Read: Connection failed")
            return false
        }

        let client = XCMPClient(xnlConnection: connection)
        var channelsFound = 0

        for ch in 0..<3 {
            if let name = try? await client.getChannelName(zone: 0, channel: UInt16(ch)) {
                if verbose { print("    Ch\(ch): \(name)") }
                channelsFound += 1
            }
        }

        await connection.disconnect()

        if channelsFound > 0 {
            print("  ✓ Clone Read: \(channelsFound) channels found")
            return true
        } else {
            print("  ✗ Clone Read: No channel data returned")
            return false
        }
    }

    static func testPSDTAddresses(host: String) async -> Bool {
        let connection = XNLConnection(host: host)
        guard case .success = await connection.connect() else {
            print("  ✗ PSDT: Connection failed")
            return false
        }

        let client = XCMPClient(xnlConnection: connection)

        // Query start address
        let startReq = XCMPPacket.psdtGetStartAddress(partition: "CP")
        let startReply = try? await client.sendAndReceive(startReq)

        // Query end address
        let endReq = XCMPPacket.psdtGetEndAddress(partition: "CP")
        let endReply = try? await client.sendAndReceive(endReq)

        await connection.disconnect()

        var startAddr: UInt32?
        var endAddr: UInt32?

        if let reply = startReply, reply.data.count >= 5 {
            startAddr = UInt32(reply.data[1]) << 24 |
                       UInt32(reply.data[2]) << 16 |
                       UInt32(reply.data[3]) << 8 |
                       UInt32(reply.data[4])
        }

        if let reply = endReply, reply.data.count >= 5 {
            endAddr = UInt32(reply.data[1]) << 24 |
                     UInt32(reply.data[2]) << 16 |
                     UInt32(reply.data[3]) << 8 |
                     UInt32(reply.data[4])
        }

        if let start = startAddr, let end = endAddr {
            let size = end - start
            print("  ✓ PSDT: Codeplug partition found")
            print("    ├─ Start: 0x\(String(format: "%08X", start))")
            print("    ├─ End:   0x\(String(format: "%08X", end))")
            print("    └─ Size:  \(size) bytes (\(size / 1024) KB)")
            return true
        } else {
            print("  ✗ PSDT: Could not query partition addresses")
            if verbose {
                print("    Start reply: \(startReply?.data.map { String(format: "%02X", $0) }.joined(separator: " ") ?? "none")")
                print("    End reply: \(endReply?.data.map { String(format: "%02X", $0) }.joined(separator: " ") ?? "none")")
            }
            return false
        }
    }

    static func testSessionManagement(host: String) async -> Bool {
        let connection = XNLConnection(host: host)
        guard case .success = await connection.connect() else {
            print("  ✗ Session: Connection failed")
            return false
        }

        let client = XCMPClient(xnlConnection: connection)
        let sessionID = UInt16.random(in: 1...0xFFFE)

        // Start session
        let startPacket = XCMPPacket.startReadSession(sessionID: sessionID)
        let startReply = try? await client.sendAndReceive(startPacket)

        var success = false

        if let reply = startReply {
            if reply.data.isEmpty || reply.data[0] == 0x00 {
                print("  ✓ Session: Started successfully (ID: 0x\(String(format: "%04X", sessionID)))")
                success = true

                // End session
                let resetPacket = XCMPPacket.resetSession(sessionID: sessionID)
                _ = try? await client.sendAndReceive(resetPacket)
                print("    └─ Session ended cleanly")
            } else {
                print("  ✗ Session: Start failed (code: 0x\(String(format: "%02X", reply.data[0])))")
            }
        } else {
            print("  ✗ Session: No reply to start request")
        }

        await connection.disconnect()
        return success
    }

    static func testCodeplugRead(_ programmer: MOTOTRBOProgrammer) async -> Bool {
        do {
            let codeplug = try await programmer.readCodeplug { progress in
                let pct = Int(progress * 100)
                if pct % 20 == 0 {
                    print("    Progress: \(pct)%")
                }
            }

            print("  ✓ Codeplug Read: Success")
            print("    └─ Size: \(codeplug.count) bytes (\(codeplug.count / 1024) KB)")

            // Show hex dump of first 32 bytes
            if verbose && codeplug.count >= 32 {
                print("    First 32 bytes:")
                let preview = codeplug.prefix(32)
                for offset in stride(from: 0, to: 32, by: 16) {
                    let end = min(offset + 16, 32)
                    let bytes = preview[offset..<end]
                    let hex = bytes.map { String(format: "%02X", $0) }.joined(separator: " ")
                    print("      \(String(format: "%04X", offset)): \(hex)")
                }
            }

            return true
        } catch {
            print("  ✗ Codeplug Read: \(error.localizedDescription)")
            return false
        }
    }

    // MARK: - Summary

    static func printSummary(passed: Int, failed: Int) {
        print()
        print(String(repeating: "═", count: 60))
        print("  TEST RESULTS")
        print(String(repeating: "─", count: 60))
        print("  Passed: \(passed)")
        print("  Failed: \(failed)")
        print("  Total:  \(passed + failed)")
        print(String(repeating: "═", count: 60))

        if failed == 0 {
            print()
            print("  ALL TESTS PASSED!")
            print("  The XPR 3500e is fully communicating with our protocol stack.")
            print()
        } else if passed > failed {
            print()
            print("  PARTIAL SUCCESS")
            print("  Basic communication works. Some advanced features need attention.")
            print()
        } else {
            print()
            print("  NEEDS INVESTIGATION")
            print("  Check the radio connection and try with --verbose for details.")
            print()
        }
    }
}
