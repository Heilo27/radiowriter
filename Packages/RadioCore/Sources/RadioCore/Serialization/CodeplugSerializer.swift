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
        let version = readUInt16LE(from: data, at: offset)
        guard version <= Self.formatVersion else { throw SerializationError.unsupportedVersion(version) }
        offset += 2

        // Metadata
        let metadataLength = Int(readUInt32LE(from: data, at: offset))
        offset += 4
        guard offset + metadataLength <= data.count else { throw SerializationError.truncatedData }
        let metadataJSON = data[offset..<(offset + metadataLength)]
        let metadata = try JSONDecoder().decode(CodeplugMetadata.self, from: Data(metadataJSON))
        offset += metadataLength

        // Model identifier
        let modelLength = Int(readUInt16LE(from: data, at: offset))
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
            let saltLen = Int(readUInt16LE(from: data, at: offset))
            offset += 2
            guard offset + saltLen <= data.count else { throw SerializationError.truncatedData }
            salt = Data(data[offset..<(offset + saltLen)])
            offset += saltLen
        } else {
            salt = nil
        }

        // Payload
        let payloadLength = Int(readUInt32LE(from: data, at: offset))
        offset += 4
        guard offset + payloadLength <= data.count else { throw SerializationError.truncatedData }
        let payload = Data(data[offset..<(offset + payloadLength)])
        offset += payloadLength

        // Original length
        let originalLength = Int(readUInt32LE(from: data, at: offset))

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

    private func readUInt16LE(from data: Data, at offset: Int) -> UInt16 {
        let low = UInt16(data[offset])
        let high = UInt16(data[offset + 1])
        return (high << 8) | low
    }

    private func readUInt32LE(from data: Data, at offset: Int) -> UInt32 {
        let b0 = UInt32(data[offset])
        let b1 = UInt32(data[offset + 1])
        let b2 = UInt32(data[offset + 2])
        let b3 = UInt32(data[offset + 3])
        return b0 | (b1 << 8) | (b2 << 16) | (b3 << 24)
    }

    // MARK: - Compression

    private func compress(_ data: Data) throws -> Data {
        let sourceSize = data.count
        let destinationSize = sourceSize + 64 // overhead buffer
        var destination = Data(count: destinationSize)

        let compressedSize = destination.withUnsafeMutableBytes { destBuf in
            data.withUnsafeBytes { srcBuf in
                compression_encode_buffer(
                    destBuf.bindMemory(to: UInt8.self).baseAddress!,
                    destinationSize,
                    srcBuf.bindMemory(to: UInt8.self).baseAddress!,
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

        let decompressedSize = destination.withUnsafeMutableBytes { destBuf in
            data.withUnsafeBytes { srcBuf in
                compression_decode_buffer(
                    destBuf.bindMemory(to: UInt8.self).baseAddress!,
                    originalSize,
                    srcBuf.bindMemory(to: UInt8.self).baseAddress!,
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
            // Use SecRandomCopyBytes for cryptographic randomness
            _ = SecRandomCopyBytes(kSecRandomDefault, Self.saltLength, buffer.baseAddress!)
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
                    CCKeyDerivationPBKDF(
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
        case .invalidFormat: return "Not a valid CPSX file"
        case .unsupportedVersion(let v): return "Unsupported format version: \(v)"
        case .truncatedData: return "File appears to be truncated"
        case .passwordRequired: return "This file is encrypted. A password is required."
        case .compressionFailed: return "Failed to compress data"
        case .decompressionFailed: return "Failed to decompress data"
        case .encryptionFailed: return "Failed to encrypt data"
        case .decryptionFailed: return "Failed to decrypt data"
        }
    }
}
