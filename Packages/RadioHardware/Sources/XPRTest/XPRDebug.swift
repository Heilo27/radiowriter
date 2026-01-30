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
        let result = await connection.connect()

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

        // Test 1: RadioStatusRequest for model number
        print("\n1. RadioStatusRequest (Model Number) - Opcode 0x000E")
        let modelReq = Data([0x00, 0x0E, 0x07])  // opcode + status type
        print("   Sending: \(modelReq.hex)")
        if let response = try? await connection.sendXCMP(modelReq, timeout: 3.0, debug: true) {
            print("   Response: \(response.hex)")
            analyzeResponse(response)
        } else {
            print("   No response")
        }

        // Test 2: RadioStatusRequest for serial number
        print("\n2. RadioStatusRequest (Serial Number) - Opcode 0x000E, Type 0x08")
        let serialReq = Data([0x00, 0x0E, 0x08])  // opcode + status type
        print("   Sending: \(serialReq.hex)")
        if let response = try? await connection.sendXCMP(serialReq, timeout: 3.0, debug: true) {
            print("   Response: \(response.hex)")
            analyzeResponse(response)
            // Parse status type from response
            if response.count >= 4 {
                let statusType = response[2]
                print("   Response status type: 0x\(String(format: "%02X", statusType))")
                if statusType == 0x08 {
                    let serial = String(data: response.dropFirst(3), encoding: .utf8) ?? "N/A"
                    print("   Serial: \(serial)")
                }
            }
        } else {
            print("   No response")
        }

        // Test 2b: VersionInfoRequest
        print("\n2b. VersionInfoRequest (Firmware) - Opcode 0x000F")
        let versionReq = Data([0x00, 0x0F, 0x00])  // opcode + version type
        print("   Sending: \(versionReq.hex)")
        if let response = try? await connection.sendXCMP(versionReq, timeout: 3.0, debug: true) {
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

        // Test 5: PSDT Access
        print("\n5. PSDT Access - Get Start Address (Opcode 0x010B)")
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

