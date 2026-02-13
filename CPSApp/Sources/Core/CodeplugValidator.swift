import Foundation
import RadioProgrammer
import RadioModelCore

/// Severity level for validation issues.
enum ValidationSeverity: Comparable {
    case error      // Blocks write operation
    case warning    // Allows write but should be reviewed
    case info       // Informational only

    var icon: String {
        switch self {
        case .error: return "xmark.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .info: return "info.circle.fill"
        }
    }

    var color: String {
        switch self {
        case .error: return "red"
        case .warning: return "orange"
        case .info: return "blue"
        }
    }
}

/// A single validation issue found in a codeplug.
struct ValidationIssue: Identifiable {
    let id = UUID()
    let severity: ValidationSeverity
    let category: String
    let message: String
    let location: String?  // e.g., "Zone 1, Channel 3"
    let suggestion: String?

    init(severity: ValidationSeverity, category: String, message: String, location: String? = nil, suggestion: String? = nil) {
        self.severity = severity
        self.category = category
        self.message = message
        self.location = location
        self.suggestion = suggestion
    }
}

/// Result of validating a codeplug.
struct ValidationResult {
    let issues: [ValidationIssue]
    let timestamp: Date

    var errors: [ValidationIssue] {
        issues.filter { $0.severity == .error }
    }

    var warnings: [ValidationIssue] {
        issues.filter { $0.severity == .warning }
    }

    var infos: [ValidationIssue] {
        issues.filter { $0.severity == .info }
    }

    var hasErrors: Bool {
        !errors.isEmpty
    }

    var canProceed: Bool {
        !hasErrors
    }

    var summary: String {
        let errorCount = errors.count
        let warningCount = warnings.count

        if errorCount == 0 && warningCount == 0 {
            return "Validation passed"
        } else if errorCount == 0 {
            return "\(warningCount) warning\(warningCount == 1 ? "" : "s")"
        } else if warningCount == 0 {
            return "\(errorCount) error\(errorCount == 1 ? "" : "s")"
        } else {
            return "\(errorCount) error\(errorCount == 1 ? "" : "s"), \(warningCount) warning\(warningCount == 1 ? "" : "s")"
        }
    }
}

/// Validates a parsed codeplug for errors and potential issues.
struct CodeplugValidator {

    // MARK: - Constants

    /// Valid DMR ID range (1 to 16,777,215)
    static let validDMRIDRange: ClosedRange<UInt32> = 1...16_777_215

    /// Common amateur radio frequency bands (in Hz)
    static let amateurBands: [(name: String, range: ClosedRange<UInt64>)] = [
        ("2m", 144_000_000...148_000_000),
        ("1.25m", 222_000_000...225_000_000),
        ("70cm", 420_000_000...450_000_000),
        ("33cm", 902_000_000...928_000_000),
        ("23cm", 1_240_000_000...1_300_000_000)
    ]

    /// Commercial frequency ranges (in Hz)
    static let commercialBands: [(name: String, range: ClosedRange<UInt64>)] = [
        ("VHF Low", 136_000_000...174_000_000),
        ("VHF High", 136_000_000...174_000_000),
        ("UHF", 403_000_000...527_000_000),
        ("800 MHz", 806_000_000...870_000_000),
        ("900 MHz", 896_000_000...941_000_000)
    ]

    // MARK: - Validation

    /// Validates a parsed codeplug and returns all issues found.
    func validate(_ codeplug: ParsedCodeplug) -> ValidationResult {
        var issues: [ValidationIssue] = []

        // Run all validation checks
        issues.append(contentsOf: validateRadioIdentity(codeplug))
        issues.append(contentsOf: validateZones(codeplug))
        issues.append(contentsOf: validateChannels(codeplug))
        issues.append(contentsOf: validateContacts(codeplug))
        issues.append(contentsOf: validateScanLists(codeplug))
        issues.append(contentsOf: validateRxGroupLists(codeplug))
        issues.append(contentsOf: validateReferences(codeplug))

        // Sort by severity (errors first)
        let sorted = issues.sorted { $0.severity > $1.severity }

        return ValidationResult(issues: sorted, timestamp: Date())
    }

