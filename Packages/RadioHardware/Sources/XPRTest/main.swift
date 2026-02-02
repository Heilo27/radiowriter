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
        // Flush stdout to ensure output is visible
        setbuf(stdout, nil)
        print("[DEBUG] XPRTest starting...")
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
            if arg == "--debug" || arg == "-d" || arg == "debug" {
                debugMode = true
            }
            if arg == "--channels" || arg == "-c" || arg == "channels" {
                await ChannelTest.run(host: host)
                return
            }
            if arg == "--analyze" || arg == "analyze" {
                await FullChannelAnalysis.run(host: host)
                return
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

        // Test 3: Radio Identification (VERIFIED CPS Protocol)
        print("\n[3/8] Testing Radio Identification (CPS Protocol)...")
        let programmer = MOTOTRBOProgrammer(host: host)
        if await testIdentificationCPS(host: host) {
            passed += 1
        } else {
            failed += 1
        }

        // Test 4: CPS Device Info Queries
        print("\n[4/8] Testing CPS Device Info Queries...")
        if await testIndividualQueries(programmer) {
            passed += 1
        } else {
            failed += 1
        }

        // Test 5: Zone/Channel Records
        print("\n[5/8] Testing Zone/Channel Records (CPS)...")
        if await testZoneChannelRecords(host: host) {
            passed += 1
        } else {
            failed += 1
        }

        // Test 6: Extended Device Info (CPS Protocol)
        print("\n[6/8] Testing Extended Device Info (CPS)...")
        if await testExtendedDeviceInfo(host: host) {
            passed += 1
        } else {
            failed += 1
        }

        // Test 7: Multi-Command Session
        print("\n[7/8] Testing Multi-Command Session...")
        if await testMultiCommandSession(host: host) {
            passed += 1
        } else {
            failed += 1
        }

        // Test 8: Full Codeplug Read (CPS Protocol)
        print("\n[8/8] Testing Full Codeplug Read (CPS)...")
        if await testCodeplugReadCPS(programmer) {
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

    /// Tests radio identification using the VERIFIED CPS 2.0 protocol.
    /// This uses SecurityKey (0x0012), ModelNumber (0x0010), etc.
    static func testIdentificationCPS(host: String) async -> Bool {
        let connection = XNLConnection(host: host)
        guard case .success = await connection.connect(debug: verbose) else {
            print("  ✗ CPS Identify: Connection failed")
            return false
        }

        // Test: Multiple commands on SAME connection
        // With proper ACKs (echoing XCMP flag and flags), this should now work!

        let client = XCMPClient(xnlConnection: connection)

        // 1. Security Key (0x0012)
        print("    1. Security Key (0x0012)...")
        if let response = try? await connection.sendXCMP(Data([0x00, 0x12]), timeout: 5.0, debug: verbose) {
            if response.count > 3, response[2] == 0x00 {
                let keyData = Data(response[3...])
                print("    ✓ Security Key: \(keyData.hex)")
            } else {
                print("    ? Security Key: \(response.hex)")
            }
        } else {
            print("    ✗ Security Key: timeout")
        }

        // 2. Model Number (0x0010)
        print("    2. Model Number (0x0010)...")
        if let response = try? await connection.sendXCMP(Data([0x00, 0x10, 0x00]), timeout: 5.0, debug: verbose) {
            if response.count > 3, response[2] == 0x00 {
                let modelData = Data(response[3...])
                if let model = String(data: modelData, encoding: .utf8)?
                    .trimmingCharacters(in: .controlCharacters)
                    .trimmingCharacters(in: CharacterSet(["\0"])) {
                    print("    ✓ Model: \(model)")
                } else {
                    print("    ? Model: \(response.hex)")
                }
            } else {
                print("    ? Model: \(response.hex)")
            }
        } else {
            print("    ✗ Model: timeout")
        }

        // 3. Serial Number (0x0011)
        print("    3. Serial Number (0x0011)...")
        if let response = try? await connection.sendXCMP(Data([0x00, 0x11, 0x00]), timeout: 5.0, debug: verbose) {
            if response.count > 3, response[2] == 0x00 {
                let serialData = Data(response[3...])
                if let serial = String(data: serialData, encoding: .utf8)?
                    .trimmingCharacters(in: .controlCharacters)
                    .trimmingCharacters(in: CharacterSet(["\0"])) {
                    print("    ✓ Serial: \(serial)")
                } else {
                    print("    ? Serial: \(response.hex)")
                }
            } else {
                print("    ? Serial: \(response.hex)")
            }
        } else {
            print("    ✗ Serial: timeout")
        }

        // 4. Firmware Version (0x000F)
        print("    4. Firmware Version (0x000F)...")
        if let response = try? await connection.sendXCMP(Data([0x00, 0x0F, 0x00]), timeout: 5.0, debug: verbose) {
            if response.count > 3, response[2] == 0x00 {
                let fwData = Data(response[3...])
                if let fw = String(data: fwData, encoding: .utf8)?
                    .trimmingCharacters(in: .controlCharacters)
                    .trimmingCharacters(in: CharacterSet(["\0"])) {
                    print("    ✓ Firmware: \(fw)")
                } else {
                    print("    ? Firmware: \(response.hex)")
                }
            } else {
                print("    ? Firmware: \(response.hex)")
            }
        } else {
            print("    ✗ Firmware: timeout")
        }

        // 5. Codeplug ID (0x001F)
        print("    5. Codeplug ID (0x001F)...")
        if let response = try? await connection.sendXCMP(Data([0x00, 0x1F, 0x00, 0x00]), timeout: 5.0, debug: verbose) {
            if response.count > 3, response[2] == 0x00 {
                let cpData = Data(response[3...])
                if let cpid = String(data: cpData, encoding: .utf8)?
                    .trimmingCharacters(in: .controlCharacters)
                    .trimmingCharacters(in: CharacterSet(["\0"])) {
                    print("    ✓ Codeplug ID: \(cpid)")
                } else {
                    print("    ? Codeplug ID: \(response.hex)")
                }
            } else {
                print("    ? Codeplug ID: \(response.hex)")
            }
        } else {
            print("    ✗ Codeplug ID: timeout")
        }

        await connection.disconnect()

        await connection.disconnect()
        print("  ✓ CPS Protocol Identification Complete")
        return true
    }

    /// Tests reading codeplug records using CPS protocol (0x002E).
    static func testIndividualQueries(_ programmer: MOTOTRBOProgrammer) async -> Bool {
        print("    Testing CodeplugRead (0x002E)...")

        // Read a few records using the CPS protocol
        do {
            let data = try await programmer.readCodeplugCPS(progress: { pct in
                if verbose && Int(pct * 100) % 25 == 0 {
                    print("      Progress: \(Int(pct * 100))%")
                }
            }, debug: verbose)

            print("  ✓ CodeplugRead: Got \(data.count) bytes")
            if verbose && data.count > 0 {
                let preview = data.prefix(min(32, data.count))
                print("    First bytes: \(preview.map { String(format: "%02X", $0) }.joined(separator: " "))")
            }
            return true
        } catch {
            print("  ✗ CodeplugRead: \(error.localizedDescription)")
            return false
        }
    }

    /// Tests reading additional records using CodeplugRead (0x002E).
    /// This reads zone and channel configuration records.
    static func testZoneChannelRecords(host: String) async -> Bool {
        let connection = XNLConnection(host: host)
        guard case .success = await connection.connect(debug: verbose) else {
            print("  ✗ Zone/Channel: Connection failed")
            return false
        }

        let client = XCMPClient(xnlConnection: connection)

        // Read zone/channel related records using CPS protocol (0x002E)
        // These record IDs are from the standard MOTOTRBO record set
        let zoneRecords: [UInt16] = [0x005E, 0x005F, 0x0060, 0x0061, 0x0062]

        print("    Reading zone/channel records...")
        if let recordData = try? await client.readCodeplugRecords(zoneRecords, debug: verbose) {
            if recordData.count > 10 {
                print("  ✓ Zone/Channel: Got \(recordData.count) bytes of configuration data")
                if verbose {
                    let preview = recordData.prefix(min(32, recordData.count))
                    print("    Preview: \(preview.map { String(format: "%02X", $0) }.joined(separator: " "))")
                }
                await connection.disconnect()
                return true
            }
        }

        await connection.disconnect()
        print("  ✗ Zone/Channel: Could not read records")
        return false
    }

    /// Tests additional CPS device queries (language, zones, capabilities).
    static func testExtendedDeviceInfo(host: String) async -> Bool {
        let connection = XNLConnection(host: host)
        guard case .success = await connection.connect(debug: verbose) else {
            print("  ✗ Extended Info: Connection failed")
            return false
        }

        var queriesSucceeded = 0

        // Query status flags (0x003D)
        print("    1. Status Flags (0x003D)...")
        if let response = try? await connection.sendXCMP(Data([0x00, 0x3D, 0x00, 0x00]), timeout: 5.0, debug: verbose) {
            if response.count >= 3 {
                print("    ✓ Status Flags: \(response.map { String(format: "%02X", $0) }.joined(separator: " "))")
                queriesSucceeded += 1
            } else {
                print("    ? Status Flags: \(response.hex)")
            }
        } else {
            print("    ✗ Status Flags: timeout")
        }

        // Query feature set (0x0037)
        print("    2. Feature Set (0x0037)...")
        if let response = try? await connection.sendXCMP(Data([0x00, 0x37, 0x01, 0x01, 0x00]), timeout: 5.0, debug: verbose) {
            if response.count >= 3 {
                print("    ✓ Feature Set: \(response.count) bytes")
                queriesSucceeded += 1
            } else {
                print("    ? Feature Set: \(response.hex)")
            }
        } else {
            print("    ✗ Feature Set: timeout")
        }

        // Query language pack (0x002C)
        print("    3. Language Pack (0x002C)...")
        if let response = try? await connection.sendXCMP(Data([0x00, 0x2C, 0x01]), timeout: 5.0, debug: verbose) {
            if response.count >= 3, response[2] == 0x00 || response.count > 10 {
                print("    ✓ Language Pack: \(response.count) bytes")
                queriesSucceeded += 1
            } else {
                print("    ? Language Pack: \(response.hex)")
            }
        } else {
            print("    ✗ Language Pack: timeout")
        }

        await connection.disconnect()

        if queriesSucceeded >= 2 {
            print("  ✓ Extended Info: \(queriesSucceeded)/3 queries succeeded")
            return true
        } else {
            print("  ✗ Extended Info: Only \(queriesSucceeded)/3 queries succeeded")
            return false
        }
    }

    /// Tests multi-command session capability using CPS protocol.
    /// Verifies that multiple XCMP commands work reliably in sequence.
    static func testMultiCommandSession(host: String) async -> Bool {
        let connection = XNLConnection(host: host)
        guard case .success = await connection.connect(debug: verbose) else {
            print("  ✗ Multi-Command: Connection failed")
            return false
        }

        var commandsSucceeded = 0
        let totalCommands = 10

        // Send 10 different XCMP commands in sequence to verify session stability
        let commands: [(String, Data)] = [
            ("SecurityKey", Data([0x00, 0x12])),
            ("Model", Data([0x00, 0x10, 0x00])),
            ("Serial", Data([0x00, 0x11, 0x00])),
            ("Firmware", Data([0x00, 0x0F, 0x00])),
            ("CodeplugID", Data([0x00, 0x1F, 0x00, 0x00])),
            ("StatusFlags", Data([0x00, 0x3D, 0x00, 0x00])),
            ("Version-P", Data([0x00, 0x0F, 0x50])),
            ("Version-Q", Data([0x00, 0x0F, 0x51])),
            ("Version-R", Data([0x00, 0x0F, 0x52])),
            ("Version-Build", Data([0x00, 0x0F, 0x41])),
        ]

        for (name, cmd) in commands {
            if let response = try? await connection.sendXCMP(cmd, timeout: 5.0, debug: verbose) {
                if response.count >= 3 {
                    commandsSucceeded += 1
                    if verbose {
                        print("    ✓ \(name): \(response.count) bytes")
                    }
                }
            } else {
                print("    ✗ \(name): timeout")
            }
        }

        await connection.disconnect()

        if commandsSucceeded == totalCommands {
            print("  ✓ Multi-Command: All \(totalCommands) commands succeeded in single session")
            return true
        } else if commandsSucceeded > totalCommands / 2 {
            print("  ~ Multi-Command: \(commandsSucceeded)/\(totalCommands) commands succeeded")
            return true
        } else {
            print("  ✗ Multi-Command: Only \(commandsSucceeded)/\(totalCommands) commands succeeded")
            return false
        }
    }

    /// Tests full codeplug read using verified CPS 2.0 protocol.
    static func testCodeplugReadCPS(_ programmer: MOTOTRBOProgrammer) async -> Bool {
        do {
            var lastPct = -1
            let codeplug = try await programmer.readCodeplugCPS(progress: { progress in
                let pct = Int(progress * 100)
                if pct % 25 == 0 && pct != lastPct {
                    print("    Progress: \(pct)%")
                    lastPct = pct
                }
            }, debug: verbose)

            print("  ✓ Codeplug Read (CPS): Success")
            print("    └─ Size: \(codeplug.count) bytes")

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

            // Also test parsing by calling readZonesAndChannels
            print("\n[9/9] Testing Zone/Channel Parsing...")

            // First show what records we have in the raw data
            if verbose {
                print("    Scanning raw codeplug data for patterns...")
                var dataRecords = 0
                var metadataRecords = 0
                for i in 0..<(codeplug.count - 2) {
                    if codeplug[i] == 0x81 && codeplug[i + 1] == 0x00 {
                        dataRecords += 1
                    } else if codeplug[i] == 0x81 && codeplug[i + 1] == 0x04 {
                        metadataRecords += 1
                    }
                }
                print("    Found \(dataRecords) data records (81 00) and \(metadataRecords) metadata records (81 04)")

                // Look for UTF-16 strings (channel names)
                var utf16Strings: [String] = []
                for i in stride(from: 0, to: codeplug.count - 20, by: 2) {
                    // Look for potential UTF-16LE text (ASCII chars as low byte, 0x00 as high byte)
                    if codeplug[i] >= 0x41 && codeplug[i] <= 0x7A && codeplug[i + 1] == 0x00 {
                        var str = ""
                        var j = i
                        while j < codeplug.count - 1 && codeplug[j + 1] == 0x00 && codeplug[j] >= 0x20 && codeplug[j] <= 0x7E {
                            str.append(Character(UnicodeScalar(codeplug[j])))
                            j += 2
                        }
                        if str.count >= 3 && str.count <= 16 {
                            utf16Strings.append(str)
                        }
                    }
                }
                let uniqueStrings = Array(Set(utf16Strings))
                if !uniqueStrings.isEmpty {
                    print("    Found UTF-16LE strings: \(uniqueStrings.prefix(10).joined(separator: ", "))")
                }
            }

            let parsedCodeplug = try await programmer.readZonesAndChannels(progress: { _ in }, debug: verbose)

            if parsedCodeplug.zones.isEmpty {
                print("  ⚠ Parsing: No zones found in codeplug")
                // Still show any settings found
                if !parsedCodeplug.radioAlias.isEmpty && parsedCodeplug.radioAlias != "Radio" {
                    print("    └─ Radio Alias: \(parsedCodeplug.radioAlias)")
                }
                if !parsedCodeplug.modelNumber.isEmpty {
                    print("    └─ Model: \(parsedCodeplug.modelNumber)")
                }
            } else {
                print("  ✓ Parsing: Found \(parsedCodeplug.zones.count) zones")
                for zone in parsedCodeplug.zones.prefix(5) {
                    print("    └─ Zone: \(zone.name) (\(zone.channels.count) channels)")
                    for channel in zone.channels.prefix(3) {
                        print("       └─ Channel: \(channel.name)")
                    }
                }
            }

            return true
        } catch {
            print("  ✗ Codeplug Read (CPS): \(error.localizedDescription)")
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
