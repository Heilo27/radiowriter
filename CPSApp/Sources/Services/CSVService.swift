import Foundation
import RadioProgrammer

/// Service for importing and exporting channel and contact data as CSV.
/// Designed for CHIRP compatibility and fleet management workflows.
final class CSVService {

    // MARK: - Channel CSV Export

    /// Column headers for channel CSV export.
    static let channelHeaders = [
        "Zone Name",
        "Channel Number",
        "Channel Name",
        "RX Frequency (MHz)",
        "TX Frequency (MHz)",
        "Mode",
        "Color Code",
        "Time Slot",
        "Contact ID",
        "Contact Type",
        "Power",
        "Bandwidth",
        "RX Group List",
        "Scan List",
        "TOT (sec)",
        "TX CTCSS (Hz)",
        "RX CTCSS (Hz)",
        "TX DCS",
        "RX DCS",
        "Squelch Type",
        "Privacy Type",
        "Privacy Key"
    ]

    /// Exports channels from a ParsedCodeplug to CSV format.
    /// - Parameter codeplug: The parsed codeplug containing zones and channels
    /// - Returns: CSV string with headers and data rows
    static func exportChannels(from codeplug: ParsedCodeplug) -> String {
        var lines: [String] = []

        // Header row
        lines.append(channelHeaders.joined(separator: ","))

        // Data rows
        for zone in codeplug.zones {
            for channel in zone.channels {
                let row = buildChannelRow(channel: channel, zoneName: zone.name)
                lines.append(row)
            }
        }

        return lines.joined(separator: "\n")
    }

    private static func buildChannelRow(channel: ChannelData, zoneName: String) -> String {
        let fields: [String] = [
            escapeCSV(zoneName),
            "\(channel.channelIndex + 1)",
            escapeCSV(channel.name),
            String(format: "%.6f", channel.rxFrequencyMHz),
            String(format: "%.6f", channel.txFrequencyMHz),
            channel.isDigital ? "Digital" : "Analog",
            "\(channel.colorCode)",
            "\(channel.timeSlot)",
            "\(channel.contactID)",
            contactTypeString(channel.contactType),
            channel.txPowerHigh ? "High" : "Low",
            channel.bandwidthWide ? "25" : "12.5",
            "\(channel.rxGroupListID)",
            "\(channel.scanListID)",
            "\(channel.totTimeout)",
            channel.txCTCSSHz > 0 ? String(format: "%.1f", channel.txCTCSSHz) : "",
            channel.rxCTCSSHz > 0 ? String(format: "%.1f", channel.rxCTCSSHz) : "",
            channel.txDCSCode > 0 ? "D\(String(format: "%03o", channel.txDCSCode))\(channel.dcsInvert ? "I" : "N")" : "",
            channel.rxDCSCode > 0 ? "D\(String(format: "%03o", channel.rxDCSCode))\(channel.dcsInvert ? "I" : "N")" : "",
            squelchTypeString(channel.rxSquelchType),
            privacyTypeString(channel.privacyType),
            channel.privacyKey > 0 ? "\(channel.privacyKey)" : ""
        ]

        return fields.joined(separator: ",")
    }

    // MARK: - Contact CSV Export

    /// Column headers for contact CSV export.
    static let contactHeaders = [
        "Contact Name",
        "DMR ID",
        "Call Type",
        "Receive Tone",
        "Call Alert"
    ]

    /// Exports contacts from a ParsedCodeplug to CSV format.
    /// - Parameter codeplug: The parsed codeplug containing contacts
    /// - Returns: CSV string with headers and data rows
    static func exportContacts(from codeplug: ParsedCodeplug) -> String {
        var lines: [String] = []

        // Header row
        lines.append(contactHeaders.joined(separator: ","))

        // Data rows
        for contact in codeplug.contacts {
            let row = buildContactRow(contact: contact)
            lines.append(row)
        }

        return lines.joined(separator: "\n")
    }

    private static func buildContactRow(contact: ParsedContact) -> String {
        let fields: [String] = [
            escapeCSV(contact.name),
            "\(contact.dmrID)",
            contact.contactType.rawValue,
            contact.callReceiveTone ? "Yes" : "No",
            contact.callAlert ? "Yes" : "No"
        ]

        return fields.joined(separator: ",")
    }

    // MARK: - Channel CSV Import

