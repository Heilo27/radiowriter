import Testing
import Foundation
@testable import USBTransport

@Suite("MockConnection Tests")
struct MockConnectionTests {

    @Test("Connect and disconnect")
    func connectDisconnect() async throws {
        let connection = MockConnection(codeplugSize: 256)
        #expect(await connection.isConnected == false)

        try await connection.connect()
        #expect(await connection.isConnected == true)

        await connection.disconnect()
        #expect(await connection.isConnected == false)
    }

    @Test("Send and receive with queued response")
    func sendReceive() async throws {
        let connection = MockConnection()
        try await connection.connect()

        let response = Data([0x06]) // ACK
        await connection.queueResponse(response)

        let result = try await connection.sendCommand(Data([0x02]), responseLength: 1)
        #expect(result == Data([0x06]))
    }

    @Test("Throws when not connected")
    func throwsWhenDisconnected() async {
        let connection = MockConnection()
        do {
            try await connection.send(Data([0x01]))
            #expect(Bool(false), "Should have thrown")
        } catch {
            #expect(error is USBError)
        }
    }

    @Test("Tracks sent commands")
    func tracksSentCommands() async throws {
        let connection = MockConnection()
        try await connection.connect()

        try await connection.send(Data([0x01, 0x02]))
        try await connection.send(Data([0x03, 0x04]))

        let commands = await connection.getSentCommands()
        #expect(commands.count == 2)
        #expect(commands[0] == Data([0x01, 0x02]))
    }
}
