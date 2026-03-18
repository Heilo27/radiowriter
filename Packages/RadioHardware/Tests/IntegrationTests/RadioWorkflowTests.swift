import Testing
import Foundation
@testable import USBTransport
@testable import RadioProgrammer
import RadioCore

// MARK: - Protocol Response Helpers

/// Queues all mock responses needed for a complete codeplug read via RadioProgrammer.
///
/// RadioProgrammer protocol sequence:
///   1. enterProgrammingMode: send 0x02, expect ACK 0x06
///   2. readBlock × N: send R+offset+len, expect len bytes + 1-byte checksum
///   3. exitProgrammingMode: send 0x45 (no response)
private func queueReadResponses(for connection: MockConnection, data: Data) async {
    let blockSize = 64
    let totalBlocks = (data.count + blockSize - 1) / blockSize

    await connection.queueResponse(Data([0x06])) // ACK: enterProgrammingMode

    for block in 0..<totalBlocks {
        let offset = block * blockSize
        let end = min(offset + blockSize, data.count)
        let blockSlice = data[offset..<end]
        let checksum = blockSlice.reduce(UInt8(0), &+)
        var response = Data(blockSlice)
        response.append(checksum)
        await connection.queueResponse(response)
    }
    // exitProgrammingMode sends only — no response queued
}

/// Queues ACK responses needed for a complete codeplug write via RadioProgrammer.
///
/// RadioProgrammer protocol sequence:
///   1. enterProgrammingMode: send 0x02, expect ACK 0x06
///   2. writeBlock × N: send W+offset+len+data+cksum, expect ACK 0x06
///   3. exitProgrammingMode: send 0x45 (no response)
private func queueWriteAcks(for connection: MockConnection, dataSize: Int) async {
    let blockSize = 64
    let totalBlocks = (dataSize + blockSize - 1) / blockSize

    await connection.queueResponse(Data([0x06])) // ACK: enterProgrammingMode
    for _ in 0..<totalBlocks {
        await connection.queueResponse(Data([0x06])) // ACK: each writeBlock
    }
    // exitProgrammingMode sends only — no response queued
}

/// Creates repeatable test codeplug data with a known byte pattern.
private func makeTestCodeplug(size: Int, seed: UInt8 = 0xAB) -> Data {
    var data = Data(count: size)
    for i in 0..<size {
        data[i] = seed &+ UInt8(i & 0xFF)
    }
    return data
}

// MARK: - Integration Tests

@Suite("Radio Programming Integration Tests")
struct RadioWorkflowTests {

    // MARK: Test 1: Read codeplug from mock radio

    @Test("Read codeplug from mock radio — full data fidelity")
    func testReadCodeplugWorkflow() async throws {
        let expectedData = makeTestCodeplug(size: 128, seed: 0xAB)

        let connection = MockConnection()
        try await connection.connect()
        await queueReadResponses(for: connection, data: expectedData)

        let programmer = RadioProgrammer(connection: connection)

        let readData = try await programmer.readCodeplug(size: 128)

        // Data fidelity: every byte must match
        #expect(readData == expectedData)

        // Programmer returns to idle after successful read
        let state = await programmer.currentState
        if case .idle = state { /* pass */ } else {
            Issue.record("Expected .idle after read, got \(state)")
        }
    }

    // MARK: Test 2: Edit → Write → Read back → Verify round-trip

    @Test("Edit codeplug, write to radio, read back, verify round-trip fidelity")
    func testWriteReadRoundTrip() async throws {
        let original = makeTestCodeplug(size: 128, seed: 0x11)

        // Simulate a field edit: invert every other byte
        var edited = original
        for i in stride(from: 0, to: edited.count, by: 2) {
            edited[i] ^= 0xFF
        }

        let connection = MockConnection()
        try await connection.connect()

        // Queue write ACKs, then read responses for the edited data
        await queueWriteAcks(for: connection, dataSize: edited.count)
        await queueReadResponses(for: connection, data: edited)

        let programmer = RadioProgrammer(connection: connection)

        try await programmer.writeCodeplug(edited)
        let readBack = try await programmer.readCodeplug(size: edited.count)

        // Round-trip must preserve every byte
        #expect(readBack == edited)
        // Edited data must differ from original to confirm the edit was applied
        #expect(readBack != original)
    }

