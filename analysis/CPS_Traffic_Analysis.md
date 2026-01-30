# CPS 2.0 Traffic Analysis - Comprehensive Protocol Documentation

**Date**: 2026-01-30
**Source**: 7 Wireshark captures of Motorola CPS 2.0 reading radio configuration
**Radio**: XPR 3500e (H02RDH9VA1AN, Serial: 867TXM0273)
**Firmware**: R02.21.01.1001

---

## Executive Summary

Analysis of 7 CPS read operations reveals a consistent protocol pattern:
1. Each "read" operation uses **2 separate TCP sessions** (one-to-one mapping)
2. **First session**: Full XNL authentication + XCMP device query
3. **Second session**: Full XNL re-authentication + different XCMP commands
4. CPS **NEVER sends DataMessageAck (0x0C)** - relies on TCP ACK only
5. The radio sends multiple unsolicited B4xx messages; CPS responds to each
6. Each session performs one logical operation then disconnects

---

## Session Parameters Comparison (All 7 Captures)

### Complete Session Table

| Capture File | Session | Client Port | Session Prefix | Auth Seed | TEA Response | Assigned Addr | TxID Prefix |
|--------------|---------|-------------|----------------|-----------|--------------|---------------|-------------|
| **cps_capture_read.txt** | 1 | 55331 | 0xFFFE | 1b 9b 4d 8a d7 df 42 74 | 43 8d 29 06 38 27 1d bf | 0x02 | 0x0301 |
| **cps_capture_read.txt** | 2 | 55332 | 0xFFFD | 6b f6 e6 ed ff fd 3d 5c | d6 32 9f 99 2b 52 ed 45 | 0x03 | 0x0401 |
| **CPS 2nd read.txt** | 1 | 64945 | 0xFFE6 | 77 dd 37 cf 7f c9 2e 98 | 21 3c f4 e6 65 d2 e3 cb | 0x1B | 0x1B01 |
| **CPS 2nd read.txt** | 2 | 64946 | 0xFFE5 | ee bf 6a 83 2f dd d1 9e | 69 31 76 6b 22 af 75 c9 | 0x1B | - |
| **CPS 3rd read.txt** | 1 | 49436 | 0xFFE4 | da 6e d1 e3 f7 37 95 0d | 45 c3 75 be c9 a8 c0 ee | 0x1D | 0x1D01 |
| **CPS 3rd read.txt** | 2 | 49437 | 0xFFE3 | 50 ef 4e 65 7d f9 17 66 | - | 0x1D | - |
| **CPS 4th read.txt** | 1 | 49459 | 0xFFE2 | de f8 fa f0 6f ed 40 18 | 8c 64 8a b6 a4 25 76 00 | 0x1F | 0x1F01 |
| **CPS 4th read.txt** | 2 | 49460 | 0xFFE1 | 56 ff 0b 5c 7d f7 d7 63 | 9b 7e e8 6c 87 8c 35 f9 | 0x20 | 0x2001 |
| **CPS 5th read.txt** | 1 | 49488 | 0xFFE0 | ff 5b 82 09 fe f4 0d 04 | e0 98 9c 1f e9 40 9a d1 | 0x21 | 0x2101 |
| **CPS 5th read.txt** | 2 | 49489 | 0xFFDF | - | - | 0x22 | - |
| **CPS 6th read.txt** | - | - | - | - | - | - | - |
| **cps 7th read.txt** | - | - | - | - | - | - | - |

**Notes:**
- Captures 6 and 7 start with different traffic (IPv6 multicast, external HTTP)
- Session prefix consistently decrements by 1 for each new TCP connection
- Assigned address increments as radio assigns new XNL addresses

### TxID Pattern Clarification

Looking at Capture 1 more carefully:
- Session 1: Assigned addr = 0x02, TxID prefix = 0x03xx
- Session 2: Assigned addr = 0x03, TxID prefix = 0x04xx

This suggests: **TxID prefix = (assigned_address + 1) << 8 | counter**

For later captures with assigned addr 0x1B:
- TxID becomes 0x1B01, 0x1B02, 0x1B03...

This inconsistency may be due to radio state or different capture times.

---

## XNL Packet Structure Definitions

