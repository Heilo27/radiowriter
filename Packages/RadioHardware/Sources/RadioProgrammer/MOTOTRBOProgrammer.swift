import Foundation
import Network
import USBTransport
import RadioModelCore
import os

/// Programmer for MOTOTRBO radios (XPR, SL, DP, DM series).
/// Uses TCP/IP communication over CDC ECM network interface.
/// Implements XNL authentication and XCMP protocol for radio operations.
public actor MOTOTRBOProgrammer: RadioFamilyProgrammer {
    private let host: String
    private var xnlConnection: XNLConnection?
    private var xcmpClient: XCMPClient?
    private let queue = DispatchQueue(label: "com.cps.mototrbo", qos: .userInitiated)

    /// Known MOTOTRBO ports
    public struct Ports {
        /// XNL/XCMP CPS programming port (TCP)
        public static let xnlCPS: UInt16 = 8002

        /// AT debug interface
        public static let atDebug: UInt16 = 8501

        /// XCMP/XNL repeater mode (UDP)
        public static let xcmpRepeater: UInt16 = 4002

        /// IP Site Connect (IPSC)
        public static let ipsc: UInt16 = 50000
    }

    public init(host: String) {
        self.host = host
    }

    // MARK: - Connection Management

    /// Connects to the radio using XNL protocol with TEA authentication.
    public func connect() async throws {
        let connection = XNLConnection(host: host)
        let result = await connection.connect()

        switch result {
        case .success(let assignedAddress):
            self.xnlConnection = connection
            self.xcmpClient = XCMPClient(xnlConnection: connection)
            let addressHex = String(format: "%04X", assignedAddress)
            RadioLog.programmer.info("MOTOTRBO connected, XNL address: 0x\(addressHex, privacy: .public)")

        case .authenticationFailed(let code):
            throw MOTOTRBOError.authenticationFailed("Radio rejected authentication (code: 0x\(String(format: "%02X", code)))")

        case .connectionError(let message):
            throw MOTOTRBOError.connectionFailed(message)

        case .timeout:
            throw MOTOTRBOError.timeout
        }
    }

    /// Disconnects from the radio.
    public func disconnect() async {
        await xnlConnection?.disconnect()
        xnlConnection = nil
        xcmpClient = nil
    }

    /// Returns whether the connection is established and authenticated.
    public var isConnected: Bool {
        get async {
            guard let conn = xnlConnection else { return false }
            return await conn.isAuthenticated
        }
    }

    // MARK: - RadioFamilyProgrammer

    /// Identifies the connected MOTOTRBO radio using XCMP protocol.
    /// Uses the verified CPS 2.0 protocol (SecurityKey, ModelNumber, etc.)
    public func identify() async throws -> RadioIdentification {
        // Connect if not already connected
        if !(await isConnected) {
            try await connect()
        }

        guard let client = xcmpClient else {
            throw MOTOTRBOError.connectionFailed("XCMP client not initialized")
        }

        // Use verified CPS protocol to get radio info
        return try await client.identifyCPS(debug: false)
    }

    /// Identifies the radio with debug output enabled.
    public func identifyWithDebug() async throws -> RadioIdentification {
        if !(await isConnected) {
            try await connect()
        }

        guard let client = xcmpClient else {
            throw MOTOTRBOError.connectionFailed("XCMP client not initialized")
        }

        return try await client.identifyCPS(debug: true)
    }

    // MARK: - Record ID Constants

    /// Standard record IDs common to all MOTOTRBO radios.
    /// Captured from CPS 2.0 communication with XPR 3500e.
    public static let standardRecordIDs: [UInt16] = [
        // Device Information (0x000A - 0x0019)
        0x000A, 0x000B, 0x000C, 0x0018, 0x0019,
        // General Settings (0x0026 - 0x0051)
        0x0026, 0x0027, 0x0028, 0x0029, 0x0034,
        0x0042, 0x0043, 0x0047, 0x004C, 0x004E, 0x004F, 0x0051,
        // Channel/Zone Data (0x005E - 0x006F)
        0x005E, 0x005F, 0x0060, 0x0061, 0x0062, 0x0063, 0x0064, 0x0065, 0x0066,
        0x006B, 0x006C, 0x006D, 0x006F,
        // Network/System Settings (0x0072 - 0x008F)
        0x0072, 0x0073, 0x0074, 0x0075, 0x0077,
        0x007A, 0x007B, 0x007C, 0x007D, 0x007E,
        0x0080, 0x0081, 0x0082, 0x0083, 0x0084, 0x0085, 0x0087, 0x0088, 0x008F,
        // Advanced Features (0x0093 - 0x00A9)
        0x0093, 0x0097, 0x009A, 0x009B, 0x009D,
        0x00A1, 0x00A2, 0x00A5, 0x00A6, 0x00A7, 0x00A8, 0x00A9,
        // Extended/Firmware (0x0F00+)
        0x0F55, 0x0F80, 0x0F81
    ]

    /// Additional record IDs for DM (mobile) series radios.
    public static let mobileRecordIDs: [UInt16] = [
        0x00B0, 0x00B1, 0x00B2, 0x00B3, 0x00B4, 0x00B5,  // Ignition/vehicle
        0x00C0, 0x00C1, 0x00C2, 0x00C3,                  // Horn/light alerts
    ]

    /// Returns record IDs appropriate for the given radio family.
    /// - Parameter family: Radio family identifier (e.g., "xpr", "dm", "sl", "dp")
    /// - Returns: Array of record IDs to read
    public static func recordIDs(for family: String?) -> [UInt16] {
        guard let family = family?.lowercased() else {
            return standardRecordIDs
        }

        switch family {
        case "dm":
            // Mobile radios have additional vehicle-related records
            return standardRecordIDs + mobileRecordIDs
        case "xpr", "sl", "fiji", "dp":
            // Portable radios use standard records
            return standardRecordIDs
        default:
            return standardRecordIDs
        }
    }

    /// Legacy alias for backward compatibility.
    public static var knownRecordIDs: [UInt16] { standardRecordIDs }

    /// Reads codeplug records using the verified CPS 2.0 protocol.
    ///
    /// Sequence verified from CPS capture:
    /// 1. SecurityKey (0x0012) - get session key
    /// 2. Device info queries (0x0010, 0x000F, 0x0011, 0x001F)
    /// 3. CodeplugRead (0x002E) - read records by ID
    ///
    /// NO programming mode entry required for reading!
    ///
    /// - Parameters:
    ///   - progress: Progress callback (0.0 to 1.0)
    ///   - debug: Enable debug output
    ///   - family: Radio family for selecting appropriate record IDs (nil for auto-detect)
    public func readCodeplugCPS(progress: @Sendable (Double) -> Void, debug: Bool = false, family: String? = nil) async throws -> Data {
        // Ensure connected
        if !(await isConnected) {
            try await connect()
        }

        guard let client = xcmpClient else {
            throw MOTOTRBOError.connectionFailed("XCMP client not initialized")
        }

        progress(0.0)

        // Step 1: Get security key (CPS does this first)
        if debug { RadioLog.programmer.debug("[READ] Getting security key...") }
        guard let securityKey = try await client.getSecurityKey(debug: debug) else {
            throw MOTOTRBOError.protocolError("Failed to get security key")
        }
        if debug {
            let keyHex = securityKey.map { String(format: "%02X", $0) }.joined(separator: " ")
            RadioLog.programmer.debug("[READ] Security key: \(keyHex, privacy: .public)")
        }

        progress(0.1)

        // Step 2: Get device info
        if debug { RadioLog.programmer.debug("[READ] Getting device info...") }
        let model = try await client.getModelNumberCPS(debug: debug)
        let firmware = try await client.getFirmwareVersionCPS(debug: debug)
        let serial = try await client.getSerialNumberCPS(debug: debug)
        let codeplugID = try await client.getCodeplugID(debug: debug)

        if debug {
            RadioLog.programmer.debug("[READ] Model: \(model ?? "unknown", privacy: .public)")
            RadioLog.programmer.debug("[READ] Firmware: \(firmware ?? "unknown", privacy: .public)")
            RadioLog.programmer.debug("[READ] Serial: \(serial ?? "unknown", privacy: .public)")
            RadioLog.programmer.debug("[READ] Codeplug ID: \(codeplugID ?? "unknown", privacy: .public)")
        }

        progress(0.2)

        // Detect family from model if not provided
        let radioFamily = family ?? RadioProtocolRegistry.detectFamily(from: model ?? "")

        // Step 3: Read codeplug records in batches
        if debug { RadioLog.programmer.debug("[READ] Reading codeplug records for family: \(radioFamily ?? "unknown", privacy: .public)...") }

        var allData = Data()
        let recordIDs = Self.recordIDs(for: radioFamily)
        let batchSize = 5  // Read 5 records at a time (like CPS does)
        let totalBatches = (recordIDs.count + batchSize - 1) / batchSize

        for (batchIndex, startIndex) in stride(from: 0, to: recordIDs.count, by: batchSize).enumerated() {
            let endIndex = min(startIndex + batchSize, recordIDs.count)
            let batchRecords = Array(recordIDs[startIndex..<endIndex])

            if debug {
                let recordsHex = batchRecords.map { String(format: "0x%04X", $0) }.joined(separator: ", ")
                RadioLog.programmer.debug(
                    "[READ] Batch \(batchIndex + 1, privacy: .public)/\(totalBatches, privacy: .public): records \(recordsHex, privacy: .public)"
                )
            }

            if let recordData = try await client.readCodeplugRecords(batchRecords, debug: debug) {
                allData.append(recordData)
                if debug { RadioLog.programmer.debug("[READ] Got \(recordData.count, privacy: .public) bytes") }
            }

            // Update progress (0.2 to 0.9)
            let readProgress = 0.2 + (0.7 * Double(batchIndex + 1) / Double(totalBatches))
            progress(readProgress)
        }

        progress(1.0)

        if debug { RadioLog.programmer.debug("[READ] Complete! Total data: \(allData.count, privacy: .public) bytes") }

        return allData
    }

    /// Reads the complete codeplug from the radio using CloneRead protocol.
    ///
    /// This method reads:
    /// 1. Device info (model, serial, firmware)
    /// 2. Radio general settings (radio ID, alias)
    /// 3. Zone structure and names
    /// 4. All channels in each zone with their settings
    /// 5. Contacts
    /// 6. Scan lists
    /// 7. RX group lists
    ///
    /// - Parameters:
    ///   - progress: Progress callback (0.0 to 1.0)
    ///   - debug: Enable debug output
    /// - Returns: ParsedCodeplug with all data
    public func readZonesAndChannels(
        progress: @escaping @Sendable (Double) -> Void,
        debug: Bool = false
    ) async throws -> ParsedCodeplug {
        // Ensure connected
        if !(await isConnected) {
            try await connect()
        }

        guard let client = xcmpClient else {
            throw MOTOTRBOError.connectionFailed("XCMP client not initialized")
        }

        var result = ParsedCodeplug()

        progress(0.0)

        // Step 1: Get security key
        if debug { RadioLog.programmer.debug("[READ] Getting security key...") }
        _ = try await client.getSecurityKey(debug: debug)
        progress(0.02)

        // Step 2: Get device info
        if debug { RadioLog.programmer.debug("[READ] Getting device info...") }
        result.modelNumber = try await client.getModelNumberCPS(debug: debug) ?? "Unknown"
        result.serialNumber = try await client.getSerialNumberCPS(debug: debug) ?? ""
        result.firmwareVersion = try await client.getFirmwareVersionCPS(debug: debug) ?? ""
        result.codeplugVersion = try await client.getCodeplugID(debug: debug) ?? ""

        if debug {
            RadioLog.programmer.debug("[READ] Model: \(result.modelNumber, privacy: .public)")
            RadioLog.programmer.debug("[READ] Serial: \(result.serialNumber, privacy: .public)")
            RadioLog.programmer.debug("[READ] Firmware: \(result.firmwareVersion, privacy: .public)")
        }

        progress(0.05)

        // Step 3: Enter ISH program mode (read). GROUND TRUTH: CPS ReadDevice does
        // OpenConnection(op=Read) which issues IshProgramMode Enter(0) before the
        // ISH walk (analysis/CPS_VERIFICATION_2026-07-06.md; RcmpIshProgramMode 0x0106).
        // NOTE: the security-unlock 0x0300/0x0301 handshake already ran in
        // XNLConnection.initialize(); we do NOT repeat it here.
        if debug { RadioLog.programmer.debug("[READ] Entering ISH program mode (0x0106 action=0)...") }
        let enterResult = try await client.ishEnterProgramMode(debug: debug)
        if debug { RadioLog.programmer.debug("[READ] Program mode enter result: \(String(describing: enterResult), privacy: .public)") }
        // Not fatal if the radio doesn't require it — some accept ISH reads without
        // an explicit enter. We proceed regardless and let the walk report reality.

        progress(0.08)

        // Step 4: THE ISH READ WALK — replaces the fabricated cloneRead (0x010A) path.
        // VERIFIED FROM CPS 2.0 SOURCE (RcmpReadIshTypeSet/IDSet/Item, RcmpWrapper.cs):
        //   partition -> ReadIshTypeSet(0x0105) -> types
        //   type      -> ReadIshIDSet(0x0104)   -> ids
        //   (type,id) -> ReadIshItem(0x0100)    -> record bytes (chunked)
        //
        // ⚠️ SEMANTIC MAPPING IS UNVERIFIED-PENDING-HARDWARE. CPS resolves which ISH
        // (partition,type,id) tuple holds channels vs zones vs contacts via an
        // internal metadata DB (IshHeader.PartitionNumber map; CodeplugConverter
        // checks PartitionID==212 / ==135). That mapping is NOT derivable from the
        // decompile. So here we perform the GENERIC walk, dump every tuple to the
        // log, and return the raw records. The channel decode below is the ONE piece
        // whose byte layout is already verified (0x0FFB indexed record, offsets
        // confirmed on an XPR 3500e 2026-01-31) — we keep it.
        //
        // Candidate logical partitions to probe. The codeplug partition number is
        // not known from source; probe a small range and keep whatever the radio
        // returns. Absent partitions reply non-success and are skipped.
        // TODO(ish-mapping): after the first real-radio dump, replace this generic
        // walk's downstream handling with a confirmed (partition,type)->section map.
        let candidatePartitions: [UInt8] = [0, 1, 2, 3, 4]
        if debug { RadioLog.programmer.debug("[READ] Starting generic ISH walk over partitions \(candidatePartitions, privacy: .public)...") }

        let ishRecords = try await client.readAllIshRecords(
            candidatePartitions: candidatePartitions,
            debug: debug
        ) { walkProgress in
            // Map the ISH walk to 8% - 45%
            progress(0.08 + (0.37 * walkProgress))
        }

        // Persist the raw ISH dump so the user/analysis can build the semantic map.
        // Each record's (partition,type,id,size) was also logged at .info level by
        // readAllIshRecords ("[ISH-DUMP] ...") for live capture.
        result.ishRecordDump = ishRecords.map { rec in
            IshRecordDump(
                partition: rec.partition, type: rec.type, id: rec.id,
                itemSize: rec.itemSize, data: rec.data
            )
        }
        if debug {
            RadioLog.programmer.info("[READ] ISH walk returned \(ishRecords.count, privacy: .public) raw records")
            // Summarise the (partition,type) shape discovered — this is the map the
            // user confirms against the radio. NOT interpreted as any section yet.
            var shape: [String: Int] = [:]
            for r in ishRecords {
                let key = "p\(r.partition)/t0x\(String(format: "%04X", r.type))"
                shape[key, default: 0] += 1
            }
            for (k, v) in shape.sorted(by: { $0.key < $1.key }) {
                RadioLog.programmer.info("[READ]   ISH \(k, privacy: .public): \(v, privacy: .public) records")
            }
        }

        progress(0.45)

        // Step 5: Decode channels via the VERIFIED indexed-record read (0x0FFB inside
        // XcmpSuperBundle 0x002E — both real opcodes). This path's byte offsets are
        // hardware-verified, so we keep it as the trustworthy source of channel data
        // and present it as "Zone 1" until the ISH zone-mapping is confirmed.
        // (The ISH walk above already captured the same channel bytes generically;
        //  this decode simply gives us structured ChannelData today.)
        if debug { RadioLog.programmer.debug("[READ] Decoding channels via indexed record 0x0FFB...") }
        let channelRecords = try await client.readAllChannels(debug: debug) { channelProgress in
            progress(0.45 + (0.35 * channelProgress))
        }

        if !channelRecords.isEmpty {
            if debug { RadioLog.programmer.debug("[READ] Decoded \(channelRecords.count, privacy: .public) channels from indexed records") }
            var zone = ParsedZone(name: "Zone 1", position: 0)
            for record in channelRecords {
                zone.channels.append(record.toChannelData(zoneIndex: 0))
                if debug && zone.channels.count <= 5 {
                    let msg = "[READ] Channel \(record.index): '\(record.name)' @ \(record.rxFrequencyMHz) MHz"
                    RadioLog.programmer.debug("\(msg, privacy: .public)")
                }
            }
            result.zones.append(zone)
        } else if debug {
            RadioLog.programmer.debug("[READ] Indexed channel decode returned no channels (see ISH dump above)")
        }

        // TODO(ish-mapping): zones, contacts, scan lists, and RX group lists are NOT
        // yet decoded. Their ISH (partition,type,id) tuples are present in
        // result.ishRecordDump but the type->section mapping is unconfirmed. Do NOT
        // guess a mapping here — decode these only once the real-radio ISH dump has
        // identified which types carry them. The old cloneRead-based scans for these
        // sections were removed because cloneRead (0x010A) is a fabricated opcode.
        progress(0.95)

        // Final progress
        progress(1.0)

        if debug {
            RadioLog.programmer.info("[READ] Complete!")
            RadioLog.programmer.info("[READ]   Zones: \(result.zones.count)")
            RadioLog.programmer.info("[READ]   Channels: \(result.totalChannels)")
            RadioLog.programmer.info("[READ]   Contacts: \(result.contacts.count)")
            RadioLog.programmer.info("[READ]   Scan Lists: \(result.scanLists.count)")
            RadioLog.programmer.info("[READ]   RX Groups: \(result.rxGroupLists.count)")
        }

        // Exit ISH program mode WITHOUT a radio reset (action 3 = ExitWithoutRadioReset).
        // A read must not reset the radio out from under the user, and reading never
        // modifies ISH storage, so no-reset exit is the safe choice.
        if debug { RadioLog.programmer.debug("[READ] Exiting ISH program mode (no reset)...") }
        _ = try? await client.ishExitProgramMode(reset: false, debug: debug)

        return result
    }

    /// Reads the complete codeplug from the radio (legacy method).
    ///
    /// Uses XCMP protocol with PSDT access to read codeplug data.
    /// Sequence based on Specter analysis of MOTOTRBO CPS DLLs:
    /// 1. Start component session (0x010F)
    /// 2. Query PSDT partition addresses (0x010B)
    /// 3. Read data blocks using component read (0x010E)
    /// 4. Create archive (0x010F with CreateArchive flag)
    /// 5. End session (0x010F with Reset flag)
    public func readCodeplug(progress: @Sendable (Double) -> Void) async throws -> Data {
        // Ensure connected
        if !(await isConnected) {
            try await connect()
        }

        guard let client = xcmpClient else {
            throw MOTOTRBOError.connectionFailed("XCMP client not initialized")
        }

        progress(0.0)

        // Generate session ID
        let sessionID = UInt16.random(in: 1...0xFFFE)

        // Step 1: Start read session
        let startPacket = XCMPPacket.startReadSession(sessionID: sessionID)
        guard let startReply = try await client.sendAndReceive(startPacket) else {
            throw MOTOTRBOError.protocolError("No reply to session start request")
        }

        // Check for success
        if !startReply.data.isEmpty && startReply.data[0] != 0x00 {
            let errorCode = startReply.data[0]
            throw MOTOTRBOError.protocolError("Session start failed with error: 0x\(String(format: "%02X", errorCode))")
        }

        progress(0.1)

        // Step 2: Query codeplug partition addresses
        let getStartAddr = XCMPPacket.psdtGetStartAddress(partition: "CP")
        guard let startAddrReply = try await client.sendAndReceive(getStartAddr) else {
            throw MOTOTRBOError.protocolError("No reply to PSDT start address query")
        }

        let getEndAddr = XCMPPacket.psdtGetEndAddress(partition: "CP")
        guard let endAddrReply = try await client.sendAndReceive(getEndAddr) else {
            throw MOTOTRBOError.protocolError("No reply to PSDT end address query")
        }

        // Parse addresses from replies (4 bytes each, big-endian)
        guard startAddrReply.data.count >= 5, endAddrReply.data.count >= 5 else {
            throw MOTOTRBOError.protocolError("Invalid PSDT address reply format")
        }

        let startAddress = UInt32(startAddrReply.data[1]) << 24 |
                          UInt32(startAddrReply.data[2]) << 16 |
                          UInt32(startAddrReply.data[3]) << 8 |
                          UInt32(startAddrReply.data[4])

        let endAddress = UInt32(endAddrReply.data[1]) << 24 |
                        UInt32(endAddrReply.data[2]) << 16 |
                        UInt32(endAddrReply.data[3]) << 8 |
                        UInt32(endAddrReply.data[4])

        let codeplugSize = Int(endAddress - startAddress)
        guard codeplugSize > 0 && codeplugSize < 50_000_000 else {  // Sanity check: < 50MB
            throw MOTOTRBOError.protocolError("Invalid codeplug size: \(codeplugSize)")
        }

        progress(0.2)

        // Step 3: Unlock PSDT partition
        let unlockPacket = XCMPPacket.psdtUnlock(partition: "CP")
        _ = try await client.sendAndReceive(unlockPacket)

        progress(0.25)

        // Step 4: Read data in blocks
        var codeplugData = Data()
        let blockSize: UInt16 = 1024  // Read 1KB at a time
        var currentAddress = startAddress
        let totalBlocks = (codeplugSize + Int(blockSize) - 1) / Int(blockSize)
        var blocksRead = 0

        while currentAddress < endAddress {
            let bytesRemaining = endAddress - currentAddress
            let readSize = min(UInt16(bytesRemaining), blockSize)

            let readPacket = XCMPPacket.cpsReadRequest(address: currentAddress, length: readSize)
            guard let readReply = try await client.sendAndReceive(readPacket, timeout: 10.0) else {
                throw MOTOTRBOError.protocolError("No reply to CPS read request at address 0x\(String(format: "%08X", currentAddress))")
            }

            // Check for error
            if readReply.data.count < 2 || readReply.data[0] != 0x00 {
                throw MOTOTRBOError.protocolError("CPS read failed at address 0x\(String(format: "%08X", currentAddress))")
            }

            // Skip error code byte, append data
            codeplugData.append(Data(readReply.data.dropFirst()))
            currentAddress += UInt32(readSize)
            blocksRead += 1

            // Update progress (0.25 to 0.9 for data transfer)
            let transferProgress = 0.25 + (0.65 * Double(blocksRead) / Double(totalBlocks))
            progress(transferProgress)
        }

        progress(0.9)

        // Step 5: Create archive (optional, for proper CPS format)
        let archivePacket = XCMPPacket.createArchive(sessionID: sessionID)
        _ = try await client.sendAndReceive(archivePacket)

        progress(0.95)

        // Step 6: End session
        let resetPacket = XCMPPacket.resetSession(sessionID: sessionID)
        _ = try await client.sendAndReceive(resetPacket)

        progress(1.0)

        return codeplugData
    }

    /// Writes a codeplug to the radio.
    ///
    /// Uses XCMP protocol with PSDT access to write codeplug data.
    /// Sequence based on Specter analysis of MOTOTRBO CPS DLLs:
    /// 1. Start component session with write flags (0x010F)
    /// 2. Unlock PSDT partition (0x010B)
    /// 3. Optionally erase partition (0x010B with Erase action)
    /// 4. Transfer data blocks (0x0446)
    /// 5. Validate CRC (0x010F with ValidateCRC flag)
    /// 6. Unpack and deploy (0x010F with UnpackFiles | Deploy flags)
    /// 7. Lock PSDT partition (0x010B)
    /// 8. End session (0x010F with Reset flag)
    public func writeCodeplug(_ data: Data, progress: @Sendable (Double) -> Void) async throws {
        // ⛔️ SAFETY GATE — DO NOT REMOVE WITHOUT SOURCE-VERIFIED WRITE PATH.
        //
        // This write path was built from GUESSED opcodes (0x010F component-session,
        // 0x010B PSDT, 0x0446 transfer-data, linear 512-byte blocks). Verification
        // against the decompiled CPS 2.0 source (analysis/cps_decompiled/, 2026-07-06)
        // proved NONE of these opcodes exist in Motorola's RcmpWrapper. The real CPS
        // write is ISH record-based: IshProgramMode(Enter=0) → IshUnlockPartition(0x108)
        // → read+diff → WriteIshItem(0x101) per changed record → IshProgramMode(Exit).
        //
        // Running THIS code against a radio will fail and MAY BRICK IT (partial ISH
        // partition modification). It stays hard-disabled until the ISH write path is
        // implemented AND the READ path is proven working against a live radio first.
        // See analysis/CPS_VERIFICATION_2026-07-06.md finding C1.
        throw MOTOTRBOError.notImplemented(
            "Codeplug write is disabled: the current write path uses unverified opcodes and could brick the radio. "
            + "A source-verified ISH-based write path must be implemented and read-path-validated first.")

        // Ensure connected
        if !(await isConnected) {
            try await connect()
        }

        guard let client = xcmpClient else {
            throw MOTOTRBOError.connectionFailed("XCMP client not initialized")
        }

        progress(0.0)

        // Generate session ID
        let sessionID = UInt16.random(in: 1...0xFFFE)

        // Step 1: Start write session (with programming indicator)
        let startPacket = XCMPPacket.startWriteSession(sessionID: sessionID)
        guard let startReply = try await client.sendAndReceive(startPacket) else {
            throw MOTOTRBOError.protocolError("No reply to write session start request")
        }

        // Check for success
        if !startReply.data.isEmpty && startReply.data[0] != 0x00 {
            let errorCode = startReply.data[0]
            throw MOTOTRBOError.protocolError("Write session start failed with error: 0x\(String(format: "%02X", errorCode))")
        }

        progress(0.05)

        // Step 2: Initiate codeplug update
        let updatePacket = XCMPPacket.initiateCodeplugUpdate()
        _ = try await client.sendAndReceive(updatePacket)

        progress(0.1)

        // Step 3: Unlock PSDT partition
        let unlockPacket = XCMPPacket.psdtUnlock(partition: "CP")
        guard let unlockReply = try await client.sendAndReceive(unlockPacket) else {
            throw MOTOTRBOError.protocolError("No reply to PSDT unlock request")
        }

        if !unlockReply.data.isEmpty && unlockReply.data[0] != 0x00 {
            throw MOTOTRBOError.protocolError("PSDT unlock failed")
        }

        progress(0.15)

        // Step 4: Transfer data in blocks
        let blockSize = 512  // Write 512 bytes at a time
        let totalBlocks = (data.count + blockSize - 1) / blockSize
        var blocksSent = 0

        for offset in stride(from: 0, to: data.count, by: blockSize) {
            let endIndex = min(offset + blockSize, data.count)
            let blockData = Data(data[offset..<endIndex])

            let transferPacket = XCMPPacket.transferCompressedData(blockData)
            guard let transferReply = try await client.sendAndReceive(transferPacket, timeout: 10.0) else {
                throw MOTOTRBOError.protocolError("No reply to data transfer at offset \(offset)")
            }

            if !transferReply.data.isEmpty && transferReply.data[0] != 0x00 {
                throw MOTOTRBOError.protocolError("Data transfer failed at offset \(offset)")
            }

            blocksSent += 1
            // Progress: 0.15 to 0.75 for data transfer
            let transferProgress = 0.15 + (0.60 * Double(blocksSent) / Double(totalBlocks))
            progress(transferProgress)
        }

        progress(0.75)

        // Step 5: Validate CRC
        let validatePacket = XCMPPacket.validateSessionCRC(sessionID: sessionID)
        guard let validateReply = try await client.sendAndReceive(validatePacket, timeout: 30.0) else {
            throw MOTOTRBOError.protocolError("No reply to CRC validation request")
        }

        if !validateReply.data.isEmpty && validateReply.data[0] != 0x00 {
            throw MOTOTRBOError.protocolError("CRC validation failed")
        }

        progress(0.80)

        // Step 6: Unpack and deploy
        let deployPacket = XCMPPacket.unpackAndDeploy(sessionID: sessionID)
        guard let deployReply = try await client.sendAndReceive(deployPacket, timeout: 60.0) else {
            throw MOTOTRBOError.protocolError("No reply to deploy request")
        }

        if !deployReply.data.isEmpty && deployReply.data[0] != 0x00 {
            throw MOTOTRBOError.protocolError("Deploy failed")
        }

        progress(0.90)

        // Step 7: Validate codeplug
        let validateCPPacket = XCMPPacket.validateCodeplug()
        _ = try await client.sendAndReceive(validateCPPacket)

        progress(0.92)

        // Step 8: Lock PSDT partition
        let lockPacket = XCMPPacket.psdtLock(partition: "CP")
        _ = try await client.sendAndReceive(lockPacket)

        progress(0.95)

        // Step 9: End session
        let resetPacket = XCMPPacket.resetSession(sessionID: sessionID)
        _ = try await client.sendAndReceive(resetPacket)

        progress(1.0)
    }

    /// Verifies the written codeplug matches the source.
    public func verify(expected: Data, progress: @Sendable (Double) -> Void) async throws -> Bool {
        // Read back and compare
        let actual = try await readCodeplug(progress: progress)
        return actual == expected
    }

    // MARK: - XCMP Commands

    /// Gets the radio model number via XCMP.
    public func getModelNumber() async throws -> String? {
        guard let client = xcmpClient else {
            try await connect()
            guard let connectedClient = xcmpClient else { return nil }
            return try await connectedClient.getModelNumber()
        }
        return try await client.getModelNumber()
    }

    /// Gets the radio serial number via XCMP.
    public func getSerialNumber() async throws -> String? {
        guard let client = xcmpClient else {
            try await connect()
            guard let connectedClient = xcmpClient else { return nil }
            return try await connectedClient.getSerialNumber()
        }
        return try await client.getSerialNumber()
    }

    /// Gets the radio ID via XCMP.
    public func getRadioID() async throws -> UInt32? {
        guard let client = xcmpClient else {
            try await connect()
            guard let connectedClient = xcmpClient else { return nil }
            return try await connectedClient.getRadioID()
        }
        return try await client.getRadioID()
    }

    /// Gets the firmware version via XCMP.
    public func getFirmwareVersion() async throws -> String? {
        guard let client = xcmpClient else {
            try await connect()
            guard let connectedClient = xcmpClient else { return nil }
            return try await connectedClient.getFirmwareVersion()
        }
        return try await client.getFirmwareVersion()
    }

    // MARK: - AT Debug Commands (Legacy)

    /// Sends an AT command and returns the response.
    /// Uses the AT debug interface on port 8501.
    public func sendATCommand(_ command: String) async throws -> String {
        let connection = try await connectTCP(to: Ports.atDebug)
        defer { connection.cancel() }

        // Read welcome banner
        _ = try await readUntilPrompt(connection: connection)

        // Send command
        try await send(command + "\r\n", to: connection)

        // Read response
        return try await readUntilPrompt(connection: connection)
    }

    /// Gets the list of available AT commands.
    public func getATHelp() async throws -> String {
        return try await sendATCommand("?")
    }

    // MARK: - TCP Connection Helpers

    private func connectTCP(to port: UInt16) async throws -> NWConnection {
        let nwHost = NWEndpoint.Host(host)
        let nwPort = NWEndpoint.Port(rawValue: port)!

        let parameters = NWParameters.tcp
        let connection = NWConnection(host: nwHost, port: nwPort, using: parameters)

        return try await withCheckedThrowingContinuation { continuation in
            connection.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    continuation.resume(returning: connection)
                case .failed(let error):
                    continuation.resume(throwing: MOTOTRBOError.connectionFailed(error.localizedDescription))
                case .cancelled:
                    continuation.resume(throwing: MOTOTRBOError.connectionFailed("Connection cancelled"))
                default:
                    break
                }
            }
            connection.start(queue: queue)
        }
    }

    private func send(_ string: String, to connection: NWConnection) async throws {
        let data = Data(string.utf8)
        return try await withCheckedThrowingContinuation { continuation in
            connection.send(content: data, completion: .contentProcessed { error in
                if let error = error {
                    continuation.resume(throwing: MOTOTRBOError.sendFailed(error.localizedDescription))
                } else {
                    continuation.resume()
                }
            })
        }
    }

    private func readUntilPrompt(connection: NWConnection, timeout: TimeInterval = 3.0) async throws -> String {
        var buffer = Data()
        let deadline = Date().addingTimeInterval(timeout)

        while Date() < deadline {
            let data = try await receive(from: connection, count: 1024, timeout: 0.5)
            buffer.append(data)

            // Check for AT_Debug> prompt
            if let str = String(data: buffer, encoding: .utf8),
               str.contains("AT_Debug>") {
                return str
            }
        }

        return String(data: buffer, encoding: .utf8) ?? ""
    }

    private func receive(from connection: NWConnection, count: Int, timeout: TimeInterval) async throws -> Data {
        return try await withThrowingTaskGroup(of: Data.self) { group in
            group.addTask {
                try await withCheckedThrowingContinuation { continuation in
                    connection.receive(minimumIncompleteLength: 1, maximumLength: count) { data, _, _, error in
                        if let error = error {
                            continuation.resume(throwing: MOTOTRBOError.receiveFailed(error.localizedDescription))
                        } else {
                            continuation.resume(returning: data ?? Data())
                        }
                    }
                }
            }

            group.addTask {
                try await Task.sleep(for: .seconds(timeout))
                return Data()
            }

            let result = try await group.next() ?? Data()
            group.cancelAll()
            return result
        }
    }

    // MARK: - Codeplug Record Parsing

    /// Parses zone and channel data from CodeplugRead record data.
    /// This interprets the binary format returned by opcode 0x002E.
    ///
    /// Record format from CPS 2.0 traffic analysis:
    /// - Response header: [status:1] [recordCount:1]
    /// - Each record: [size:2] [81:1] [00:1] [00:1] [80:1] [recordID:2] [length:4] [length:4] [data...]
    /// - Channel data (record 0x0084): name at offset 60 from data start, UTF-16LE
    private func parseCodeplugRecordData(
        _ data: Data,
        excludeStrings: Set<String> = [],
        debug: Bool = false
    ) -> (zones: [ParsedZone], channels: [ChannelData]) {
        var zones: [ParsedZone] = []
        var channels: [ChannelData] = []

        // Build a set of strings to exclude (radio alias, zone names, etc.)
        let excludeLowercased = Set(excludeStrings.map { $0.lowercased() })

        guard data.count > 10 else {
            if debug { RadioLog.programmer.debug("[PARSE] Data too short to contain records") }
            return (zones, channels)
        }

        if debug {
            let hex64 = data.prefix(64).map { String(format: "%02X", $0) }.joined(separator: " ")
            RadioLog.programmer.debug("[PARSE] Total data: \(data.count) bytes")
            RadioLog.programmer.debug("[PARSE] First 64 bytes: \(hex64, privacy: .public)")

            // Count occurrences of different status patterns
            var dataRecords = 0
            var metadataRecords = 0
            for i in 0..<(data.count - 2) {
                if data[i] == 0x81 && data[i + 1] == 0x00 {
                    dataRecords += 1
                } else if data[i] == 0x81 && data[i + 1] == 0x04 {
                    metadataRecords += 1
                }
            }
            RadioLog.programmer.debug("[PARSE] Found \(dataRecords) data records (81 00) and \(metadataRecords) metadata records (81 04)")
        }

        // Response format from CodeplugRead (0x802E):
        // [successCount:1] [requestedCount:1] [headerBytes:2] [records...]
        // OR just start scanning for 81 00 00 80 patterns
        //
        // We'll scan for record patterns directly since the header format varies
        var offset = 0

        // Skip past any header bytes to find the first record
        // Records start with 81 00 00 80 (data) or 81 04 00 80 (metadata)
        // Look for the first 81 XX pattern
        while offset < data.count - 4 {
            if data[offset] == 0x81 && (data[offset + 1] == 0x00 || data[offset + 1] == 0x04) {
                break
            }
            offset += 1
        }

        if debug && offset > 0 {
            RadioLog.programmer.debug("[PARSE] Skipped \(offset) header bytes to first record")
        }

        // Collect all unique record IDs to understand the data format
        var recordIDSet: Set<UInt16> = []
        var recordsFound = 0
        var metadataFound = 0

        // First pass: understand what patterns we have
        // Try both "81 00 00 80" (strict) and "81 00" (relaxed) patterns
        if debug {
            RadioLog.programmer.debug("[PARSE] Analyzing response format...")
            var strictPattern = 0
            var relaxedPattern = 0
            for i in 0..<(data.count - 4) {
                if data[i] == 0x81 && data[i + 1] == 0x00 {
                    relaxedPattern += 1
                    if data[i + 2] == 0x00 && data[i + 3] == 0x80 {
                        strictPattern += 1
                    }
                }
            }
            RadioLog.programmer.debug("[PARSE] Found \(strictPattern) strict (81 00 00 80) and \(relaxedPattern) relaxed (81 00) patterns")
        }

        // Scan for record patterns: look for "81 00 00 80" (data) or "81 04 00 80" (metadata)
        while offset < data.count - 12 {
            // Check for DATA record pattern: 81 00 00 80 [recordID:2] [offset:2] [size:2] [pad:2] [data...]
            // Note: size is little-endian, total header is 12 bytes before data
            if data[offset] == 0x81 && offset + 1 < data.count && data[offset + 1] == 0x00 &&
               offset + 2 < data.count && data[offset + 2] == 0x00 &&
               offset + 3 < data.count && data[offset + 3] == 0x80 {

                // Found DATA record header pattern at offset
                let recordID = (UInt16(data[offset + 4]) << 8) | UInt16(data[offset + 5])
                recordIDSet.insert(recordID)

                // Size is at offset+8,9 as little-endian 16-bit
                let recordLength = Int(data[offset + 8]) | (Int(data[offset + 9]) << 8)

                if debug && recordsFound < 10 {
                    let recIDHex = String(format: "%04X", recordID)
                    RadioLog.programmer.debug("[PARSE] DATA record 0x\(recIDHex, privacy: .public) at offset \(offset), length \(recordLength)")
                    let headerPreview = data[offset..<min(offset + 16, data.count)]
                    let headerHex = headerPreview.map { String(format: "%02X", $0) }.joined(separator: " ")
                    RadioLog.programmer.debug("[PARSE] Header bytes: \(headerHex, privacy: .public)")
                }

                // Skip to data start: 4 (header) + 2 (id) + 2 (offset) + 2 (size) + 2 (padding) = 12
                let dataStart = offset + 12

                if dataStart + recordLength <= data.count && recordLength > 0 {
                    // Parse based on record type
                    switch recordID {
                    case 0x0084:
                        // Channel data record
                        if let channel = parseChannelRecord(
                            data,
                            dataStart: dataStart,
                            length: recordLength,
                            channelIndex: channels.count,
                            debug: debug
                        ) {
                            channels.append(channel)
                            if debug { RadioLog.programmer.debug("[PARSE] Extracted channel: \(channel.name, privacy: .public)") }
                        }

                    case 0x0093:
                        // Zone/channel mapping - may contain zone structure
                        if debug { RadioLog.programmer.debug("[PARSE] Found zone mapping record (0x0093)") }

                    case 0x009D:
                        // Zone configuration
                        if debug { RadioLog.programmer.debug("[PARSE] Found zone config record (0x009D)") }

                    case 0x0074:
                        // Zone list - parse zone name
                        if debug { RadioLog.programmer.debug("[PARSE] Found zone list record (0x0074)") }
                        if let zone = parseZoneRecord(data, dataStart: dataStart, length: recordLength, zoneIndex: zones.count, debug: debug) {
                            zones.append(zone)
                            if debug { RadioLog.programmer.debug("[PARSE] Extracted zone: \(zone.name, privacy: .public)") }
                        }

                    default:
                        if debug && recordsFound < 5 {
                            let preview = data[dataStart..<min(dataStart + 32, data.count)]
                            let recIDHex2 = String(format: "%04X", recordID)
                            let previewHex = preview.map { String(format: "%02X", $0) }.joined(separator: " ")
                            RadioLog.programmer.debug("[PARSE] Unknown record 0x\(recIDHex2, privacy: .public): \(previewHex, privacy: .public)...")
                        }
                    }

                    recordsFound += 1
                    offset = dataStart + recordLength
                    continue
                }
            }

            // Check for METADATA record pattern: 81 04 00 80 [recordID:2] 00 01 00 00 00 [count:4]
            if data[offset] == 0x81 && offset + 1 < data.count && data[offset + 1] == 0x04 &&
               offset + 2 < data.count && data[offset + 2] == 0x00 &&
               offset + 3 < data.count && data[offset + 3] == 0x80 {

                let recordID = (UInt16(data[offset + 4]) << 8) | UInt16(data[offset + 5])
                recordIDSet.insert(recordID)
                metadataFound += 1

                if debug && metadataFound <= 3 {
                    let metaIDHex = String(format: "%04X", recordID)
                    RadioLog.programmer.debug("[PARSE] METADATA record 0x\(metaIDHex, privacy: .public) - no data, just existence info")
                }

                offset += 14  // Skip the metadata entry
                continue
            }

            offset += 1
        }

        if debug {
            RadioLog.programmer.debug("[PARSE] Structured parsing: \(recordsFound) data records, \(metadataFound) metadata entries")
            if !recordIDSet.isEmpty {
                let sortedIDs = recordIDSet.sorted().map { String(format: "0x%04X", $0) }.joined(separator: ", ")
                RadioLog.programmer.debug("[PARSE] Unique record IDs found: \(sortedIDs, privacy: .public)")
            }
            if metadataFound > 0 && recordsFound == 0 {
                RadioLog.programmer.error("[PARSE] Got only metadata (81 04), no actual data (81 00). Need different request format!")
            }
        }

        // FALLBACK: Direct UTF-16LE string extraction (no record structure required)
        // This is more reliable when the record format doesn't match our expectations
        if debug {
            RadioLog.programmer.debug("[PARSE] Running fallback UTF-16LE string extraction...")
        }

        // Pre-build O(1) lookup sets to avoid O(n) array scans inside the hot loop.
        var foundNameSet = Set(channels.map { $0.name })
        let foundZoneNameSet = Set(zones.map { $0.name })
        let systemStrings: Set<String> = ["talkset", "scanlist", "contact", "group", "radio", "zone"]

        data.withUnsafeBytes { (ptr: UnsafeRawBufferPointer) in
            guard let base = ptr.baseAddress else { return }
            let bytes = base.assumingMemoryBound(to: UInt8.self)
            let count = ptr.count
            var i = 0
            // Reserve 2 bytes for the high byte check; reserve 1 more for the null terminator probe.
            while i < count - 2 {
                let b = bytes[i]
                // Gate: must start with A-z (0x41-0x7A) and next byte 0x00 (UTF-16LE ASCII)
                guard b >= 0x41 && b <= 0x7A && bytes[i + 1] == 0x00 else {
                    i += 1
                    continue
                }

                // Scan forward collecting the UTF-16LE run.
                // Each code unit: low byte 0x20-0x7E, high byte 0x00.
                var charBuf = [UInt8]()
                charBuf.reserveCapacity(32)
                var j = i
                while j + 1 < count && bytes[j] >= 0x20 && bytes[j] <= 0x7E && bytes[j + 1] == 0x00 {
                    charBuf.append(bytes[j])
                    j += 2
                }

                let charCount = charBuf.count
                // Valid channel/zone name: 3-16 characters, starts with letter (A-z already ensured)
                if charCount >= 3 && charCount <= 16 {
                    let str = String(bytes: charBuf, encoding: .ascii) ?? ""
                    if !str.isEmpty {
                        let lowercased = str.lowercased()

                        // Check exclusions (O(1) set lookups)
                        let isExcluded = excludeLowercased.contains(lowercased) ||
                                        excludeLowercased.contains { excluded in
                                            lowercased.contains(excluded) || excluded.contains(lowercased)
                                        }
                        let isLanguageCode = lowercased.contains("-") && charCount <= 6
                        let isSystemString = systemStrings.contains(lowercased)
                        let isFragment = lowercased.hasPrefix("et ") || lowercased.hasPrefix("io") ||
                                        lowercased.hasPrefix("dio") || lowercased.hasPrefix("set ") ||
                                        lowercased.hasPrefix("kset")

                        if !isExcluded && !isLanguageCode && !isSystemString && !isFragment {
                            // O(1) duplicate check via set; O(n) overlap check only when needed.
                            let isDuplicate = foundNameSet.contains(str) || foundZoneNameSet.contains(str)
                            if !isDuplicate {
                                // Substring/overlap check — still O(n) but only on non-duplicates
                                let isSubstring = foundNameSet.contains { $0.contains(str) && $0 != str }
                                let hasOverlap = !isSubstring && foundNameSet.contains { existing in
                                    str.hasSuffix(existing) || existing.hasSuffix(str)
                                }
                                if !isSubstring && !hasOverlap {
                                    var channel = ChannelData(zoneIndex: 0, channelIndex: channels.count)
                                    channel.name = str
                                    channels.append(channel)
                                    foundNameSet.insert(str)
                                    if debug && channels.count <= 10 {
                                        RadioLog.programmer.debug("[PARSE] UTF-16LE channel found: '\(str, privacy: .public)' at offset \(i)")
                                    }
                                }
                            }
                        }
                    }
                }
                // If the run produced no characters (gate passed but inner loop didn't advance),
                // ensure we make forward progress to avoid an infinite loop.
                if j > i {
                    i = j
                } else {
                    i += 1
                }
            }
        }
        _ = foundZoneNameSet  // suppress unused-variable warning

        // Also try the old 02 03 prefix pattern as another fallback
        offset = 0
        while offset < data.count - 20 {
            if data[offset] == 0x02 && data[offset + 1] == 0x03 {
                // Found potential channel name marker
                let nameStart = offset + 2
                let maxNameLength = min(32, data.count - nameStart)

                if maxNameLength > 0 {
                    let nameData = Data(data[nameStart..<(nameStart + maxNameLength)])

                    // Try to decode as UTF-16LE
                    if let name = String(data: nameData, encoding: .utf16LittleEndian)?
                        .trimmingCharacters(in: .controlCharacters)
                        .trimmingCharacters(in: CharacterSet(["\0"])) {

                        if !name.isEmpty && name.count <= 16 && !name.contains("\u{FFFD}") {
                            // Check if we already have this channel
                            let existingNames = channels.map { $0.name }
                            if !existingNames.contains(name) {
                                var channel = ChannelData(zoneIndex: 0, channelIndex: channels.count)
                                channel.name = name

                                // Try to find frequency data nearby (before the name marker)
                                if offset >= 60 {
                                    // Look for TX/RX frequencies in the bytes before the name
                                    // Frequencies may be stored at specific offsets
                                    channel = extractFrequenciesFromContext(data, nameOffset: offset, channel: channel, debug: debug)
                                }

                                if debug && channels.count < 10 {
                                    RadioLog.programmer.debug("[PARSE] Found channel name '\(name, privacy: .public)' at offset \(offset)")
                                }
                                channels.append(channel)
                            }
                        }
                    }
                }
            }
            offset += 1
        }

        // If we found channels but no zones, create a default zone
        if !channels.isEmpty && zones.isEmpty {
            var zone = ParsedZone(name: "Zone 1", position: 0)
            zone.channels = channels
            zones.append(zone)
        }

        if debug {
            RadioLog.programmer.debug("[PARSE] Extracted \(zones.count) zones with \(channels.count) channels total")
        }

        return (zones, channels)
    }

    /// Parses a channel data record (0x0084).
    private func parseChannelRecord(_ data: Data, dataStart: Int, length: Int, channelIndex: Int, debug: Bool) -> ChannelData? {
        guard dataStart + 70 <= data.count else { return nil }

        var channel = ChannelData(zoneIndex: 0, channelIndex: channelIndex)

        // From CPS traffic analysis, channel name is at offset ~60 from data start
        // Look for the 02 03 prefix before UTF-16LE channel name.
        // Use Data.range(of:) for O(n) marker search instead of O(n*m) stride decode.
        let searchRange = (dataStart + 50)..<min(dataStart + length, data.count - 2)
        if searchRange.lowerBound < searchRange.upperBound,
           let markerRange = data.range(of: Data([0x02, 0x03]), in: searchRange) {
            let nameStart = markerRange.upperBound
            let maxLen = min(32, data.count - nameStart)
            if maxLen >= 2 {
                let nameData = data[nameStart..<(nameStart + maxLen)]
                if let name = String(data: nameData, encoding: .utf16LittleEndian)?
                    .trimmingCharacters(in: .controlCharacters)
                    .trimmingCharacters(in: CharacterSet(["\0"])),
                   !name.isEmpty && name.count <= 16 {
                    channel.name = name
                }
            }
        }

        // If no name found, return nil
        if channel.name.starts(with: "CH") {
            return nil
        }

        return channel
    }

    /// Parses a zone record (0x0074) to extract zone name.
    /// Zone names are typically stored as UTF-16LE strings.
    private func parseZoneRecord(_ data: Data, dataStart: Int, length: Int, zoneIndex: Int, debug: Bool) -> ParsedZone? {
        guard dataStart + 10 <= data.count else { return nil }

        var zone = ParsedZone(position: zoneIndex)

        // Look for UTF-16LE zone name in the record.
        // Optimized: scan byte-pairs with raw pointer arithmetic to find the first run of
        // printable ASCII UTF-16LE code units (low byte 0x20-0x7E, high byte 0x00).
        // This avoids allocating a Data slice and calling String(data:encoding:) at every offset.
        let scanEnd = min(dataStart + length, data.count - 1)
        var foundName: String? = nil

        data.withUnsafeBytes { (ptr: UnsafeRawBufferPointer) in
            guard let base = ptr.baseAddress else { return }
            let bytes = base.assumingMemoryBound(to: UInt8.self)
            var i = dataStart
            while i < scanEnd - 1 {
                let lo = bytes[i]
                let hi = bytes[i + 1]
                // UTF-16LE ASCII code unit: high byte must be 0x00, low byte printable.
                guard lo >= 0x20 && lo <= 0x7E && hi == 0x00 else {
                    i += 1
                    continue
                }
                // Must start with a letter (A-Z or a-z).
                guard (lo >= 0x41 && lo <= 0x5A) || (lo >= 0x61 && lo <= 0x7A) else {
                    i += 2  // Skip this non-letter code unit
                    continue
                }
                // Collect the run.
                var charBuf = [UInt8]()
                charBuf.reserveCapacity(16)
                var j = i
                while j + 1 < scanEnd && bytes[j] >= 0x20 && bytes[j] <= 0x7E && bytes[j + 1] == 0x00 {
                    charBuf.append(bytes[j])
                    j += 2
                }
                let charCount = charBuf.count
                if charCount >= 2 && charCount <= 16 {
                    let candidate = String(bytes: charBuf, encoding: .ascii) ?? ""
                    if !candidate.isEmpty && !candidate.contains("\u{FFFD}") {
                        foundName = candidate
                        return
                    }
                }
                i = j > i ? j : i + 1
            }
        }

        guard let name = foundName else { return nil }
        zone.name = name
        if debug { RadioLog.programmer.debug("[PARSE] Zone name found: '\(name, privacy: .public)'") }
        return zone
    }

    /// Tries to extract TX/RX frequencies from data around a channel name.
    private func extractFrequenciesFromContext(_ data: Data, nameOffset: Int, channel: ChannelData, debug: Bool) -> ChannelData {
        var result = channel

        // Frequencies may be stored before the name in the record
        // Look for 4-byte values that could be frequencies
        // DMR frequencies are often stored in 10 Hz or 100 Hz units

        // Scan backward from name for frequency patterns
        for searchOffset in stride(from: max(0, nameOffset - 60), through: max(0, nameOffset - 20), by: 4) {
            if searchOffset + 4 <= data.count {
                // Try little-endian first (common in DMR)
                let freqLE = UInt32(data[searchOffset]) |
                            (UInt32(data[searchOffset + 1]) << 8) |
                            (UInt32(data[searchOffset + 2]) << 16) |
                            (UInt32(data[searchOffset + 3]) << 24)

                // Check if this looks like a frequency
                // UHF: 400-520 MHz (40000000-52000000 in 10Hz units)
                // VHF: 136-174 MHz (13600000-17400000 in 10Hz units)
                let freqMHz = Double(freqLE) / 100000.0  // Assuming 10Hz units

                if (freqMHz >= 400 && freqMHz <= 520) || (freqMHz >= 136 && freqMHz <= 174) {
                    if result.rxFrequencyHz == 0 {
                        result.rxFrequencyHz = UInt32(freqLE) * 10
                        if debug { RadioLog.programmer.debug("[PARSE] Found RX frequency: \(freqMHz) MHz at offset \(searchOffset)") }
                    } else if result.txFrequencyHz == 0 {
                        result.txFrequencyHz = UInt32(freqLE) * 10
                        if debug { RadioLog.programmer.debug("[PARSE] Found TX frequency: \(freqMHz) MHz at offset \(searchOffset)") }
                    }
                }
            }
        }

        return result
    }
}