    // MARK: - Radio Identity Validation

    private func validateRadioIdentity(_ codeplug: ParsedCodeplug) -> [ValidationIssue] {
        var issues: [ValidationIssue] = []

        // Check Radio ID
        if codeplug.radioID == 0 {
            issues.append(ValidationIssue(
                severity: .error,
                category: "Radio Identity",
                message: "Radio ID is not set",
                suggestion: "Set a valid DMR Radio ID (1-16777215)"
            ))
        } else if !Self.validDMRIDRange.contains(codeplug.radioID) {
            issues.append(ValidationIssue(
                severity: .error,
                category: "Radio Identity",
                message: "Radio ID \(codeplug.radioID) is out of valid range",
                suggestion: "Use a Radio ID between 1 and 16,777,215"
            ))
        }

        return issues
    }

    // MARK: - Zone Validation

    private func validateZones(_ codeplug: ParsedCodeplug) -> [ValidationIssue] {
        var issues: [ValidationIssue] = []

        // Check for empty zones list
        if codeplug.zones.isEmpty {
            issues.append(ValidationIssue(
                severity: .warning,
                category: "Zones",
                message: "No zones defined",
                suggestion: "Add at least one zone with channels"
            ))
            return issues
        }

        // Check for duplicate zone names
        let zoneNames = codeplug.zones.map { $0.name.lowercased() }
        let duplicates = Dictionary(grouping: zoneNames, by: { $0 })
            .filter { $1.count > 1 }
            .keys

        for duplicate in duplicates {
            issues.append(ValidationIssue(
                severity: .warning,
                category: "Zones",
                message: "Duplicate zone name: '\(duplicate)'",
                suggestion: "Use unique names for each zone"
            ))
        }

        // Check for empty zones
        for (index, zone) in codeplug.zones.enumerated() {
            if zone.channels.isEmpty {
                issues.append(ValidationIssue(
                    severity: .warning,
                    category: "Zones",
                    message: "Zone '\(zone.name)' has no channels",
                    location: "Zone \(index + 1)",
                    suggestion: "Add channels to the zone or remove it"
                ))
            }

            if zone.name.trimmingCharacters(in: .whitespaces).isEmpty {
                issues.append(ValidationIssue(
                    severity: .error,
                    category: "Zones",
                    message: "Zone \(index + 1) has no name",
                    location: "Zone \(index + 1)",
                    suggestion: "Provide a name for the zone"
                ))
            }
        }

        return issues
    }

    // MARK: - Channel Validation