### XNL Header (All Packets)
```
Offset  Size  Field
0x00    2     Length (big-endian, does NOT include these 2 bytes)
0x02    1     Opcode
0x03    1     Flags
0x04    2     Destination Address
0x06    2     Source Address
0x08    2     Transaction ID / Session Prefix
0x0A    2     Payload Length (varies by opcode)
0x0C    ...   Payload (opcode-specific)
```

### Opcode 0x02: MasterStatusBroadcast (Radio -> CPS)
```
0000  00 13 00 02 00 00 00 00 00 06 00 00 00 07 00 00
0010  00 02 01 01 01

Length:      0x0013 (19 bytes)
Opcode:      0x02 (MasterStatusBroadcast)
Flags:       0x00
Dest:        0x0000 (broadcast)
Src:         0x0000 (unassigned)
SessionPfx:  0x0006 (varies)
PayloadLen:  0x0000
Extra:       00 07 00 00 00 02 01 01 01
  - Protocol version: 0x07
  - Master address: 0x0006
  - Device type: 0x02 (repeater/radio)
  - Auth required: 0x01
  - Status: 0x01 0x01
```

### Opcode 0x04: DevMasterQuery (CPS -> Radio)
```
0000  00 0c 00 04 00 00 00 06 00 00 00 00 00 00

Length:      0x000C (12 bytes)
Opcode:      0x04 (DevMasterQuery)
Flags:       0x00
Dest:        0x0000
Src:         0x0006 (master address from broadcast)
SessionPfx:  0x0000
PayloadLen:  0x0000
Extra:       00 00
```

### Opcode 0x05: DevSysMapBroadcast (Radio -> CPS)
```
0000  00 16 00 05 00 00 00 00 00 06 00 00 00 0a ff e6
0010  77 dd 37 cf 7f c9 2e 98

Length:      0x0016 (22 bytes)
Opcode:      0x05 (DevSysMapBroadcast)
Flags:       0x00
Dest:        0x0000
Src:         0x0000
SessionPfx:  0x0006
PayloadLen:  0x0000
Extra:       00 0a                    - Constant
SessionPfx:  ff e6                    - Session prefix (decrements each session)
AuthSeed:    77 dd 37 cf 7f c9 2e 98  - 8-byte random seed for TEA auth
```

### Opcode 0x06: DevAuthKey (CPS -> Radio)
```
0000  00 18 00 06 00 08 00 06 ff e6 00 00 00 0c 00 00
0010  0a 00 21 3c f4 e6 65 d2 e3 cb

Length:      0x0018 (24 bytes)
Opcode:      0x06 (DevAuthKey)
Flags:       0x00
Dest:        0x0008
Src:         0x0006
SessionPfx:  0xFFE6 (echoes from DevSysMapBroadcast)
PayloadLen:  0x0000
Extra:       00 0c 00 00 0a 00        - Auth context
TEAResponse: 21 3c f4 e6 65 d2 e3 cb  - 8-byte TEA encrypted response
```

### Opcode 0x07: DevAuthKeyReply (Radio -> CPS)
```
0000  00 1a 00 07 00 08 ff e6 00 06 00 00 00 0e 01 1b
0010  00 1b 0a 01 54 6b 64 86 3d d8 4d c1

Length:      0x001A (26 bytes)
Opcode:      0x07 (DevAuthKeyReply)
Flags:       0x00
Dest:        0x0008
Src:         0xFFE6 (session prefix as source)
SessionPfx:  0x0006
PayloadLen:  0x0000
Extra:       00 0e                      - Auth result context
AuthStatus:  01                         - 0x01 = success
AssignedAddr:0x1B                       - CPS's new XNL address
Unknown:     00 1b 0a 01                - Echo of assigned addr, device type
TEAVerify:   54 6b 64 86 3d d8 4d c1    - Radio's verification response
```

### Opcode 0x09: DevConnReply (Radio -> CPS)
```
0000  00 1d 00 09 00 00 00 00 00 06 00 00 00 11 00 03
0010  01 01 00 06 00 0f 01 00 01 00 0a 01 00 1b 00

Length:      0x001D (29 bytes)
Opcode:      0x09 (DevConnReply)
Flags:       0x00
Dest:        0x0000
Src:         0x0000
SessionPfx:  0x0006 (master address)
PayloadLen:  0x0000
Extra:       00 11 00 03 01 01 00 06 00 0f 01 00 01 00 0a 01 00 1b 00
  - Connection status, device capabilities, assigned address confirmation
```

