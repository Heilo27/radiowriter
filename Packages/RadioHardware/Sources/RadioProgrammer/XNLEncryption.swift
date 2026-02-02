import Foundation

/// XNL Authentication encryption for MOTOTRBO radios.
/// Uses TEA (Tiny Encryption Algorithm) variant.
///
/// Key extracted from XnlAuthentication.dll via static analysis.
/// Seed bytes: 1D 30 96 5A 55 AA F2 0C C6 6C 93 BF 5B CD 5E BD
public struct XNLEncryption {

    // MARK: - TEA Key (extracted from XnlAuthentication.dll)

    /// TEA key components extracted from obfuscated DLL
    /// Source: XnlAuthentication.dll → iq::a field
    /// Raw bytes: 1D 30 96 5A 55 AA F2 0C C6 6C 93 BF 5B CD 5E BD
    ///
    /// CRITICAL: Key must be interpreted as LITTLE-ENDIAN UInt32 values
    /// (as .NET BitConverter.ToInt32 reads on x86)
    /// VERIFIED WORKING: 2026-01-29
    private static let key: [UInt32] = [
        0x5A96301D,  // bytes 0-3 (LE: 1D 30 96 5A)
        0x0CF2AA55,  // bytes 4-7 (LE: 55 AA F2 0C)
        0xBF936CC6,  // bytes 8-11 (LE: C6 6C 93 BF)
        0xBD5ECD5B   // bytes 12-15 (LE: 5B CD 5E BD)
    ]

    /// MOTOTRBO custom TEA delta constant.
    /// NOTE: This is NOT the standard TEA delta (0x9E3779B9)!
    /// Extracted from XnlAuthentication.dll IL instruction: ldc.i4 2030745457
    /// VERIFIED WORKING: 2026-01-29
    private static let delta: UInt32 = 0x790AB771

    // MARK: - Encryption

    /// Encrypts an 8-byte authentication challenge using TEA.
    /// - Parameter data: 8-byte challenge from radio
    /// - Returns: 8-byte encrypted response
    public static func encrypt(_ data: Data) -> Data? {
        guard data.count == 8 else { return nil }

        // Convert to two UInt32 values (big-endian)
        var v0 = UInt32(bigEndian: data.withUnsafeBytes { $0.load(as: UInt32.self) })
        var v1 = UInt32(bigEndian: data.dropFirst(4).withUnsafeBytes { $0.load(as: UInt32.self) })

        var sum: UInt32 = 0

        // 32 rounds of TEA encryption
        for _ in 0..<32 {
            sum = sum &+ delta
            v0 = v0 &+ (((v1 << 4) &+ key[0]) ^ (v1 &+ sum) ^ ((v1 >> 5) &+ key[1]))
            v1 = v1 &+ (((v0 << 4) &+ key[2]) ^ (v0 &+ sum) ^ ((v0 >> 5) &+ key[3]))
        }

        // Convert back to bytes (big-endian)
        var result = Data(count: 8)
        result.withUnsafeMutableBytes { ptr in
            ptr.storeBytes(of: v0.bigEndian, as: UInt32.self)
            ptr.storeBytes(of: v1.bigEndian, toByteOffset: 4, as: UInt32.self)
        }

        return result
    }

    /// Decrypts an 8-byte encrypted value using TEA.
    /// - Parameter data: 8-byte encrypted data
    /// - Returns: 8-byte decrypted data
    public static func decrypt(_ data: Data) -> Data? {
        guard data.count == 8 else { return nil }

        // Convert to two UInt32 values (big-endian)
        var v0 = UInt32(bigEndian: data.withUnsafeBytes { $0.load(as: UInt32.self) })
        var v1 = UInt32(bigEndian: data.dropFirst(4).withUnsafeBytes { $0.load(as: UInt32.self) })

        // Calculate final sum after 32 rounds
        var sum: UInt32 = delta &* 32

        // 32 rounds of TEA decryption (reverse order)
        for _ in 0..<32 {
            v1 = v1 &- (((v0 << 4) &+ key[2]) ^ (v0 &+ sum) ^ ((v0 >> 5) &+ key[3]))
            v0 = v0 &- (((v1 << 4) &+ key[0]) ^ (v1 &+ sum) ^ ((v1 >> 5) &+ key[1]))
            sum = sum &- delta
        }

        // Convert back to bytes (big-endian)
        var result = Data(count: 8)
        result.withUnsafeMutableBytes { ptr in
            ptr.storeBytes(of: v0.bigEndian, as: UInt32.self)
            ptr.storeBytes(of: v1.bigEndian, toByteOffset: 4, as: UInt32.self)
        }

        return result
    }

    // MARK: - Test Vectors

    /// Validates the encryption implementation with a round-trip test.
    /// Returns true if encrypt(decrypt(x)) == x
    public static func validateImplementation() -> Bool {
        let testData = Data([0x12, 0x34, 0x56, 0x78, 0x9A, 0xBC, 0xDE, 0xF0])

        guard let encrypted = encrypt(testData),
              let decrypted = decrypt(encrypted) else {
            return false
        }

        return decrypted == testData
    }

    /// Prints test vectors for debugging.
    public static func printTestVectors() {
        let testInputs: [[UInt8]] = [
            [0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00],
            [0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08],
            [0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF],
            [0x12, 0x34, 0x56, 0x78, 0x9A, 0xBC, 0xDE, 0xF0],
        ]

        print("XNL Encryption Test Vectors")
        print("Key: \(key.map { String(format: "0x%08X", $0) }.joined(separator: ", "))")
        print("Delta: 0x\(String(format: "%08X", delta))")
        print("")

        for input in testInputs {
            let inputData = Data(input)
            let inputHex = input.map { String(format: "%02X", $0) }.joined(separator: " ")

            if let output = encrypt(inputData) {
                let outputHex = output.map { String(format: "%02X", $0) }.joined(separator: " ")
                print("Input:  \(inputHex)")
                print("Output: \(outputHex)")
                print("")
            }
        }
    }

    // MARK: - Radio Key Encryption (TEA-based)

    /// Encrypts a 32-byte radio key using TEA in ECB mode.
    /// Used for the RcmpUnlockSecurity command (0x0301).
    ///
    /// The documentation states: "Radio key encryption uses the same TEA algorithm as XNL authentication"
    /// The 32-byte key is encrypted in four 8-byte blocks using the same TEA key/delta as authentication.
    ///
    /// - Parameter radioKey: 32-byte key from RcmpReadRadioKey response
    /// - Returns: 32-byte encrypted key for unlock command
    public static func encryptRadioKey(_ radioKey: Data) -> Data? {
        guard radioKey.count == 32 else { return nil }

        var result = Data()

        // Encrypt the 32-byte key in four 8-byte blocks using TEA
        for blockIndex in 0..<4 {
            let blockStart = blockIndex * 8
            let blockEnd = blockStart + 8
            let block = radioKey[blockStart..<blockEnd]

            guard let encryptedBlock = encrypt(Data(block)) else {
                return nil
            }

            result.append(encryptedBlock)
        }

        return result
    }
}
