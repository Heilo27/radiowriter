//
// XPR Debug Tool - Raw packet capture
//

import Foundation
import RadioProgrammer

/// Debug tool for capturing and analyzing XNL/XCMP traffic
struct XPRDebug {

    static func runDebug(host: String) async {
        print("\n" + String(repeating: "═", count: 60))
        print("  XPR 3500e DEBUG MODE")
        print(String(repeating: "═", count: 60))
        print()

        // Test 1: Raw XNL connection and capture all received packets
        await testRawXNL(host: host)
    }

    static func testRawXNL(host: String) async {
        print("[DEBUG] Starting raw XNL capture...")
        print("Host: \(host):8002\n")

        let connection = XNLConnection(host: host)
        let result = await connection.connect(debug: true)  // Enable init broadcast debug

        switch result {
        case .success(let addr):
            print("✓ XNL Connected - Assigned Address: 0x\(String(format: "%04X", addr))")
            print()

            // Now try sending various XCMP commands and log responses
            await testXCMPFormats(connection: connection)

        case .authenticationFailed(let code):
            print("✗ Auth failed: 0x\(String(format: "%02X", code))")

        case .connectionError(let msg):
            print("✗ Connection error: \(msg)")

        case .timeout:
            print("✗ Timeout")
        }

        await connection.disconnect()
    }

