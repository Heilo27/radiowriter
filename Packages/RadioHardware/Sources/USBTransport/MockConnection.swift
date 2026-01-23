import Foundation

/// A mock USB connection for development and testing without hardware.
public actor MockConnection: USBConnection {
    public var isConnected: Bool = false
    private var responseQueue: [Data] = []
    private var sentCommands: [Data] = []
    private let simulatedCodeplug: Data

    /// Creates a mock connection with optional simulated codeplug data.
    public init(codeplugSize: Int = 256) {
        self.simulatedCodeplug = Data(count: codeplugSize)
    }

    /// Creates a mock connection with specific codeplug data.
    public init(codeplugData: Data) {
        self.simulatedCodeplug = codeplugData
    }

    public func connect() async throws {
        isConnected = true
    }

    public func disconnect() async {
        isConnected = false
    }

    public func send(_ data: Data) async throws {
        guard isConnected else { throw USBError.notConnected }
        sentCommands.append(data)
    }

    public func receive(count: Int, timeout: TimeInterval) async throws -> Data {
        guard isConnected else { throw USBError.notConnected }
        // Simulate small delay
        try await Task.sleep(for: .milliseconds(50))

        if !responseQueue.isEmpty {
            return responseQueue.removeFirst()
        }
        // Return zeros as default response
        return Data(count: count)
    }

    public func sendCommand(_ command: Data, responseLength: Int, timeout: TimeInterval = 5.0) async throws -> Data {
        try await send(command)
        return try await receive(count: responseLength, timeout: timeout)
    }

    // MARK: - Test Helpers

    /// Queues a response to be returned on the next receive call.
    public func queueResponse(_ data: Data) {
        responseQueue.append(data)
    }

    /// Returns all commands sent during this session.
    public func getSentCommands() -> [Data] {
        sentCommands
    }

    /// Resets the mock state.
    public func reset() {
        sentCommands.removeAll()
        responseQueue.removeAll()
    }
}
