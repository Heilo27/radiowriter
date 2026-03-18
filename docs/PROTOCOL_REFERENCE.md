# MOTOTRBO Protocol Reference

**Status:** Authoritative consolidated reference
**Verified against:** CPS 2.0 traffic captures (7 sessions, 2026-01-30) and static analysis of MOTOTRBO CPS DLLs
**Target radio:** XPR 3500e — findings apply broadly to MOTOTRBO DMR series

> Prior art sources: `Moto.Net` (C# implementation), `xcmp-xnl-dissector` (Wireshark plugin), CPS DLL IL decompilation

---

## Table of Contents

1. [Protocol Overview](#1-protocol-overview)
2. [Transport and Network Configuration](#2-transport-and-network-configuration)
3. [XNL Protocol Layer](#3-xnl-protocol-layer)
4. [XNL Authentication Sequence](#4-xnl-authentication-sequence)
5. [XNL Encryption](#5-xnl-encryption)
6. [XCMP Protocol Layer](#6-xcmp-protocol-layer)
7. [Codeplug Read Sequence](#7-codeplug-read-sequence)
8. [Codeplug Write Sequence](#8-codeplug-write-sequence)
9. [Codeplug Format](#9-codeplug-format)
10. [Supported Operations by Radio Family](#10-supported-operations-by-radio-family)

---

## 1. Protocol Overview

MOTOTRBO radios use a two-layer proprietary protocol for computer-aided programming:

| Layer | Name | Role |
|-------|------|------|
| Application | **XCMP** (eXtended Command and Management Protocol) | Radio queries, codeplug read/write commands |
| Session | **XNL** (eXtended Network Layer or Extensible Network Link) | Authentication, message framing, address assignment |
| Transport | TCP port 8002 | Subscriber/CPS programming mode |
| Physical | USB CDC-ECM or serial cable | |

XCMP payloads are carried inside XNL `dataMessage` (opcode `0x0B`) packets.

**Important:** TCP port 8002 is for CPS/subscriber programming. UDP port 4002 is for repeater/network mode. RadioWriter uses TCP 8002.

---

## 2. Transport and Network Configuration

### USB CDC-ECM (XPR series)

When an XPR radio is connected via USB it presents as a CDC-ECM (USB network adapter):

| Parameter | Value |
|-----------|-------|
| Radio IP | 192.168.10.1 |
| Host IP (DHCP) | 192.168.10.2 |
| Subnet | 255.255.255.0 |
| CPS programming port | TCP 8002 |
| Repeater mode port | UDP 4002 |
| AT debug | TCP/UDP 8501 |
| IPSC data | UDP 50000–50002 |

**macOS note:** The CDC-ECM interface may become the default gateway, breaking internet connectivity. Fix: reorder network services in System Settings → Network.

### Discovery Methods (RadioDetector)

RadioWriter tries five methods in order:

1. IOKit USB scan for VID `0x0CAD`, PIDs `0x1020`–`0x102D`
2. CDC-ECM network interface scan (once Motorola USB device found)
3. mDNS Bonjour browse for `_otap._tcp.local`
4. IP range scan (TCP port 8002 probe across 192.168.x.x, 172.16.x.x, 10.x.x.x, 169.254.x.x)
5. Serial port scan (`/dev/cu.usbserial*`, `cu.usbmodem*`, SLAB, CH340)

---

## 3. XNL Protocol Layer

### Packet Format

Every XNL packet has a fixed 14-byte header:

```
Offset  Size  Field              Byte order  Notes
------  ----  -----              ----------  -----
0       2     Total length       Big-endian  Includes header
2       2     Op code            Big-endian  See XNL op-codes below
4       1     Protocol           —           0x00 = XNL only; 0x01 = XCMP payload
5       1     Flags              —           Sequence counter 0–7, wraps
6       2     Destination        Big-endian  XNL address
8       2     Source             Big-endian  XNL address
10      2     Transaction ID     Big-endian
12      2     Payload length     Big-endian
14      N     Payload            —
```

### XNL Op-Codes (verified from CPS 2.0 captures)

| Op-code | Direction | Name | Notes |
|---------|-----------|------|-------|
| `0x02` | Radio → Client | `MasterStatusBroadcast` | First packet after TCP connect |
| `0x04` | Client → Radio | `DeviceMasterQuery` | Query after receiving status |
| `0x05` | Radio → Client | `DeviceSysMapBroadcast` | Contains 8-byte auth seed |
| `0x06` | Client → Radio | `DeviceAuthKey` | TEA-encrypted auth response |
| `0x07` | Radio → Client | `DeviceAuthKeyReply` | Contains assigned XNL address |
| `0x09` | Radio → Client | `DeviceConnReply` | Connection parameters |
| `0x0B` | Bidirectional | `DataMessage` | XCMP payload carrier |
| `0x0C` | Bidirectional | `DataMessageAck` | ACK — CPS does NOT send these |

**Key finding from captures:** CPS never sends `DataMessageAck` (0x0C). It relies on TCP acknowledgement only.

---

## 4. XNL Authentication Sequence

Every XNL TCP session authenticates from scratch. CPS opens and closes two separate TCP sessions per logical "read" operation.

```
Step  Client                            Radio
----  ------                            -----
1     ── DeviceMasterQuery (0x04) ────▶
2                                       ◀── MasterStatusBroadcast (0x02)
      (Learn master address from source field)
      (Learn device type: 0x01=repeater, 0x02=subscriber)
3     ── DeviceSysMapBroadcast (0x05) ─▶
4     ── DeviceAuthKey (0x06) ─────────▶
      (Payload: TEA-encrypted 8-byte seed from step 2)
5                                       ◀── DeviceAuthKeyReply (0x07)
      (Payload includes assigned XNL address — use as source for all future packets)
6     XCMP commands follow inside DataMessage (0x0B) packets
```

### DeviceAuthKey Payload (step 4)

```
Offset  Size  Field
------  ----  -----
0       2     Connection address (0x0000 for new connection)
1       1     Connection type (0x0A typical)
2       1     Auth index (0x00 = CPS, 0x01 = control station)
3       8     Encrypted auth response
```

### DeviceAuthKeyReply Payload (step 5)

```
Offset  Size  Field
------  ----  -----
0       1     Result code (0x01 = success)
1       1     Transaction ID base
2       2     Assigned XNL ID
4       1     Connection type
5       1     Connection number
6       8     Connection auth info
```

### Session Prefix Pattern

From 7 CPS capture sessions:

- Session prefix decrements by 1 per new TCP connection
- Assigned XNL address increments as radio assigns addresses
- Transaction ID pattern: `(assigned_address + 1) << 8 | counter`

---

## 5. XNL Encryption

XNL authentication uses a TEA (Tiny Encryption Algorithm) variant — **not** standard TEA.

### CPS Encryption (auth index 0x00 — used by RadioWriter)

Key extracted from `XnlAuthentication.dll` via static analysis. Raw bytes:

```
1D 30 96 5A  55 AA F2 0C  C6 6C 93 BF  5B CD 5E BD
```

Interpreted as four little-endian UInt32 values (as .NET BitConverter reads on x86):

```swift
let key: [UInt32] = [
    0x5A96301D,   // bytes  0– 3
    0x0CF2AA55,   // bytes  4– 7
    0xBF936CC6,   // bytes  8–11
    0xBD5ECD5B    // bytes 12–15
]
let delta: UInt32 = 0x790AB771  // NOT standard TEA delta 0x9E3779B9
```

**Algorithm** (32-round TEA, big-endian input/output):

```swift
// Input: 8-byte challenge from radio (DeviceSysMapBroadcast payload)
// Output: 8-byte encrypted response

var v0 = UInt32(bigEndian: data[0..<4])
var v1 = UInt32(bigEndian: data[4..<8])
var sum: UInt32 = 0

for _ in 0..<32 {
    sum = sum &+ delta
    v0 = v0 &+ (((v1 << 4) &+ key[0]) ^ (v1 &+ sum) ^ ((v1 >> 5) &+ key[1]))
    v1 = v1 &+ (((v0 << 4) &+ key[2]) ^ (v0 &+ sum) ^ ((v0 >> 5) &+ key[3]))
}
// Write v0, v1 back as big-endian bytes
```

**Verified working:** 2026-01-29 against live XPR 3500e.

### Other Encryption Modes (not used by RadioWriter)

| Mode | Auth index | Device type | Key source |
|------|-----------|-------------|------------|
| ControlStation | 0x01 | Subscriber (0x02) | 6 separate constants, not public |
| RepeaterIPSC | 0x01 | Repeater (0x01) | 6 separate constants, not public |
| CPS | 0x00 | Any | Extracted — see above |

---

## 6. XCMP Protocol Layer

XCMP packets are carried as the payload of XNL `DataMessage` (0x0B) packets.

### XCMP Packet Format

```
Offset  Size  Field
------  ----  -----
0       2     Op-code (big-endian)
2       N     Command-specific parameters
```

Reply op-codes have `0x8000` ORed into the request op-code (e.g., request `0x000F` → reply `0x800F`).

### Verified Op-Codes (from CPS 2.0 captures, 2026-01-30)

| Op-code | Reply | Name | Purpose |
|---------|-------|------|---------|
| `0x000F` | `0x800F` | `versionInfoRequest` | Firmware version (param 0x00=full, 0x41=build) |
| `0x0010` | `0x8010` | `modelNumberRequest` | Radio model string |
| `0x0011` | `0x8011` | `serialNumberRequest` | Serial number |
| `0x0012` | `0x8012` | `securityKeyRequest` | 16-byte session key (no params) |
| `0x001F` | `0x801F` | `codeplugIdRequest` | Codeplug identifier (params: 0x00 0x00) |
| `0x002C` | `0x802C` | `languagePackRequest` | Language pack info |
| `0x002E` | `0x802E` | `codeplugReadRequest` | Codeplug read (record-based, not linear) |
| `0x003D` | `0x803D` | `statusFlagsRequest` | Status flags (params: 0x00 0x00) |
| `0x0037` | `0x8037` | `featureSetRequest` | Feature set (3-byte params) |
| `0x010B` | `0x810B` | `psdtAccessRequest` | PSDT partition access |
| `0xB10B` | — | `psdtAccessBroadcast` | PSDT operation progress |
| `0x010F` | `0x810F` | `componentSessionRequest` | Programming session lifecycle |

**Critical finding:** CPS reads codeplugs *without* entering programming mode (`0x0106`). Programming mode is required for writes only.

### PsdtAccess (0x010B) Actions

```
0x01  GetStartAddress   Query partition start address → returns uint32
0x02  GetEndAddress     Query partition end address → returns uint32
0x03  Lock              Lock partition
0x04  Unlock            Unlock partition
0x05  Erase             Erase partition
0x06  Copy              Copy data between partitions
0x07  ImageReorg        Reorganize partition image
```

### ComponentSession (0x010F) Action Flags

```
0x0001  Reset
0x0002  StartSession
0x0004  Snapshot
0x0008  ValidateCRC
0x0010  UnpackFiles
0x0020  Deploy
0x0040  DelayTOD
0x0080  SuppressPN
0x0100  Status
0x0200  ReadWrite
0x0400  CreateArchive
0x0800  ProgrammingIndicator

Common combos:
  0x0202  StartSession | ReadWrite        ← Read session
  0x0A02  StartSession | ReadWrite | ProgrammingIndicator  ← Write session
  0x0400  CreateArchive                  ← Create codeplug archive
```

---

## 7. Codeplug Read Sequence

From CPS 2.0 traffic analysis (verified):

```
Session 1 (TCP connect → disconnect):
  1. XNL authentication (full, as above)
  2. SecurityKeyRequest (0x0012) → get 16-byte session key
  3. ModelNumberRequest (0x0010)
  4. VersionInfoRequest (0x000F) with 0x00, 0x41, P/R/Q variants
  5. SerialNumberRequest (0x0011)
  6. CodeplugIdRequest (0x001F)
  7. Disconnect

Session 2 (TCP connect → disconnect):
  1. XNL authentication (full, new challenge)
  2. StatusFlagsRequest (0x003D)
  3. FeatureSetRequest (0x0037)
  4. LanguagePackRequest (0x002C)
  5. CodeplugReadRequest (0x002E) — record-list format
  6. [Transfer loop until codeplug complete]
  7. Disconnect
```

**Note:** Each `read` in CPS = 2 separate TCP sessions. This is intentional.

---

## 8. Codeplug Write Sequence

Write requires programming mode entry. Not yet implemented in RadioWriter (XPR write path in progress as of 2026-02-25).

```
1. XNL authentication
2. IshProgramModeRequest (0x0106), action EnterProgramMode (0x01)
3. ComponentSession (0x010F), StartSession | ReadWrite | ProgrammingIndicator
4. PsdtAccess — GetStartAddress for target partition
5. PsdtAccess — Unlock partition
6. Data transfer loop (XcmpTransferData)
7. ComponentSession — ValidateCRC
8. ComponentSession — Deploy
9. IshProgramModeRequest (0x0106), action ExitProgramMode (0x00)
```

### ISH Program Mode Actions (0x0106)

```
0x00  ExitProgramMode
0x01  EnterProgramMode
0x02  EnterCloneMode
0x03  ExitWithoutRadioReset
0x04  EnterOtapWriteMode
0x05  EnterOtapReadMode
0x06  ExitOtapModeWithChecksum
0x07  EnterRemoteProgrammingMode
```

---

## 9. Codeplug Format

### MOTOTRBO (XPR / record-based)

XPR codeplugs use a record-based format accessed via `codeplugReadRequest` (0x002E). The binary is not a flat linear address space — it is organized into named PSDT (Persistent Storage Data Table) partitions.

Key partition IDs (4 bytes ASCII, null-padded):

| ID | Content |
|----|---------|
| `0x80` | Application (main codeplug data) |
| `0x81` | Security settings |
| `0x82` | Tuning/calibration |
| `0x87` | CFS data |

### CLP (and legacy serial-cable radios — linear/binary)

CLP codeplugs are flat binary blobs with bit-packed fields. Field naming follows the `CP_*` convention from `BL.Clp.Constants.dll`:

```
CP_CHANNEL_RX_FREQ        — RX frequency (raw, 100 Hz units)
CP_CHANNEL_TX_FREQ        — TX frequency
CP_CHANNEL_NAME           — Channel name (fixed-length, null-padded)
CP_CHANNEL_RX_PL          — RX CTCSS/DCS code index
CP_CHANNEL_TX_PL          — TX CTCSS/DCS code index
CP_CHANNEL_TX_POWER       — TX power level
CP_CHANNEL_INSCANLIST     — Scan list membership bitmask
CP_DISABLE_CHANNEL        — Inverted enable flag (0 = enabled)
```

**Inversion convention:** Fields named `Disable*` or `Quiet Mode` are stored inverted relative to the UI. `UnpackTransform_Quiet_Mode` returns `!CPValue`.

**Version encoding:** 3 bytes `[ASCII char][major byte][minor byte]` → display string `"R03.00"`.

**File extensions:** `.rdt` (radio data), `.ctb` (codeplug template).

### RadioWriter Native Format (.cpsx)

RadioWriter's own save format wraps the raw binary in a versioned envelope:

```
[Magic: "CPSX" 4 bytes]
[Format version: UInt16 LE]
[Metadata JSON length: UInt32 LE]
[Metadata JSON: radio serial, model, firmware, dates]
[Model identifier length: UInt16 LE]
[Model identifier: UTF-8]
[Encrypted flag: UInt8]
[Salt length: UInt16 LE]         ← v2 only
[Salt: 16 bytes]                 ← v2 only
[Payload length: UInt32 LE]
[Payload: LZFSE-compressed, optionally AES-256-GCM encrypted]
[Original data length: UInt32 LE]
```

Encryption: AES-256-GCM. Key derivation: PBKDF2-HMAC-SHA256, 100,000 iterations, 16-byte random salt (v2). v1 used plain SHA-256 with no salt — insecure, supported for reading only.

---

## 10. Supported Operations by Radio Family

| Family | Read | Write | Verify write | Notes |
|--------|------|-------|-------------|-------|
| XPR | Stable | In progress | No | XCMP/XNL over CDC-ECM |
| CLP | Stable | Stable | No | Serial cable, linear protocol |
| APX | Experimental | No | No | |
| CP200 | Experimental | Experimental | No | |
| DLR, DTR, SL300, RM, RDM, RMU, RMM, RDU, CLS, VL/RDU4100 | Experimental | Experimental | No | |

---

*For implementation details see the DocC articles in each package:*
- `RadioCore` — data model, serialization, binary I/O, transforms
- `RadioModelCore` — radio model registry, field definitions, parsed domain model
- `RadioProgrammer` — discovery, XNL/XCMP stack, transport