    /// Result of parsing a channel CSV file.
    struct ChannelImportResult {
        var channels: [(zoneName: String, channel: ChannelData)]
        var errors: [ImportError]
        var warnings: [String]
    }

    struct ImportError: Identifiable {
        let id = UUID()
        let row: Int
        let field: String
        let message: String
    }

    /// Parses a CSV string and returns channels with validation results.
    /// - Parameter csvString: The CSV content to parse
    /// - Returns: Import result with channels, errors, and warnings
    static func importChannels(from csvString: String) -> ChannelImportResult {
        var channels: [(zoneName: String, channel: ChannelData)] = []
        var errors: [ImportError] = []
        var warnings: [String] = []

        let lines = csvString.components(separatedBy: .newlines)
            .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }

        guard lines.count > 1 else {
            errors.append(ImportError(row: 0, field: "", message: "CSV file is empty or has no data rows"))
            return ChannelImportResult(channels: [], errors: errors, warnings: warnings)
        }

        // Parse header to find column indices
        let headerLine = lines[0]
        let headers = parseCSVLine(headerLine)
        let columnMap = buildColumnMap(headers)

        // Validate required columns
        let requiredColumns = ["Channel Name", "RX Frequency (MHz)"]
        for required in requiredColumns {
            if columnMap[required] == nil {
                errors.append(ImportError(row: 1, field: required, message: "Required column '\(required)' not found"))
            }
        }

        guard errors.isEmpty else {
            return ChannelImportResult(channels: [], errors: errors, warnings: warnings)
        }

        // Parse data rows
        for (index, line) in lines.enumerated().dropFirst() {
            let rowNum = index + 1
            let fields = parseCSVLine(line)

            guard fields.count >= 2 else {
                warnings.append("Row \(rowNum): Skipped - too few fields")
                continue
            }

            var channel = ChannelData()

            // Zone name (optional, defaults to "Zone 1")
            let zoneName = getField(fields, columnMap, "Zone Name") ?? "Zone 1"

            // Channel name (required)
            if let name = getField(fields, columnMap, "Channel Name") {
                channel.name = name
            } else {
                errors.append(ImportError(row: rowNum, field: "Channel Name", message: "Missing channel name"))
                continue
            }

            // Channel number
            if let numStr = getField(fields, columnMap, "Channel Number"),
               let num = Int(numStr) {
                channel.channelIndex = num - 1
            }

            // RX Frequency (required)
            if let rxStr = getField(fields, columnMap, "RX Frequency (MHz)"),
               let rxMHz = Double(rxStr) {
                channel.rxFrequencyHz = UInt32(rxMHz * 1_000_000)
            } else {
                errors.append(ImportError(row: rowNum, field: "RX Frequency", message: "Invalid or missing RX frequency"))
                continue
            }

            // TX Frequency (defaults to RX if not specified)
            if let txStr = getField(fields, columnMap, "TX Frequency (MHz)"),
               let txMHz = Double(txStr) {
                channel.txFrequencyHz = UInt32(txMHz * 1_000_000)
            } else {
                channel.txFrequencyHz = channel.rxFrequencyHz  // Simplex
            }

            // Mode
            if let mode = getField(fields, columnMap, "Mode")?.lowercased() {
                channel.isDigital = mode.contains("digital") || mode.contains("dmr")
            }

            // Color Code
            if let ccStr = getField(fields, columnMap, "Color Code"),
               let cc = Int(ccStr), cc >= 0 && cc <= 15 {
                channel.colorCode = cc
            }

            // Time Slot
            if let tsStr = getField(fields, columnMap, "Time Slot"),
               let ts = Int(tsStr), ts == 1 || ts == 2 {
                channel.timeSlot = ts
            }

            // Contact ID
            if let idStr = getField(fields, columnMap, "Contact ID"),
               let contactID = UInt32(idStr) {
                channel.contactID = contactID
            }

            // Contact Type
            if let typeStr = getField(fields, columnMap, "Contact Type") {
                channel.contactType = parseContactType(typeStr)
            }

            // Power
            if let power = getField(fields, columnMap, "Power")?.lowercased() {
                channel.txPowerHigh = !power.contains("low")
            }

            // Bandwidth
            if let bwStr = getField(fields, columnMap, "Bandwidth") {
                channel.bandwidthWide = bwStr.contains("25")
            }

            // RX Group List
            if let rgStr = getField(fields, columnMap, "RX Group List"),
               let rg = UInt8(rgStr) {
                channel.rxGroupListID = rg
            }

            // Scan List
            if let slStr = getField(fields, columnMap, "Scan List"),
               let sl = UInt8(slStr) {
                channel.scanListID = sl
            }

            // TOT
            if let totStr = getField(fields, columnMap, "TOT (sec)"),
               let tot = UInt16(totStr) {
                channel.totTimeout = tot
            }

            // CTCSS/DCS for analog channels
            if let txCTCSS = getField(fields, columnMap, "TX CTCSS (Hz)"),
               let hz = Double(txCTCSS) {
                channel.txCTCSSHz = hz
            }
            if let rxCTCSS = getField(fields, columnMap, "RX CTCSS (Hz)"),
               let hz = Double(rxCTCSS) {
                channel.rxCTCSSHz = hz
            }
            if let txDCS = getField(fields, columnMap, "TX DCS") {
                channel.txDCSCode = parseDCSCode(txDCS)
            }
            if let rxDCS = getField(fields, columnMap, "RX DCS") {
                channel.rxDCSCode = parseDCSCode(rxDCS)
            }

            // Squelch Type
            if let sqStr = getField(fields, columnMap, "Squelch Type") {
                channel.rxSquelchType = parseSquelchType(sqStr)
            }

            // Privacy
            if let privType = getField(fields, columnMap, "Privacy Type") {
                channel.privacyType = parsePrivacyType(privType)
            }
            if let privKey = getField(fields, columnMap, "Privacy Key"),
               let key = UInt8(privKey) {
                channel.privacyKey = key
            }

            channels.append((zoneName: zoneName, channel: channel))
        }