### Opcode 0x0B: DataMessage (Bi-directional, carries XCMP)
```
0000  00 33 00 0b 01 00 00 1b 00 06 01 ac 00 27 b4 00
0010  0b 02 00 05 00 01 00 00 1c 00 05 02 0a 04 09 05
0020  00 07 01 09 01 0a 01 0d 10 0e 02 11 00 13 ff 14
0030  fd 19 ff 1a 00

Length:      0x0033 (51 bytes)
Opcode:      0x0B (DataMessage)
Flags:       0x01 0x00                - Message flags
Dest:        0x001B                   - CPS assigned address
Src:         0x0006                   - Master/radio address
TxID:        0x01AC                   - Transaction ID (increments)
PayloadLen:  0x0027 (39 bytes)        - XCMP payload length
XCMPOpcode:  0xB400                   - XCMP command (big-endian)
XCMPData:    0b 02 00 05 ...          - XCMP payload
```

---

## B400 Init Handshake Sequence

The B400 (InitComplete) handshake is **critical** for establishing XCMP communication.

### Typical Sequence (from Capture 2, Session 1):

**1. Radio sends first B400 (InitComplete=0x00, query):**
```
Frame 15: Radio -> CPS
00 33 00 0b 01 00 00 1b 00 06 01 ac 00 27 b4 00
0b 02 00 05 00 01 00 00 1c 00 05 02 0a 04 09 05
00 07 01 09 01 0a 01 0d 10 0e 02 11 00 13 ff 14
fd 19 ff 1a 00

XCMP Opcode: B4 00 (InitComplete)
InitStatus:  0x00 (requesting capabilities)
Capabilities: 0b 02 00 05 00 01 00 00 1c 00 05 02 0a 04 09 05 00 07 01 09 01 0a 01 0d 10 0e 02 11 00 13 ff 14 fd 19 ff 1a 00
```

**2. CPS responds with B400 (acknowledgment):**
```
Frame 16: CPS -> Radio
00 17 00 0b 01 00 00 06 00 1b 01 ac 00 0b b4 00
00 00 00 00 00 0a 00 00 00

XCMP Opcode: B4 00 (InitComplete)
InitStatus:  0x00 (acknowledgment)
Data:        00 00 00 00 0a 00 00 00 (minimal capabilities)
```

**3. Radio sends B400 (InitComplete=0x02, continued):**
```
Frame 18: Radio -> CPS
00 17 00 0b 01 01 00 00 00 06 01 ad 00 0b b4 00
0b 02 00 05 02 0a 00 00 00

TxID:        0x01AD (incremented)
InitStatus:  0x02 (capabilities exchange)
```

**4. Radio sends B400 (InitComplete=0x0F, format info):**
```
Frame 20: Radio -> CPS
00 19 00 0b 01 02 00 1b 00 06 01 ae 00 0d b4 00
0b 02 00 05 02 0f 00 00 02 0b 01

TxID:        0x01AE (incremented)
InitStatus:  0x0F (format/version info)
Data:        00 00 02 0b 01 (version 2.11.1?)
```

**5. Radio sends B400 (InitComplete=0x01, done):**
```
Frame 22: Radio -> CPS
00 13 00 0b 01 03 00 1b 00 06 01 af 00 07 b4 00
0b 02 00 05 01

TxID:        0x01AF (incremented)
InitStatus:  0x01 (init complete)
```

**6. Radio sends B41C (VersionQuery):**
```
Frame 23: Radio -> CPS (unsolicited!)
00 19 00 0b 01 04 00 00 00 06 01 b0 00 0d b4 1c
02 20 01 03 00 00 00 00 00 00 00

XCMP Opcode: B4 1C (VersionQuery/Notify)
```

---

## XCMP Command Sequence (First Session)

After B400 handshake, CPS issues XCMP queries:

### 1. First XCMP Command: 0x0012 (DeviceDescriptor Query)
```
Frame 25: CPS -> Radio
00 0e 00 0b 01 02 00 06 00 1b 1b 01 00 02 00 12

DataMessage with:
  Dest: 0x0006 (radio)
  Src:  0x001B (CPS)
  TxID: 0x1B01 (new counter, uses assigned addr as prefix!)
  Len:  0x0002
  XCMP: 00 12 (DeviceDescriptor query)
```

