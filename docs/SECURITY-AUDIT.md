# Security Audit: Encryption Keys and Secrets

**Audit Date:** 2026-02-25
**Auditor:** Friday (automated security audit)
**Scope:** All encryption keys, secrets, passwords, and sensitive constants in the RadioWriter codebase
**Project Context:** Reverse engineering project for Motorola CPS radio programming software. CPS-extracted keys are expected and intentional.

---

## Executive Summary

The RadioWriter codebase contains **7 distinct encryption keys/secrets** across **2 source files** and **5 documentation files** that reference those keys. All identified keys are CPS-extracted protocol constants required for radio communication -- no personal credentials, API keys, or accidentally committed secrets were found.

**Overall Assessment: PASS** -- No unauthorized secrets detected. CPS keys are properly attributed, documented, and appropriately scoped.

---

## Inventory of All Keys and Secrets

### 1. Business Radio 3DES Key

| Property | Value |
|----------|-------|
| **File** | `Packages/RadioHardware/Sources/RadioProgrammer/CPSKeys.swift:16` |
| **Identifier** | `businessRadioDESKey` |
| **Value** | `HAVNCPSCMTTUNERAIRTRACER` (24 bytes, ASCII) |
| **Algorithm** | Triple DES (3DES) |
| **Source** | `secure.dll` -> `CSecureConstants.DefStrKey` |
| **CPS Versions** | Business Radio CPS r09.10, r09.11, r11.00 |
| **Purpose** | Encrypts/decrypts Business Radio CPS config files |
| **Access** | `public static let` |
| **Risk** | **Low** |
| **Status** | Properly documented with source attribution |

### 2. Business Radio 3DES IV

| Property | Value |
|----------|-------|
| **File** | `Packages/RadioHardware/Sources/RadioProgrammer/CPSKeys.swift:21` |
| **Identifier** | `businessRadioDESIV` |
| **Value** | `VEDKDJSP` (8 bytes, ASCII) |
| **Algorithm** | Triple DES IV |
| **Source** | `secure.dll` -> `CSecureConstants.DefStrIV` |
| **Purpose** | Initialization vector for Business Radio CPS 3DES |
| **Access** | `public static let` |
| **Risk** | **Low** |
| **Status** | Properly documented with source attribution |

### 3. Admin/License Key

| Property | Value |
|----------|-------|
| **File** | `Packages/RadioHardware/Sources/RadioProgrammer/CPSKeys.swift:39` |
| **Identifier** | `adminKey` |
| **Value** | `MOTOROLACHENGDUSITERBRTEAMCOM` (28 chars) |
| **Source** | `CMT.Web.dll` -> `WebLicense.ADMINKEY` |
| **Purpose** | License validation in Business Radio CPS |
| **Access** | `public static let` |
| **Risk** | **Low** |
| **Status** | Properly documented. This is a static key embedded in the CPS DLL, not a per-user credential. |

### 4. MOTOTRBO Cipher Key

| Property | Value |
|----------|-------|
| **File** | `Packages/RadioHardware/Sources/RadioProgrammer/CPSKeys.swift:50` |
| **Identifier** | `mototrboCipherKey` |
| **Value** | `Mot-Sols` (8 bytes, ASCII; hex: `4D 6F 74 2D 53 6F 6C 73`) |
| **Algorithm** | DES/AES hybrid |
| **Source** | `aes.dll` -> `authAES.AESCryptography.CIPHER_DEF_KEY` |
| **CPS Version** | MOTOTRBO CPS 2.0 |
| **Purpose** | Default cipher key for MOTOTRBO password encryption |
| **Access** | `public static let` |
| **Risk** | **Low** |
| **Status** | Properly documented with source attribution and hex representation |

### 5. MOTOTRBO Cipher IV

