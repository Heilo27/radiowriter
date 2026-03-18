//
// XPR Debug Tool - Raw packet capture
//

import Foundation
import RadioProgrammer

/// Debug tool for capturing and analyzing XNL/XCMP traffic
struct XPRDebug {

    static func runDebug(host: String) async {
        RadioLog.xprtest.info("\n\(String(repeating: "═", count: 60))")
        RadioLog.xprtest.info("  XPR 3500e DEBUG MODE")
        RadioLog.xprtest.info("\(String(repeating: "═", count: 60))")

        // Test 1: Raw XNL connection and capture all received packets
        await testRawXNL(host: host)
    }

    static func testRawXNL(host: String) async {
        RadioLog.xprtest.debug("[DEBUG] Starting raw XNL capture...")
        RadioLog.xprtest.info("Host: \(host):8002")

        let connection = XNLConnection(host: host)
        let result = await connection.connect(debug: true)  // Enable init broadcast debug

        switch result {
        case .success(let addr):
            RadioLog.xprtest.info("✓ XNL Connected - Assigned Address: 0x\(String(format: "%04X", addr))")

            // Now try sending various XCMP commands and log responses
            await testXCMPFormats(connection: connection)

        case .authenticationFailed(let code):
            RadioLog.xprtest.error("✗ Auth failed: 0x\(String(format: "%02X", code))")

        case .connectionError(let msg):
            RadioLog.xprtest.error("✗ Connection error: \(msg)")

        case .timeout:
            RadioLog.xprtest.error("✗ Timeout")
        }

        await connection.disconnect()
    }