### 2. Response: 0x8012 (DeviceDescriptor Response)
```
Frame 27: Radio -> CPS
00 1f 00 0b 01 05 00 1b 00 06 1b 01 00 13 80 12
00 05 71 af e2 44 66 4f 99 9a 96 b0 20 e8 2d c6 9c

XCMP: 80 12 (response to 00 12)
  Status: 00 (success)
  Data: 05 71 af e2 44 66 4f 99 9a 96 b0 20 e8 2d c6 9c
  (Radio identifier/serial)
```

### 3. Second XCMP Command: 0x0010 (Model Query)
```
Frame 28: CPS -> Radio
00 0f 00 0b 01 03 00 06 00 1b 1b 02 00 03 00 10 00

TxID: 0x1B02 (incremented)
XCMP: 00 10 00 (Model Query)
```

### 4. Response: 0x8010 (Model Response)
```
Frame 29: Radio -> CPS
00 1c 00 0b 01 06 00 1b 00 06 1b 02 00 10 80 10
00 48 30 32 52 44 48 39 56 41 31 41 4e 00

XCMP: 80 10 (response to 00 10)
  Status: 00
  ModelLen: 48 (72 chars? or 'H'?)
  Model: "02RDH9VA1AN" (null terminated)
```

### 5. Third XCMP Command: 0x000F (Type Query)
```
Frame 30: CPS -> Radio
00 0f 00 0b 01 04 00 06 00 1b 1b 03 00 03 00 0f 41

TxID: 0x1B03
XCMP: 00 0f 41 (Type Query, param 0x41 = 'A')
```

### 6. Response: 0x800F (Type Response)
```
Frame 31: Radio -> CPS
00 16 00 0b 01 07 00 1b 00 06 1b 03 00 0a 80 0f
00 32 31 31 30 33 36 00

XCMP: 80 0f (response)
  Status: 00
  Type: "211036" (null terminated)
```

### 7. Fourth XCMP Command: 0x0011 (Serial Query)
```
Frame 32: CPS -> Radio
00 0f 00 0b 01 05 00 06 00 1b 1b 04 00 03 00 11 00

TxID: 0x1B04
XCMP: 00 11 00 (Serial Query)
```

### 8. Response: 0x8011 (Serial Response)
```
Frame 33: Radio -> CPS
00 1a 00 0b 01 00 00 1b 00 06 1b 04 00 0e 80 11
00 38 36 37 54 58 4d 30 32 37 33 00

XCMP: 80 11 (response)
  Status: 00
  Serial: "867TXM0273" (null terminated)
```

### 9. Fifth XCMP Command: 0x000F (Firmware Version Query)
```
Frame 34: CPS -> Radio
00 0f 00 0b 01 06 00 06 00 1b 1b 05 00 03 00 0f 00

TxID: 0x1B05
XCMP: 00 0f 00 (Firmware query)
```

### 10. Response: 0x800F (Firmware Response)
```
Frame 35: Radio -> CPS
00 1e 00 0b 01 01 00 1b 00 06 1b 05 00 12 80 0f
00 52 30 32 2e 32 31 2e 30 31 2e 31 30 30 31 00

XCMP: 80 0f
  Firmware: "R02.21.01.1001" (null terminated)
```

### 11. Sixth XCMP Command: 0x003D (Capabilities Query)
```
Frame 36: CPS -> Radio
00 10 00 0b 01 00 00 06 00 1b 1b 06 00 04 00 3d 00 00

TxID: 0x1B06
XCMP: 00 3d 00 00 (Capabilities Query)
```

### 12. Response: 0x803D (Capabilities Response)
```
Frame 37: Radio -> CPS
00 12 00 0b 01 02 00 1b 00 06 1b 06 00 06 80 3d
01 00 01 00

XCMP: 80 3d
  Status: 01 (?)
  Capabilities: 00 01 00
```

### 13. Session Terminated
```
Frame 38: CPS -> Radio [FIN, ACK]
```

---

## Critical Findings

### 1. NO DataMessageAck (0x0C) Sent by CPS

**Across all 7 captures, CPS NEVER sends an XNL 0x0C (DataMessageAck) packet.**

