# Security Model Documentation

**Document Version:** 1.0
**Date:** 2026-02-02

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

---

## Data Handling

### Codeplug Data

- Codeplugs may contain sensitive information (radio IDs, frequencies, encryption keys)
- Codeplug files are stored locally in user-specified locations
- No codeplug data is transmitted to external servers
- Users are responsible for securing codeplug files

### No Cloud Connectivity

This application:
- Does **not** connect to any cloud services
- Does **not** send telemetry or analytics
- Does **not** require internet connectivity
- Operates entirely offline with direct radio connections

---

## Threat Model

### In Scope

| Threat | Mitigation |
|--------|------------|
| Local network sniffing of USB-Ethernet traffic | Physical access control; local-only network |
| Malformed radio responses | Input validation on all protocol messages |
| Codeplug file tampering | CRC validation on codeplug records |
| Memory corruption from radio data | Bounds checking on all binary parsing |

### Out of Scope

| Threat | Rationale |
|--------|-----------|
| Man-in-the-middle on LAN | Radio uses direct USB connection, not LAN |
| Remote network attacks | No routable network exposure |
| Radio firmware exploits | Out of scope for CPS application |

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

See also: Future privacy policy in preparation for distribution.

---

## Changelog

| Version | Date | Changes |
|---------|------|---------|
| 1.0 | 2026-02-02 | Initial security documentation |