    private func validateChannels(_ codeplug: ParsedCodeplug) -> [ValidationIssue] {
        var issues: [ValidationIssue] = []

        for (zoneIndex, zone) in codeplug.zones.enumerated() {
            // Check for duplicate channel names within zone
            let channelNames = zone.channels.map { $0.name.lowercased() }
            let duplicates = Dictionary(grouping: channelNames, by: { $0 })
                .filter { $1.count > 1 }
                .keys

            for duplicate in duplicates {
                issues.append(ValidationIssue(
                    severity: .warning,
                    category: "Channels",
                    message: "Duplicate channel name in zone '\(zone.name)': '\(duplicate)'",
                    location: "Zone \(zoneIndex + 1): \(zone.name)",
                    suggestion: "Use unique channel names within each zone"
                ))
            }

            for (channelIndex, channel) in zone.channels.enumerated() {
                let location = "Zone \(zoneIndex + 1) '\(zone.name)', Channel \(channelIndex + 1)"

                // Validate channel name
                if channel.name.trimmingCharacters(in: .whitespaces).isEmpty {
                    issues.append(ValidationIssue(
                        severity: .error,
                        category: "Channels",
                        message: "Channel has no name",
                        location: location,
                        suggestion: "Provide a name for the channel"
                    ))
                }

                // Validate frequencies
                if channel.rxFrequencyHz == 0 {
                    issues.append(ValidationIssue(
                        severity: .error,
                        category: "Channels",
                        message: "RX frequency is not set",
                        location: location,
                        suggestion: "Set a valid receive frequency"
                    ))
                }

                if channel.txFrequencyHz == 0 && !channel.rxOnly {
                    issues.append(ValidationIssue(
                        severity: .error,
                        category: "Channels",
                        message: "TX frequency is not set for transmit-enabled channel",
                        location: location,
                        suggestion: "Set a valid transmit frequency or mark as RX-only"
                    ))
                }

                // Check frequency is in a valid band
                issues.append(contentsOf: validateFrequency(
                    UInt64(channel.rxFrequencyHz),
                    type: "RX",
                    location: location
                ))

                if !channel.rxOnly && channel.txFrequencyHz > 0 {
                    issues.append(contentsOf: validateFrequency(
                        UInt64(channel.txFrequencyHz),
                        type: "TX",
                        location: location
                    ))
                }

                // Digital channel specific validation
                if channel.isDigital {
                    // Color code validation (0-15)
                    if channel.colorCode > 15 {
                        issues.append(ValidationIssue(
                            severity: .error,
                            category: "Channels",
                            message: "Invalid color code: \(channel.colorCode)",
                            location: location,
                            suggestion: "Color code must be 0-15"
                        ))
                    }

                    // Time slot validation (1-2)
                    if channel.timeSlot < 1 || channel.timeSlot > 2 {
                        issues.append(ValidationIssue(
                            severity: .error,
                            category: "Channels",
                            message: "Invalid time slot: \(channel.timeSlot)",
                            location: location,
                            suggestion: "Time slot must be 1 or 2"
                        ))
                    }

                    // Contact validation for digital channels
                    if channel.contactID == 0 {
                        issues.append(ValidationIssue(
                            severity: .warning,
                            category: "Channels",
                            message: "No contact assigned to digital channel",
                            location: location,
                            suggestion: "Assign a contact for transmit calls"
                        ))
                    }
                }

                // TOT validation
                if channel.totTimeout > 600 {
                    issues.append(ValidationIssue(
                        severity: .warning,
                        category: "Channels",
                        message: "Unusually long TOT timeout: \(channel.totTimeout) seconds",
                        location: location,
                        suggestion: "Consider setting TOT to 180 seconds or less"
                    ))
                }
            }
        }

        return issues
    }

    private func validateFrequency(_ frequencyHz: UInt64, type: String, location: String) -> [ValidationIssue] {
        var issues: [ValidationIssue] = []

        // Check if frequency is in a known band
        let inAmateurBand = Self.amateurBands.contains { $0.range.contains(frequencyHz) }
        let inCommercialBand = Self.commercialBands.contains { $0.range.contains(frequencyHz) }

        if !inAmateurBand && !inCommercialBand {
            let freqMHz = Double(frequencyHz) / 1_000_000.0
            issues.append(ValidationIssue(
                severity: .warning,
                category: "Frequencies",
                message: "\(type) frequency \(String(format: "%.5f", freqMHz)) MHz is outside common bands",
                location: location,
                suggestion: "Verify this frequency is correct for your license and radio"
            ))
        }

        return issues
    }

    // MARK: - Contact Validation

    private func validateContacts(_ codeplug: ParsedCodeplug) -> [ValidationIssue] {
        var issues: [ValidationIssue] = []

        // Check for duplicate contact names
        let contactNames = codeplug.contacts.map { $0.name.lowercased() }
        let duplicates = Dictionary(grouping: contactNames, by: { $0 })
            .filter { $1.count > 1 }
            .keys

        for duplicate in duplicates {
            issues.append(ValidationIssue(
                severity: .warning,
                category: "Contacts",
                message: "Duplicate contact name: '\(duplicate)'",
                suggestion: "Use unique names for each contact"
            ))
        }

        for (index, contact) in codeplug.contacts.enumerated() {
            let location = "Contact \(index + 1): \(contact.name)"

            // Validate contact name
            if contact.name.trimmingCharacters(in: .whitespaces).isEmpty {
                issues.append(ValidationIssue(
                    severity: .error,
                    category: "Contacts",
                    message: "Contact has no name",
                    location: "Contact \(index + 1)",
                    suggestion: "Provide a name for the contact"
                ))
            }

            // Validate DMR ID
            if contact.dmrID == 0 {
                issues.append(ValidationIssue(
                    severity: .error,
                    category: "Contacts",
                    message: "Contact has no DMR ID",
                    location: location,
                    suggestion: "Set a valid DMR ID for the contact"
                ))
            } else if !Self.validDMRIDRange.contains(contact.dmrID) {
                issues.append(ValidationIssue(
                    severity: .error,
                    category: "Contacts",
                    message: "Invalid DMR ID: \(contact.dmrID)",
                    location: location,
                    suggestion: "DMR ID must be between 1 and 16,777,215"
                ))
            }
        }

        return issues
    }