    // MARK: Test 3: Merge channel data into codeplug, validate, write to radio

    @Test("Merge channel fields into codeplug, validate constraints, write to radio")
    func testCodeplugMergeAndProgramRadio() async throws {
        // Simulate a codeplug as it would exist after loading from radio or file
        let codeplug = Codeplug(modelIdentifier: "XPR7550", size: 128)

        // Channel name field (8 chars, UTF-8 encoded at bit 0)
        let channelNameField = FieldDefinition(
            id: "ch.0.name",
            name: "channelName",
            displayName: "Channel Name",
            category: .general,
            valueType: .string(maxLength: 8, encoding: .utf8),
            bitOffset: 0,
            bitLength: 64,
            defaultValue: .string("")
        )

        // TX power field (uint8 at bit 72, 0=Low … 3=Turbo)
        let txPowerField = FieldDefinition(
            id: "ch.0.power",
            name: "txPower",
            displayName: "TX Power",
            category: .general,
            valueType: .uint8,
            bitOffset: 72,
            bitLength: 8,
            defaultValue: .uint8(0),
            constraint: .range(min: 0, max: 3)
        )

        // Simulate merging imported CSV row values into the codeplug
        let nameResult  = codeplug.setValue(.string("Repeater"), for: channelNameField)
        let powerResult = codeplug.setValue(.uint8(2), for: txPowerField)

        // All valid imports must pass constraint validation
        #expect(nameResult.isValid,  "Channel name should satisfy string constraint")
        #expect(powerResult.isValid, "TX power 2 (High) should be in range 0–3")

        // Verify stored values round-trip correctly through the codeplug
        #expect(codeplug.getValue(for: channelNameField) == .string("Repeater"))
        #expect(codeplug.getValue(for: txPowerField) == .uint8(2))

        // Out-of-range import value must be rejected before write
        let invalidPower = codeplug.setValue(.uint8(5), for: txPowerField)
        #expect(!invalidPower.isValid, "TX power 5 exceeds max of 3 and must be rejected")

        // Restore valid power level, then write the validated codeplug to radio
        _ = codeplug.setValue(.uint8(2), for: txPowerField)

        let connection = MockConnection()
        try await connection.connect()
        await queueWriteAcks(for: connection, dataSize: codeplug.rawData.count)

        let programmer = RadioProgrammer(connection: connection)
        try await programmer.writeCodeplug(codeplug.rawData)

        let state = await programmer.currentState
        if case .idle = state { /* pass */ } else {
            Issue.record("Expected .idle after write, got \(state)")
        }

        // Verify the correct block write commands were issued
        let commands = await connection.getSentCommands()
        let writeCommands = commands.filter { $0.first == 0x57 } // 'W'
        let expectedBlocks = (codeplug.rawData.count + 63) / 64
        #expect(writeCommands.count == expectedBlocks)
    }

    // MARK: Test 4: Clone radio (read from source, write to destination, compare)