/// Errors specific to MOTOTRBO programming.
public enum MOTOTRBOError: Error, LocalizedError {
    case connectionFailed(String)
    case sendFailed(String)
    case receiveFailed(String)
    case timeout
    case notImplemented(String)
    case protocolError(String)
    case authenticationFailed(String)

    public var errorDescription: String? {
        switch self {
        case .connectionFailed: return "Could not connect to radio"
        case .sendFailed: return "Communication error"
        case .receiveFailed: return "No response from radio"
        case .timeout: return "Radio is not responding"
        case .notImplemented: return "Feature not supported"
        case .protocolError: return "Unexpected radio response"
        case .authenticationFailed: return "Radio rejected connection"
        }
    }

    public var recoverySuggestion: String? {
        switch self {
        case .connectionFailed:
            return "Try: Ensure the radio is powered on and USB cable is connected. Most MOTOTRBO radios appear at 192.168.10.1"
        case .sendFailed:
            return "Try: Check USB cable connection and retry"
        case .receiveFailed:
            return "Try: The radio may have disconnected. Check connection and retry"
        case .timeout:
            return "Try: Unplug and reconnect the USB cable, power cycle the radio, then retry"
        case .notImplemented:
            return "This feature is not yet supported for this radio model"
        case .protocolError:
            return "Try: Restart the radio and retry. If the issue persists, the radio firmware may be incompatible"
        case .authenticationFailed:
            return "Try: Restart the radio and retry the connection"
        }
    }

    /// Technical details suitable for diagnostic disclosure.
    public var technicalDescription: String {
        switch self {
        case .connectionFailed(let msg): return "XNL connection failed: \(msg)"
        case .sendFailed(let msg): return "Send error: \(msg)"
        case .receiveFailed(let msg): return "Receive error: \(msg)"
        case .timeout: return "Radio communication timed out"
        case .notImplemented(let msg): return "Not implemented: \(msg)"
        case .protocolError(let msg): return "Protocol error: \(msg)"
        case .authenticationFailed(let msg): return "XNL authentication failed: \(msg)"
        }
    }
}