        return ChannelImportResult(channels: channels, errors: errors, warnings: warnings)
    }

    // MARK: - Contact CSV Import

    /// Result of parsing a contact CSV file.
    struct ContactImportResult {
        var contacts: [ParsedContact]
        var errors: [ImportError]
        var warnings: [String]
    }

    /// Parses a CSV string and returns contacts with validation results.
    /// - Parameter csvString: The CSV content to parse
    /// - Returns: Import result with contacts, errors, and warnings
    static func importContacts(from csvString: String) -> ContactImportResult {
        var contacts: [ParsedContact] = []
        var errors: [ImportError] = []
        var warnings: [String] = []

        let lines = csvString.components(separatedBy: .newlines)
            .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }

        guard lines.count > 1 else {
            errors.append(ImportError(row: 0, field: "", message: "CSV file is empty or has no data rows"))
            return ContactImportResult(contacts: [], errors: errors, warnings: warnings)
        }

        // Parse header
        let headers = parseCSVLine(lines[0])
        let columnMap = buildColumnMap(headers)

        // Validate required columns
        if columnMap["Contact Name"] == nil && columnMap["Name"] == nil {
            errors.append(ImportError(row: 1, field: "Name", message: "Required column 'Contact Name' or 'Name' not found"))
        }
        if columnMap["DMR ID"] == nil && columnMap["Radio ID"] == nil {
            errors.append(ImportError(row: 1, field: "DMR ID", message: "Required column 'DMR ID' or 'Radio ID' not found"))
        }

        guard errors.isEmpty else {
            return ContactImportResult(contacts: [], errors: errors, warnings: warnings)
        }

        // Parse data rows
        for (index, line) in lines.enumerated().dropFirst() {
            let rowNum = index + 1
            let fields = parseCSVLine(line)

            guard fields.count >= 2 else {
                warnings.append("Row \(rowNum): Skipped - too few fields")
                continue
            }

            // Contact name
            guard let name = getField(fields, columnMap, "Contact Name") ??
                            getField(fields, columnMap, "Name"),
                  !name.isEmpty else {
                warnings.append("Row \(rowNum): Skipped - missing name")
                continue
            }

            // DMR ID
            guard let idStr = getField(fields, columnMap, "DMR ID") ??
                             getField(fields, columnMap, "Radio ID"),
                  let dmrID = UInt32(idStr.trimmingCharacters(in: .whitespaces)),
                  dmrID > 0 && dmrID <= 16_777_215 else {
                errors.append(ImportError(row: rowNum, field: "DMR ID", message: "Invalid DMR ID (must be 1-16777215)"))
                continue
            }

            var contact = ParsedContact(name: name, dmrID: dmrID)

            // Call type
            if let typeStr = getField(fields, columnMap, "Call Type") ??
                            getField(fields, columnMap, "Type") {
                contact.contactType = parseCallType(typeStr)
            }

            // Receive tone
            if let toneStr = getField(fields, columnMap, "Receive Tone") {
                contact.callReceiveTone = toneStr.lowercased() == "yes" || toneStr == "1"
            }

            // Call alert
            if let alertStr = getField(fields, columnMap, "Call Alert") {
                contact.callAlert = alertStr.lowercased() == "yes" || alertStr == "1"
            }

            contacts.append(contact)
        }

        return ContactImportResult(contacts: contacts, errors: errors, warnings: warnings)
    }

    // MARK: - Helper Functions

    /// Escapes a string for CSV output (handles commas and quotes).
    private static func escapeCSV(_ string: String) -> String {
        if string.contains(",") || string.contains("\"") || string.contains("\n") {
            let escaped = string.replacingOccurrences(of: "\"", with: "\"\"")
            return "\"\(escaped)\""
        }
        return string
    }

    /// Parses a CSV line respecting quoted fields.
    private static func parseCSVLine(_ line: String) -> [String] {
        var fields: [String] = []
        var currentField = ""
        var inQuotes = false

        for char in line {
            if char == "\"" {
                inQuotes.toggle()
            } else if char == "," && !inQuotes {
                fields.append(currentField.trimmingCharacters(in: .whitespaces))
                currentField = ""
            } else {
                currentField.append(char)
            }
        }
        fields.append(currentField.trimmingCharacters(in: .whitespaces))

        return fields
    }

    /// Builds a map from column name (case-insensitive) to index.
    private static func buildColumnMap(_ headers: [String]) -> [String: Int] {
        var map: [String: Int] = [:]
        for (index, header) in headers.enumerated() {
            let normalized = header.trimmingCharacters(in: .whitespaces)
            map[normalized] = index
            // Also store lowercase version for flexible matching
            map[normalized.lowercased()] = index
        }
        return map
    }

    /// Gets a field value from parsed fields using the column map.
    private static func getField(_ fields: [String], _ columnMap: [String: Int], _ columnName: String) -> String? {
        if let index = columnMap[columnName] ?? columnMap[columnName.lowercased()],
           index < fields.count {
            let value = fields[index]
            return value.isEmpty ? nil : value
        }
        return nil
    }

    private static func contactTypeString(_ type: Int) -> String {
        switch type {
        case 0: return "Private"
        case 1: return "Group"
        case 2: return "All Call"
        default: return "Group"
        }
    }

    private static func squelchTypeString(_ type: Int) -> String {
        switch type {
        case 0: return "Carrier"
        case 1: return "CTCSS/DCS"
        case 2: return "Tight"
        default: return "Carrier"
        }
    }

    private static func privacyTypeString(_ type: Int) -> String {
        switch type {
        case 0: return "None"
        case 1: return "Basic"
        case 2: return "Enhanced"
        case 3: return "AES"
        default: return "None"
        }
    }

    private static func parseContactType(_ string: String) -> Int {
        let lower = string.lowercased()
        if lower.contains("private") { return 0 }
        if lower.contains("all") { return 2 }
        return 1  // Group is default
    }

    private static func parseCallType(_ string: String) -> ContactCallType {
        let lower = string.lowercased()
        if lower.contains("private") { return .privateCall }
        if lower.contains("all") { return .allCall }
        return .group
    }

    private static func parseSquelchType(_ string: String) -> Int {
        let lower = string.lowercased()
        if lower.contains("ctcss") || lower.contains("dcs") || lower.contains("tone") { return 1 }
        if lower.contains("tight") { return 2 }
        return 0
    }

    private static func parsePrivacyType(_ string: String) -> Int {
        let lower = string.lowercased()
        if lower.contains("basic") { return 1 }
        if lower.contains("enhanced") { return 2 }
        if lower.contains("aes") { return 3 }
        return 0
    }

    /// Parses a DCS code string like "D023N" or "D023I" into the code value.
    private static func parseDCSCode(_ string: String) -> UInt16 {
        var str = string.uppercased()
        if str.hasPrefix("D") {
            str.removeFirst()
        }
        // Remove N (normal) or I (inverted) suffix
        if str.hasSuffix("N") || str.hasSuffix("I") {
            str.removeLast()
        }
        // Parse as octal
        return UInt16(str, radix: 8) ?? 0
    }
}
