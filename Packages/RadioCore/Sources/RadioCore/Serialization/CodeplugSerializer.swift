import Foundation
import CryptoKit
import Compression
import CommonCrypto
import Security

/// Handles serialization of codeplugs to and from the native `.cpsx` file format.
/// Format: [Header][Metadata JSON][Compressed+Encrypted Binary Data]
public struct CodeplugSerializer: Sendable {

    /// File format magic bytes: "CPSX"
    private static let magic: [UInt8] = [0x43, 0x50, 0x53, 0x58]
    /// Current format version (v2 = PBKDF2 with salt, v1 = legacy SHA-256)
    private static let formatVersion: UInt16 = 2

    /// PBKDF2 parameters for v2+ files
    /// - Rounds: 100,000 iterations (OWASP recommended minimum for PBKDF2-SHA256)
    /// - Salt length: 16 bytes (128 bits)
    /// - Key length: 32 bytes (256 bits for AES-256)
    private static let pbkdf2Rounds = 100_000
    private static let saltLength = 16

    public init() {}

    // MARK: - Serialization

    /// Serializes a codeplug to the native format.
    ///
    /// Note: Compression happens on a background thread to avoid blocking.
    /// However, this method is synchronous to maintain compatibility with FileDocument.
    /// The system's file I/O layer typically calls this off the main thread already.
    public func serialize(_ codeplug: Codeplug, password: String? = nil) throws -> Data {
        var output = Data()

        // Header
        output.append(contentsOf: Self.magic)
        output.append(contentsOf: withUnsafeBytes(of: Self.formatVersion.littleEndian) { Data($0) })

        // Metadata as JSON
        let metadataJSON = try JSONEncoder().encode(codeplug.metadata)
        let metadataLength = UInt32(metadataJSON.count)
        output.append(contentsOf: withUnsafeBytes(of: metadataLength.littleEndian) { Data($0) })
        output.append(metadataJSON)

        // Model identifier
        let modelData = codeplug.modelIdentifier.data(using: .utf8) ?? Data()
        let modelLength = UInt16(modelData.count)
        output.append(contentsOf: withUnsafeBytes(of: modelLength.littleEndian) { Data($0) })
        output.append(modelData)

        // Compress the raw data
        let compressed = try compress(codeplug.rawData)

        // Encrypt if password provided
        let payload: Data
        let isEncrypted: UInt8
        let salt: Data?
        if let password = password {
            let generatedSalt = generateSalt()
            payload = try encrypt(compressed, password: password, salt: generatedSalt)
            isEncrypted = 1
            salt = generatedSalt
        } else {
            payload = compressed
            isEncrypted = 0
            salt = nil
        }

        output.append(isEncrypted)

        // For encrypted files (v2+), write salt length and salt
        if let salt = salt {
            let saltLen = UInt16(salt.count)
            output.append(contentsOf: withUnsafeBytes(of: saltLen.littleEndian) { Data($0) })
            output.append(salt)
        }

        let payloadLength = UInt32(payload.count)
        output.append(contentsOf: withUnsafeBytes(of: payloadLength.littleEndian) { Data($0) })
        output.append(payload)

        // Original data length for decompression
        let originalLength = UInt32(codeplug.rawData.count)
        output.append(contentsOf: withUnsafeBytes(of: originalLength.littleEndian) { Data($0) })

        return output
    }