The radio sends multiple DataMessage (0x0B) packets, and CPS:
- Relies purely on TCP-level ACK for acknowledgment
- Sends the next XCMP command immediately
- Does not explicitly acknowledge at XNL layer

### 2. Two Sessions Per Read Operation

Each "Read" button click in CPS triggers:
1. **Session 1**: Full XNL auth + device info queries (model, serial, firmware)
2. **Session 2**: Full XNL re-auth + additional queries (possibly codeplug read)

### 3. Transaction ID Pattern

The Transaction ID (TxID) in DataMessage has a specific pattern:
- Initial TxID base comes from radio (e.g., 0x01AC, 0x01B8, 0x01C4)
- After B400 handshake, CPS uses **assigned address as TxID prefix** (e.g., 0x1B01, 0x1B02...)
- Radio responds with matching TxID

### 4. Session Prefix Decrement

The session prefix in DevSysMapBroadcast (0x05) decrements for each new TCP connection:
- 0xFFE6, 0xFFE5, 0xFFE4, 0xFFE3, 0xFFE2, 0xFFE1, 0xFFE0, 0xFFDF...

### 5. Assigned Address Increment

The assigned address in DevAuthKeyReply (0x07) increments:
- 0x1B, 0x1B (same session), 0x1D, 0x1D, 0x1F, 0x20, 0x21, 0x22...

---

## Packet Flow Timing (Session 1 from Capture 4)

| Time (s) | Direction | Opcode | Description |
|----------|-----------|--------|-------------|
| 0.000    | CPS->Radio| TCP SYN | Connection start |
| 0.007    | Radio->CPS| 0x02   | MasterStatusBroadcast |
| 0.009    | CPS->Radio| 0x04   | DevMasterQuery |
| 0.014    | Radio->CPS| 0x05   | DevSysMapBroadcast (with seed) |
| 0.018    | CPS->Radio| 0x06   | DevAuthKey (TEA response) |
| 0.023    | Radio->CPS| 0x07   | DevAuthKeyReply (assigned addr) |
| 0.025    | Radio->CPS| 0x09   | DevConnReply |
| 0.152    | Radio->CPS| 0x0B   | B400 InitComplete=0x00 |
| 0.153    | CPS->Radio| 0x0B   | B400 Response |
| 0.284    | Radio->CPS| 0x0B   | B400 InitComplete=0x02 |
| 0.413    | Radio->CPS| 0x0B   | B400 InitComplete=0x0F |
| 0.542    | Radio->CPS| 0x0B   | B400 InitComplete=0x01 (done) |
| 0.543    | Radio->CPS| 0x0B   | B41C VersionQuery |
| 0.557    | CPS->Radio| 0x0B   | 0x0012 DeviceDescriptor |
| 0.564    | Radio->CPS| 0x0B   | 0x8012 Response |
| 0.585    | CPS->Radio| 0x0B   | 0x0010 Model Query |
| 0.593    | Radio->CPS| 0x0B   | 0x8010 Response |
| ...      | ...       | ...    | (more queries) |
| 0.685    | CPS->Radio| TCP FIN| Session close |

**Total session duration: ~0.7 seconds**

---

## TEA Authentication Analysis

The authentication uses TEA (Tiny Encryption Algorithm) with:
- 8-byte seed from DevSysMapBroadcast
- 8-byte response in DevAuthKey
- Likely 16-byte key (standard TEA)

### Observed Seed/Response Pairs:
```
Seed:     77 dd 37 cf 7f c9 2e 98
Response: 21 3c f4 e6 65 d2 e3 cb

Seed:     ee bf 6a 83 2f dd d1 9e
Response: 69 31 76 6b 22 af 75 c9

Seed:     da 6e d1 e3 f7 37 95 0d
Response: 45 c3 75 be c9 a8 c0 ee

Seed:     de f8 fa f0 6f ed 40 18
Response: 8c 64 8a b6 a4 25 76 00
```

The key is likely derived from a fixed password or radio serial number.

---

## Implementation Recommendations

### For Multi-Command Sessions:

1. **DO NOT send DataMessageAck (0x0C)** - It's not needed with TCP
2. Complete full B400 handshake before sending XCMP commands
3. Wait for each response before sending next command
4. Use assigned address as TxID prefix (e.g., 0x1B01, 0x1B02...)
5. Increment TxID for each command

