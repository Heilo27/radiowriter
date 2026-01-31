# XNL/XCMP Protocol White Paper
## Motorola MOTOTRBO Radio Communication Protocol

**Version:** 1.0
**Date:** 2026-01-30
**Status:** VERIFIED AND IMPLEMENTED
**Target Radio:** XPR 3500e (MOTOTRBO)

---

## Table of Contents

1. [Executive Summary](#executive-summary)
2. [Protocol Stack Overview](#protocol-stack-overview)
3. [Transport Layer Requirements](#transport-layer-requirements)
4. [XNL Protocol Layer](#xnl-protocol-layer)
5. [XNL Authentication Sequence](#xnl-authentication-sequence)
6. [XCMP Command Protocol](#xcmp-command-protocol)
7. [DeviceInitStatusBroadcast Handshake](#deviceinitstatusbroadcast-handshake)
8. [Multi-Command Sessions](#multi-command-sessions)
9. [XCMP Command Reference](#xcmp-command-reference)
10. [Implementation Requirements](#implementation-requirements)
11. [Common Pitfalls](#common-pitfalls)
12. [Our Implementation Status](#our-implementation-status)

---

## Executive Summary

This white paper documents the complete XNL/XCMP protocol used for communication between programming software and Motorola MOTOTRBO radios (XPR series). The protocol operates over TCP port 8002 and consists of two layers:

- **XNL (Extensible Network Link)**: Transport/session layer handling authentication and message framing
- **XCMP (Extensible Command Messaging Protocol)**: Application layer carrying radio commands

Our implementation in `XNLConnection.swift` has been verified against 7 CPS 2.0 traffic captures and successfully communicates with XPR 3500e radios.

---

## Protocol Stack Overview

```
┌─────────────────────────────────────┐
│           XCMP Commands             │  Application Layer
│  (Radio queries, codeplug access)   │
├─────────────────────────────────────┤
│              XNL                    │  Session Layer
│  (Authentication, message framing)  │
├─────────────────────────────────────┤
│              TCP                    │  Transport Layer
│           Port 8002                 │
├─────────────────────────────────────┤
│              IP                     │  Network Layer
└─────────────────────────────────────┘
```

---

## Transport Layer Requirements

### TCP Connection

| Parameter | Value | Notes |
|-----------|-------|-------|
| Port | 8002 | CPS programming port |
| Protocol | TCP | Reliable delivery required |
| TCP_NODELAY | **REQUIRED** | Disables Nagle's algorithm |

### Critical: TCP_NODELAY

The radio protocol requires immediate packet delivery. Without `TCP_NODELAY`, small packets are buffered by Nagle's algorithm, causing timeouts.

```swift
// REQUIRED: Set TCP_NODELAY on socket
var nodelay: Int32 = 1
setsockopt(sock, IPPROTO_TCP, TCP_NODELAY, &nodelay, socklen_t(MemoryLayout<Int32>.size))
```

### Socket Implementation

**Use raw BSD sockets, NOT Apple's NWConnection framework.**

Testing confirmed that `NWConnection` (even with `noDelay: true`) does not reliably deliver packets with the timing characteristics the radio expects. Raw BSD sockets with `TCP_NODELAY` work correctly.

```swift
// Correct: BSD socket
let sock = socket(AF_INET, SOCK_STREAM, 0)

// Incorrect: NWConnection (unreliable for this protocol)
// let connection = NWConnection(...)
```

---

## XNL Protocol Layer

### Packet Structure

All XNL packets follow this structure:

```
Offset  Size  Field           Description
──────────────────────────────────────────────────────
0x00    2     Length          Packet length (excludes this field)
0x02    1     Reserved        Always 0x00
0x03    1     Opcode          XNL operation code
0x04    1     XCMP Flag       0x01 if carrying XCMP payload
0x05    1     Flags/MsgID     Message ID (MUST INCREMENT!)
0x06    2     Destination     Target address (big-endian)
0x08    2     Source          Sender address (big-endian)
0x0A    2     Transaction ID  Session prefix + sequence
0x0C    2     Payload Length  XCMP payload size
0x0E    ...   Payload         XCMP data (if any)
```

### XNL Opcodes

| Opcode | Name | Direction | Description |
|--------|------|-----------|-------------|
| 0x02 | MasterStatusBroadcast | Radio → App | First packet after TCP connect |
| 0x04 | DevMasterQuery | App → Radio | Query after receiving broadcast |
| 0x05 | DevSysMapBroadcast | Radio → App | Contains 8-byte auth seed |
| 0x06 | DevAuthKey | App → Radio | TEA-encrypted auth response |
| 0x07 | DevAuthKeyReply | Radio → App | Contains assigned address |
| 0x09 | DevConnReply | Radio → App | Connection confirmation |
| 0x0B | DataMessage | Bidirectional | Carries XCMP payload |
| 0x0C | DataMessageAck | Radio → App | Acknowledgment (CPS ignores) |

---

## XNL Authentication Sequence

Authentication uses TEA (Tiny Encryption Algorithm) with the MOTOTRBO delta constant.

### Flow Diagram

```
    App                                   Radio
     │                                      │
     │◄────── MasterStatusBroadcast (0x02) ─┤  Radio initiates
     │                                      │
     ├────── DevMasterQuery (0x04) ────────►│  App responds
     │                                      │
     │◄────── DevSysMapBroadcast (0x05) ────┤  Contains auth seed
     │                                      │
     ├────── DevAuthKey (0x06) ────────────►│  TEA-encrypted response
     │                                      │
     │◄────── DevAuthKeyReply (0x07) ───────┤  Assigned address
     │                                      │
     │◄────── DevConnReply (0x09) ──────────┤  Connection confirmed
     │                                      │
```

### Step-by-Step

#### 1. Wait for MasterStatusBroadcast (0x02)

The radio sends first. Do not send anything until this is received.

```
Packet: 00 13 00 02 00 00 00 00 00 06 00 00 00 07 00 00 00 02 01 01 01
        ───── ───── ───── ───── ───── ───────────────────────────────
        Len   Op=02 Dest  Src   Sess  Payload (master addr=0x0006)
```

#### 2. Send DevMasterQuery (0x04)

```
Packet: 00 0C 00 04 00 00 00 06 00 00 00 00 00 00
        ───── ───── ───── ───── ───── ─────
        Len   Op=04 Dest  Src   TxID  PLen
```

#### 3. Wait for DevSysMapBroadcast (0x05)

Contains the 8-byte authentication seed.

```
Packet: 00 16 00 05 00 00 00 00 00 06 00 00 00 0A FF FE [8-byte seed]
                                               ───── ──────────────
                                               Sess  Auth Seed
```

#### 4. Send DevAuthKey (0x06)

Encrypt the seed using TEA and send as response.

```swift
// TEA encryption with MOTOTRBO delta
let delta: UInt32 = 0x790AB771  // MOTOTRBO-specific constant
```

```
Packet: 00 18 00 06 00 08 00 06 FF FE 00 00 00 0C 00 00 0A 00 [8-byte TEA response]
```

#### 5. Receive DevAuthKeyReply (0x07)

Contains critical session parameters:

```
Packet: 00 1A 00 07 00 08 FF FE 00 06 00 00 00 0E 01 [prefix] [addr] ...
                                               ─── ──────── ──────
                                               OK  Session  Assigned
                                                   Prefix   Address
```

- **Byte 14**: Result code (0x01 = success)
- **Byte 15**: Session prefix (high byte of XCMP transaction IDs)
- **Bytes 16-17**: Assigned XNL address (your address for this session)

#### 6. Wait for DevConnReply (0x09)

Connection confirmation. Optional but indicates radio is ready.

---

## DeviceInitStatusBroadcast Handshake

**CRITICAL: This handshake MUST complete before XCMP commands will work.**

After XNL authentication, the radio initiates a B400 (DeviceInitStatusBroadcast) handshake.

### Handshake Flow

```
    App                                          Radio
     │                                             │
     │◄── B400 (InitComplete=0x00, query) ─────────┤
     │                                             │
     ├── B400 (response with capabilities) ───────►│
     │                                             │
     │◄── B400 (InitComplete=0x02, transitioning) ─┤
     │                                             │
     │◄── B400 (InitComplete=0x0F, format info) ───┤
     │                                             │
     │◄── B400 (InitComplete=0x01, READY) ─────────┤
     │                                             │
     │◄── B41C (VersionQuery, optional) ───────────┤
     │                                             │
     │    *** NOW XCMP COMMANDS CAN BE SENT ***    │
```

### InitComplete Values

| Value | Meaning |
|-------|---------|
| 0x00 | Radio requesting client capabilities |
| 0x02 | Transitioning / capability exchange |
| 0x0F | Format/version information |
| 0x01 | Initialization complete, READY |

### B400 Response Format

When the radio sends B400 with InitComplete=0x00, respond with:

```swift
var response = Data()
response.append(0xB4)  // Opcode high
response.append(0x00)  // Opcode low
response.append(0x00)  // majorVersion = 0x00
response.append(0x00)  // minorVersion = 0x00
response.append(0x00)  // revVersion = 0x00
response.append(0x00)  // EntityType: 0
response.append(0x00)  // InitComplete: 0 (STATUS mode)
response.append(0x0A)  // DeviceType: IPPeripheral
response.append(0x00)  // Status high
response.append(0x00)  // Status low
response.append(0x00)  // Descriptor length: 0
```

**Important:** Mirror the radio's transaction ID in your B400 response.

---

## Multi-Command Sessions

### The Critical Discovery: Message ID Must Increment

**This is the most important finding from traffic analysis.**

Byte 5 in XNL DataMessage packets is a **message ID that MUST INCREMENT** with each DataMessage sent:

```
1st command: ... 00 0B 01 02 ... (msgID = 0x02)
2nd command: ... 00 0B 01 03 ... (msgID = 0x03)
3rd command: ... 00 0B 01 04 ... (msgID = 0x04)
4th command: ... 00 0B 01 05 ... (msgID = 0x05)
```

Without incrementing, the radio treats subsequent commands as retransmissions and drops them.

### Implementation

```swift
/// Message ID counter - MUST increment for each DataMessage
private var xnlMessageID: UInt8 = 1  // Starts at 1, first command uses 0x02

public func sendXCMP(_ xcmpData: Data) async throws -> Data? {
    // Increment BEFORE building packet
    xnlMessageID += 1
    let messageID = xnlMessageID

    var packet = Data()
    // ... build packet ...
    packet.append(0x01)       // Byte 4: XCMP flag
    packet.append(messageID)  // Byte 5: INCREMENTING message ID
    // ... rest of packet ...
}
```

### Transaction ID Format

XCMP transaction IDs use the session prefix from authentication:

```
TxID = [sessionPrefix:8] [sequence:8]

Example with sessionPrefix = 0x1B:
  1st command: 0x1B01
  2nd command: 0x1B02
  3rd command: 0x1B03
```

---

## XCMP Command Reference

### Read Operations (Verified Working)

| Opcode | Name | Parameters | Response |
|--------|------|------------|----------|
| 0x0012 | Security Key | None | 16-byte device key |
| 0x0010 | Model Number | 0x00 | ASCII model string |
| 0x000F | Firmware Version | 0x00/0x30/0x41/etc | ASCII version string |
| 0x0011 | Serial Number | 0x00 | ASCII serial string |
| 0x001F | Codeplug ID | 0x00 0x00 | ASCII part number |
| 0x003D | Capabilities | 0x00 0x00 | Capability flags |
| 0x0037 | Zone Info | 0x01 0x01 0x00 | Zone/channel data |
| 0x002C | Language Info | 0x01 | Localization data |
| 0x002E | Codeplug Read | Record ID | Codeplug data |

### Response Format

All XCMP responses follow this pattern:

```
[Opcode:2] [Status:1] [Data:N]

Opcode: Original opcode with high bit set (0x0012 → 0x8012)
Status: 0x00 = success, others = error codes
Data: Command-specific response data
```

### Write Operations (Not Covered)

ComponentSession (0x010F) and PSDT (0x010B) are **write-only** protocols used for codeplug programming. They are not used for reading and are outside the scope of this document.

---

## Implementation Requirements

### Mandatory Requirements

| Requirement | Details |
|-------------|---------|
| TCP_NODELAY | Must be set on socket |
| BSD Sockets | Use raw sockets, not NWConnection |
| Message ID | Must increment for each DataMessage |
| B400 Handshake | Must complete before XCMP commands |
| Transaction ID | Use session prefix from auth reply |
| Timing | 500ms+ delay after authentication |

### Packet Building Checklist

When building an XNL DataMessage for XCMP:

1. ✅ Calculate total length correctly
2. ✅ Set opcode to 0x0B (DataMessage)
3. ✅ Set XCMP flag (byte 4) to 0x01
4. ✅ Set message ID (byte 5) to incrementing value
5. ✅ Set destination to master address
6. ✅ Set source to assigned address
7. ✅ Set transaction ID with session prefix
8. ✅ Set payload length correctly
9. ✅ Append XCMP payload

---

## Common Pitfalls

### Things That DO NOT Work

| Approach | Problem | Solution |
|----------|---------|----------|
| Static message ID (0x02) | Commands after first fail | Increment message ID |
| NWConnection | Unreliable packet delivery | Use BSD sockets |
| Sending DataMessageAck (0x0C) | Not needed, may confuse radio | Don't send ACKs |
| Skipping B400 handshake | XCMP commands timeout | Complete full handshake |
| Short delays (100ms) | Timing issues | Use 500ms+ after auth |
| Wrong TxID format | Commands fail | Use session prefix from byte 15 |

### Debugging Tips

1. **First command works, subsequent fail**: Check message ID increment
2. **All commands timeout**: Check B400 handshake completion
3. **Authentication fails**: Verify TEA encryption and delta constant
4. **Intermittent failures**: Check TCP_NODELAY is set

---

## Our Implementation Status

### Verified Working

| Component | Status | Notes |
|-----------|--------|-------|
| TCP Connection | ✅ | BSD sockets with TCP_NODELAY |
| XNL Authentication | ✅ | TEA encryption verified |
| B400 Handshake | ✅ | Full sequence implemented |
| Multi-Command Sessions | ✅ | Message ID incrementing |
| Device Identification | ✅ | All basic queries work |
| Security Key (0x0012) | ✅ | Returns 16-byte key |
| Model Number (0x0010) | ✅ | Returns H02RDH9VA1AN |
| Serial Number (0x0011) | ✅ | Returns 867TXM0273 |
| Firmware Version (0x000F) | ✅ | Returns R02.21.01.1001 |
| Codeplug ID (0x001F) | ✅ | Returns PMUE3836DK |
| Zone/Channel Info (0x002E) | ✅ | Returns codeplug records |

### Test Results

```
════════════════════════════════════════════════════════════
  XPR 3500e COMPREHENSIVE TEST TOOL
════════════════════════════════════════════════════════════

[1/8] Network Connectivity.............. ✓ PASS
[2/8] XNL Authentication................ ✓ PASS
[3/8] Radio Identification.............. ✓ PASS
[4/8] CPS Device Info................... ✓ PASS
[5/8] Zone/Channel Records.............. ✓ PASS
[6/8] Extended Device Info.............. ✓ PASS
[7/8] Multi-Command Session (10 cmds)... ✓ PASS
[8/8] Codeplug Read..................... ✓ PASS

════════════════════════════════════════════════════════════
RESULTS: 8/8 tests passed
════════════════════════════════════════════════════════════
```

### Implementation Files

| File | Purpose |
|------|---------|
| `XNLConnection.swift` | Core XNL/XCMP implementation |
| `XNLEncryption.swift` | TEA encryption with MOTOTRBO delta |
| `XCMPProtocol.swift` | XCMP opcode definitions |
| `XPRTest/main.swift` | Comprehensive test suite |

---

## Appendix A: Complete Session Trace

### Example Multi-Command Session

```
[TCP] Connect to 192.168.10.1:8002

[XNL RX] MasterStatusBroadcast (0x02)
         Master address: 0x0006

[XNL TX] DevMasterQuery (0x04)
         Destination: 0x0006

[XNL RX] DevSysMapBroadcast (0x05)
         Session prefix: 0xFFFE
         Auth seed: 1B 9B 4D 8A D7 DF 42 74

[XNL TX] DevAuthKey (0x06)
         TEA response: 43 8D 29 06 38 27 1D BF

[XNL RX] DevAuthKeyReply (0x07)
         Result: 0x01 (success)
         Session prefix: 0x03
         Assigned address: 0x0002

[XNL RX] DevConnReply (0x09)
         Connection confirmed

[XCMP RX] B400 InitComplete=0x00 (query)
[XCMP TX] B400 Response (mirror TxID)
[XCMP RX] B400 InitComplete=0x02 (transitioning)
[XCMP RX] B400 InitComplete=0x0F (format info)
[XCMP RX] B400 InitComplete=0x01 (READY)

[XCMP TX] 0x0012 Security Key Query (msgID=0x02, txID=0x0301)
[XCMP RX] 0x8012 Response: 05 71 AF E2 44 66 4F 99 9A 96 B0 20 E8 2D C6 9C

[XCMP TX] 0x0010 Model Query (msgID=0x03, txID=0x0302)
[XCMP RX] 0x8010 Response: H02RDH9VA1AN

[XCMP TX] 0x0011 Serial Query (msgID=0x04, txID=0x0303)
[XCMP RX] 0x8011 Response: 867TXM0273

[XCMP TX] 0x000F Firmware Query (msgID=0x05, txID=0x0304)
[XCMP RX] 0x800F Response: R02.21.01.1001

[TCP] FIN - Session complete
```

---

## Appendix B: Hex Packet Examples

### XNL DataMessage (XCMP Query)

```
Offset: 00 01 02 03 04 05 06 07 08 09 0A 0B 0C 0D 0E 0F
Data:   00 0E 00 0B 01 02 00 06 00 1B 1B 01 00 02 00 12
        ───── ───── ───── ───── ───── ───── ───── ─────
        Len   Op    XCMP  Dest  Src   TxID  PLen  XCMP
        14    0B    Msg   0006  001B  1B01  2     0012
              Data  ID=02
              Msg
```

### XNL DataMessage (XCMP Response)

```
Offset: 00 01 02 03 04 05 06 07 08 09 0A 0B 0C 0D 0E 0F 10 11 ...
Data:   00 1F 00 0B 01 05 00 1B 00 06 1B 01 00 13 80 12 00 05 71 AF ...
        ───── ───── ───── ───── ───── ───── ───── ─────────────────
        Len   Op    XCMP  Dest  Src   TxID  PLen  XCMP Response
        31    0B    Msg   001B  0006  1B01  19    8012 00 (data...)
              Data  ID=05                         (success)
              Msg
```

---

## Document History

| Version | Date | Changes |
|---------|------|---------|
| 1.0 | 2026-01-30 | Initial release - verified implementation |

---

*This document is based on reverse engineering of Motorola CPS 2.0 traffic captures and verified against XPR 3500e hardware.*
