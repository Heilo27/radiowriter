import Foundation
import RadioProgrammer

/// Test the new indexed channel reading functionality
struct ChannelTest {

    static func run(host: String) async {
        print("\n" + String(repeating: "═", count: 60))
        print("  CHANNEL READING TEST (Record 0x0FFB)")
        print(String(repeating: "═", count: 60))
        print()

        let connection = XNLConnection(host: host)
        let result = await connection.connect(debug: false)

        switch result {
        case .success(let addr):
            print("✓ Connected - XNL Address: 0x\(String(format: "%04X", addr))")

            let client = XCMPClient(xnlConnection: connection)

            // Step 1: Get channel count
            print("\n[1] Querying channel count...")
            do {
                if let count = try await client.getChannelCount(debug: true) {
                    print("✓ Channel count: \(count)")

                    // Step 2: Read channels one at a time to find valid ones
                    if count > 0 {
                        print("\n[2] Reading channels one at a time (up to 35)...")
                        var allChannels: [ParsedChannelRecord] = []

                        for idx in 0..<min(count, 35) {
                            let channels = try await client.readChannelRecords(indices: [UInt8(idx)], debug: false)
                            if let channel = channels.first {
                                allChannels.append(channel)
                                print("  [\(idx)] \"\(channel.name)\" @ \(String(format: "%.4f", channel.rxFrequencyMHz)) MHz")
                            }
                        }

                        let channels = allChannels

                        print("\n" + String(repeating: "-", count: 50))
                        print("CHANNELS FOUND: \(channels.count)")
                        print(String(repeating: "-", count: 50))

                        for channel in channels {
                            let rxMHz = String(format: "%.5f", channel.rxFrequencyMHz)
                            let txMHz = String(format: "%.5f", channel.txFrequencyMHz)
                            let mode = channel.isDigital ? "Digital (DMR)" : "Analog"
                            let power = channel.highPower ? "High" : "Low"

                            print("  [\(channel.index)] \"\(channel.name)\"")
                            print("      Mode: \(mode)")
                            print("      RX: \(rxMHz) MHz, TX: \(txMHz) MHz")

                            // Show TX offset for repeater channels
                            if abs(channel.txOffsetMHz) > 0.001 {
                                let offset = String(format: "%+.3f", channel.txOffsetMHz)
                                print("      TX Offset: \(offset) MHz")
                            }

                            // Show mode-specific settings
                            if channel.isDigital {
                                print("      DMR: Color Code \(channel.colorCode), Timeslot \(channel.timeslot)")
                            } else {
                                // Show CTCSS tones for analog
                                if channel.rxCTCSSHz > 0 || channel.txCTCSSHz > 0 {
                                    let rxTone = channel.rxCTCSSHz > 0 ? String(format: "%.1f Hz", channel.rxCTCSSHz) : "None"
                                    let txTone = channel.txCTCSSHz > 0 ? String(format: "%.1f Hz", channel.txCTCSSHz) : "None"
                                    print("      CTCSS: RX \(rxTone), TX \(txTone)")
                                }
                            }

                            print("      Power: \(power)")
                            print()
                        }
                    }
                } else {
                    print("✗ Failed to get channel count")

                    // Try direct read anyway
                    print("\n[FALLBACK] Trying direct channel read...")
                    let channels = try await client.readChannelRecords(indices: [0, 1, 2, 3, 4], debug: true)
                    print("Got \(channels.count) channels from direct read")
                    for channel in channels {
                        print("  [\(channel.index)] \"\(channel.name)\"")
                    }
                }
            } catch {
                print("✗ Error: \(error)")
            }

        case .authenticationFailed(let code):
            print("✗ Auth failed: 0x\(String(format: "%02X", code))")

        case .connectionError(let msg):
            print("✗ Connection error: \(msg)")

        case .timeout:
            print("✗ Timeout")
        }

        await connection.disconnect()
        print("\n" + String(repeating: "═", count: 60))
    }
}
