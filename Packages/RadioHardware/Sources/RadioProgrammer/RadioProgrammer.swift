import Foundation
import RadioCore
import USBTransport

/// Handles the radio programming protocol — reading, writing, and cloning codeplugs.
public actor RadioProgrammer {
    private let connection: any USBConnection
    private var state: ProgrammerState = .idle

    public init(connection: any USBConnection) {
        self.connection = connection
    }

    /// Current programmer state.
    public var currentState: ProgrammerState { state }

    // MARK: - Read Radio

    /// Reads the complete codeplug from a connected radio.
    public func readCodeplug(
        size: Int,
        progress: @Sendable (Double) -> Void = { _ in }
    ) async throws -> Data {
        guard await connection.isConnected else {
            throw ProgrammerError.notConnected
        }

        state = .reading

        // Enter programming mode
        try await enterProgrammingMode()

        // Read codeplug in blocks
        let blockSize = 64
        var codeplugData = Data(capacity: size)
        let totalBlocks = (size + blockSize - 1) / blockSize

        for block in 0..<totalBlocks {
            let offset = block * blockSize
            let remaining = min(blockSize, size - offset)
            let data = try await readBlock(offset: offset, length: remaining)
            codeplugData.append(data)
            progress(Double(block + 1) / Double(totalBlocks))
        }

        // Exit programming mode
        try await exitProgrammingMode()

        state = .idle
        return codeplugData
    }

    // MARK: - Write Radio

    /// Writes a codeplug to the connected radio.
    public func writeCodeplug(
        _ data: Data,
        progress: @Sendable (Double) -> Void = { _ in }
    ) async throws {
        guard await connection.isConnected else {
            throw ProgrammerError.notConnected
        }

        state = .writing

        // Enter programming mode
        try await enterProgrammingMode()

        // Write codeplug in blocks
        let blockSize = 64
        let totalBlocks = (data.count + blockSize - 1) / blockSize

        for block in 0..<totalBlocks {
            let offset = block * blockSize
            let end = min(offset + blockSize, data.count)
            let blockData = data[offset..<end]
            try await writeBlock(offset: offset, data: Data(blockData))
            progress(Double(block + 1) / Double(totalBlocks))
        }

        // Exit programming mode
        try await exitProgrammingMode()

        state = .idle
    }

    // MARK: - Verify

    /// Reads back the codeplug and compares with expected data.
    public func verifyCodeplug(
        expected: Data,
        progress: @Sendable (Double) -> Void = { _ in }
    ) async throws -> Bool {
        let actual = try await readCodeplug(size: expected.count, progress: progress)
        return actual == expected
    }

    // MARK: - Protocol Commands

    private func enterProgrammingMode() async throws {
        // Send programming mode entry command
        // Protocol: 0x02 (STX) followed by model query
        let enterCmd = Data([0x02])
        let response = try await connection.sendCommand(enterCmd, responseLength: 1, timeout: 3.0)
        guard response.first == 0x06 else { // ACK
            throw ProgrammerError.protocolError("Radio did not acknowledge programming mode")
        }
    }

    private func exitProgrammingMode() async throws {
        // Send programming mode exit command
        let exitCmd = Data([0x45]) // 'E' for exit
        try await connection.send(exitCmd)
        try await Task.sleep(for: .milliseconds(100))
    }

    private func readBlock(offset: Int, length: Int) async throws -> Data {
        // Read command: 'R' + 2-byte offset + 1-byte length
        var cmd = Data([0x52]) // 'R'
        cmd.append(UInt8(offset >> 8))
        cmd.append(UInt8(offset & 0xFF))
        cmd.append(UInt8(length))

        let response = try await connection.sendCommand(cmd, responseLength: length + 1, timeout: 2.0)

        // Verify checksum (last byte)
        let payload = response.prefix(length)
        let checksum = response.last ?? 0
        let calculated = payload.reduce(UInt8(0), &+)
        guard checksum == calculated else {
            throw ProgrammerError.checksumError(offset: offset)
        }

        return Data(payload)
    }

    private func writeBlock(offset: Int, data: Data) async throws {
        // Write command: 'W' + 2-byte offset + 1-byte length + data + checksum
        var cmd = Data([0x57]) // 'W'
        cmd.append(UInt8(offset >> 8))
        cmd.append(UInt8(offset & 0xFF))
        cmd.append(UInt8(data.count))
        cmd.append(data)
        cmd.append(data.reduce(UInt8(0), &+)) // checksum

        let response = try await connection.sendCommand(cmd, responseLength: 1, timeout: 2.0)
        guard response.first == 0x06 else { // ACK
            throw ProgrammerError.writeRejected(offset: offset)
        }
    }
}

/// Programming operation state.
public enum ProgrammerState: Sendable {
    case idle
    case reading
    case writing
    case verifying
    case error(String)
}

/// Errors during radio programming.
public enum ProgrammerError: Error, LocalizedError {
    case notConnected
    case protocolError(String)
    case checksumError(offset: Int)
    case writeRejected(offset: Int)
    case verificationFailed
    case timeout

    public var errorDescription: String? {
        switch self {
        case .notConnected: return "Radio is not connected"
        case .protocolError(let msg): return "Protocol error: \(msg)"
        case .checksumError(let offset): return "Checksum mismatch at offset \(offset)"
        case .writeRejected(let offset): return "Radio rejected write at offset \(offset)"
        case .verificationFailed: return "Verification failed: written data does not match"
        case .timeout: return "Radio did not respond in time"
        }
    }
}
