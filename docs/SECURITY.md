# Security Model Documentation

**Document Version:** 1.1
**Date:** 2026-02-20

---

## Overview

This document describes the security model for the MotorolaCPS radio programming application, including network communication security, data handling, and threat considerations.

---

## Network Communication Model

### Transport Layer

The application communicates with MOTOTRBO radios over a **local network connection** using:

- **Protocol:** UDP (XNL/XCMP) or TCP (direct socket)
- **Port:** 4002 (XNL) or 8002 (TCP programming)
- **Network:** Direct USB-Ethernet (CDC ECM) connection to radio at 192.168.10.1

### Plaintext TCP/UDP Considerations

**Important:** Network traffic between the application and radio is transmitted in plaintext. This design decision reflects the original Motorola CPS behavior and operational requirements:

1. **Local-only connection:** The radio connection is over a direct USB-Ethernet link, not a routed network. The 192.168.10.1 address is only accessible on the local machine.

2. **Physical access required:** An attacker would need physical access to the USB cable connecting the computer to the radio.

3. **Protocol constraints:** The MOTOTRBO XNL/XCMP protocol does not support TLS or transport-layer encryption. The protocol includes its own authentication challenge-response mechanism.

4. **Interoperability requirement:** This application implements the standard Motorola protocol for compatibility. Adding transport encryption would break interoperability with the radio firmware.

### Authentication Security

The XNL protocol includes a challenge-response authentication mechanism:

1. Client requests authentication key from radio
2. Radio provides a challenge and encrypted key
3. Client responds with encrypted challenge response using radio-specific keys
4. Radio validates response and establishes session

**Note:** The authentication keys and encryption algorithms are documented in `docs/protocols/ENCRYPTION_DETAILS.md`. These are required for protocol interoperability, not application secrets.

### Encryption Key Storage

XNL/XCMP authentication requires static keys that are embedded in the application source code. This is intentional and expected for the following reasons:

1. **Protocol design:** The MOTOTRBO XNL protocol uses shared, device-class keys for authentication — not per-user or per-installation secrets. These keys are part of the protocol specification, not application credentials.

2. **Interoperability requirement:** Any software implementing the XNL protocol must use these keys. They are equivalent to a public standard, not a private secret.

3. **No privilege escalation risk:** Possession of these keys only allows programming radios that are physically connected via USB. They do not grant access to any network service, user data, or external system.

4. **Open source acknowledgment:** Because this project is open source, embedding these keys in source is transparent by design. They are not secrets that need protecting from the application's own users.

These keys are **not** used to protect user data. They are protocol-level authentication artifacts required for radio communication.

---

## Data Handling

### Data at Rest (Codeplug Files)

Codeplug files stored on disk may contain sensitive operational information:

| Data Type | Sensitivity | Notes |
|-----------|-------------|-------|
| Radio IDs (DMR/MDC) | Medium | Identifies specific radios/users |
| Programmed frequencies | Medium–High | Operational channels for public safety/commercial |
| Radio encryption keys (if present) | High | AES/DES keys for over-the-air encryption |
| CTCSS/DCS tones | Low | Squelch access tones |
| Talk groups | Low–Medium | Operational group assignments |

**Mitigations:**
- The application stores no codeplug data in its own data directory — files are written only to user-specified paths.
- No codeplug data is transmitted to external services.
- Users are responsible for securing codeplug files at rest. FileVault or equivalent disk encryption is recommended for deployments with high-sensitivity configurations.

### Data in Transit (XNL/XCMP Protocol)

Radio programming sessions transmit the full codeplug over the USB-Ethernet link. This data is in plaintext at the transport layer. The threat surface is intentionally narrow:

| Property | Value |
|----------|-------|
| Transport | UDP/TCP over USB-Ethernet (CDC ECM) |
| Network scope | Link-local only (192.168.10.1) — not routable |
| Authentication | XNL challenge-response per session |
| Encryption | None at transport layer (protocol constraint) |
| Exposure window | Duration of programming session only |

**Risk assessment:** Because the link is local-only and requires physical USB access, the practical risk of in-transit interception is low. An attacker capable of sniffing this traffic already has physical access to the machine, which represents a larger compromise.

### No Cloud Connectivity

This application:
- Does **not** connect to any cloud services
- Does **not** send telemetry or analytics
- Does **not** require internet connectivity
- Operates entirely offline with direct radio connections

---

## Threat Model

### Codeplug Data Threats

Codeplug files warrant specific threat modeling due to potentially sensitive content:

| Threat | Impact | Mitigation |
|--------|--------|------------|
| Unauthorized access to codeplug file on disk | High (if file contains encryption keys or sensitive frequencies) | User-controlled file permissions; FileVault recommended |
| Codeplug exfiltration via application | None | Application never transmits codeplug data externally |
| Codeplug tampering before write | Medium (misconfigured radio) | CRC validation; user review before programming |
| Accidental overwrite of radio config | Medium | Backup prompts; read-before-write workflow |

### Protocol-Level Threats

| Threat | Mitigation |
|--------|------------|
| Local network sniffing of USB-Ethernet traffic | Physical access control; local-only link-layer network |
| Malformed radio responses | Input validation on all protocol messages |
| Replay attack on XNL session | Per-session challenge-response prevents replay |
| Memory corruption from radio data | Bounds checking on all binary parsing |

### Out of Scope

| Threat | Rationale |
|--------|-----------|
| Man-in-the-middle on LAN | Radio uses direct USB connection, not LAN |
| Remote network attacks | No routable network exposure |
| Radio firmware exploits | Out of scope for CPS application |
| Theft of protocol authentication keys | Keys are public protocol artifacts, not secrets |

---

## Recommendations for Users

1. **Physical Security:** Ensure physical access control to the programming computer and radio during programming operations.

2. **Codeplug Storage:** Store codeplug files in encrypted storage if they contain sensitive information.

3. **Network Isolation:** When programming radios, ensure the computer is not connected to untrusted networks.

4. **File Integrity:** Verify codeplug file integrity before writing to radios in critical deployments.

---

## Privacy

This application:
- Collects no user data
- Contains no tracking or analytics
- Stores no data outside user-specified locations
- Requires no account or registration

See also: [Privacy Policy](PRIVACY_POLICY.md) for the full privacy commitments and data handling disclosures.

---

## Changelog

| Version | Date | Changes |
|---------|------|---------|
| 1.1 | 2026-02-20 | Link to PRIVACY_POLICY.md; add encryption key storage rationale; document data at rest and in transit; expand threat model with codeplug data section |
| 1.0 | 2026-02-02 | Initial security documentation |
