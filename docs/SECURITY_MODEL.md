# Security Model

**Document Version:** 1.0
**Date:** 2026-02-25

---

## Overview

RadioWriter is an offline macOS application. It has no server, no cloud backend, and no user accounts. The attack surface is narrow by design: a physical USB connection to a radio, and codeplug files on your local disk.

This document covers the security model for RadioWriter's own file format, the XNL/XCMP radio communication protocol, and the overall threat model.

See [SECURITY-AUDIT.md](SECURITY-AUDIT.md) for a full audit of encryption keys and secrets in the codebase.

---

## RadioWriter File Encryption (`.cpsx`)

RadioWriter uses its own `.cpsx` file format for saving and loading codeplugs. Encryption is optional — files can be saved without a password.

### Algorithm

| Parameter | Value |
|-----------|-------|
| Cipher | AES-256-GCM |
| Key derivation | PBKDF2-HMAC-SHA256 |
| PBKDF2 iterations | 100,000 (meets OWASP 2023) |
| Salt | 16 bytes, `SecRandomCopyBytes` per encryption |
| Nonce | Unique per encryption operation |
| Library | Apple CryptoKit |

Each save generates a fresh random salt and GCM nonce. Identical plaintexts produce different ciphertexts.

### Key Management (`CPSKeys.swift`)

`CPSKeys.swift` in `Packages/RadioHardware/Sources/RadioProgrammer/` is the central registry for CPS-extracted protocol constants. These are **not** keys used to protect user data. They are protocol authentication artifacts extracted from Motorola CPS software by static analysis — required for XNL/XCMP interoperability.

User file encryption uses only password-derived keys (PBKDF2). No static key from `CPSKeys.swift` touches `.cpsx` file encryption.

### Legacy v1 Format

The serializer supports reading v1 files (SHA-256 key derivation, no salt) for backward compatibility. This derivation is cryptographically weak. New files are always written as v2. Migrate v1 files by re-saving them.

---

## Radio Communication Security (XNL/XCMP)

### Transport

Radio communication is over a direct USB-Ethernet (CDC ECM) link. The radio appears at `192.168.10.1`, accessible only on the local machine. Traffic does not traverse any routed network.

| Property | Value |
|----------|-------|
| Protocol | UDP (XNL, port 4002) or TCP (port 8002) |
| Network scope | Link-local only — not routable |
| Encryption | None at transport layer (protocol constraint) |

The XNL/XCMP protocol does not support TLS. This matches Motorola's own CPS behavior. Because the link is physical and local-only, the practical risk of in-transit interception is low: an attacker who can sniff this traffic already has physical access to the machine.

### Authentication

XNL uses a challenge-response handshake per session:

1. Client requests an authentication challenge from the radio
2. Radio responds with a challenge and an encrypted key
3. Client encrypts the challenge using a TEA (Tiny Encryption Algorithm) variant with a static protocol key
4. Radio validates the response and establishes the session

The TEA key (`XNLEncryption.swift`) is a `private static let` — not accessible outside the struct. The encrypt/decrypt methods accept and return `Data`; the key never leaves the struct.

Session keys are never stored persistently. They exist only for the duration of the programming session.

### Protocol Authentication Keys

The XNL TEA key and all keys in `CPSKeys.swift` are CPS-extracted protocol constants documented with their source DLL, algorithm, and extraction method. They are required for interoperability, not application secrets. See [SECURITY-AUDIT.md](SECURITY-AUDIT.md) for the full inventory.

---

## Threat Model

### In Scope

| Threat | Mitigation |
|--------|------------|
| Unauthorized access to codeplug file on disk | User-controlled file system permissions; FileVault recommended for sensitive configs |
| Codeplug exfiltration via the application | Application never transmits codeplug data externally |
| Codeplug tampering before write | CRC validation; user review before programming |
| Accidental overwrite of radio config | Backup prompt; read-before-write workflow |
| Local network sniffing of USB-Ethernet | Physical access control; link-local network only |
| Malformed radio responses | Input validation and bounds checking on all binary parsing |
| Replay attack on XNL session | Per-session challenge-response prevents replay |
| Memory corruption from radio data | Bounds checking on all binary parsing |

### Out of Scope

| Threat | Rationale |
|--------|-----------|
| Man-in-the-middle on LAN | Radio uses direct USB connection, not LAN |
| Remote network attacks | No routable network exposure |
| Radio firmware exploits | Out of scope for a CPS application |
| Theft of protocol authentication keys | Keys are public protocol constants, not secrets |
| Compromise of RadioID.net API | User-initiated lookup only; no credentials sent |

---

## Data at Rest

| Data Type | Sensitivity | Notes |
|-----------|-------------|-------|
| Radio IDs (DMR/MDC) | Medium | Identifies specific radios/users |
| Programmed frequencies | Medium–High | Operational channels for public safety/commercial use |
| Radio encryption keys (if present in codeplug) | High | AES/DES over-the-air keys |
| CTCSS/DCS tones | Low | Squelch access tones |
| Talk groups | Low–Medium | Operational group assignments |

Codeplug files are written only to user-specified paths. No codeplug data is stored in the application's own data directory or transmitted externally.

Recommendation: Use FileVault for deployments with high-sensitivity configurations (encryption keys, licensed commercial frequencies).

---

## No Cloud Connectivity

RadioWriter:
- Does not connect to any cloud service
- Does not send telemetry or analytics
- Does not require internet access
- Operates entirely offline with direct radio connections

The only optional network feature is a user-initiated DMR ID lookup against the public RadioID.net API (HTTPS, no authentication required). See [PRIVACY_POLICY.md](PRIVACY_POLICY.md).

---

## Recommendations for Users

1. **Physical security:** Control physical access to the programming computer and radio during programming sessions.
2. **Codeplug storage:** Store codeplug files in FileVault-encrypted storage if they contain sensitive frequencies or over-the-air encryption keys.
3. **Network isolation:** Avoid connecting to untrusted networks during radio programming sessions.
4. **Backups:** Always read and save the existing codeplug before writing a new one.
5. **Legacy files:** Re-save any v1 `.cpsx` files to upgrade to v2 (PBKDF2 + AES-256-GCM).

---

## Related Documents

- [SECURITY-AUDIT.md](SECURITY-AUDIT.md) — Full inventory of encryption keys and secrets
- [PRIVACY_POLICY.md](PRIVACY_POLICY.md) — Data collection and handling
- [SECURITY.md](SECURITY.md) — Network communication security (legacy; this document supersedes it)