### B400 Handshake Requirements:

1. Wait for radio's B400 (InitComplete=0x00)
2. Send B400 response with minimal capabilities
3. Wait for radio's B400 sequence (0x02, 0x0F, 0x01)
4. Wait for B41C VersionQuery
5. Now safe to send XCMP queries

### Session Management:

- CPS creates new TCP connection for each logical operation
- Full re-authentication required for each session
- Radio assigns new address each session
- Session prefix decrements, assigned address increments

---

## Raw Hex Dumps Reference

### Complete Session 1 Authentication (from Capture 4):

**MasterStatusBroadcast (Radio):**
```
00 13 00 02 00 00 00 00 00 06 00 00 00 07 00 00 00 02 01 01 01
```

**DevMasterQuery (CPS):**
```
00 0c 00 04 00 00 00 06 00 00 00 00 00 00
```

**DevSysMapBroadcast (Radio):**
```
00 16 00 05 00 00 00 00 00 06 00 00 00 0a ff e2 de f8 fa f0 6f ed 40 18
```

**DevAuthKey (CPS):**
```
00 18 00 06 00 08 00 06 ff e2 00 00 00 0c 00 00 0a 00 8c 64 8a b6 a4 25 76 00
```

**DevAuthKeyReply (Radio):**
```
00 1a 00 07 00 08 ff e2 00 06 00 00 00 0e 01 1f 00 1f 0a 01 e6 86 29 c8 ab f0 41 d8
```

**DevConnReply (Radio):**
```
00 1d 00 09 00 00 00 00 00 06 00 00 00 11 00 03 01 01 00 06 00 0f 01 00 01 00 0a 01 00 1f 00
```

---

## Anomalies and Notes

1. **Capture 1 (cps_capture_read.txt)**: Appears to be a different session structure, possibly partial capture
2. **Consistent Radio Info**: All captures show same radio (H02RDH9VA1AN, 867TXM0273)
3. **Firmware Version**: R02.21.01.1001 reported consistently
4. **B41C**: Radio sends unsolicited B41C (VersionQuery) after init complete
5. **No 0x0C observed**: Critical - CPS relies on TCP ACK, not XNL ACK

---

## Files Analyzed

1. `/Users/home/Desktop/CPS Read Traffic/cps_capture_read.txt`
2. `/Users/home/Desktop/CPS Read Traffic/CPS 2nd read.txt`
3. `/Users/home/Desktop/CPS Read Traffic/CPS 3rd read.txt`
4. `/Users/home/Desktop/CPS Read Traffic/CPS 4th read.txt`
5. `/Users/home/Desktop/CPS Read Traffic/CPS 5th read.txt`
6. `/Users/home/Desktop/CPS Read Traffic/CPS 6th read.txt`
7. `/Users/home/Desktop/CPS Read Traffic/cps 7th read.txt`

---

## Extended Session Analysis (Capture 1 - Second Session)

Capture 1 shows a longer second session with **many more XCMP commands** (beyond the basic 6 seen in other captures):

### Second Session Command Sequence (55332 port, Session 2):

| TxID | XCMP Cmd | Description | Response Data |
|------|----------|-------------|---------------|
| 04 01 | 0x0012 | DeviceDescriptor | 71 af e2 44... |
| 04 02 | 0x0010 00 | Model Query | H02RDH9VA1AN |
| 04 03 | 0x000F 41 | Type Query (A) | 211036 |
| 04 04 | 0x0011 00 | Serial Query | 867TXM0273 |
| 04 05 | 0x000F 00 | Firmware Query | R02.21.01.1001 |
| 04 06 | 0x003D 00 00 | Capabilities | 01 00 01 00 |
| 04 07 | 0x001F 00 00 | Part Number | PMUE3836DK |
| 04 08 | 0x000F 50 | Version (P) | R0221011001 |
| 04 09 | 0x000F 30 | Version (0) | R02.21.01.1001 |
| 04 0a | 0x000F 52 | Version (R) | R02.21.01.1001 |
| 04 0b | 0x000F 51 | Version (Q) | R0221011001 |
| 04 0c | 0x0037 01 01 00 | Zone Query | Zone info |
| 04 0d | 0x002C 01 | Language Query | Localization data (208 bytes!) |
| 04 0e | 0x0011 00 | Serial (repeat) | 867TXM0273 |
| 04 0f | 0x000F 00 | Firmware (repeat) | R02.21.01.1001 |
| 04 10 | 0x003D 00 00 | Capabilities (repeat) | 01 00 01 00 |
| 04 11 | 0x0037 01 03 00 | Zone Details | Details |
| 04 12 | 0x000F 35 | Version (5) | R02.21.01.1001 |
| 04 13 | 0x0467 00 | Unknown (0467) | 00 00 00 00 00 00 01 00 |
| 04 14 | 0x000E 4B | Unknown (000E K) | - |

