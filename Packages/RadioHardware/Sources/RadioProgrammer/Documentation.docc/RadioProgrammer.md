# ``RadioProgrammer``

USB transport, radio discovery, XNL/XCMP protocol stack, and codeplug programming for Motorola radios.

## Overview

RadioHardware is the hardware-facing layer of RadioWriter. It handles everything from detecting a connected radio to reading and writing its codeplug over the wire. The package contains three logical sub-systems:

1. **USBTransport** — The `USBConnection` protocol and connection types (`NetworkConnection`, `SerialConnection`, `MockConnection`)
2. **Discovery** — `RadioDetector` (multi-method radio scanning)
3. **RadioProgrammer** — Protocol implementations (`MOTOTRBOProgrammer`, `RadioProgrammer`), XNL/XCMP stack, TEA encryption, and XCMP op-code definitions

---

## Protocol Stack Architecture

MOTOTRBO radios (XPR, SL, DP, DM series) use a two-layer protocol stack over TCP:

```
┌─────────────────────────────────────────┐
│              XCMP                       │  Application layer
│  Radio queries, codeplug read/write     │  Op-codes: 0x000F–0x040A+
├─────────────────────────────────────────┤
│              XNL                        │  Session layer
│  Authentication, message framing,       │  TCP port 8002
│  address assignment                     │
├─────────────────────────────────────────┤
│              TCP / IP                   │  Transport / Network
│  CDC-ECM or direct network              │
├─────────────────────────────────────────┤
│  USB (CDC-ECM) or serial cable          │  Physical
└─────────────────────────────────────────┘
```

CLP and older serial-cable radios use a simpler byte-stream protocol (STX/ACK + block read/write) managed by ``RadioProgrammer``.

---

## Radio Discovery

``RadioDetector`` is a `@MainActor @Observable` class that polls for connected radios every 2 seconds. It tries five discovery methods in priority order:

| Method | Mechanism | When used |
|--------|-----------|-----------|
| 1 | IOKit USB VID/PID scan (VID `0x0CAD`, PIDs `0x1020`–`0x102D`) | Always first |
| 2 | CDC-ECM network interface scan | When Motorola USB device found |
| 3 | mDNS `_otap._tcp.local` Bonjour browse | Fallback if no USB network found |
| 4 | IP range scan (TCP port 8002 probe) | Fallback for all network types |
| 5 | Serial port scan (`/dev/cu.usbserial*`, `cu.usbmodem*`, SLAB, CH340) | Always (serial cable radios) |

Detected radios are reported as ``USBDeviceInfo`` with a ``RadioConnectionType`` of `.serial(path:)` or `.network(ip:interface:)`.

---

## XNL Connection and Authentication

``XNLConnection`` is a Swift `actor` that manages a single raw TCP connection to a radio on port 8002. It uses BSD sockets with `TCP_NODELAY` rather than NWConnection (found unreliable with this protocol).

### Authentication Sequence

Every XNL session performs a full challenge-response authentication before any XCMP traffic:

```
Client                          Radio
  │                               │
  │──── DeviceMasterQuery ────────▶│  XNL opcode 0x04
  │◀─── MasterStatusBroadcast ────│  XNL opcode 0x02 — contains 8-byte auth seed
  │                               │
  │──── DeviceSysMapBroadcast ────▶│  XNL opcode 0x05 — CPS also does this
  │──── DeviceAuthKey ────────────▶│  XNL opcode 0x06 — TEA-encrypted auth response
  │◀─── DeviceAuthKeyReply ────────│  XNL opcode 0x07 — assigned XNL address
  │                               │
  │  (XCMP commands follow)       │
```

See ``XNLOpCode`` for the full opcode enumeration verified against CPS 2.0 captures.

### XNL Packet Format

Every XNL packet has a 14-byte header:

```
Offset  Size  Field              Byte order
------  ----  -----              ----------
0       2     Total length       Big-endian
2       2     Op code            Big-endian
4       1     Protocol           0x00 = XNL only, 0x01 = XCMP payload
5       1     Flags              Sequence counter (0–7, wraps)
6       2     Destination        Big-endian
8       2     Source             Big-endian
10      2     Transaction ID     Big-endian
12      2     Payload length     Big-endian
14      N     Payload
```

---

## TEA Authentication Encryption

``XNLEncryption`` implements a custom TEA (Tiny Encryption Algorithm) variant. The key and delta were extracted from `XnlAuthentication.dll` via static analysis.

**Key** (16 bytes, little-endian UInt32 words as read by .NET BitConverter):

