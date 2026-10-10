import XCTest
@testable import RadioModelCore

/// Verifies that a radio-read ParsedCodeplug survives a full save/reopen cycle
/// losslessly. This is the regression guard for the P0 data-loss bug where saving
/// a read codeplug wrote an empty rawData and lost all channel/zone/contact data.
final class ParsedCodeplugRoundTripTests: XCTestCase {

    private func makeSampleCodeplug() -> ParsedCodeplug {
        var cp = ParsedCodeplug()
        cp.modelNumber = "AAM27JQC9JA1AN"
        cp.serialNumber = "123TEST456"
        cp.radioID = 4242
        cp.radioAlias = "Test Radio"
        cp.voxEnabled = true

        // Zone 1 with two channels
        var zone1 = ParsedZone(name: "Ops", position: 0)
        var ch1 = ChannelData(zoneIndex: 0, channelIndex: 0)
        ch1.name = "Repeater 1"
        ch1.rxFrequencyHz = 145_500_000
        ch1.txFrequencyHz = 145_500_000
        ch1.isDigital = true
        ch1.timeSlot = 2
        ch1.colorCode = 3
        var ch2 = ChannelData(zoneIndex: 0, channelIndex: 1)
        ch2.name = "Simplex"
        ch2.rxFrequencyHz = 446_000_000
        ch2.txFrequencyHz = 446_000_000
        ch2.isDigital = false
        ch2.txCTCSSHz = 100.0
        zone1.channels = [ch1, ch2]

        // Zone 2 with one channel
        var zone2 = ParsedZone(name: "Simplex Zone", position: 1)
        var ch3 = ChannelData(zoneIndex: 1, channelIndex: 0)
        ch3.name = "Calling"
        ch3.rxFrequencyHz = 446_500_000
        ch3.txFrequencyHz = 446_500_000
        zone2.channels = [ch3]

        cp.zones = [zone1, zone2]

        // Contacts
        cp.contacts = [
            ParsedContact(name: "All Call", dmrID: 16_777_215, type: .allCall),
            ParsedContact(name: "Dispatch", dmrID: 1001, type: .group),
        ]

        // Button assignment (enum round-trip)
        cp.topButtonShortPress = .scan
        cp.sideButton1LongPress = .emergency

        return cp
    }

    /// Encoding then decoding the parsed graph directly must be lossless.
    func testCodableRoundTripIsLossless() throws {
        let original = makeSampleCodeplug()
        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(ParsedCodeplug.self, from: encoded)
        XCTAssertEqual(original, decoded)
    }

    /// The full .cpsx rawData bridge (marker + JSON) must round-trip losslessly and
    /// preserve the key channel/zone/contact fields.
    func testRawDataBridgeRoundTrip() throws {
        let original = makeSampleCodeplug()

        // Encode to the rawData blob (as saveDocument does).
        let rawData = try original.encodedRawData()
        XCTAssertTrue(ParsedCodeplug.isParsedRawData(rawData))

        // Decode back (as openDocument does).
        let decoded = try XCTUnwrap(ParsedCodeplug.decoded(fromRawData: rawData))

        XCTAssertEqual(decoded, original)

        // Spot-check the key fields explicitly.
        XCTAssertEqual(decoded.zones.count, 2)
        XCTAssertEqual(decoded.totalChannels, 3)
        XCTAssertEqual(decoded.zones[0].name, "Ops")
        XCTAssertEqual(decoded.zones[0].channels[0].name, "Repeater 1")
        XCTAssertEqual(decoded.zones[0].channels[0].rxFrequencyHz, 145_500_000)
        XCTAssertEqual(decoded.zones[0].channels[0].timeSlot, 2)
        XCTAssertEqual(decoded.zones[0].channels[0].colorCode, 3)
        XCTAssertEqual(decoded.zones[0].channels[1].isDigital, false)
        XCTAssertEqual(decoded.zones[0].channels[1].txCTCSSHz, 100.0)
        XCTAssertEqual(decoded.zones[1].channels[0].name, "Calling")
        XCTAssertEqual(decoded.contacts.count, 2)
        XCTAssertEqual(decoded.contacts[0].contactType, .allCall)
        XCTAssertEqual(decoded.contacts[1].dmrID, 1001)
        XCTAssertEqual(decoded.radioID, 4242)
        XCTAssertEqual(decoded.topButtonShortPress, .scan)
        XCTAssertEqual(decoded.sideButton1LongPress, .emergency)
    }

    /// A non-parsed (binary) rawData blob must NOT be mistaken for a parsed codeplug.
    func testBinaryRawDataIsNotMisdetected() throws {
        let binary = Data([0x00, 0x01, 0x02, 0x03, 0xFF])
        XCTAssertFalse(ParsedCodeplug.isParsedRawData(binary))
        XCTAssertNil(try ParsedCodeplug.decoded(fromRawData: binary))
    }
}