### Key Discovery: Language Data (0x002C)

The 0x002C command returns localization/language information:
```
00 ce 00 0b 01 01 00 03 00 06 04 0d 00 c2 80 2c
00 09 1d 80 00 04 2d 00 65 00 6e 00 2d 00 75 00   "en-us"
73 00 00 00 00 00 00 00 00 00 02 00 00 00 13 00
04 7f eb 00 45 00 6e 00 67 00 6c 00 69 00 73 00   "English"
68 00 00 31 00 65 00 6e 00 2d 00 75 00 73 00 00
...
00 46 00 72 00 61 00 6e 00 e7 00 61 00 69 00      "Francais"
73 00 00 2d 00 65 00 73 00 2d 00 63 00 6f 00      "es-co"
...
00 45 00 73 00 70 00 61 00 f1 00 6f 00 6c 00      "Espanol"
```

This shows UTF-16LE encoded language names: English, Francais (French), Espanol (Spanish).

---

## Summary: Critical Implementation Notes

### 1. DataMessageAck (0x0C) NOT REQUIRED
- Confirmed across all 7 captures
- CPS relies on TCP-level acknowledgment
- No application-layer ACK between commands

### 2. Multi-Command Sessions Work
- Capture 1 Session 2 shows 20+ XCMP commands in single session
- Each command uses incrementing TxID (04 01, 04 02, 04 03...)
- TxID prefix based on assigned address (0x03 in session 2, 0x04 becomes prefix)

### 3. TxID Pattern
```
Session 1: Assigned addr 0x02 -> TxID prefix 0x03xx
Session 2: Assigned addr 0x03 -> TxID prefix 0x04xx
```
The TxID prefix appears to be `assigned_address + 1`.

### 4. B400 Init is REQUIRED Before XCMP
- Every session shows B400 handshake before XCMP queries work
- CPS must respond to initial B400 from radio
- Wait for B400 InitComplete=0x01 before sending queries

### 5. Session Close Pattern
- CPS initiates TCP FIN after last command
- Radio responds with FIN, ACK
- Clean session teardown

---

---

## Implementation Comparison: CPS vs. Our Code

### Current State (XNLConnection.swift)

Our implementation successfully:
- ✅ Establishes TCP connection with TCP_NODELAY
- ✅ Completes XNL authentication (TEA encryption works)
- ✅ Handles B400 DeviceInitStatusBroadcast handshake
- ✅ Sends first XCMP command and receives response

Our implementation fails at:
- ❌ Second and subsequent XCMP commands timeout

### Critical Differences Found

#### 1. Message Flags (Byte 5) - LIKELY ROOT CAUSE

Looking at CPS outgoing DataMessage packets:

```
Frame 25 (1st cmd): 00 0e 00 0b 01 02 00 06 00 1b 1b 01 00 02 00 12
Frame 28 (2nd cmd): 00 0f 00 0b 01 03 00 06 00 1b 1b 02 00 03 00 10 00
Frame 30 (3rd cmd): 00 0f 00 0b 01 04 00 06 00 1b 1b 03 00 03 00 0f 41
Frame 32 (4th cmd): 00 0f 00 0b 01 05 00 06 00 1b 1b 04 00 03 00 11 00
                          ^^ ^^ ^^
                          |  |  Byte 5 INCREMENTS: 02, 03, 04, 05...
                          |  Byte 4: XCMP flag (always 01)
                          Byte 3: opcode (always 0B)
```

**CPS increments byte 5 with each DataMessage sent!**

Our code always uses 0x02:
```swift
packet.append(0x02)  // Flags (byte 5) = 0x02 (CPS uses this, Python uses 0 but fails)
```