| Property | Value |
|----------|-------|
| **File** | `Packages/RadioHardware/Sources/RadioProgrammer/CPSKeys.swift:56` |
| **Identifier** | `mototrboCipherIV` |
| **Value** | `ABCD1234` (8 bytes, ASCII; hex: `41 42 43 44 31 32 33 34`) |
| **Algorithm** | DES/AES IV |
| **Source** | `aes.dll` -> `authAES.AESCryptography` (field `a`) |
| **Purpose** | Default IV for MOTOTRBO encryption |
| **Access** | `public static let` |
| **Risk** | **Low** |
| **Status** | Properly documented with source attribution |

### 6. XNL TEA Key (Authentication)

| Property | Value |
|----------|-------|
| **File** | `Packages/RadioHardware/Sources/RadioProgrammer/XNLEncryption.swift:20-25` |
| **Identifier** | `key` (private static) |
| **Value** | `[0x5A96301D, 0x0CF2AA55, 0xBF936CC6, 0xBD5ECD5B]` |
| **Raw Bytes** | `1D 30 96 5A 55 AA F2 0C C6 6C 93 BF 5B CD 5E BD` |
| **Algorithm** | TEA (Tiny Encryption Algorithm) variant |
| **Source** | `XnlAuthentication.dll` -> obfuscated class `iq` -> field `a` |
| **Purpose** | Challenge-response authentication with MOTOTRBO radios |
| **Access** | `private static let` (correctly scoped) |
| **Risk** | **Low** |
| **Status** | Properly documented with raw bytes, endianness notes, and verification date (2026-01-29) |

### 7. XNL TEA Delta Constant

| Property | Value |
|----------|-------|
| **File** | `Packages/RadioHardware/Sources/RadioProgrammer/XNLEncryption.swift:31` |
| **Identifier** | `delta` (private static) |
| **Value** | `0x790AB771` (decimal: 2030745457) |
| **Algorithm** | Custom TEA delta (NOT standard TEA delta 0x9E3779B9) |
| **Source** | `XnlAuthentication.dll` IL instruction `ldc.i4 2030745457` |
| **Purpose** | TEA round accumulator constant |
| **Access** | `private static let` (correctly scoped) |
| **Risk** | **Low** |
| **Status** | Properly documented with IL source reference and explicit warning that it differs from standard TEA |

### Nil/Placeholder Keys (Not Yet Extracted)

| Identifier | File | Status |
|-----------|------|--------|
| `mototrboAESKey` | `CPSKeys.swift:71` | `nil` -- Not found in MOTOTRBO CPS 2.0 |
| `mototrboAESIV` | `CPSKeys.swift:76` | `nil` -- Not found |
| `mototrboSigningPassword` | `CPSKeys.swift:81` | `nil` -- Not found |
| `mototrboSigningCertificate` | `CPSKeys.swift:85` | `nil` -- Not found |

These are correctly set to `nil` with documentation explaining they were not found during reverse engineering. No risk.

---

## Files Containing Key References

### Source Code (Keys Defined)

| File | Keys | Notes |
|------|------|-------|
| `Packages/RadioHardware/Sources/RadioProgrammer/CPSKeys.swift` | #1-5, nil placeholders | Central key registry. Well-documented. |
| `Packages/RadioHardware/Sources/RadioProgrammer/XNLEncryption.swift` | #6-7 | TEA implementation. Keys are `private static`. |

### Source Code (Keys Used)

| File | Usage | Notes |
|------|-------|-------|
| `Packages/RadioHardware/Sources/RadioProgrammer/XNLConnection.swift` | Calls `XNLEncryption.encrypt()` for auth, `XNLEncryption.encryptRadioKey()` for unlock | Correct usage. Keys never exposed. |
| `Packages/RadioCore/Sources/RadioCore/Serialization/CodeplugSerializer.swift` | AES-256-GCM via CryptoKit (user-supplied password, not CPS keys) | No CPS keys used. Uses PBKDF2. |
| `Packages/RadioCore/Tests/RadioCoreTests/SerializerTests.swift` | Test passwords: "secret123", "correct", "wrong", "secret", "same_password", "test123", "testPassword123" | Test-only. Not real credentials. |

### Documentation (Keys Referenced)