```
1D 30 96 5A  55 AA F2 0C  C6 6C 93 BF  5B CD 5E BD
```

**Delta:** `0x790AB771` — this is *not* the standard TEA delta (`0x9E3779B9`).

**Algorithm:** 32-round TEA, inputs as big-endian UInt32 pairs, output as big-endian UInt32 pairs.

This encryption is used only for XNL authentication. The `.cpsx` file format uses AES-256-GCM (see ``RadioCore``).

---

## XCMP Commands

``XCMPOpCode`` (in `XCMPProtocol.swift`) enumerates all known XCMP operation codes. Request codes have the high bit clear; reply codes have `0x8000` ORed in.

### Verified Commands (from CPS 2.0 captures, 2026-01-30)

| Op-code | Name | Purpose |
|---------|------|---------|
| `0x000F` | `versionInfoRequest` | Firmware/version query |
| `0x0010` | `modelNumberRequest` | Radio model string |
| `0x0011` | `serialNumberRequest` | Radio serial number |
| `0x0012` | `securityKeyRequest` | 16-byte session key (no params) |
| `0x001F` | `codeplugIdRequest` | Codeplug identifier |
| `0x002E` | `codeplugReadRequest` | Codeplug read (record-based, not linear) |
| `0x003D` | `statusFlagsRequest` | Status flags |
| `0x0037` | `featureSetRequest` | Feature set query |
| `0x010B` | `psdtAccessRequest` | PSDT partition access (Lock/Unlock/Erase/Copy) |
| `0x010F` | `componentSessionRequest` | Programming session lifecycle |

**Important finding:** CPS 2.0 reads codeplugs without entering programming mode (`0x0106`). Programming mode is required for *writes* only.

### XCMP Packet Format

XCMP packets are carried as XNL `dataMessage` (opcode `0x0B`) payloads:

```
Offset  Size  Field
------  ----  -----
0       2     Op-code (big-endian)
2       N     Command-specific parameters
```

---

## MOTOTRBOProgrammer

``MOTOTRBOProgrammer`` is the high-level `actor` for MOTOTRBO radio operations. It owns an ``XNLConnection`` and an `XCMPClient`, and exposes async methods for connecting, reading, writing, and querying device info.

Each logical operation (e.g., read model number, read codeplug) uses its own TCP session — this matches observed CPS 2.0 behavior where every "read" operation opens and closes two separate TCP sessions.

---

## RadioProgrammer (Serial/Legacy)

``RadioProgrammer`` handles older serial-cable radios using a simpler block protocol:

- Enter programming mode: STX (`0x02`) → ACK (`0x06`)
- Read block: `'R'` + 2-byte offset + 1-byte length → data + checksum
- Write block: `'W'` + 2-byte offset + 1-byte length + data + checksum → ACK
- Exit: `'E'` (`0x45`)

Blocks are 64 bytes. A trailing byte checksum (byte-additive) protects each read response.

``ProgrammerState`` tracks the current operation (`.idle`, `.reading`, `.writing`, `.verifying`, `.error`).

---

## USBConnection Protocol

``USBConnection`` is the `Actor`-based protocol that all transport implementations conform to. Concrete types:

| Type | Transport |
|------|-----------|
| `NetworkConnection` | TCP/IP (MOTOTRBO CDC-ECM) |
| `SerialConnection` | Serial port (programming cable) |
| `MockConnection` | In-process mock for testing |

``USBError`` provides user-facing error messages with recovery suggestions.

---

## Supported Port Numbers

| Port | Protocol | Usage |
|------|----------|-------|
| 8002 (TCP) | XNL/XCMP | CPS programming (subscriber/read/write) |
| 4002 (UDP) | XCMP/XNL | Repeater/network mode |
| 8501 (TCP/UDP) | AT debug | Interactive AT command interface |
| 50000–50002 (UDP) | IPSC | IP Site Connect / data |

## Topics

### Radio Discovery

- ``RadioDetector``
- ``USBDeviceInfo``
- ``RadioConnectionType``

### USB Transport

- ``USBConnection``
- ``USBError``

### MOTOTRBO Programming

- ``MOTOTRBOProgrammer``
- ``XNLConnection``
- ``XNLConnectionResult``
- ``XNLEncryption``

### Protocol Definitions

- ``XNLOpCode``
- ``XCMPOpCode``
- ``XCMPOpcode``
- ``RadioPartition``
- ``ProgramModeAction``

### Legacy (Serial) Programming

- ``RadioProgrammer``
- ``ProgrammerState``
- ``ProgrammerError``