    static func testXCMPFormats(connection: XNLConnection) async {
        RadioLog.xprtest.debug("[DEBUG] Testing XCMP packet formats...")
        RadioLog.xprtest.debug("\(String(repeating: "-", count: 50))")

        // ============================================
        // CPS-VERIFIED OPCODES (from CPS 2.0 capture)
        // ============================================

        // Test 1: SecurityKeyRequest (0x0012) - CPS sends this FIRST
        RadioLog.xprtest.info("1. SecurityKeyRequest (0x0012) - VERIFIED CPS PROTOCOL")
        let securityKeyReq = Data([0x00, 0x12])  // opcode only, no params
        RadioLog.xprtest.debug("   Sending: \(securityKeyReq.hex)")
        if let response = try? await connection.sendXCMP(securityKeyReq, timeout: 5.0, debug: true) {
            RadioLog.xprtest.debug("   Response: \(response.hex)")
            analyzeResponse(response)
            if response.count >= 17 {
                let key = Data(response[1...16])
                RadioLog.xprtest.info("   Security Key: \(key.hex)")
            }
        } else {
            RadioLog.xprtest.info("   No response")
        }

        // Test 2: ModelNumberRequest (0x0010) - VERIFIED CPS PROTOCOL
        RadioLog.xprtest.info("2. ModelNumberRequest (0x0010) - VERIFIED CPS PROTOCOL")
        let modelReq = Data([0x00, 0x10, 0x00])  // opcode + param 0x00
        RadioLog.xprtest.debug("   Sending: \(modelReq.hex)")
        if let response = try? await connection.sendXCMP(modelReq, timeout: 5.0, debug: true) {
            RadioLog.xprtest.debug("   Response: \(response.hex)")
            analyzeResponse(response)
            if response.count > 3 {
                let model = String(data: Data(response[1...]), encoding: .utf8) ?? "N/A"
                RadioLog.xprtest.info("   Model: \(model)")
            }
        } else {
            RadioLog.xprtest.info("   No response")
        }

        // Test 3: SerialNumberRequest (0x0011) - VERIFIED CPS PROTOCOL
        RadioLog.xprtest.info("3. SerialNumberRequest (0x0011) - VERIFIED CPS PROTOCOL")
        let serialReq = Data([0x00, 0x11, 0x00])  // opcode + param 0x00
        RadioLog.xprtest.debug("   Sending: \(serialReq.hex)")
        if let response = try? await connection.sendXCMP(serialReq, timeout: 5.0, debug: true) {
            RadioLog.xprtest.debug("   Response: \(response.hex)")
            analyzeResponse(response)
            if response.count > 3 {
                let serial = String(data: Data(response[1...]), encoding: .utf8) ?? "N/A"
                RadioLog.xprtest.info("   Serial: \(serial)")
            }
        } else {
            RadioLog.xprtest.info("   No response")
        }

        // Test 4: VersionInfoRequest (0x000F) - VERIFIED CPS PROTOCOL
        RadioLog.xprtest.info("4. VersionInfoRequest (0x000F type=0x00) - VERIFIED CPS PROTOCOL")
        let versionReq = Data([0x00, 0x0F, 0x00])  // opcode + version type
        RadioLog.xprtest.debug("   Sending: \(versionReq.hex)")
        if let response = try? await connection.sendXCMP(versionReq, timeout: 5.0, debug: true) {
            RadioLog.xprtest.debug("   Response: \(response.hex)")
            analyzeResponse(response)
            if response.count > 3 {
                let version = String(data: Data(response[1...]), encoding: .utf8) ?? "N/A"
                RadioLog.xprtest.info("   Firmware: \(version)")
            }
        } else {
            RadioLog.xprtest.info("   No response")
        }

        // Test 5: CodeplugIdRequest (0x001F) - VERIFIED CPS PROTOCOL
        RadioLog.xprtest.info("5. CodeplugIdRequest (0x001F) - VERIFIED CPS PROTOCOL")
        let cpIdReq = Data([0x00, 0x1F, 0x00, 0x00])  // opcode + params
        RadioLog.xprtest.debug("   Sending: \(cpIdReq.hex)")
        if let response = try? await connection.sendXCMP(cpIdReq, timeout: 5.0, debug: true) {
            RadioLog.xprtest.debug("   Response: \(response.hex)")
            analyzeResponse(response)
        } else {
            RadioLog.xprtest.info("   No response")
        }

        // ============================================
        // LEGACY OPCODES (may not work with XPR)
        // ============================================

        // Test 6: Legacy RadioStatusRequest for model number
        RadioLog.xprtest.info("6. (Legacy) RadioStatusRequest (0x000E type=0x07)")
        let legacyModelReq = Data([0x00, 0x0E, 0x07])  // opcode + status type
        RadioLog.xprtest.debug("   Sending: \(legacyModelReq.hex)")
        if let response = try? await connection.sendXCMP(legacyModelReq, timeout: 3.0, debug: true) {
            RadioLog.xprtest.debug("   Response: \(response.hex)")
            analyzeResponse(response)
        } else {
            RadioLog.xprtest.info("   No response")
        }

        // Test 3: Try bare opcode without payload
        RadioLog.xprtest.info("3. RadioStatusRequest (bare opcode)")
        let bareReq = Data([0x00, 0x0E])
        RadioLog.xprtest.debug("   Sending: \(bareReq.hex)")
        if let response = try? await connection.sendXCMP(bareReq, timeout: 3.0) {
            RadioLog.xprtest.debug("   Response: \(response.hex)")
            analyzeResponse(response)
        } else {
            RadioLog.xprtest.info("   No response")
        }

        // Test 4: Try with different endianness
        RadioLog.xprtest.info("4. RadioStatusRequest (little-endian opcode)")
        let leReq = Data([0x0E, 0x00, 0x07])
        RadioLog.xprtest.debug("   Sending: \(leReq.hex)")
        if let response = try? await connection.sendXCMP(leReq, timeout: 3.0) {
            RadioLog.xprtest.debug("   Response: \(response.hex)")
            analyzeResponse(response)
        } else {
            RadioLog.xprtest.info("   No response")
        }

        // Test 5: Initialize radio before PSDT access
        RadioLog.xprtest.info("5. Radio Initialization Sequence (unlock before PSDT)")
        let initResult = await connection.initialize(partition: .application, debug: true)
        switch initResult {
        case .success:
            RadioLog.xprtest.info("   ✓ Initialization successful!")

            // Now try PSDT Access
            RadioLog.xprtest.info("6. PSDT Access - Get Start Address (Opcode 0x010B)")
            var psdtReq = Data([0x01, 0x0B, 0x01])  // opcode + action (getStartAddress)
            psdtReq.append(contentsOf: "CP".utf8)   // partition
            psdtReq.append(contentsOf: [0x00, 0x00]) // padding
            psdtReq.append(contentsOf: [0x00, 0x00, 0x00, 0x00]) // target partition
            RadioLog.xprtest.debug("   Sending: \(psdtReq.hex)")
            if let response = try? await connection.sendXCMP(psdtReq, timeout: 3.0) {
                RadioLog.xprtest.debug("   Response: \(response.hex)")
                analyzeResponse(response)
            } else {
                RadioLog.xprtest.info("   No response")
            }

        case .enterProgramModeFailed(let code):
            RadioLog.xprtest.error("   ✗ Enter programming mode failed: 0x\(String(format: "%02X", code))")
        case .readRadioKeyFailed(let code):
            RadioLog.xprtest.error("   ✗ Read radio key failed: 0x\(String(format: "%02X", code))")
        case .unlockSecurityFailed(let code):
            RadioLog.xprtest.error("   ✗ Unlock security failed: 0x\(String(format: "%02X", code))")
        case .unlockPartitionFailed(let code):
            RadioLog.xprtest.error("   ✗ Unlock partition failed: 0x\(String(format: "%02X", code))")
        case .notAuthenticated:
            RadioLog.xprtest.error("   ✗ Not authenticated")
        case .timeout:
            RadioLog.xprtest.error("   ✗ Timeout")
        }

        // Skip the old PSDT test since we do it inside the init block now
        RadioLog.xprtest.debug("-- Skipping standalone PSDT test (done above) --")

        // Test 6: Component Session Start
        RadioLog.xprtest.info("6. Component Session Start (Opcode 0x010F)")
        let sessionID: UInt16 = 0x1234
        var sessionReq = Data([0x01, 0x0F])  // opcode
        sessionReq.append(0x02)  // actions: startSession
        sessionReq.append(0x02)  // second byte of actions
        sessionReq.append(UInt8(sessionID >> 8))
        sessionReq.append(UInt8(sessionID & 0xFF))
        RadioLog.xprtest.debug("   Sending: \(sessionReq.hex)")
        if let response = try? await connection.sendXCMP(sessionReq, timeout: 3.0) {
            RadioLog.xprtest.debug("   Response: \(response.hex)")
            analyzeResponse(response)
        } else {
            RadioLog.xprtest.info("   No response")
        }

        // Test 7: Module Info Request (simple)
        RadioLog.xprtest.info("7. Module Info Request (Opcode 0x0461)")
        let moduleReq = Data([0x04, 0x61])
        RadioLog.xprtest.debug("   Sending: \(moduleReq.hex)")
        if let response = try? await connection.sendXCMP(moduleReq, timeout: 3.0) {
            RadioLog.xprtest.debug("   Response: \(response.hex)")
            analyzeResponse(response)
        } else {
            RadioLog.xprtest.info("   No response")
        }

        // Test 8: Try CPS Unlock
        RadioLog.xprtest.info("8. CPS Unlock Request (Opcode 0x0100)")
        let unlockReq = Data([0x01, 0x00])
        RadioLog.xprtest.debug("   Sending: \(unlockReq.hex)")
        if let response = try? await connection.sendXCMP(unlockReq, timeout: 3.0) {
            RadioLog.xprtest.debug("   Response: \(response.hex)")
            analyzeResponse(response)
        } else {
            RadioLog.xprtest.info("   No response")
        }

        // Test 9: Clone Read (channel 0)
        RadioLog.xprtest.info("9. Clone Read Request (Opcode 0x010A)")
        var cloneReq = Data([0x01, 0x0A])  // opcode
        // Zone index type + zone number
        cloneReq.append(contentsOf: [0x80, 0x01, 0x00, 0x00])
        // Channel index type + channel number
        cloneReq.append(contentsOf: [0x80, 0x02, 0x00, 0x00])
        // Data type (channel name)
        cloneReq.append(contentsOf: [0x00, 0x0F])
        RadioLog.xprtest.debug("   Sending: \(cloneReq.hex)")
        if let response = try? await connection.sendXCMP(cloneReq, timeout: 3.0) {
            RadioLog.xprtest.debug("   Response: \(response.hex)")
            analyzeResponse(response)
        } else {
            RadioLog.xprtest.info("   No response")
        }

        // Test 10: Check if we need to wait longer after auth
        RadioLog.xprtest.info("10. Waiting 2 seconds then retry RadioStatusRequest...")
        try? await Task.sleep(for: .seconds(2))
        if let response = try? await connection.sendXCMP(modelReq, timeout: 5.0) {
            RadioLog.xprtest.debug("    Response: \(response.hex)")
            analyzeResponse(response)
        } else {
            RadioLog.xprtest.info("    Still no response")
        }

        RadioLog.xprtest.debug("\(String(repeating: "-", count: 50))")
        RadioLog.xprtest.debug("[DEBUG] Test complete")
    }

    static func analyzeResponse(_ data: Data) {
        if data.count >= 2 {
            let opcode = UInt16(data[0]) << 8 | UInt16(data[1])
            RadioLog.xprtest.debug("   Opcode: 0x\(String(format: "%04X", opcode))")

            // Check if it's a reply (high bit set)
            if opcode & 0x8000 != 0 {
                RadioLog.xprtest.debug("   Type: Reply")
            } else if opcode & 0xB000 == 0xB000 {
                RadioLog.xprtest.debug("   Type: Broadcast")
            } else {
                RadioLog.xprtest.debug("   Type: Request")
            }

            if data.count > 2 {
                let payload = Data(data.dropFirst(2))
                RadioLog.xprtest.debug("   Payload (\(payload.count) bytes): \(payload.hex)")

                // Check for error code
                if !payload.isEmpty {
                    let errorCode = payload[0]
                    if errorCode == 0x00 {
                        RadioLog.xprtest.debug("   Status: Success")
                    } else {
                        RadioLog.xprtest.debug("   Status: Error code 0x\(String(format: "%02X", errorCode))")
                    }
                }
            }
        }
    }
}