    @Test("Clone radio — read source, write to destination, verify identical")
    func testCloneWorkflow() async throws {
        let sourceData = makeTestCodeplug(size: 128, seed: 0xCA)

        // Step 1: Read from source radio
        let sourceConnection = MockConnection()
        try await sourceConnection.connect()
        await queueReadResponses(for: sourceConnection, data: sourceData)

        let sourceProgrammer = RadioProgrammer(connection: sourceConnection)
        let clonedData = try await sourceProgrammer.readCodeplug(size: 128)

        #expect(clonedData == sourceData, "Cloned data must match source exactly")

        // Step 2: Write to destination radio
        let destConnection = MockConnection()
        try await destConnection.connect()
        await queueWriteAcks(for: destConnection, dataSize: clonedData.count)

        let destProgrammer = RadioProgrammer(connection: destConnection)
        try await destProgrammer.writeCodeplug(clonedData)

        // Verify destination received the correct protocol commands
        let sentCommands = await destConnection.getSentCommands()
        #expect(sentCommands.first?.first == 0x02, "First command: enter programming mode (0x02)")
        #expect(sentCommands.last?.first  == 0x45, "Last command: exit programming mode (0x45)")

        let writeCommands = sentCommands.filter { $0.first == 0x57 } // 'W'
        #expect(writeCommands.count == 2, "128 bytes / 64-byte blocks = 2 write commands")

        // State on both programmers should be idle
        let srcState  = await sourceProgrammer.currentState
        let destState = await destProgrammer.currentState
        if case .idle = srcState  { /* pass */ } else { Issue.record("Source not idle") }
        if case .idle = destState { /* pass */ } else { Issue.record("Dest not idle") }
    }

    // MARK: Test 5: Write failure recovery (partial write, retry)

    @Test("Write failure recovery — NAK on first block, retry succeeds")
    func testWriteFailureAndRetry() async throws {
        let codeplugData = makeTestCodeplug(size: 64, seed: 0xBB)

        let connection = MockConnection()
        try await connection.connect()

        // First attempt: ACK for enter, NAK (0x07) for first writeBlock
        await connection.queueResponse(Data([0x06])) // enterProgrammingMode ACK
        await connection.queueResponse(Data([0x07])) // writeBlock NAK → rejected

        let programmer = RadioProgrammer(connection: connection)

        // First write must throw writeRejected at offset 0
        var didThrowRejected = false
        do {
            try await programmer.writeCodeplug(codeplugData)
            Issue.record("First write should have thrown ProgrammerError.writeRejected")
        } catch ProgrammerError.writeRejected(let offset) {
            didThrowRejected = true
            #expect(offset == 0, "Write was rejected at the first block (offset 0)")
        } catch {
            Issue.record("Unexpected error during first write attempt: \(error)")
        }
        #expect(didThrowRejected)

        // Reset mock state and queue valid responses for retry
        await connection.reset()
        await connection.queueResponse(Data([0x06])) // enterProgrammingMode ACK
        await connection.queueResponse(Data([0x06])) // writeBlock ACK (64 bytes = 1 block)

        // Retry must succeed
        try await programmer.writeCodeplug(codeplugData)

        let stateAfterRetry = await programmer.currentState
        if case .idle = stateAfterRetry { /* pass */ } else {
            Issue.record("Expected .idle after successful retry, got \(stateAfterRetry)")
        }

        // Only retry commands should be present (reset cleared the first attempt)
        let commands = await connection.getSentCommands()
        #expect(commands.first?.first == 0x02, "Retry starts with enter programming mode")
        #expect(commands.last?.first  == 0x45, "Retry ends with exit programming mode")
    }

    // MARK: Edge case: bad checksum triggers checksumError

    @Test("Read with corrupted checksum throws checksumError")
    func testChecksumError() async throws {
        let connection = MockConnection()
        try await connection.connect()

        // ACK for enterProgrammingMode
        await connection.queueResponse(Data([0x06]))

        // Block response: 64 zero bytes + deliberately wrong checksum (should be 0x00)
        var badResponse = Data(count: 65)
        badResponse[64] = 0xFF // correct checksum for all-zeros is 0x00
        await connection.queueResponse(badResponse)

        let programmer = RadioProgrammer(connection: connection)

        var didThrowChecksumError = false
        do {
            _ = try await programmer.readCodeplug(size: 64)
            Issue.record("Should have thrown ProgrammerError.checksumError")
        } catch ProgrammerError.checksumError(let offset) {
            didThrowChecksumError = true
            #expect(offset == 0, "Checksum error should report offset 0")
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
        #expect(didThrowChecksumError)
    }
}
