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

        // Step 3: Start a reading session using CPS method (0x0105)
        // This is what CPS does - NOT programming mode (0x0106/0x0300/0x0301)
        if debug { RadioLog.programmer.debug("[READ] Starting read session (0x0105)...") }
        let availableRecords = try await client.startReadSession(debug: debug)
        if availableRecords.isEmpty {
            if debug { RadioLog.programmer.debug("[READ] Session start returned no records, will try fallback...") }
        } else {
            if debug { RadioLog.programmer.debug("[READ] Session started with \(availableRecords.count, privacy: .public) available records") }
        }

        progress(0.08)

        // Step 4: Get radio general settings
        if debug { RadioLog.programmer.debug("[READ] Reading radio settings...") }
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
            RadioLog.programmer.debug("[READ] Radio ID: \(result.radioID, privacy: .public)")
            RadioLog.programmer.debug("[READ] Radio Alias: \(result.radioAlias, privacy: .public)")
        }

        progress(0.12)

        // Step 5: Read channels using indexed record format (0x0FFB)
        // This is the correct CPS 2.0 protocol - channels are indexed records
        if debug { RadioLog.programmer.debug("[READ] Reading channels using indexed record format (0x0FFB)...") }

        let channelRecords = try await client.readAllChannels(debug: debug) { channelProgress in
            // Map channel reading progress to 12% - 45%
            progress(0.12 + (0.33 * channelProgress))
        }

        if !channelRecords.isEmpty {
            if debug { RadioLog.programmer.debug("[READ] Successfully read \(channelRecords.count, privacy: .public) channels from indexed records") }

            // Convert ParsedChannelRecord to ChannelData and create a default zone
            var zone = ParsedZone(name: "Zone 1", position: 0)
            for record in channelRecords {
                let channelData = record.toChannelData(zoneIndex: 0)
                zone.channels.append(channelData)

                if debug && zone.channels.count <= 5 {
                    let msg = "[READ] Channel \(record.index): '\(record.name)' @ \(record.rxFrequencyMHz) MHz"
                    RadioLog.programmer.debug("\(msg, privacy: .public)")
                }
            }
            result.zones.append(zone)
        } else {
            if debug { RadioLog.programmer.debug("[READ] Indexed channel read returned no channels, trying fallback...") }

            // Fallback: Try the old metadata-based approach
            var allRecordData = Data()

            // Read zone/channel mapping records
            let mappingRecords: [UInt16] = [0x0084, 0x0093, 0x009D, 0x005E, 0x005F, 0x0060]
            if let batchData = try await client.readCodeplugRecords(mappingRecords, debug: debug) {
                if debug { RadioLog.programmer.debug("[READ] Fallback got \(batchData.count, privacy: .public) bytes from mapping records") }
                allRecordData.append(batchData)
            }

            if !allRecordData.isEmpty {
                // Exclude known settings strings like the radio alias
                var excludeStrings: Set<String> = []
                if !result.radioAlias.isEmpty && result.radioAlias != "Radio" {
                    excludeStrings.insert(result.radioAlias)
                }
                if !result.introScreenLine1.isEmpty {
                    excludeStrings.insert(result.introScreenLine1)
                }
                if !result.introScreenLine2.isEmpty {
                    excludeStrings.insert(result.introScreenLine2)
                }
                let parsed = parseCodeplugRecordData(allRecordData, excludeStrings: excludeStrings, debug: debug)
                if !parsed.zones.isEmpty {
                    result.zones = parsed.zones
                    if debug { RadioLog.programmer.debug("[READ] Fallback parsed \(result.zones.count, privacy: .public) zones") }
                }
            }
        }

        progress(0.45)

        // Step 6: If CodeplugRead didn't give us zones, try CloneRead method
        if result.zones.isEmpty {
            if debug { print("[READ] CodeplugRead didn't return zones, trying CloneRead...") }

            // Query zone structure using multiple methods
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

            // Method 3: Default to scanning
            let maxZones = zoneCount > 0 ? zoneCount : 16
            let maxChannelsPerZone = 64

            if debug { print("[READ] Will scan up to \(maxZones) zones with CloneRead") }

            var emptyZoneCount = 0

            for zoneIndex in 0..<maxZones {
                var zone = ParsedZone(name: "Zone \(zoneIndex + 1)", position: zoneIndex)

                // Try to read zone name using CloneRead
                if let zoneName = try await client.readZoneName(zone: UInt16(zoneIndex), debug: debug) {
                    zone.name = zoneName
                    if debug { RadioLog.programmer.debug("[READ] Zone \(zoneIndex, privacy: .public): \(zoneName, privacy: .public)") }
                } else if debug {
                    RadioLog.programmer.debug("[READ] Zone \(zoneIndex, privacy: .public): No name returned from CloneRead")
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

                    // Check for error response
                    if let reply = nameReply {
                        if debug && channelIndex == 0 {
                            let msg = "[READ] CloneRead reply for Z\(zoneIndex)C\(channelIndex): error=\(reply.errorCode.rawValue) data=\(reply.data.count) bytes"
                            RadioLog.programmer.debug("\(msg, privacy: .public)")
                        }
                    }

                    let name = nameReply?.stringValue

                    if name == nil || name?.isEmpty == true {
                        emptyChannelCount += 1
                        if emptyChannelCount >= 2 {
                            if debug {
                                let channelCount = channelIndex - emptyChannelCount + 1
                                RadioLog.programmer.debug("[READ] Zone \(zoneIndex, privacy: .public) has \(channelCount, privacy: .public) channels")
                            }
                            break
                        }
                        channelIndex += 1
                        continue
                    }

                    emptyChannelCount = 0

                    // Read full channel data
                    let channelData = try await client.readCompleteChannel(
                        zone: UInt16(zoneIndex),
                        channel: UInt16(channelIndex),
                        debug: debug
                    )

                    zone.channels.append(channelData)
                    channelIndex += 1

                    let channelProgress = 0.20 + (0.30 * Double(zoneIndex * 10 + min(channelIndex, 10)) / Double(maxZones * 10))
                    progress(min(channelProgress, 0.50))
                }

                if !zone.channels.isEmpty {
                    result.zones.append(zone)
                    emptyZoneCount = 0
                } else {
                    emptyZoneCount += 1
                    if !result.zones.isEmpty && emptyZoneCount >= 2 {
                        if debug { RadioLog.programmer.debug("[READ] Stopping zone scan after \(result.zones.count, privacy: .public) zones") }
                        break
                    }
                }
            }
        }

        progress(0.50)

        // Step 6: Read contacts
        // Progress allocation: 50% to 70%
        if debug { RadioLog.programmer.debug("[READ] Reading contacts...") }
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

        if debug { RadioLog.programmer.debug("[READ] Read \(result.contacts.count, privacy: .public) contacts") }
        progress(0.70)

        // Step 7: Read scan lists
        // Progress allocation: 70% to 85%
        if debug { RadioLog.programmer.debug("[READ] Reading scan lists...") }
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

        // Exit programming mode
        if debug { print("[READ] Exiting programming mode...") }
        if let connection = xnlConnection {
            let exitCmd = Data([
                UInt8(XCMPOpcode.ishProgramMode.rawValue >> 8),
                UInt8(XCMPOpcode.ishProgramMode.rawValue & 0xFF),
                ProgramModeAction.exitProgramMode.rawValue  // 0x00
            ])
            _ = try? await connection.sendXCMP(exitCmd, timeout: 2.0, debug: debug)
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
            if debug { print("[PARSE] Data too short to contain records") }
            return (zones, channels)
        }

        if debug {
            // Show overview of response data
            print("[PARSE] Total data: \(data.count) bytes")
            print("[PARSE] First 64 bytes: \(data.prefix(64).map { String(format: "%02X", $0) }.joined(separator: " "))")

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
            print("[PARSE] Found \(dataRecords) data records (81 00) and \(metadataRecords) metadata records (81 04)")
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
            print("[PARSE] Skipped \(offset) header bytes to first record")
        }

        // Collect all unique record IDs to understand the data format
        var recordIDSet: Set<UInt16> = []
        var recordsFound = 0
        var metadataFound = 0

        // First pass: understand what patterns we have
        // Try both "81 00 00 80" (strict) and "81 00" (relaxed) patterns
        if debug {
            print("[PARSE] Analyzing response format...")
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
            print("[PARSE] Found \(strictPattern) strict (81 00 00 80) and \(relaxedPattern) relaxed (81 00) patterns")
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
                    print("[PARSE] DATA record 0x\(String(format: "%04X", recordID)) at offset \(offset), length \(recordLength)")
                    // Show first few bytes of record header
                    let headerPreview = data[offset..<min(offset + 16, data.count)]
                    print("[PARSE] Header bytes: \(headerPreview.map { String(format: "%02X", $0) }.joined(separator: " "))")
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
                            if debug { print("[PARSE] Extracted channel: \(channel.name)") }
                        }

                    case 0x0093:
                        // Zone/channel mapping - may contain zone structure
                        if debug { print("[PARSE] Found zone mapping record (0x0093)") }

                    case 0x009D:
                        // Zone configuration
                        if debug { print("[PARSE] Found zone config record (0x009D)") }

                    case 0x0074:
                        // Zone list - parse zone name
                        if debug { print("[PARSE] Found zone list record (0x0074)") }
                        if let zone = parseZoneRecord(data, dataStart: dataStart, length: recordLength, zoneIndex: zones.count, debug: debug) {
                            zones.append(zone)
                            if debug { print("[PARSE] Extracted zone: \(zone.name)") }
                        }

                    default:
                        if debug && recordsFound < 5 {
                            // Show some data for unknown records
                            let preview = data[dataStart..<min(dataStart + 32, data.count)]
                            let recordIDHex = String(format: "%04X", recordID)
                            let previewHex = preview.map { String(format: "%02X", $0) }.joined(separator: " ")
                            print("[PARSE] Unknown record 0x\(recordIDHex): \(previewHex)...")
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
                    print("[PARSE] METADATA record 0x\(String(format: "%04X", recordID)) - no data, just existence info")
                }

                offset += 14  // Skip the metadata entry
                continue
            }

            offset += 1
        }

        if debug {
            print("[PARSE] Structured parsing: \(recordsFound) data records, \(metadataFound) metadata entries")
            if !recordIDSet.isEmpty {
                let sortedIDs = recordIDSet.sorted().map { String(format: "0x%04X", $0) }
                print("[PARSE] Unique record IDs found: \(sortedIDs.joined(separator: ", "))")
            }
            if metadataFound > 0 && recordsFound == 0 {
                print("[PARSE] ⚠️ Got only metadata (81 04), no actual data (81 00). Need different request format!")
            }
        }

        // FALLBACK: Direct UTF-16LE string extraction (no record structure required)
        // This is more reliable when the record format doesn't match our expectations
        if debug {
            print("[PARSE] Running fallback UTF-16LE string extraction...")
        }

        offset = 0
        while offset < data.count - 20 {
            // Look for UTF-16LE strings directly: ASCII char (0x20-0x7E) followed by 0x00
            if data[offset] >= 0x41 && data[offset] <= 0x7A && // A-z
               offset + 1 < data.count && data[offset + 1] == 0x00 {
                // Potential UTF-16LE string start
                var str = ""
                var j = offset
                while j < data.count - 1 &&
                      data[j] >= 0x20 && data[j] <= 0x7E &&
                      data[j + 1] == 0x00 {
                    str.append(Character(UnicodeScalar(data[j])))
                    j += 2
                }

                // Valid channel/zone name: 3-16 characters, starts with letter
                // Filter out false positives: language codes, system strings, fragments, and known settings
                if str.count >= 3 && str.count <= 16 && str.first?.isLetter == true {
                    // Skip known non-channel strings
                    let lowercased = str.lowercased()

                    // Check if this matches any excluded string (radio alias, zone names, etc.)
                    let isExcluded = excludeLowercased.contains(lowercased) ||
                                    excludeLowercased.contains { excluded in
                                        lowercased.contains(excluded) || excluded.contains(lowercased)
                                    }

                    let isLanguageCode = lowercased.contains("-") && str.count <= 6 // e.g., "en-us"
                    let isSystemString = ["talkset", "scanlist", "contact", "group", "radio", "zone"]
                        .contains { lowercased == $0 }
                    let isFragment = lowercased.hasPrefix("et ") || lowercased.hasPrefix("io") ||
                                    lowercased.hasPrefix("dio") || lowercased.hasPrefix("set ") ||
                                    lowercased.hasPrefix("kset")

                    if !isExcluded && !isLanguageCode && !isSystemString && !isFragment {
                        // Check if already found or is a substring/suffix of an existing name
                        let existingNames = channels.map { $0.name }
                        let existingZoneNames = zones.map { $0.name }
                        let isDuplicate = existingNames.contains(str) || existingZoneNames.contains(str)
                        let isSubstring = existingNames.contains { $0.contains(str) && $0 != str }
                        // Check if this is a longer version of an existing name (e.g., "dRyan's Radio" vs "Ryan's Radio")
                        let hasOverlap = existingNames.contains { existing in
                            str.hasSuffix(existing) || existing.hasSuffix(str)
                        }

                        if !isDuplicate && !isSubstring && !hasOverlap {
                            var channel = ChannelData(zoneIndex: 0, channelIndex: channels.count)
                            channel.name = str
                            channels.append(channel)
                            if debug && channels.count <= 10 {
                                print("[PARSE] UTF-16LE channel found: '\(str)' at offset \(offset)")
                            }
                        }
                    }
                }
                offset = j  // Skip past the string
                continue
            }
            offset += 1
        }

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
                                    print("[PARSE] Found channel name '\(name)' at offset \(offset)")
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
            print("[PARSE] Extracted \(zones.count) zones with \(channels.count) channels total")
        }

        return (zones, channels)
    }

    /// Parses a channel data record (0x0084).
    private func parseChannelRecord(_ data: Data, dataStart: Int, length: Int, channelIndex: Int, debug: Bool) -> ChannelData? {
        guard dataStart + 70 <= data.count else { return nil }

        var channel = ChannelData(zoneIndex: 0, channelIndex: channelIndex)

        // From CPS traffic analysis, channel name is at offset ~60 from data start
        // Look for the 02 03 prefix before UTF-16LE channel name
        for searchOffset in stride(from: dataStart + 50, to: min(dataStart + length, data.count - 20), by: 1) {
            if data[searchOffset] == 0x02 && data[searchOffset + 1] == 0x03 {
                let nameStart = searchOffset + 2
                let maxLen = min(32, data.count - nameStart)
                let nameData = Data(data[nameStart..<(nameStart + maxLen)])

                if let name = String(data: nameData, encoding: .utf16LittleEndian)?
                    .trimmingCharacters(in: .controlCharacters)
                    .trimmingCharacters(in: CharacterSet(["\0"])) {
                    if !name.isEmpty && name.count <= 16 {
                        channel.name = name
                        break
                    }
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

        // Look for UTF-16LE zone name in the record
        // Try different offsets for the name
        for searchOffset in stride(from: dataStart, to: min(dataStart + length, data.count - 10), by: 1) {
            // Look for printable UTF-16LE text
            let nameData = Data(data[searchOffset..<min(searchOffset + 32, data.count)])

            if let name = String(data: nameData, encoding: .utf16LittleEndian)?
                .trimmingCharacters(in: .controlCharacters)
                .trimmingCharacters(in: CharacterSet(["\0"])) {
                if name.count >= 2 && name.count <= 16 && !name.contains("\u{FFFD}") && name.first?.isLetter == true {
                    zone.name = name
                    if debug { print("[PARSE] Zone name found: '\(name)' at offset \(searchOffset)") }
                    return zone
                }
            }
        }

        return nil
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
                        if debug { print("[PARSE] Found RX frequency: \(freqMHz) MHz at offset \(searchOffset)") }
                    } else if result.txFrequencyHz == 0 {
                        result.txFrequencyHz = UInt32(freqLE) * 10
                        if debug { print("[PARSE] Found TX frequency: \(freqMHz) MHz at offset \(searchOffset)") }
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