This is likely the root cause - the radio may be expecting incrementing message IDs.

#### 2. TxID Generation (Correct)

Our code correctly uses `xcmpSessionPrefix` from AUTH_KEY_REPLY byte 15:
```swift
xcmpSequence += 1
return UInt16(xcmpSessionPrefix) << 8 | UInt16(xcmpSequence)
```

This matches CPS behavior (0x1B01, 0x1B02, 0x1B03...)

#### 3. Packet Structure (Correct)

Our DataMessage structure matches CPS:
- Bytes 0-1: Length
- Bytes 2-3: Opcode (0x000B)
- Byte 4: XCMP flag (0x01)
- Byte 5: Flags/MessageID (NEEDS FIX)
- Bytes 6-7: Destination (master address)
- Bytes 8-9: Source (assigned address)
- Bytes 10-11: TxID
- Bytes 12-13: Payload length
- Bytes 14+: XCMP payload

---

## Things That DON'T Work (Avoid These)

### 1. Setting flags=0x00 (Byte 5)

**Attempted:** Python-style with byte 5 = 0x00
**Result:** ALL commands fail, including the first one
**Conclusion:** Must use non-zero value, CPS uses incrementing starting at 0x02

### 2. Sending DataMessageAck (0x0C)

**Attempted:** Sending XNL ACKs after receiving DataMessage
**Result:** No improvement, potentially confuses radio
**Conclusion:** CPS NEVER sends 0x0C - relies on TCP ACK. Don't send them.

### 3. NWConnection (Apple Network Framework)

**Attempted:** Using NWConnection with noDelay=true
**Result:** Unreliable communication, packets buffered
**Conclusion:** Must use raw BSD sockets with TCP_NODELAY

### 4. Short delays (100ms)

**Attempted:** 100ms delays between commands
**Result:** Some timing issues
**Conclusion:** CPS shows ~546ms delay after auth, use 500ms+

### 5. Not handling B400 handshake

**Attempted:** Skip directly to XCMP commands after XNL auth
**Result:** Commands timeout
**Conclusion:** Must complete full B400 sequence (0x00→0x02→0x0F→0x01)

### 6. Using wrong TxID prefix

**Attempted:** Various TxID formats
**Result:** Commands fail
**Conclusion:** Use session prefix from AUTH_KEY_REPLY byte 15, increment sequence

---

## Required Fix - CONFIRMED WORKING

Change byte 5 (message flags/ID) from static 0x02 to incrementing counter:

**Before:**
```swift
packet.append(0x02)  // Static - BROKEN
```

**After:**
```swift
xnlMessageID += 1
packet.append(xnlMessageID)  // Incrementing: 0x02, 0x03, 0x04...
```

The counter should start at 0x02 for the first XCMP command (xnlMessageID starts at 1, increment before use).

### Test Results After Fix (2026-01-30)

```
[3/8] Testing Radio Identification (CPS Protocol)...
    1. Security Key (0x0012)...
    ✓ Security Key: 05 71 AF E2 44 66 4F 99 9A 96 B0 20 E8 2D C6 9C
    2. Model Number (0x0010)...
    ✓ Model: H02RDH9VA1AN
    3. Serial Number (0x0011)...
    ✓ Serial: 867TXM0273
    4. Firmware Version (0x000F)...
    ✓ Firmware: R02.21.01.1001
    5. Codeplug ID (0x001F)...
    ✓ Codeplug ID: PMUE3836DK
```

**Multiple XCMP commands now work in a single session!**

The root cause was the XNL message ID (byte 5) must increment with each DataMessage sent.
The radio uses this to detect duplicate/retransmitted packets. Without incrementing,
the radio treated subsequent commands as retransmissions and dropped them.

---

## Remaining Issues (New Problems to Investigate)

1. **Clone Read**: "No channel data returned" - Different protocol command needed
2. **PSDT Query**: "Could not query partition addresses" - May need unlock sequence
3. **Session Management**: "Start failed (code: 0x01)" - May need different mode
4. **Codeplug Read**: Depends on session management working

These are separate protocol issues, not related to the multi-command bug.

---

*Analysis completed 2026-01-30*
*Updated with implementation comparison and failures 2026-01-30*
*FIX CONFIRMED WORKING 2026-01-30*