    static func testXCMPFormats(connection: XNLConnection) async {
        print("[DEBUG] Testing XCMP packet formats...")
        print(String(repeating: "-", count: 50))

        // ============================================
        // CPS-VERIFIED OPCODES (from CPS 2.0 capture)
        // ============================================

        // Test 1: SecurityKeyRequest (0x0012) - CPS sends this FIRST
        print("\n1. SecurityKeyRequest (0x0012) - VERIFIED CPS PROTOCOL")
        let securityKeyReq = Data([0x00, 0x12])  // opcode only, no params
        print("   Sending: \(securityKeyReq.hex)")
        if let response = try? await connection.sendXCMP(securityKeyReq, timeout: 5.0, debug: true) {
            print("   Response: \(response.hex)")
            analyzeResponse(response)
            if response.count >= 17 {
                let key = Data(response[1...16])
                print("   Security Key: \(key.hex)")
            }
        } else {
            print("   No response")
        }

        // Test 2: ModelNumberRequest (0x0010) - VERIFIED CPS PROTOCOL
        print("\n2. ModelNumberRequest (0x0010) - VERIFIED CPS PROTOCOL")
        let modelReq = Data([0x00, 0x10, 0x00])  // opcode + param 0x00
        print("   Sending: \(modelReq.hex)")
        if let response = try? await connection.sendXCMP(modelReq, timeout: 5.0, debug: true) {
            print("   Response: \(response.hex)")
            analyzeResponse(response)
            if response.count > 3 {
                let model = String(data: Data(response[1...]), encoding: .utf8) ?? "N/A"
                print("   Model: \(model)")
            }
        } else {
            print("   No response")
        }

        // Test 3: SerialNumberRequest (0x0011) - VERIFIED CPS PROTOCOL
        print("\n3. SerialNumberRequest (0x0011) - VERIFIED CPS PROTOCOL")
        let serialReq = Data([0x00, 0x11, 0x00])  // opcode + param 0x00
        print("   Sending: \(serialReq.hex)")
        if let response = try? await connection.sendXCMP(serialReq, timeout: 5.0, debug: true) {
            print("   Response: \(response.hex)")
            analyzeResponse(response)
            if response.count > 3 {
                let serial = String(data: Data(response[1...]), encoding: .utf8) ?? "N/A"
                print("   Serial: \(serial)")
            }
        } else {
            print("   No response")
        }

        // Test 4: VersionInfoRequest (0x000F) - VERIFIED CPS PROTOCOL
        print("\n4. VersionInfoRequest (0x000F type=0x00) - VERIFIED CPS PROTOCOL")
        let versionReq = Data([0x00, 0x0F, 0x00])  // opcode + version type
        print("   Sending: \(versionReq.hex)")
        if let response = try? await connection.sendXCMP(versionReq, timeout: 5.0, debug: true) {
            print("   Response: \(response.hex)")
            analyzeResponse(response)
            if response.count > 3 {
                let version = String(data: Data(response[1...]), encoding: .utf8) ?? "N/A"
                print("   Firmware: \(version)")
            }
        } else {
            print("   No response")
        }

        // Test 5: CodeplugIdRequest (0x001F) - VERIFIED CPS PROTOCOL
        print("\n5. CodeplugIdRequest (0x001F) - VERIFIED CPS PROTOCOL")
        let cpIdReq = Data([0x00, 0x1F, 0x00, 0x00])  // opcode + params
        print("   Sending: \(cpIdReq.hex)")
        if let response = try? await connection.sendXCMP(cpIdReq, timeout: 5.0, debug: true) {
            print("   Response: \(response.hex)")
            analyzeResponse(response)
        } else {
            print("   No response")
        }

        // ============================================
        // LEGACY OPCODES (may not work with XPR)
        // ============================================

        // Test 6: Legacy RadioStatusRequest for model number
        print("\n6. (Legacy) RadioStatusRequest (0x000E type=0x07)")
        let legacyModelReq = Data([0x00, 0x0E, 0x07])  // opcode + status type
        print("   Sending: \(legacyModelReq.hex)")
        if let response = try? await connection.sendXCMP(legacyModelReq, timeout: 3.0, debug: true) {
            print("   Response: \(response.hex)")
            analyzeResponse(response)
        } else {
            print("   No response")
        }

        // Test 3: Try bare opcode without payload
        print("\n3. RadioStatusRequest (bare opcode)")
        let bareReq = Data([0x00, 0x0E])
        print("   Sending: \(bareReq.hex)")
        if let response = try? await connection.sendXCMP(bareReq, timeout: 3.0) {
            print("   Response: \(response.hex)")
            analyzeResponse(response)
        } else {
            print("   No response")
        }

        // Test 4: Try with different endianness
        print("\n4. RadioStatusRequest (little-endian opcode)")
        let leReq = Data([0x0E, 0x00, 0x07])
        print("   Sending: \(leReq.hex)")
        if let response = try? await connection.sendXCMP(leReq, timeout: 3.0) {
            print("   Response: \(response.hex)")
            analyzeResponse(response)
        } else {
            print("   No response")
        }

        // Test 5: Initialize radio before PSDT access
        print("\n5. Radio Initialization Sequence (unlock before PSDT)")
        let initResult = await connection.initialize(partition: .application, debug: true)
        switch initResult {
        case .success:
            print("   ✓ Initialization successful!")

            // Now try PSDT Access
            print("\n6. PSDT Access - Get Start Address (Opcode 0x010B)")
            var psdtReq = Data([0x01, 0x0B, 0x01])  // opcode + action (getStartAddress)
            psdtReq.append(contentsOf: "CP".utf8)   // partition
            psdtReq.append(contentsOf: [0x00, 0x00]) // padding
            psdtReq.append(contentsOf: [0x00, 0x00, 0x00, 0x00]) // target partition
            print("   Sending: \(psdtReq.hex)")
            if let response = try? await connection.sendXCMP(psdtReq, timeout: 3.0) {
                print("   Response: \(response.hex)")
                analyzeResponse(response)
            } else {
                print("   No response")
            }

        case .enterProgramModeFailed(let code):
            print("   ✗ Enter programming mode failed: 0x\(String(format: "%02X", code))")
        case .readRadioKeyFailed(let code):
            print("   ✗ Read radio key failed: 0x\(String(format: "%02X", code))")
        case .unlockSecurityFailed(let code):
            print("   ✗ Unlock security failed: 0x\(String(format: "%02X", code))")
        case .unlockPartitionFailed(let code):
            print("   ✗ Unlock partition failed: 0x\(String(format: "%02X", code))")
        case .notAuthenticated:
            print("   ✗ Not authenticated")
        case .timeout:
            print("   ✗ Timeout")
        }

        // Skip the old PSDT test since we do it inside the init block now
        print("\n-- Skipping standalone PSDT test (done above) --")

        // Test 6: Component Session Start
        print("\n6. Component Session Start (Opcode 0x010F)")
        let sessionID: UInt16 = 0x1234
        var sessionReq = Data([0x01, 0x0F])  // opcode
        sessionReq.append(0x02)  // actions: startSession
        sessionReq.append(0x02)  // second byte of actions
        sessionReq.append(UInt8(sessionID >> 8))
        sessionReq.append(UInt8(sessionID & 0xFF))
        print("   Sending: \(sessionReq.hex)")
        if let response = try? await connection.sendXCMP(sessionReq, timeout: 3.0) {
            print("   Response: \(response.hex)")
            analyzeResponse(response)
        } else {
            print("   No response")
        }

        // Test 7: Module Info Request (simple)
        print("\n7. Module Info Request (Opcode 0x0461)")
        let moduleReq = Data([0x04, 0x61])
        print("   Sending: \(moduleReq.hex)")
        if let response = try? await connection.sendXCMP(moduleReq, timeout: 3.0) {
            print("   Response: \(response.hex)")
            analyzeResponse(response)
        } else {
            print("   No response")
        }

        // Test 8: Try CPS Unlock
        print("\n8. CPS Unlock Request (Opcode 0x0100)")
        let unlockReq = Data([0x01, 0x00])
        print("   Sending: \(unlockReq.hex)")
        if let response = try? await connection.sendXCMP(unlockReq, timeout: 3.0) {
            print("   Response: \(response.hex)")
            analyzeResponse(response)
        } else {
            print("   No response")
        }

        // Test 9: Clone Read (channel 0)
        print("\n9. Clone Read Request (Opcode 0x010A)")
        var cloneReq = Data([0x01, 0x0A])  // opcode
        // Zone index type + zone number
        cloneReq.append(contentsOf: [0x80, 0x01, 0x00, 0x00])
        // Channel index type + channel number
        cloneReq.append(contentsOf: [0x80, 0x02, 0x00, 0x00])
        // Data type (channel name)
        cloneReq.append(contentsOf: [0x00, 0x0F])
        print("   Sending: \(cloneReq.hex)")
        if let response = try? await connection.sendXCMP(cloneReq, timeout: 3.0) {
            print("   Response: \(response.hex)")
            analyzeResponse(response)
        } else {
            print("   No response")
        }

        // Test 10: Check if we need to wait longer after auth
        print("\n10. Waiting 2 seconds then retry RadioStatusRequest...")
        try? await Task.sleep(for: .seconds(2))
        if let response = try? await connection.sendXCMP(modelReq, timeout: 5.0) {
            print("    Response: \(response.hex)")
            analyzeResponse(response)
        } else {
            print("    Still no response")
        }

        print("\n" + String(repeating: "-", count: 50))
        print("[DEBUG] Test complete")
    }

    static func analyzeResponse(_ data: Data) {
        if data.count >= 2 {
            let opcode = UInt16(data[0]) << 8 | UInt16(data[1])
            print("   Opcode: 0x\(String(format: "%04X", opcode))")

            // Check if it's a reply (high bit set)
            if opcode & 0x8000 != 0 {
                print("   Type: Reply")
            } else if opcode & 0xB000 == 0xB000 {
                print("   Type: Broadcast")
            } else {
                print("   Type: Request")
            }

            if data.count > 2 {
                let payload = Data(data.dropFirst(2))
                print("   Payload (\(payload.count) bytes): \(payload.hex)")

                // Check for error code
                if !payload.isEmpty {
                    let errorCode = payload[0]
                    if errorCode == 0x00 {
                        print("   Status: Success")
                    } else {
                        print("   Status: Error code 0x\(String(format: "%02X", errorCode))")
                    }
                }
            }
        }
    }
}
