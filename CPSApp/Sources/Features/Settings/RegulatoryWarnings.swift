import Foundation

/// Manages user acknowledgment of FCC regulatory compliance warnings.
@Observable
final class RegulatoryWarningManager {
    private static let fccWarningAcknowledgedKey = "com.radiowriter.fccWarningAcknowledged"
    private static let preWriteWarningDismissedKey = "com.radiowriter.preWriteWarningDismissed"

    /// Whether the user has acknowledged the first-run FCC warning.
    var fccWarningAcknowledged: Bool {
        get {
            UserDefaults.standard.bool(forKey: Self.fccWarningAcknowledgedKey)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: Self.fccWarningAcknowledgedKey)
        }
    }

    /// Whether the user has dismissed the pre-write confirmation (for "Don't show again").
    var preWriteWarningDismissed: Bool {
        get {
            UserDefaults.standard.bool(forKey: Self.preWriteWarningDismissedKey)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: Self.preWriteWarningDismissedKey)
        }
    }

    /// Resets all regulatory warning acknowledgments (for testing/debugging).
    func resetAllWarnings() {
        UserDefaults.standard.removeObject(forKey: Self.fccWarningAcknowledgedKey)
        UserDefaults.standard.removeObject(forKey: Self.preWriteWarningDismissedKey)
    }
}

/// Localized text for FCC regulatory warnings.
enum RegulatoryText {
    static let fccWarningTitle = "FCC Regulatory Compliance"

    static let fccWarningMessage = """
    IMPORTANT: Radio programming requires compliance with FCC regulations.

    You are responsible for ensuring:
    • You are authorized to operate on programmed frequencies
    • Power levels comply with your license class requirements
    • All transmissions comply with applicable FCC regulations (Parts 90, 95, 97)

    Improper radio programming may violate federal law and cause harmful interference.

    By continuing, you acknowledge your responsibility for regulatory compliance.
    """

    static let fccWarningAcknowledge = "I Acknowledge"
    static let fccWarningCancel = "Cancel"
    static let dontShowAgain = "Don't show again"

    static let preWriteTitle = "Write to Radio"

    static let preWriteMessage = """
    Before writing to the radio, confirm that:
    • You are authorized to operate on all programmed frequencies
    • Power levels comply with your license requirements
    • Your codeplug settings are legal and appropriate
    """

    static let preWriteContinue = "Write to Radio"

    static let aboutTitle = "About RadioWriter"

    static let aboutRegulatorySection = """
    Regulatory Compliance & Legal Notice

    RadioWriter is a tool for configuring Motorola digital radios. Users are solely responsible for ensuring their radio programming complies with all applicable FCC regulations and their radio license.

    Key Regulatory Requirements:
    • FCC Part 90: Commercial Mobile Radio Service (CMRS)
    • FCC Part 95: Personal Radio Services
    • FCC Part 97: Amateur Radio Service

    It is the user's responsibility to:
    • Verify frequency authorization for their license class
    • Ensure power levels comply with license restrictions
    • Prevent harmful interference with licensed services
    • Maintain compliance with all applicable regulations

    Improper radio programming may violate federal law (47 U.S.C. § 309(f)) and result in substantial fines or criminal penalties.

    For more information:
    • FCC Rules and Regulations: www.fcc.gov/rules
    • Part 90: www.fcc.gov/wireless/bureau-divisions/mobility-division/part-90-commercial-mobile-services
    • Part 95: www.fcc.gov/wireless/bureau-divisions/mobility-division/part-95-personal-radio-services
    • Part 97: www.fcc.gov/wireless/bureau-divisions/competition-division/amateur-radio
    """
}