    /// Deserializes a codeplug from the native format.
    ///
    /// Note: Decompression happens on a background thread to avoid blocking.
    /// However, this method is synchronous to maintain compatibility with FileDocument.
    /// The system's file I/O layer typically calls this off the main thread already.
    public func deserialize(_ data: Data, password: String? = nil) throws -> Codeplug {
        var offset = 0

        // Verify magic
        guard data.count > 12 else { throw SerializationError.invalidFormat }
        let magic = Array(data[0..<4])
        guard magic == Self.magic else { throw SerializationError.invalidFormat }
        offset = 4

        // Version
        let version = try readUInt16LE(from: data, at: offset)
        guard version <= Self.formatVersion else { throw SerializationError.unsupportedVersion(version) }
        offset += 2

        // Metadata
        let metadataLength = Int(try readUInt32LE(from: data, at: offset))
        offset += 4
        guard offset + metadataLength <= data.count else { throw SerializationError.truncatedData }
        let metadataJSON = data[offset..<(offset + metadataLength)]
        let metadata = try JSONDecoder().decode(CodeplugMetadata.self, from: Data(metadataJSON))
        offset += metadataLength

        // Model identifier
        let modelLength = Int(try readUInt16LE(from: data, at: offset))
        offset += 2
        guard offset + modelLength <= data.count else { throw SerializationError.truncatedData }
        let modelData = data[offset..<(offset + modelLength)]
        let modelIdentifier = String(data: Data(modelData), encoding: .utf8) ?? ""
        offset += modelLength

        // Encryption flag
        guard offset < data.count else { throw SerializationError.truncatedData }
        let isEncrypted = data[offset] == 1
        offset += 1

        // For v2+ encrypted files, read salt
        let salt: Data?
        if isEncrypted && version >= 2 {
            let saltLen = Int(try readUInt16LE(from: data, at: offset))
            offset += 2
            guard offset + saltLen <= data.count else { throw SerializationError.truncatedData }
            salt = Data(data[offset..<(offset + saltLen)])
            offset += saltLen
        } else {
            salt = nil
        }

        // Payload
        let payloadLength = Int(try readUInt32LE(from: data, at: offset))
        offset += 4
        guard offset + payloadLength <= data.count else { throw SerializationError.truncatedData }
        let payload = Data(data[offset..<(offset + payloadLength)])
        offset += payloadLength

        // Original length
        let originalLength = Int(try readUInt32LE(from: data, at: offset))

        // Decrypt if needed
        let compressed: Data
        if isEncrypted {
            guard let password = password else { throw SerializationError.passwordRequired }
            compressed = try decrypt(payload, password: password, salt: salt, version: version)
        } else {
            compressed = payload
        }

        // Decompress
        let rawData = try decompress(compressed, originalSize: originalLength)

        return Codeplug(modelIdentifier: modelIdentifier, rawData: rawData, metadata: metadata)
    }

    // MARK: - Safe Byte Reading

    private func readUInt16LE(from data: Data, at offset: Int) throws -> UInt16 {
        guard offset + 1 < data.count else { throw SerializationError.truncatedData }
        let low = UInt16(data[offset])
        let high = UInt16(data[offset + 1])
        return (high << 8) | low
    }

    private func readUInt32LE(from data: Data, at offset: Int) throws -> UInt32 {
        guard offset + 3 < data.count else { throw SerializationError.truncatedData }
        let b0 = UInt32(data[offset])
        let b1 = UInt32(data[offset + 1])
        let b2 = UInt32(data[offset + 2])
        let b3 = UInt32(data[offset + 3])
        return b0 | (b1 << 8) | (b2 << 16) | (b3 << 24)
    }

    // MARK: - Compression

    private func compress(_ data: Data) throws -> Data {
        let sourceSize = data.count
        let destinationSize = max(sourceSize + sourceSize / 16 + 64, 1024)
        var destination = Data(count: destinationSize)

        let compressedSize = try destination.withUnsafeMutableBytes { destBuf in
            try data.withUnsafeBytes { srcBuf in
                guard let destBase = destBuf.bindMemory(to: UInt8.self).baseAddress,
                      let srcBase = srcBuf.bindMemory(to: UInt8.self).baseAddress else {
                    throw SerializationError.compressionFailed
                }
                return compression_encode_buffer(
                    destBase,
                    destinationSize,
                    srcBase,
                    sourceSize,
                    nil,
                    COMPRESSION_LZFSE
                )
            }
        }

        guard compressedSize > 0 else { throw SerializationError.compressionFailed }
        destination.count = compressedSize
        return destination
    }

    private func decompress(_ data: Data, originalSize: Int) throws -> Data {
        var destination = Data(count: originalSize)

        let decompressedSize = try destination.withUnsafeMutableBytes { destBuf in
            try data.withUnsafeBytes { srcBuf in
                guard let destBase = destBuf.bindMemory(to: UInt8.self).baseAddress,
                      let srcBase = srcBuf.bindMemory(to: UInt8.self).baseAddress else {
                    throw SerializationError.decompressionFailed
                }
                return compression_decode_buffer(
                    destBase,
                    originalSize,
                    srcBase,
                    data.count,
                    nil,
                    COMPRESSION_LZFSE
                )
            }
        }

        guard decompressedSize == originalSize else { throw SerializationError.decompressionFailed }
        return destination
    }

    // MARK: - Encryption (AES-256-GCM via CryptoKit)

    /// Generates a cryptographically secure random salt for PBKDF2.
    private func generateSalt() -> Data {
        var salt = Data(count: Self.saltLength)
        salt.withUnsafeMutableBytes { buffer in
            guard let base = buffer.baseAddress else { return }
            _ = SecRandomCopyBytes(kSecRandomDefault, Self.saltLength, base)
        }
        return salt
    }

