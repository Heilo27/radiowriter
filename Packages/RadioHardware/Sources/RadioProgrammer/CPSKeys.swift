import Foundation

/// Encryption keys extracted from Motorola CPS software.
/// These keys are used for decrypting codeplug files and authenticating with radios.
public enum CPSKeys {

    // MARK: - Business Radio CPS Keys (r09.10/r09.11/r11.00)
    // Supports: CLP, CLS, DLR, DTR, RMx, Fiji, Nome, Renoir, Solo, Sunb, Vanu series
    // Source: secure.dll → CSecureConstants
    // Confirmed identical across r09.10, r09.11, and r11.00

    /// Triple DES encryption key for Business Radio CPS config files
    /// Algorithm: 3DES (Triple DES)
    /// Length: 24 bytes (192 bits)
    /// Source: secure.dll CSecureConstants.DefStrKey
    public static let businessRadioDESKey: [UInt8] = Array("HAVNCPSCMTTUNERAIRTRACER".utf8)

    /// Triple DES initialization vector for Business Radio CPS config files
    /// Length: 8 bytes (64 bits)
    /// Source: secure.dll CSecureConstants.DefStrIV
    public static let businessRadioDESIV: [UInt8] = Array("VEDKDJSP".utf8)

    /// Convenience property returning key as Data
    public static var businessRadioDESKeyData: Data {
        Data(businessRadioDESKey)
    }

    /// Convenience property returning IV as Data
    public static var businessRadioDESIVData: Data {
        Data(businessRadioDESIV)
    }

    // MARK: - Admin/License Keys
    // Source: CMT.Web.dll → WebLicense class

    /// Admin key used for license validation
    /// Length: 28 characters
    /// Source: CMT.Web.dll WebLicense.ADMINKEY
    public static let adminKey: String = "MOTOROLACHENGDUSITERBRTEAMCOM"

    // MARK: - MOTOTRBO CPS 2.0 Keys
    // Supports: XPR, SL, DP, DM series (DMR radios)
    // Source: cpservices.dll (to be extracted)

    /// AES encryption key for MOTOTRBO codeplug files (Base64)
    /// Length: 43 characters + padding = 44 chars (256 bits decoded)
    /// Status: PLACEHOLDER - Extract from MOTOTRBO CPS 2.0 cpservices.dll
    public static let mototrboAESKey: String? = nil

    /// AES initialization vector for MOTOTRBO codeplug files (Base64)
    /// Length: 22 characters + padding = 24 chars (128 bits decoded)
    /// Status: PLACEHOLDER - Extract from MOTOTRBO CPS 2.0 cpservices.dll
    public static let mototrboAESIV: String? = nil

    /// Signing password for MOTOTRBO codeplug files (Base64)
    /// Length: 22 characters + padding
    /// Status: PLACEHOLDER - Extract from MOTOTRBO CPS 2.0 cpservices.dll
    public static let mototrboSigningPassword: String? = nil

    /// Signing certificate for MOTOTRBO codeplug files (Base64 PFX)
    /// Status: PLACEHOLDER - Extract from MOTOTRBO CPS 2.0 resources/mototrbocps
    public static let mototrboSigningCertificate: String? = nil

    // MARK: - Key Information

    /// Information about supported CPS versions and their keys
    public struct CPSVersion {
        public let name: String
        public let version: String
        public let supportedRadios: [String]
        public let hasKeys: Bool

        /// Business Radio CPS supports these radio families (codenames from DLLs):
        /// - CLP: Original CLP series
        /// - CLP2: Second-gen CLP
        /// - ClpNova: CLP Nova series
        /// - CLS (Sunb): CLS series (codename Sunb)
        /// - DLRx: DLR series (digital)
        /// - DTR: DTR series
        /// - Fiji: SL series (original, codename Fiji)
        /// - NewFiji: SL series (new, codename NewFiji)
        /// - Nome: RMx series (codename Nome)
        /// - Renoir: Unknown series (codename Renoir)
        /// - Solo: Unknown series (codename Solo)
        /// - Vanu: Unknown series (codename Vanu)
        public static let businessRadioCPS = CPSVersion(
            name: "Business Radio CPS",
            version: "r09.10/r09.11/r11.00",
            supportedRadios: [
                "CLP", "CLP2", "ClpNova",  // CLP family
                "CLS", "Sunb",              // CLS family
                "DLR", "DLRx",              // DLR family
                "DTR",                      // DTR family
                "Fiji", "NewFiji",          // SL family (older models)
                "Nome",                     // RMx family
                "RM", "RMU", "RMM", "RDU",  // RMx variants
                "VL",                       // VL family
                "Renoir", "Solo", "Vanu"    // Other codenames
            ],
            hasKeys: true
        )

        public static let motortrboCPS = CPSVersion(
            name: "MOTOTRBO CPS",
            version: "2.0",
            supportedRadios: ["XPR", "SL", "DP", "DM", "DR"],
            hasKeys: false  // Keys not yet extracted - requires cpservices.dll
        )
    }

    /// All radio families supported by Business Radio CPS (lowercase)
    public static let businessRadioFamilies: Set<String> = [
        "clp", "clp2", "clpnova",
        "cls", "sunb",
        "dlr", "dlrx",
        "dtr",
        "fiji", "newfiji",
        "nome",
        "rm", "rmu", "rmm", "rdu",
        "vl",
        "renoir", "solo", "vanu"
    ]

    /// All radio families supported by MOTOTRBO CPS (lowercase)
    public static let mototrboFamilies: Set<String> = [
        "xpr", "sl", "dp", "dm", "dr"
    ]

    /// Check if keys are available for a radio family
    public static func hasKeys(for radioFamily: String) -> Bool {
        let family = radioFamily.lowercased()

        // Business Radio families - keys available
        if businessRadioFamilies.contains(family) {
            return true
        }

        // MOTOTRBO families - keys not yet extracted
        if mototrboFamilies.contains(family) {
            return mototrboAESKey != nil
        }

        return false
    }

    /// Returns the CPS version that supports a given radio family
    public static func cpsVersion(for radioFamily: String) -> CPSVersion? {
        let family = radioFamily.lowercased()

        if businessRadioFamilies.contains(family) {
            return .businessRadioCPS
        }

        if mototrboFamilies.contains(family) {
            return .motortrboCPS
        }

        return nil
    }
}
