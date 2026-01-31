import Foundation
import Network
import USBTransport

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
            print("MOTOTRBO connected, XNL address: 0x\(String(format: "%04X", assignedAddress))")

        case .authenticationFailed(let code):
            throw MOTOTRBOError.protocolError("XNL authentication failed (code: 0x\(String(format: "%02X", code)))")

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
            throw MOTOTRBOError.notImplemented("XCMP client not initialized")
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
            throw MOTOTRBOError.notImplemented("XCMP client not initialized")
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
            throw MOTOTRBOError.notImplemented("XCMP client not initialized")
        }

        progress(0.0)

        // Step 1: Get security key (CPS does this first)
        if debug { print("[READ] Getting security key...") }
        guard let securityKey = try await client.getSecurityKey(debug: debug) else {
            throw MOTOTRBOError.protocolError("Failed to get security key")
        }
        if debug { print("[READ] Security key: \(securityKey.map { String(format: "%02X", $0) }.joined(separator: " "))") }

        progress(0.1)

        // Step 2: Get device info
        if debug { print("[READ] Getting device info...") }
        let model = try await client.getModelNumberCPS(debug: debug)
        let firmware = try await client.getFirmwareVersionCPS(debug: debug)
        let serial = try await client.getSerialNumberCPS(debug: debug)
        let codeplugID = try await client.getCodeplugID(debug: debug)

        if debug {
            print("[READ] Model: \(model ?? "unknown")")
            print("[READ] Firmware: \(firmware ?? "unknown")")
            print("[READ] Serial: \(serial ?? "unknown")")
            print("[READ] Codeplug ID: \(codeplugID ?? "unknown")")
        }

        progress(0.2)

        // Detect family from model if not provided
        let radioFamily = family ?? RadioProtocolRegistry.detectFamily(from: model ?? "")

        // Step 3: Read codeplug records in batches
        if debug { print("[READ] Reading codeplug records for family: \(radioFamily ?? "unknown")...") }

        var allData = Data()
        let recordIDs = Self.recordIDs(for: radioFamily)
        let batchSize = 5  // Read 5 records at a time (like CPS does)
        let totalBatches = (recordIDs.count + batchSize - 1) / batchSize

        for (batchIndex, startIndex) in stride(from: 0, to: recordIDs.count, by: batchSize).enumerated() {
            let endIndex = min(startIndex + batchSize, recordIDs.count)
            let batchRecords = Array(recordIDs[startIndex..<endIndex])

            if debug { print("[READ] Batch \(batchIndex + 1)/\(totalBatches): records \(batchRecords.map { String(format: "0x%04X", $0) }.joined(separator: ", "))") }

            if let recordData = try await client.readCodeplugRecords(batchRecords, debug: debug) {
                allData.append(recordData)
                if debug { print("[READ] Got \(recordData.count) bytes") }
            }

            // Update progress (0.2 to 0.9)
            let readProgress = 0.2 + (0.7 * Double(batchIndex + 1) / Double(totalBatches))
            progress(readProgress)
        }

        progress(1.0)

        if debug { print("[READ] Complete! Total data: \(allData.count) bytes") }

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
        progress: @Sendable (Double) -> Void,
        debug: Bool = false
    ) async throws -> ParsedCodeplug {
        // Ensure connected
        if !(await isConnected) {
            try await connect()
        }

        guard let client = xcmpClient else {
            throw MOTOTRBOError.notImplemented("XCMP client not initialized")
        }

        var result = ParsedCodeplug()

        progress(0.0)

        // Step 1: Get security key
        if debug { print("[READ] Getting security key...") }
        _ = try await client.getSecurityKey(debug: debug)
        progress(0.02)

        // Step 2: Get device info
        if debug { print("[READ] Getting device info...") }
        result.modelNumber = try await client.getModelNumberCPS(debug: debug) ?? "Unknown"
        result.serialNumber = try await client.getSerialNumberCPS(debug: debug) ?? ""
        result.firmwareVersion = try await client.getFirmwareVersionCPS(debug: debug) ?? ""
        result.codeplugVersion = try await client.getCodeplugID(debug: debug) ?? ""

        if debug {
            print("[READ] Model: \(result.modelNumber)")
            print("[READ] Serial: \(result.serialNumber)")
            print("[READ] Firmware: \(result.firmwareVersion)")
        }

        progress(0.05)

        // Step 3: Get radio general settings
        if debug { print("[READ] Reading radio settings...") }
        let settings = try await client.readGeneralSettings(debug: debug)

        // Copy settings to result
        result.radioID = settings.radioID
        result.radioAlias = settings.radioAlias
        result.introScreenLine1 = settings.introLine1
        result.introScreenLine2 = settings.introLine2

        // Audio settings
        result.voxEnabled = settings.voxEnabled
        result.voxSensitivity = settings.voxSensitivity
        result.voxDelay = settings.voxDelay
        result.keypadTones = settings.keypadTones
        result.callAlertTone = settings.callAlertTone
        result.powerUpTone = settings.powerUpTone

        // Timing settings
        result.totTime = settings.totTime
        result.groupCallHangTime = settings.groupCallHangTime
        result.privateCallHangTime = settings.privateCallHangTime

        // Display settings
        result.backlightTime = settings.backlightTime
        result.defaultPowerLevel = settings.defaultPowerHigh

        // Signaling settings
        result.radioCheckEnabled = settings.radioCheckEnabled
        result.remoteMonitorEnabled = settings.remoteMonitorEnabled
        result.callConfirmation = settings.callConfirmation

        // GPS settings
        result.gpsEnabled = settings.gpsEnabled
        result.enhancedGNSSEnabled = settings.enhancedGNSS

        // Lone Worker settings
        result.loneWorkerEnabled = settings.loneWorkerEnabled
        result.loneWorkerResponseTime = settings.loneWorkerResponseTime

        // Man Down settings
        result.manDownEnabled = settings.manDownEnabled

        if debug {
            print("[READ] Radio ID: \(result.radioID)")
            print("[READ] Radio Alias: \(result.radioAlias)")
        }

        progress(0.08)

        // Step 4: Query zone structure
        // Try multiple methods to determine zone count
        if debug { print("[READ] Querying zones...") }

        var zoneCount = 0

        // Method 1: Try FeatureSetRequest (0x0037)
        if let zoneResult = try await client.queryZones(queryType: 0x01, debug: debug) {
            zoneCount = zoneResult.zoneCount
            if debug { print("[READ] FeatureSet query returned \(zoneCount) zones") }
        }

        // Method 2: Try reading zone count from radio settings
        if zoneCount == 0 {
            if let countReply = try await client.readRadioSetting(dataType: .zoneCount, debug: debug),
               let count = countReply.byteValue {
                zoneCount = Int(count)
                if debug { print("[READ] Radio settings returned \(zoneCount) zones") }
            }
        }

        // Method 3: Default to scanning and detecting zones
        let maxZones = zoneCount > 0 ? zoneCount : 16  // Scan up to 16 zones if count unknown
        let maxChannelsPerZone = 64  // Increased to handle larger zones

        if debug { print("[READ] Will scan up to \(maxZones) zones") }
        progress(0.10)

        // Step 5: Read zones and channels
        // Progress allocation: 10% to 50% for zones/channels
        var emptyZoneCount = 0

        for zoneIndex in 0..<maxZones {
            var zone = ParsedZone(name: "Zone \(zoneIndex + 1)", position: zoneIndex)

            // Try to read zone name
            if let zoneName = try await client.readZoneName(zone: UInt16(zoneIndex), debug: debug) {
                zone.name = zoneName
                if debug { print("[READ] Zone \(zoneIndex): \(zoneName)") }
            } else if debug {
                print("[READ] Zone \(zoneIndex): No name returned")
            }

            // Read channels in this zone
            var channelIndex = 0
            var emptyChannelCount = 0

            while channelIndex < maxChannelsPerZone {
                // Try to read channel name first to see if channel exists
                let nameReply = try await client.readChannelData(
                    zone: UInt16(zoneIndex),
                    channel: UInt16(channelIndex),
                    dataType: .channelName
                )

                // Parse the response
                let name = nameReply?.stringValue

                // If no name returned or error, check if we should continue
                if name == nil || name?.isEmpty == true {
                    emptyChannelCount += 1
                    // Stop after 2 consecutive empty channels
                    if emptyChannelCount >= 2 {
                        if debug { print("[READ] Zone \(zoneIndex) has \(channelIndex - emptyChannelCount + 1) channels") }
                        break
                    }
                    channelIndex += 1
                    continue
                }

                emptyChannelCount = 0  // Reset on valid channel

                // Read full channel data
                let channelData = try await client.readCompleteChannel(
                    zone: UInt16(zoneIndex),
                    channel: UInt16(channelIndex),
                    debug: debug
                )

                zone.channels.append(channelData)
                channelIndex += 1

                // Update progress (10% to 50%)
                let channelProgress = 0.10 + (0.40 * Double(zoneIndex * 10 + min(channelIndex, 10)) / Double(maxZones * 10))
                progress(min(channelProgress, 0.50))
            }

            if !zone.channels.isEmpty {
                result.zones.append(zone)
                emptyZoneCount = 0  // Reset on valid zone
            } else {
                emptyZoneCount += 1
                // Stop scanning if we've found zones and hit 2 consecutive empty zones
                if result.zones.count > 0 && emptyZoneCount >= 2 {
                    if debug { print("[READ] Stopping zone scan after \(result.zones.count) zones") }
                    break
                }
            }
        }

        progress(0.50)

        // Step 6: Read contacts
        // Progress allocation: 50% to 70%
        if debug { print("[READ] Reading contacts...") }
        let maxContacts = 256  // Typical max for XPR series
        var contactIndex = 0

        while contactIndex < maxContacts {
            guard let contactResult = try await client.readCompleteContact(index: UInt16(contactIndex), debug: debug) else {
                // No more contacts or couldn't read
                break
            }

            let contact = ParsedContact(
                name: contactResult.name,
                dmrID: contactResult.dmrID,
                type: ContactCallType(rawValue: ["Private Call", "Group Call", "All Call"][min(contactResult.callType, 2)]) ?? .group
            )
            var mutableContact = contact
            mutableContact.callReceiveTone = contactResult.callReceiveTone
            mutableContact.callAlert = contactResult.callAlert
            result.contacts.append(mutableContact)

            contactIndex += 1

            // Update progress (50% to 70%)
            let contactProgress = 0.50 + (0.20 * Double(contactIndex) / Double(maxContacts))
            progress(min(contactProgress, 0.70))
        }

        if debug { print("[READ] Read \(result.contacts.count) contacts") }
        progress(0.70)

        // Step 7: Read scan lists
        // Progress allocation: 70% to 85%
        if debug { print("[READ] Reading scan lists...") }
        let maxScanLists = 64  // Typical max
        var scanListIndex = 0

        while scanListIndex < maxScanLists {
            guard let scanResult = try await client.readCompleteScanList(index: UInt16(scanListIndex), debug: debug) else {
                break
            }

            var scanList = ParsedScanList(name: scanResult.name)
            scanList.talkbackEnabled = scanResult.talkbackEnabled
            scanList.holdTime = scanResult.holdTime

            // Convert members to ScanListMember
            for member in scanResult.members {
                let slm = ScanListMember(zoneIndex: member.zoneIndex, channelIndex: member.channelIndex)
                scanList.channelMembers.append(slm)
            }

            result.scanLists.append(scanList)
            scanListIndex += 1

            // Update progress (70% to 85%)
            let scanProgress = 0.70 + (0.15 * Double(scanListIndex) / Double(maxScanLists))
            progress(min(scanProgress, 0.85))
        }

        if debug { print("[READ] Read \(result.scanLists.count) scan lists") }
        progress(0.85)

        // Step 8: Read RX group lists
        // Progress allocation: 85% to 95%
        if debug { print("[READ] Reading RX group lists...") }
        let maxRxGroups = 64  // Typical max
        var rxGroupIndex = 0

        while rxGroupIndex < maxRxGroups {
            guard let rxResult = try await client.readCompleteRxGroup(index: UInt16(rxGroupIndex), debug: debug) else {
                break
            }

            var rxGroup = ParsedRxGroupList(name: rxResult.name)
            rxGroup.contactIndices = rxResult.contactIndices

            result.rxGroupLists.append(rxGroup)
            rxGroupIndex += 1

            // Update progress (85% to 95%)
            let rxProgress = 0.85 + (0.10 * Double(rxGroupIndex) / Double(maxRxGroups))
            progress(min(rxProgress, 0.95))
        }

        if debug { print("[READ] Read \(result.rxGroupLists.count) RX group lists") }
        progress(0.95)

        // Final progress
        progress(1.0)

        if debug {
            print("[READ] Complete!")
            print("[READ]   Zones: \(result.zones.count)")
            print("[READ]   Channels: \(result.totalChannels)")
            print("[READ]   Contacts: \(result.contacts.count)")
            print("[READ]   Scan Lists: \(result.scanLists.count)")
            print("[READ]   RX Groups: \(result.rxGroupLists.count)")
        }

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
            throw MOTOTRBOError.notImplemented("XCMP client not initialized")
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
        if startReply.data.count > 0 && startReply.data[0] != 0x00 {
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
        // Ensure connected
        if !(await isConnected) {
            try await connect()
        }

        guard let client = xcmpClient else {
            throw MOTOTRBOError.notImplemented("XCMP client not initialized")
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
        if startReply.data.count > 0 && startReply.data[0] != 0x00 {
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

        if unlockReply.data.count > 0 && unlockReply.data[0] != 0x00 {
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

            if transferReply.data.count > 0 && transferReply.data[0] != 0x00 {
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

        if validateReply.data.count > 0 && validateReply.data[0] != 0x00 {
            throw MOTOTRBOError.protocolError("CRC validation failed")
        }

        progress(0.80)

        // Step 6: Unpack and deploy
        let deployPacket = XCMPPacket.unpackAndDeploy(sessionID: sessionID)
        guard let deployReply = try await client.sendAndReceive(deployPacket, timeout: 60.0) else {
            throw MOTOTRBOError.protocolError("No reply to deploy request")
        }

        if deployReply.data.count > 0 && deployReply.data[0] != 0x00 {
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
            guard let c = xcmpClient else { return nil }
            return try await c.getModelNumber()
        }
        return try await client.getModelNumber()
    }

    /// Gets the radio serial number via XCMP.
    public func getSerialNumber() async throws -> String? {
        guard let client = xcmpClient else {
            try await connect()
            guard let c = xcmpClient else { return nil }
            return try await c.getSerialNumber()
        }
        return try await client.getSerialNumber()
    }

    /// Gets the radio ID via XCMP.
    public func getRadioID() async throws -> UInt32? {
        guard let client = xcmpClient else {
            try await connect()
            guard let c = xcmpClient else { return nil }
            return try await c.getRadioID()
        }
        return try await client.getRadioID()
    }

    /// Gets the firmware version via XCMP.
    public func getFirmwareVersion() async throws -> String? {
        guard let client = xcmpClient else {
            try await connect()
            guard let c = xcmpClient else { return nil }
            return try await c.getFirmwareVersion()
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
}

// MARK: - Parsed Codeplug Structure

/// Parsed codeplug data from MOTOTRBO radio.
/// This is the structured representation of zone/channel data.
public struct ParsedCodeplug: Sendable {
    // MARK: - Device Information (read-only from radio)
    public var modelNumber: String = ""
    public var serialNumber: String = ""
    public var firmwareVersion: String = ""
    public var codeplugVersion: String = ""

    // MARK: - General Settings
    public var radioID: UInt32 = 1
    public var radioAlias: String = "Radio"
    public var introScreenLine1: String = ""
    public var introScreenLine2: String = ""
    public var powerOnPassword: String = ""
    public var defaultPowerLevel: Bool = true  // true=High, false=Low

    // MARK: - Display Settings
    public var backlightTime: UInt8 = 5  // seconds, 0=Always On
    public var backlightAuto: Bool = true

    // MARK: - Audio Settings
    public var voxEnabled: Bool = false
    public var voxSensitivity: UInt8 = 3  // 1-10
    public var voxDelay: UInt16 = 500  // ms
    public var keypadTones: Bool = true
    public var callAlertTone: Bool = true
    public var powerUpTone: Bool = true
    public var audioEnhancement: Bool = false

    // MARK: - Timing Settings
    public var totTime: UInt16 = 60  // seconds (0=infinite)
    public var totResetTime: UInt8 = 0  // seconds
    public var groupCallHangTime: UInt16 = 5000  // ms
    public var privateCallHangTime: UInt16 = 5000  // ms

    // MARK: - Signaling Settings
    public var radioCheckEnabled: Bool = true
    public var remoteMonitorEnabled: Bool = false
    public var callConfirmation: Bool = true
    public var emergencyAlertType: UInt8 = 0  // 0=Alarm, 1=Silent, 2=AlarmWithCall
    public var emergencyDestinationID: UInt32 = 0

    // MARK: - GPS/GNSS Settings
    public var gpsEnabled: Bool = false
    public var gpsRevertChannelEnabled: Bool = false
    public var enhancedGNSSEnabled: Bool = false

    // MARK: - Lone Worker Settings
    public var loneWorkerEnabled: Bool = false
    public var loneWorkerResponseTime: UInt16 = 30  // seconds
    public var loneWorkerReminderTime: UInt16 = 300  // seconds

    // MARK: - Man Down Settings (if supported)
    public var manDownEnabled: Bool = false
    public var manDownDelay: UInt16 = 10  // seconds

    // MARK: - Zones and Channels
    public var zones: [ParsedZone] = []

    // MARK: - Contacts
    public var contacts: [ParsedContact] = []

    // MARK: - Scan Lists
    public var scanLists: [ParsedScanList] = []

    // MARK: - RX Group Lists
    public var rxGroupLists: [ParsedRxGroupList] = []

    // MARK: - Text Messages (pre-programmed)
    public var textMessages: [PresetTextMessage] = []

    // MARK: - Emergency Systems
    public var emergencySystems: [EmergencySystem] = []

    // MARK: - Button Assignments
    public var topButtonShortPress: ButtonFunction = .none
    public var topButtonLongPress: ButtonFunction = .none
    public var sideButton1ShortPress: ButtonFunction = .none
    public var sideButton1LongPress: ButtonFunction = .none
    public var sideButton2ShortPress: ButtonFunction = .none
    public var sideButton2LongPress: ButtonFunction = .none

    /// Total number of channels across all zones.
    public var totalChannels: Int {
        zones.reduce(0) { $0 + $1.channels.count }
    }

    public init() {}
}

/// Pre-programmed text message
public struct PresetTextMessage: Sendable, Identifiable {
    public var id = UUID()
    public var text: String = ""

    public init(text: String = "") {
        self.text = text
    }
}

/// Emergency system definition
public struct EmergencySystem: Sendable, Identifiable {
    public var id = UUID()
    public var name: String = "Emergency"
    public var alarmType: UInt8 = 0  // 0=Alarm, 1=AlarmWithCall, 2=AlarmWithVoice, 3=Silent
    public var mode: UInt8 = 0  // 0=Regular, 1=Acknowledged
    public var hotMicEnabled: Bool = false
    public var hotMicDuration: UInt8 = 10  // seconds
    public var destinationID: UInt32 = 0
    public var callType: UInt8 = 1  // 0=Private, 1=Group, 2=AllCall

    public init() {}
}

/// Available button functions
public enum ButtonFunction: String, Sendable, CaseIterable {
    case none = "None"
    case monitor = "Monitor"
    case scan = "Scan"
    case emergency = "Emergency"
    case zoneSelect = "Zone Select"
    case powerLevel = "Power Level"
    case talkaround = "Talkaround"
    case vox = "VOX"
    case oneTouchCall = "One Touch Call"
    case textMessage = "Text Message"
    case privacy = "Privacy"
    case audioToggle = "Audio Toggle"
    case bluetooth = "Bluetooth"
    case gps = "GPS"
    case manDown = "Man Down"
    case loneWorker = "Lone Worker"
    case radioCheck = "Radio Check"
    case remoteMonitor = "Remote Monitor"
    case callLog = "Call Log"
    case contacts = "Contacts"
}

/// A zone in the parsed codeplug.
public struct ParsedZone: Sendable {
    public var name: String = "Zone"
    public var position: Int = 0
    public var channels: [ChannelData] = []

    public init(name: String = "Zone", position: Int = 0) {
        self.name = name
        self.position = position
    }
}

/// A contact in the parsed codeplug.
public struct ParsedContact: Sendable, Identifiable {
    public var id = UUID()
    public var name: String = "Contact"
    public var contactType: ContactCallType = .group
    public var dmrID: UInt32 = 0
    public var callReceiveTone: Bool = true
    public var callAlert: Bool = false

    public init(name: String = "Contact", dmrID: UInt32 = 0, type: ContactCallType = .group) {
        self.name = name
        self.dmrID = dmrID
        self.contactType = type
    }
}

/// Contact call types.
public enum ContactCallType: String, Sendable, CaseIterable {
    case privateCall = "Private Call"
    case group = "Group Call"
    case allCall = "All Call"
}

/// A scan list in the parsed codeplug.
public struct ParsedScanList: Sendable, Identifiable {
    public var id = UUID()
    public var name: String = "Scan List"
    public var channelMembers: [ScanListMember] = []
    public var priorityChannel1Index: Int? = nil
    public var priorityChannel2Index: Int? = nil
    public var talkbackEnabled: Bool = true
    public var holdTime: UInt16 = 500  // ms

    public init(name: String = "Scan List") {
        self.name = name
    }
}

/// A member of a scan list.
public struct ScanListMember: Sendable, Identifiable {
    public var id = UUID()
    public var zoneIndex: Int
    public var channelIndex: Int

    public init(zoneIndex: Int, channelIndex: Int) {
        self.zoneIndex = zoneIndex
        self.channelIndex = channelIndex
    }
}

/// An RX group list in the parsed codeplug.
public struct ParsedRxGroupList: Sendable, Identifiable {
    public var id = UUID()
    public var name: String = "RX Group"
    public var contactIndices: [Int] = []  // Indices into contacts array

    public init(name: String = "RX Group") {
        self.name = name
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
        case .connectionFailed(let msg): return "Connection failed: \(msg)"
        case .sendFailed(let msg): return "Send failed: \(msg)"
        case .receiveFailed(let msg): return "Receive failed: \(msg)"
        case .timeout: return "Communication timeout"
        case .notImplemented(let msg): return "Not implemented: \(msg)"
        case .protocolError(let msg): return "Protocol error: \(msg)"
        case .authenticationFailed(let msg): return "Authentication failed: \(msg)"
        }
    }
}