    // MARK: - Scan List Validation

    private func validateScanLists(_ codeplug: ParsedCodeplug) -> [ValidationIssue] {
        var issues: [ValidationIssue] = []

        for (index, scanList) in codeplug.scanLists.enumerated() {
            let location = "Scan List \(index + 1): \(scanList.name)"

            if scanList.name.trimmingCharacters(in: .whitespaces).isEmpty {
                issues.append(ValidationIssue(
                    severity: .warning,
                    category: "Scan Lists",
                    message: "Scan list has no name",
                    location: "Scan List \(index + 1)",
                    suggestion: "Provide a name for the scan list"
                ))
            }

            if scanList.channelMembers.isEmpty {
                issues.append(ValidationIssue(
                    severity: .warning,
                    category: "Scan Lists",
                    message: "Scan list is empty",
                    location: location,
                    suggestion: "Add channels to the scan list or remove it"
                ))
            }
        }

        return issues
    }

    // MARK: - RX Group List Validation

    private func validateRxGroupLists(_ codeplug: ParsedCodeplug) -> [ValidationIssue] {
        var issues: [ValidationIssue] = []

        for (index, rxGroup) in codeplug.rxGroupLists.enumerated() {
            let location = "RX Group \(index + 1): \(rxGroup.name)"

            if rxGroup.name.trimmingCharacters(in: .whitespaces).isEmpty {
                issues.append(ValidationIssue(
                    severity: .warning,
                    category: "RX Groups",
                    message: "RX group list has no name",
                    location: "RX Group \(index + 1)",
                    suggestion: "Provide a name for the RX group list"
                ))
            }

            if rxGroup.contactIndices.isEmpty {
                issues.append(ValidationIssue(
                    severity: .warning,
                    category: "RX Groups",
                    message: "RX group list is empty",
                    location: location,
                    suggestion: "Add contacts to the RX group list or remove it"
                ))
            }
        }

        return issues
    }

    // MARK: - Reference Validation

    private func validateReferences(_ codeplug: ParsedCodeplug) -> [ValidationIssue] {
        var issues: [ValidationIssue] = []

        // Build set of valid contact IDs
        let validContactIDs = Set(codeplug.contacts.map { $0.dmrID })

        // Check channel contact references
        for (zoneIndex, zone) in codeplug.zones.enumerated() {
            for (channelIndex, channel) in zone.channels.enumerated() {
                if channel.isDigital && channel.contactID > 0 {
                    if !validContactIDs.contains(channel.contactID) {
                        let location = "Zone \(zoneIndex + 1) '\(zone.name)', Channel \(channelIndex + 1) '\(channel.name)'"
                        issues.append(ValidationIssue(
                            severity: .warning,
                            category: "References",
                            message: "Channel references non-existent contact ID: \(channel.contactID)",
                            location: location,
                            suggestion: "Update the channel contact or add the missing contact"
                        ))
                    }
                }
            }
        }

        // Check RX group contact references
        let contactCount = codeplug.contacts.count
        for (index, rxGroup) in codeplug.rxGroupLists.enumerated() {
            for contactIndex in rxGroup.contactIndices {
                if contactIndex < 0 || contactIndex >= contactCount {
                    let location = "RX Group \(index + 1): \(rxGroup.name)"
                    issues.append(ValidationIssue(
                        severity: .warning,
                        category: "References",
                        message: "RX group references non-existent contact index: \(contactIndex)",
                        location: location,
                        suggestion: "Update the RX group or add the missing contact"
                    ))
                }
            }
        }

        return issues
    }
}
