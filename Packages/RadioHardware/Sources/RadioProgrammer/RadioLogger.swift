import os

/// Centralized logging for RadioHardware using os.Logger.
///
/// Subsystem: `com.heiloprojects.motorolacps`
///
/// Categories:
/// - `xcmp`: XCMP protocol commands, responses, and packet parsing
/// - `xnl`: XNL connection, authentication, and packet transport
/// - `programmer`: High-level radio programming operations (read, identify)
/// - `crypto`: TEA encryption and key operations
///
/// Log levels used:
/// - `debug`: Protocol traces, hex dumps, packet contents (stripped in release)
/// - `info`: Connection events, session milestones
/// - `error`: Protocol failures, connection drops, timeouts
///
/// Usage:
/// ```swift
/// RadioLog.xnl.debug("Received packet: \(data.hex)")
/// RadioLog.programmer.info("Connected to radio at \(host)")
/// RadioLog.xcmp.error("Timeout waiting for response")
/// ```
public enum RadioLog {
    private static let subsystem = "com.heiloprojects.motorolacps"

    /// XNL connection layer: authentication, packet send/receive, socket operations
    public static let xnl = Logger(subsystem: subsystem, category: "xnl")

    /// XCMP protocol layer: commands, responses, opcode handling
    public static let xcmp = Logger(subsystem: subsystem, category: "xcmp")

    /// High-level programmer operations: identify, read codeplug, zone/channel parsing
    public static let programmer = Logger(subsystem: subsystem, category: "programmer")

    /// TEA encryption: key operations, test vectors
    public static let crypto = Logger(subsystem: subsystem, category: "crypto")
}
