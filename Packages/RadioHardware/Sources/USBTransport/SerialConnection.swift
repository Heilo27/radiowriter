import Foundation

/// Serial port connection to a radio via IOKit/POSIX.
/// This is the primary connection method using /dev/cu.usbserial-* devices.
public actor SerialConnection: USBConnection {
    private let portPath: String
    private let baudRate: speed_t
    private var fileDescriptor: Int32 = -1

    public var isConnected: Bool { fileDescriptor >= 0 }

    /// Standard baud rate for Motorola business radios.
    public static let defaultBaudRate: speed_t = 115200

    public init(portPath: String, baudRate: speed_t = SerialConnection.defaultBaudRate) {
        self.portPath = portPath
        self.baudRate = baudRate
    }

    public func connect() async throws {
        let fd = open(portPath, O_RDWR | O_NOCTTY | O_NONBLOCK)
        guard fd >= 0 else {
            throw USBError.connectionFailed("Cannot open \(portPath): \(String(cString: strerror(errno)))")
        }

        // Configure serial port: 8N1, no flow control
        var options = termios()
        tcgetattr(fd, &options)

        cfsetispeed(&options, baudRate)
        cfsetospeed(&options, baudRate)

        // 8 data bits, no parity, 1 stop bit
        options.c_cflag &= ~tcflag_t(PARENB)
        options.c_cflag &= ~tcflag_t(CSTOPB)
        options.c_cflag &= ~tcflag_t(CSIZE)
        options.c_cflag |= tcflag_t(CS8)

        // No hardware flow control
        options.c_cflag &= ~tcflag_t(CRTSCTS)

        // Enable receiver, local mode
        options.c_cflag |= tcflag_t(CLOCAL | CREAD)

        // Raw input
        options.c_lflag &= ~tcflag_t(ICANON | ECHO | ECHOE | ISIG)

        // Raw output
        options.c_oflag &= ~tcflag_t(OPOST)

        // No software flow control
        options.c_iflag &= ~tcflag_t(IXON | IXOFF | IXANY)

        // Read timeout: 1 second
        options.c_cc.16 = 0  // VMIN
        options.c_cc.17 = 10 // VTIME (tenths of seconds)

        tcsetattr(fd, TCSANOW, &options)

        // Clear O_NONBLOCK for blocking reads with timeout
        var flags = fcntl(fd, F_GETFL, 0)
        flags &= ~O_NONBLOCK
        _ = fcntl(fd, F_SETFL, flags)

        // Flush any pending data
        tcflush(fd, TCIOFLUSH)

        fileDescriptor = fd
    }

    public func disconnect() async {
        if fileDescriptor >= 0 {
            close(fileDescriptor)
            fileDescriptor = -1
        }
    }

    public func send(_ data: Data) async throws {
        guard fileDescriptor >= 0 else { throw USBError.notConnected }

        let written = data.withUnsafeBytes { buffer in
            write(fileDescriptor, buffer.baseAddress!, data.count)
        }

        guard written == data.count else {
            throw USBError.writeError("Wrote \(written)/\(data.count) bytes")
        }

        // Wait for transmission to complete
        tcdrain(fileDescriptor)
    }

    public func receive(count: Int, timeout: TimeInterval) async throws -> Data {
        guard fileDescriptor >= 0 else { throw USBError.notConnected }

        var buffer = Data(count: count)
        var totalRead = 0
        let deadline = Date().addingTimeInterval(timeout)

        while totalRead < count && Date() < deadline {
            let bytesRead = buffer.withUnsafeMutableBytes { buf in
                read(fileDescriptor, buf.baseAddress!.advanced(by: totalRead), count - totalRead)
            }

            if bytesRead > 0 {
                totalRead += bytesRead
            } else if bytesRead == 0 {
                try await Task.sleep(for: .milliseconds(10))
            } else {
                if errno == EAGAIN || errno == EWOULDBLOCK {
                    try await Task.sleep(for: .milliseconds(10))
                } else {
                    throw USBError.readError(String(cString: strerror(errno)))
                }
            }
        }

        guard totalRead == count else {
            throw USBError.timeout
        }

        return buffer.prefix(count)
    }

    public func sendCommand(_ command: Data, responseLength: Int, timeout: TimeInterval = 5.0) async throws -> Data {
        try await send(command)
        return try await receive(count: responseLength, timeout: timeout)
    }
}
