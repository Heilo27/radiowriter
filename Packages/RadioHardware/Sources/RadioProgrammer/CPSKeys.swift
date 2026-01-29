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
    // Source: aes.dll → authAES.AESCryptography (extracted via Wine from MOTOTRBO_CPS_2.0.msi)

    /// Default cipher key for MOTOTRBO password encryption
    /// Algorithm: DES/AES hybrid (uses 8-byte key expanded for AES)
    /// Length: 8 bytes
    /// Source: aes.dll authAES.AESCryptography.CIPHER_DEF_KEY
    /// Hex: 4D 6F 74 2D 53 6F 6C 73
    public static let mototrboCipherKey: [UInt8] = Array("Mot-Sols".utf8)

    /// Default initialization vector for MOTOTRBO encryption
    /// Length: 8 bytes
    /// Source: aes.dll authAES.AESCryptography (field 'a')
    /// Hex: 41 42 43 44 31 32 33 34
    public static let mototrboCipherIV: [UInt8] = Array("ABCD1234".utf8)

    /// Convenience property returning MOTOTRBO key as Data
    public static var mototrboCipherKeyData: Data {
        Data(mototrboCipherKey)
    }

    /// Convenience property returning MOTOTRBO IV as Data
    public static var mototrboCipherIVData: Data {
        Data(mototrboCipherIV)
    }

    /// AES encryption key for MOTOTRBO codeplug files (Base64)
    /// Length: 43 characters + padding = 44 chars (256 bits decoded)
    /// Status: Not found in MOTOTRBO CPS 2.0 - may use different encryption scheme
    public static let mototrboAESKey: String? = nil

    /// AES initialization vector for MOTOTRBO codeplug files (Base64)
    /// Length: 22 characters + padding = 24 chars (128 bits decoded)
    /// Status: Not found in MOTOTRBO CPS 2.0 - may use different encryption scheme
    public static let mototrboAESIV: String? = nil

    /// Signing password for MOTOTRBO codeplug files (Base64)
    /// Length: 22 characters + padding
    /// Status: Not found - MOTOTRBO CPS 2.0 may not use signed codeplugs
    public static let mototrboSigningPassword: String? = nil

    /// Signing certificate for MOTOTRBO codeplug files (Base64 PFX)
    /// Status: Not found - MOTOTRBO CPS 2.0 may not use signed codeplugs
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
            hasKeys: true  // Keys extracted from aes.dll via Wine
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

        // MOTOTRBO families - cipher keys available
        if mototrboFamilies.contains(family) {
            return true  // mototrboCipherKey is available
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
