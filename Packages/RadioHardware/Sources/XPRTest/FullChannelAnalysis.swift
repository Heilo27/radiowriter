import Foundation
import RadioProgrammer

/// Full analysis of channel record structure
struct FullChannelAnalysis {

    static func run(host: String) async {
        print("\n" + String(repeating: "═", count: 70))
        print("  FULL CHANNEL RECORD ANALYSIS")
        print(String(repeating: "═", count: 70))
        print()

        let connection = XNLConnection(host: host)
        let result = await connection.connect(debug: false)

        guard case .success = result else {
            print("✗ Connection failed")
            return
        }

        print("✓ Connected\n")
        let client = XCMPClient(xnlConnection: connection)

        // Read different types of channels for comparison
        // Channel 0: OPERATIONS (DMR)
        // Channel 3: W4RAT Rpt (Repeater with offset)
        // Channel 4: FRS01 (Analog simplex)
        let channelsToAnalyze = [0, 3, 4]

        for idx in channelsToAnalyze {
            do {
                let channels = try await client.readChannelRecords(indices: [UInt8(idx)], debug: false)
                if let channel = channels.first, !channel.rawData.isEmpty {
                    print(String(repeating: "─", count: 70))
                    print("CHANNEL \(idx): \"\(channel.name)\"")
                    print(String(repeating: "─", count: 70))
                    analyzeChannelRecord(channel.rawData)
                    print()
                }
            } catch {
                print("Error reading channel \(idx): \(error)")
            }
        }

        await connection.disconnect()
        print(String(repeating: "═", count: 70))
    }

