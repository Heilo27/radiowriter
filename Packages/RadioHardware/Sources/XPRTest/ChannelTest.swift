import Foundation
import RadioProgrammer

/// Test the new indexed channel reading functionality
struct ChannelTest {

    static func run(host: String) async {
        RadioLog.xprtest.info("\n\(String(repeating: "═", count: 60))")
        RadioLog.xprtest.info("  CHANNEL READING TEST (Record 0x0FFB)")
        RadioLog.xprtest.info("\(String(repeating: "═", count: 60))")

        let connection = XNLConnection(host: host)
        let result = await connection.connect(debug: false)

        switch result {
        case .success(let addr):
            RadioLog.xprtest.info("✓ Connected - XNL Address: 0x\(String(format: "%04X", addr))")

            let client = XCMPClient(xnlConnection: connection)

            // Step 1: Get channel count
            RadioLog.xprtest.info("[1] Querying channel count...")
            do {
                if let count = try await client.getChannelCount(debug: true) {
                    RadioLog.xprtest.info("✓ Channel count: \(count)")

                    // Step 2: Read channels one at a time to find valid ones
                    if count > 0 {
                        RadioLog.xprtest.info("[2] Reading channels one at a time (up to 35)...")
                        var allChannels: [ParsedChannelRecord] = []

                        for idx in 0..<min(count, 35) {
                            let channels = try await client.readChannelRecords(indices: [UInt8(idx)], debug: false)
                            if let channel = channels.first {
                                allChannels.append(channel)
                                RadioLog.xprtest.debug("  [\(idx)] \"\(channel.name)\" @ \(String(format: "%.4f", channel.rxFrequencyMHz)) MHz")
                            }
                        }

                        let channels = allChannels

                        RadioLog.xprtest.info("\(String(repeating: "-", count: 50))")
                        RadioLog.xprtest.info("CHANNELS FOUND: \(channels.count)")
                        RadioLog.xprtest.info("\(String(repeating: "-", count: 50))")

                        for channel in channels {
                            let rxMHz = String(format: "%.5f", channel.rxFrequencyMHz)
                            let txMHz = String(format: "%.5f", channel.txFrequencyMHz)
                            let mode = channel.isDigital ? "Digital (DMR)" : "Analog"
                            let power = channel.highPower ? "High" : "Low"

                            RadioLog.xprtest.info("  [\(channel.index)] \"\(channel.name)\"")
                            RadioLog.xprtest.info("      Mode: \(mode)")
                            RadioLog.xprtest.info("      RX: \(rxMHz) MHz, TX: \(txMHz) MHz")

                            // Show TX offset for repeater channels
                            if abs(channel.txOffsetMHz) > 0.001 {
                                let offset = String(format: "%+.3f", channel.txOffsetMHz)
                                RadioLog.xprtest.info("      TX Offset: \(offset) MHz")
                            }

                            // Show mode-specific settings
                            if channel.isDigital {
                                RadioLog.xprtest.info("      DMR: Color Code \(channel.colorCode), Timeslot \(channel.timeslot)")
                            } else {
                                // Show CTCSS tones for analog
                                if channel.rxCTCSSHz > 0 || channel.txCTCSSHz > 0 {
                                    let rxTone = channel.rxCTCSSHz > 0 ? String(format: "%.1f Hz", channel.rxCTCSSHz) : "None"
                                    let txTone = channel.txCTCSSHz > 0 ? String(format: "%.1f Hz", channel.txCTCSSHz) : "None"
                                    RadioLog.xprtest.info("      CTCSS: RX \(rxTone), TX \(txTone)")
                                }
                            }

                            RadioLog.xprtest.info("      Power: \(power)")
                        }
                    }
                } else {
                    RadioLog.xprtest.error("✗ Failed to get channel count")

                    // Try direct read anyway
                    RadioLog.xprtest.info("[FALLBACK] Trying direct channel read...")
                    let channels = try await client.readChannelRecords(indices: [0, 1, 2, 3, 4], debug: true)
                    RadioLog.xprtest.info("Got \(channels.count) channels from direct read")
                    for channel in channels {
                        RadioLog.xprtest.info("  [\(channel.index)] \"\(channel.name)\"")
                    }
                }
            } catch {
                RadioLog.xprtest.error("✗ Error: \(error.localizedDescription)")
            }

        case .authenticationFailed(let code):
            RadioLog.xprtest.error("✗ Auth failed: 0x\(String(format: "%02X", code))")

        case .connectionError(let msg):
            RadioLog.xprtest.error("✗ Connection error: \(msg)")

        case .timeout:
            RadioLog.xprtest.error("✗ Timeout")
        }

        await connection.disconnect()
        RadioLog.xprtest.info("\(String(repeating: "═", count: 60))")
    }
}