| File | What's Referenced |
|------|-------------------|
| `analysis/XPR_PROTOCOL_FINDINGS.md` | TEA key bytes, delta, auth index. Full extraction notes. |
| `docs/XNL-XCMP-Protocol-Whitepaper.md` | TEA key bytes referenced |
| `docs/protocols/ENCRYPTION_DETAILS.md` | TEA algorithm template with placeholder constants. Actual CPS key not embedded here. |
| `LEGAL.md` | References to extracted key values for legal context |
| `CONTRIBUTING.md` | References key bytes for contributor context |

---

## Non-CPS Secrets Scan

### Items Checked -- All Clear

| Check | Result |
|-------|--------|
| `.env` files | None found |
| `.pem`, `.p12`, `.pfx`, `.cer`, `.crt`, `.key` files | None found |
| `BEGIN PRIVATE KEY` / `BEGIN CERTIFICATE` patterns | None in source code |
| API keys (cloud services, SaaS) | None found |
| OAuth tokens / bearer tokens | None found |
| Personal credentials | None found |
| Hardcoded passwords (non-test) | None found |
| Cloud service endpoints with auth | None (DMRIDService uses public API at `radioid.net/api/dmr/user/` with no authentication) |

### Environment Variables Used

| Variable | File | Purpose | Risk |
|----------|------|---------|------|
| `RADIO_HW_TESTS` | `XPRConnectionTests.swift:15` | Gate for hardware integration tests | **None** -- test infrastructure only |
| `RADIO_HOST` | `XPRConnectionTests.swift:20` | Override default radio IP (192.168.10.1) | **None** -- test infrastructure, default is local link-layer IP |

---

## Key Handling Analysis

### XNLEncryption.swift -- GOOD

- TEA key is `private static let` -- not accessible outside the struct.
- Delta constant is `private static let` -- correctly scoped.
- Encrypt/decrypt methods are `public static` but only accept/return `Data` -- keys never leave the struct.
- `encryptRadioKey()` properly validates input length (32 bytes) before processing.
- `validateImplementation()` provides self-test capability.
- `printTestVectors()` logs key values with `privacy: .public` -- **NOTE:** This is a debug/test function. In release builds, `os.Logger` debug-level messages are stripped. Acceptable for development but should not be called in production code paths.

### CodeplugSerializer.swift -- GOOD

- Uses **no CPS keys** at all. This file handles RadioWriter's own `.cpsx` file format.
- Encryption: AES-256-GCM via Apple CryptoKit (industry standard).
- Key derivation: PBKDF2-HMAC-SHA256 with 100,000 iterations (meets OWASP 2023 recommendation).
- Salt: 16 bytes of `SecRandomCopyBytes` per encryption operation (cryptographically secure).
- Each serialization generates a unique salt + GCM nonce.
- Legacy v1 format support uses SHA-256 (no salt) -- documented as insecure, kept for backward compatibility.
- No hardcoded encryption keys -- all encryption is password-derived.

### CPSKeys.swift -- ACCEPTABLE WITH NOTES

- All keys are `public static let` -- accessible from any module importing `RadioProgrammer`.
- This is intentional: other modules need these keys for radio communication.
- Each key has doc comments with source DLL, field name, algorithm, and length.
- CPS version metadata is included via the `CPSVersion` struct.
- `hasKeys(for:)` and `cpsVersion(for:)` provide clean lookup interfaces.
- Keys are stored as plain ASCII strings or byte arrays -- no obfuscation.

### XNLConnection.swift -- GOOD

- Uses `XNLEncryption.encrypt()` to encrypt 8-byte auth challenge -- key never touched directly.
- Uses `XNLEncryption.encryptRadioKey()` to encrypt 32-byte radio key for unlock -- key never touched directly.
- Logs encrypted key values at debug level with `privacy: .public` -- acceptable for protocol debugging during development. Debug logs are stripped in release.
- Radio key (read from radio, encrypted, sent back) is never stored persistently.

---

## .gitignore Coverage

The `.gitignore` correctly excludes:

| Pattern | What It Protects |
|---------|------------------|
| `*.exe`, `*.dll`, `*.msi`, `*.cab` | Proprietary Motorola binaries |
| `Binaries/` | Extracted binary directory |
| `*.ctb`, `*.rdt`, `*.mdf`, `*.key` | CPS-format files that may contain proprietary data |
| `*.hdr` | Header files from CPS packages |
| `analysis/raw/`, `analysis/extracted_*/`, `analysis/payload_*/`, `analysis/unshielded/` | Raw analysis outputs that may contain proprietary content |
| `.build/`, `DerivedData/` | Build artifacts |
| `__pycache__/`, `.venv/` | Python analysis tool artifacts |

**No gaps identified.** The gitignore covers all relevant file types that could contain proprietary or sensitive data.

---

## Risk Assessment Summary

| Item | Risk Level | Justification |
|------|-----------|---------------|
| Business Radio 3DES Key + IV | **Low** | Protocol constant, physical access required, documented |
| Admin/License Key | **Low** | Static CPS DLL constant, not a user credential |
| MOTOTRBO Cipher Key + IV | **Low** | Protocol constant for password encryption |
| XNL TEA Key + Delta | **Low** | Authentication protocol constant, physical access required |
| Nil placeholder keys | **None** | Not extracted, set to nil |
| CodeplugSerializer encryption | **Low** | Strong cryptography (AES-256-GCM, PBKDF2 100k rounds) |
| Test passwords in SerializerTests | **None** | Test-only, not real credentials |
| DMRIDService API endpoint | **None** | Public API, no authentication required |
| Debug logging of key material | **Low** | Debug level only, stripped in release builds |
| Legacy v1 key derivation (SHA-256, no salt) | **Medium** | Insecure but only used for backward compatibility reads |

---

## Recommendations

### 1. Consider Key Obfuscation for Distribution (Priority: Low)

The CPS keys in `CPSKeys.swift` are stored as plaintext ASCII strings. While these are protocol constants (not secrets), if this project is distributed as a compiled binary, basic obfuscation could discourage casual extraction. This is a defense-in-depth measure, not a security requirement.

**Suggested approach:** XOR the key bytes with a compile-time constant and decode at runtime. This deters `strings` analysis without adding real complexity.

### 2. Remove printTestVectors() Before Release (Priority: Low)

`XNLEncryption.printTestVectors()` logs the TEA key and delta in formatted hex. While debug logs are stripped in release builds, the function itself remains compiled in. Consider gating it behind `#if DEBUG`:

```swift
#if DEBUG
public static func printTestVectors() {
    // existing implementation
}
#endif
```

### 3. Deprecate Legacy v1 Format (Priority: Medium)

`CodeplugSerializer` supports v1 files using SHA-256 without salt -- this is cryptographically weak. Plan to:
- Log a warning when reading v1 files
- Offer to re-save as v2 (PBKDF2 + salt)
- Eventually remove v1 read support after a transition period

### 4. Document Key Provenance in LEGAL.md (Priority: Low)

The keys are documented in source code comments, but `LEGAL.md` should also maintain a complete inventory of extracted keys with their legal basis (DMCA 1201(f) interoperability exemption). This appears to already be partially addressed -- verify it covers all 7 keys.

### 5. Pin RadioID.net API to HTTPS (Priority: None -- Already Done)

`DMRIDService.swift` uses `https://radioid.net/api/dmr/user/` -- confirmed HTTPS. No action needed.

---

## Conclusion

The RadioWriter codebase has a clean security posture for its stated purpose. All encryption keys are CPS-extracted protocol constants with clear source attribution. No personal credentials, API keys, cloud service secrets, or accidentally committed sensitive data was found. The `.gitignore` properly excludes proprietary binaries and analysis artifacts. The `CodeplugSerializer` uses modern cryptography (AES-256-GCM with PBKDF2) for RadioWriter's own file format, completely separate from the CPS-extracted keys.

The recommendations above are defense-in-depth improvements, not critical findings.