    static func analyzeChannelRecord(_ data: Data) {
        guard data.count >= 324 else {
            print("  Record too short: \(data.count) bytes")
            return
        }

        // Print full hex dump first
        print("\nFull hex dump (324 bytes):")
        for row in 0..<(324 / 16 + 1) {
            let offset = row * 16
            if offset >= data.count { break }
            let end = min(offset + 16, data.count)
            var hexParts: [String] = []
            var asciiParts: [String] = []
            for i in offset..<end {
                hexParts.append(String(format: "%02X", data[i]))
                let byte = data[i]
                asciiParts.append((0x20...0x7E).contains(byte) ? String(UnicodeScalar(byte)) : ".")
            }
            let hex = hexParts.joined(separator: " ")
            let ascii = asciiParts.joined()
            print("  \(String(format: "%04X", offset)): \(hex.padding(toLength: 48, withPad: " ", startingAt: 0))  \(ascii)")
        }

        print("\n" + String(repeating: "─", count: 50))
        print("PARSED FIELDS:")
        print(String(repeating: "─", count: 50))

        // Known fields
        let flags1 = readUInt16LE(data, 0x00)
        let flags2 = readUInt16LE(data, 0x02)
        print(String(format: "0x00-0x03: Flags: 0x%04X 0x%04X", flags1, flags2))

        let byte08 = data[0x08]
        let byte09 = data[0x09]
        print(String(format: "0x08-0x09: Unknown: 0x%02X 0x%02X", byte08, byte09))

        // Check for channel mode indicator
        let channelMode = data[0x0E]
        let modeStr = channelMode == 0x01 ? "Digital (DMR)" : (channelMode == 0x00 ? "Analog" : "Unknown(\(channelMode))")
        print(String(format: "0x0E: Channel Mode: 0x%02X (%@)", channelMode, modeStr))

        // Bandwidth/Power area
        let byte18 = data[0x18]
        let byte19 = data[0x19]
        let byte1A = data[0x1A]
        let byte1B = data[0x1B]
        print(String(format: "0x18-0x1B: Config: 0x%02X 0x%02X 0x%02X 0x%02X", byte18, byte19, byte1A, byte1B))

        // Color code for DMR
        if channelMode == 0x01 {
            print(String(format: "  → Color Code: %d (0x%02X)", byte18, byte18))
        }

        // Frequencies (verified)
        let rxFreq5Hz = readUInt32LE(data, 0x24)
        let txFreq5Hz = readUInt32LE(data, 0x28)
        let rxMHz = Double(rxFreq5Hz) * 5.0 / 1_000_000.0
        let txMHz = Double(txFreq5Hz) * 5.0 / 1_000_000.0
        print(String(format: "0x24-0x27: RX Freq: %d (%.5f MHz)", rxFreq5Hz, rxMHz))
        print(String(format: "0x28-0x2B: TX Freq: %d (%.5f MHz)", txFreq5Hz, txMHz))

        if rxMHz != txMHz {
            let offset = txMHz - rxMHz
            print(String(format: "  → TX Offset: %+.4f MHz", offset))
        }

        // Bytes around frequencies
        let byte2C = readUInt16LE(data, 0x2C)
        let byte2E = readUInt16LE(data, 0x2E)
        let byte30 = readUInt16LE(data, 0x30)
        let byte32 = readUInt16LE(data, 0x32)
        print(String(format: "0x2C-0x33: Post-freq: 0x%04X 0x%04X 0x%04X 0x%04X", byte2C, byte2E, byte30, byte32))

        // CTCSS/DCS area for analog channels
        if channelMode == 0x00 {
            // Look for CTCSS tones
            let possibleRxTone = readUInt16LE(data, 0x30)
            let possibleTxTone = readUInt16LE(data, 0x32)
            if possibleRxTone > 0 && possibleRxTone < 3000 {
                print(String(format: "  → Possible RX Tone: %.1f Hz", Double(possibleRxTone) / 10.0))
            }
            if possibleTxTone > 0 && possibleTxTone < 3000 {
                print(String(format: "  → Possible TX Tone: %.1f Hz", Double(possibleTxTone) / 10.0))
            }
        }

        // Pre-name area
        let byte34 = data[0x34]
        let byte35 = data[0x35]
        let byte36 = data[0x36]
        let byte37 = data[0x37]
        let byte38 = data[0x38]
        let byte39 = data[0x39]
        let byte3A = data[0x3A]
        let byte3B = data[0x3B]
        print(String(format: "0x34-0x3B: Pre-name: %02X %02X %02X %02X %02X %02X %02X %02X",
                     byte34, byte35, byte36, byte37, byte38, byte39, byte3A, byte3B))

        // Channel name (verified at 0x3C)
        let nameData = data[0x3C..<min(0x5C, data.count)]
        if let name = String(data: Data(nameData), encoding: .utf16LittleEndian)?
            .trimmingCharacters(in: CharacterSet(["\0"])) {
            print(String(format: "0x3C-0x5B: Name: \"%@\"", name))
        }

        // Post-name area
        print("0x5C-0x6F: Post-name config:")
        for offset in stride(from: 0x5C, to: min(0x70, data.count), by: 4) {
            let val = readUInt32LE(data, offset)
            if val != 0 && val != 0xFFFFFFFF {
                print(String(format: "  0x%02X: 0x%08X (%d)", offset, val, val))
            }
        }

        // Scan list / contact references
        let byte70 = data[0x70]
        let byte71 = data[0x71]
        let byte72 = data[0x72]
        let byte73 = data[0x73]
        print(String(format: "0x70-0x73: References: 0x%02X 0x%02X 0x%02X 0x%02X", byte70, byte71, byte72, byte73))

        // Contact ID for DMR
        if channelMode == 0x01 {
            let contactID = readUInt32LE(data, 0x74)
            if contactID > 0 && contactID < 0xFFFFFF {
                print(String(format: "0x74-0x77: Contact ID: %d", contactID))
            }
        }

        // Power level indicator
        let powerByte = data[0x77]
        let powerStr = powerByte == 0x00 ? "Low" : (powerByte == 0x01 ? "High" : "Unknown(\(powerByte))")
        if data[0x77] != 0 || data[0x76] != 0 {
            print(String(format: "0x76-0x77: Power: 0x%02X 0x%02X (%@)", data[0x76], data[0x77], powerStr))
        }

        // Look for TOT (timeout timer)
        let possibleTOT = readUInt16LE(data, 0x78)
        if possibleTOT > 0 && possibleTOT <= 600 {
            print(String(format: "0x78-0x79: Possible TOT: %d seconds", possibleTOT))
        }

        // RX Group List
        let rxGroupByte = data[0x7A]
        if rxGroupByte > 0 && rxGroupByte < 0xFF {
            print(String(format: "0x7A: RX Group List Index: %d", rxGroupByte))
        }

        // Scan list reference
        let scanListByte = data[0x7B]
        if scanListByte > 0 && scanListByte < 0xFF {
            print(String(format: "0x7B: Scan List Index: %d", scanListByte))
        }

        // Check later bytes for more settings
        print("\nAdditional non-zero fields:")
        for offset in stride(from: 0x80, to: min(0x144, data.count), by: 2) {
            let val = readUInt16LE(data, offset)
            if val != 0 && val != 0xFFFF {
                print(String(format: "  0x%02X: 0x%04X (%d)", offset, val, val))
            }
        }
    }

    static func readUInt16LE(_ data: Data, _ offset: Int) -> UInt16 {
        guard offset + 1 < data.count else { return 0 }
        return UInt16(data[offset]) | (UInt16(data[offset + 1]) << 8)
    }

    static func readUInt32LE(_ data: Data, _ offset: Int) -> UInt32 {
        guard offset + 3 < data.count else { return 0 }
        return UInt32(data[offset]) |
               (UInt32(data[offset + 1]) << 8) |
               (UInt32(data[offset + 2]) << 16) |
               (UInt32(data[offset + 3]) << 24)
    }
}