    /// Derives an encryption key from a password using PBKDF2-HMAC-SHA256.
    ///
    /// - Parameters:
    ///   - password: User-provided password
    ///   - salt: Random salt (16 bytes)
    ///   - rounds: Number of PBKDF2 iterations (100,000 for v2+)
    /// - Returns: 256-bit symmetric key for AES-256-GCM
    ///
    /// **Security Parameters (v2+):**
    /// - Algorithm: PBKDF2-HMAC-SHA256
    /// - Iterations: 100,000 (OWASP 2023 recommendation)
    /// - Salt length: 16 bytes (128 bits)
    /// - Output key length: 32 bytes (256 bits)
    ///
    /// **Legacy (v1):**
    /// - Algorithm: SHA-256 (single hash, no salt) - INSECURE
    /// - Maintained for backward compatibility only
    private func deriveKey(from password: String, salt: Data, rounds: Int) -> SymmetricKey {
        let passwordData = Data(password.utf8)

        // PBKDF2-HMAC-SHA256
        var derivedKeyData = Data(count: 32) // 256 bits
        derivedKeyData.withUnsafeMutableBytes { derivedKeyBytes in
            passwordData.withUnsafeBytes { passwordBytes in
                salt.withUnsafeBytes { saltBytes in
                    _ = CCKeyDerivationPBKDF(
                        CCPBKDFAlgorithm(kCCPBKDF2),
                        passwordBytes.baseAddress?.assumingMemoryBound(to: Int8.self),
                        passwordData.count,
                        saltBytes.baseAddress?.assumingMemoryBound(to: UInt8.self),
                        salt.count,
                        CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA256),
                        UInt32(rounds),
                        derivedKeyBytes.baseAddress?.assumingMemoryBound(to: UInt8.self),
                        32
                    )
                }
            }
        }

        return SymmetricKey(data: derivedKeyData)
    }

    /// Legacy v1 key derivation (INSECURE - kept for backward compatibility).
    /// Uses single SHA-256 hash without salt or iterations.
    private func legacyDeriveKey(from password: String) -> SymmetricKey {
        let passwordData = Data(password.utf8)
        let hash = SHA256.hash(data: passwordData)
        return SymmetricKey(data: hash)
    }

    private func encrypt(_ data: Data, password: String, salt: Data) throws -> Data {
        let key = deriveKey(from: password, salt: salt, rounds: Self.pbkdf2Rounds)
        let sealed = try AES.GCM.seal(data, using: key)
        guard let combined = sealed.combined else { throw SerializationError.encryptionFailed }
        return combined
    }

    private func decrypt(_ data: Data, password: String, salt: Data?, version: UInt16) throws -> Data {
        let key: SymmetricKey
        if version >= 2, let salt = salt {
            // v2+: PBKDF2 with salt
            key = deriveKey(from: password, salt: salt, rounds: Self.pbkdf2Rounds)
        } else {
            // v1: Legacy SHA-256 (no salt)
            key = legacyDeriveKey(from: password)
        }

        let box = try AES.GCM.SealedBox(combined: data)
        return try AES.GCM.open(box, using: key)
    }
}

/// Errors during codeplug serialization/deserialization.
public enum SerializationError: Error, LocalizedError {
    case invalidFormat
    case unsupportedVersion(UInt16)
    case truncatedData
    case passwordRequired
    case compressionFailed
    case decompressionFailed
    case encryptionFailed
    case decryptionFailed

    public var errorDescription: String? {
        switch self {
        case .invalidFormat: return "This file is not a valid RadioWriter codeplug"
        case .unsupportedVersion(let version): return "This codeplug was saved with a newer version of RadioWriter (format version \(version))"
        case .truncatedData: return "The file is incomplete or corrupted"
        case .passwordRequired: return "This codeplug is password-protected"
        case .compressionFailed: return "Could not save the codeplug"
        case .decompressionFailed: return "Could not open the codeplug"
        case .encryptionFailed: return "Could not encrypt the codeplug"
        case .decryptionFailed: return "Wrong password"
        }
    }

    public var recoverySuggestion: String? {
        switch self {
        case .invalidFormat:
            return "Make sure you are opening a .cpsx file saved by RadioWriter. Files from Motorola CPS software use a different format."
        case .unsupportedVersion:
            return "Update RadioWriter to the latest version to open this file."
        case .truncatedData:
            return "The file may have been cut short during a save or transfer. Try restoring from a backup if available."
        case .passwordRequired:
            return "Enter the password that was set when this codeplug was saved."
        case .compressionFailed:
            return "Check that there is sufficient disk space available and try saving again."
        case .decompressionFailed:
            return "The file may be corrupted. Try restoring from a backup if available."
        case .encryptionFailed:
            return "There was a problem encrypting the file. Try saving to a different location."
        case .decryptionFailed:
            return "The password you entered is incorrect. Check the password and try again."
        }
    }
}
