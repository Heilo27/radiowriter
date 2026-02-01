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
9. [CPS Read Protocol (IshSessionStart)](#cps-read-protocol-ishsessionstart) ← **USE THIS FOR READING**
10. [Programming Mode Initialization](#programming-mode-initialization-write-only) ← **WRITE ONLY**
11. [XCMP Command Reference](#xcmp-command-reference)
12. [Implementation Requirements](#implementation-requirements)
13. [Common Pitfalls](#common-pitfalls)
14. [Our Implementation Status](#our-implementation-status)

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

## Radio Detection Protocol

### Overview

Before XNL/XCMP communication can begin, the radio must be detected on the system. MOTOTRBO radios connect via USB and present as CDC-ECM network adapters. Detection involves multiple methods in order of reliability.

### Detection Methods (Priority Order)

#### Method 1: USB VID/PID Detection (Most Reliable)

When physically connected, MOTOTRBO radios enumerate as USB devices with:

| Parameter | Value | Notes |
|-----------|-------|-------|
| Vendor ID | 0x0CAD (3245) | Motorola Solutions |
| Product IDs | 0x1020-0x102D | MOTOTRBO range |
| Product Name | "Motorola Solutions LTD Device" | As reported by radio |

**macOS Detection (IOKit):**
```swift
let matchingDict = IOServiceMatching(kIOUSBDeviceClassName)
IOServiceGetMatchingServices(kIOMainPortDefault, matchingDict, &iterator)
// Check each device for idVendor == 0x0CAD
```

**If no device with VID 0x0CAD is found, the radio is NOT connected.** This is the definitive check.

#### Method 2: Network Interface Detection

Once USB enumerates, macOS creates a CDC-ECM network interface:

| Parameter | Value | Notes |
|-----------|-------|-------|
| Interface Name | Dynamic (en7, en17, etc.) | **Never hardcode!** |
| Host IP | 192.168.10.2 | Assigned by radio's DHCP |
| Radio IP | 192.168.10.1 | Fixed |
| Subnet | 255.255.255.0 | /24 network |

**Detection via ifconfig:**
```bash
ifconfig | grep -A 5 "192.168.10"
```

**Important:** Interface names are NOT fixed. macOS assigns them based on connection order. Always scan all interfaces.

#### Method 3: mDNS/Bonjour Discovery (CPS Method)

Motorola CPS 2.0 uses mDNS for radio discovery (from `DNSConfig.xml`):

| Parameter | Value |
|-----------|-------|
| Multicast IP | 224.0.0.251 |
| Port | 5353 |
| Service Type | `_otap._tcp.local` |

**macOS Detection (NWBrowser):**
```swift
let browser = NWBrowser(for: .bonjour(type: "_otap._tcp", domain: "local"), using: .tcp)
browser.browseResultsChangedHandler = { results, _ in
    // Check results for radio services
}
browser.start(queue: queue)
```

**Note:** Not all radios advertise via mDNS. This is a supplementary method.

#### Method 4: XNL Port Scan (Verification)

To confirm a detected IP is actually a radio, check XNL port 8002:

```bash
nc -z -v -G 1 192.168.10.1 8002
```

**TCP port 8002 responding = Radio ready for XNL communication**

### Detection Sequence

```
┌─────────────────────────────────────────────────────────────┐
│  1. Scan USB bus for VID 0x0CAD                             │
│     └─ NO DEVICE? → Radio not connected (hardware issue)    │
├─────────────────────────────────────────────────────────────┤
│  2. Find associated network interface                        │
│     └─ Scan all interfaces for 192.168.10.x                 │
│     └─ NO INTERFACE? → Wait 5-10 sec, CDC-ECM initializing  │
├─────────────────────────────────────────────────────────────┤
│  3. Verify XNL port 8002 is open                            │
│     └─ PORT CLOSED? → Radio booting, wait and retry         │
├─────────────────────────────────────────────────────────────┤
│  4. Radio ready for XNL authentication                       │
└─────────────────────────────────────────────────────────────┘
```

### Timing Considerations

| Stage | Typical Duration |
|-------|------------------|
| Radio power-on to USB enumeration | 2-5 seconds |
| USB enumeration to interface creation | 1-3 seconds |
| Interface creation to DHCP assignment | 1-2 seconds |
| **Total: Power-on to ready** | **5-10 seconds** |

**Best Practice:** Poll every 2 seconds. Don't give up before 15 seconds.

### Common Detection Failures

| Symptom | Cause | Solution |
|---------|-------|----------|
| No USB device (VID 0x0CAD) | Radio not powered on | Power on radio fully |
| No USB device | Charge-only cable | Use data cable |
| No USB device | VM capturing device | Check VM USB settings |
| USB found, no interface | CDC-ECM initializing | Wait 5-10 seconds |
| Interface found, port closed | Radio still booting | Wait and retry |
| Worked yesterday, not today | Radio state issue | Power cycle radio |

### Verified Working Configuration (XPR 3500e)

```
USB Device:
  Vendor ID: 3245 (0x0CAD)
  Product ID: 4386 (0x1122)
  Product Name: "Motorola Solutions LTD Device"
  Vendor Name: "Motorola Solutions Corporation"

Network:
  Interface: en17 (varies)
  Host IP: 192.168.10.2
  Radio IP: 192.168.10.1
  XNL Port: 8002 (TCP)
```

---

## Transport Layer Requirements

### USB Network Connection (CDC-ECM)

**Important Discovery:** XPR 3500e radios use **CDC-ECM** (Communications Device Class - Ethernet Control Model) for USB networking, **NOT RNDIS**. This is significant because:

- **macOS has native CDC-ECM support** - no third-party drivers needed (unlike RNDIS which requires HoRNDIS)
- The radio appears as a standard Ethernet interface (e.g., `en17`)
- The radio acts as a DHCP server, assigning the host an IP address

| Parameter | Value | Notes |
|-----------|-------|-------|
| USB Mode | CDC-ECM | Native macOS support |
| Radio IP | 192.168.10.1 | Fixed address |
| Host IP | 192.168.10.2 | Assigned via DHCP |
| Interface | Dynamic (e.g., en17) | Created when radio connects |

### Timing Considerations

**Critical:** The USB network interface may take several seconds to appear after the radio is connected and powered on. The sequence is:

1. Radio powers on and completes boot sequence
2. USB enumeration occurs (radio appears on USB bus)
3. CDC-ECM driver loads and creates network interface
4. Radio's DHCP server assigns IP to host (192.168.10.2)
5. Interface becomes active and routable

**Detection Strategy:**
- Scan for new network interfaces periodically
- Check for interfaces with 192.168.10.x addresses
- Verify XNL port 8002 is reachable before declaring radio ready
- Allow 5-10 seconds after radio power-on for full initialization

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

## CPS Read Protocol (IshSessionStart)

### CRITICAL DISCOVERY (2026-01-31)

**The CPS 2.0 software does NOT use Programming Mode (0x0106/0x0300/0x0301) for reading codeplugs.**

Instead, CPS uses a simpler protocol:
1. **IshSessionStart (0x0105)** - Returns list of available record IDs
2. **CodeplugRead (0x002E)** - Reads records in batches

This was discovered by analyzing actual CPS 2.0 Wireshark captures (CPS 2nd write.txt) and comparing to our implementation which was failing with error 0x01 (invalid key) on the UnlockSecurity command.

### Read vs Write Protocols

| Operation | Protocol | Opcodes | Security Required |
|-----------|----------|---------|-------------------|
| **READ** | IshSessionStart | 0x0105 → 0x002E | NO (just XNL auth) |
| **WRITE** | Programming Mode | 0x0106 → 0x0300 → 0x0301 → 0x0108 | YES (encrypted key) |

### IshSessionStart Flow

```
    App                                          Radio
     │                                             │
     │    [XNL Authentication completed]           │
     │    [B400 Handshake completed]               │
     │                                             │
     ├── IshSessionStart (0x0105) ────────────────►│
     │   Params: 80 01 EE 00 00                    │
     │                                             │
     │◄── IshSessionStartReply (0x8105) ───────────┤
     │   Returns: List of available record IDs     │
     │                                             │
     ├── CodeplugRead (0x002E) ───────────────────►│
     │   Batch 1: First N records                  │
     │                                             │
     │◄── CodeplugReadReply (0x802E) ──────────────┤
     │   Record data for batch 1                   │
     │                                             │
     ├── CodeplugRead (0x002E) ───────────────────►│
     │   Batch 2: Next N records                   │
     │                                             │
     │◄── CodeplugReadReply (0x802E) ──────────────┤
     │   Record data for batch 2                   │
     │                                             │
     │   [Continue until all records read]         │
     │                                             │
```

### IshSessionStart Request (0x0105)

**Packet format captured from CPS 2.0:**

```
XNL Header:
  00 13        Length: 19 bytes
  00 0B        Opcode: DataMessage
  01 03        Flags/MsgID
  00 06        Destination: Radio (master)
  00 1A        Source: Our assigned address
  1A 1E        Transaction ID

XCMP Payload:
  00 07        Payload length: 7 bytes
  01 05        XCMP Opcode: IshSessionStart
  80           Read flag (0x80 = read, 0x00 = write)
  01           Partition: 0x01 (application)
  EE 00 00     Session parameters (meaning unknown)
```

**Parameters explained:**
- `0x80` - Read flag (high bit set = read mode)
- `0x01` - Partition ID (application partition)
- `0xEE 0x00 0x00` - Additional session parameters (possibly timeout or version)

### IshSessionStartReply (0x8105)

**Response format from radio:**

```
XNL Header:
  00 EA        Length: 234 bytes
  00 0B        Opcode: DataMessage
  01 02        Flags/MsgID
  00 1A        Destination: Us
  00 06        Source: Radio
  1A 1E        Transaction ID (echoed)

XCMP Payload:
  00 DE        Payload length: 222 bytes
  81 05        XCMP Opcode: IshSessionStartReply (0x8105)
  00           Status: Success
  80           Session flags
  00 6A        Record count high byte, low byte (106 records)
  00 00        Unknown
  00 6A        Repeat count (confirmation)

Record ID list (2 bytes each):
  00 0A        Record ID: 0x000A
  00 0B        Record ID: 0x000B
  00 0C        Record ID: 0x000C
  00 18        Record ID: 0x0018
  00 19        Record ID: 0x0019
  00 26        Record ID: 0x0026
  ...          (continues for all 106 records)
```

**Response structure:**
- Byte 0: Status (0x00 = success)
- Byte 1: Session flags (0x80 = read session)
- Bytes 2-3: Record count (big-endian)
- Bytes 4-5: Unknown (possibly reserved)
- Bytes 6-7: Repeat of record count
- Bytes 8+: Array of 2-byte record IDs (big-endian)

### Available Record IDs (XPR 3500e Example)

From CPS capture, the radio returns these record categories:

```
Device Information:     0x000A, 0x000B, 0x000C
General Settings:       0x0018, 0x0019, 0x0026, 0x0027, 0x0028, 0x0029
Channel Configuration:  0x0034, 0x0042, 0x0043, 0x0047, 0x004C, 0x004E, 0x004F, 0x0051
Zone Configuration:     0x005E, 0x005F, 0x0060, 0x0062, 0x0064, 0x0065, 0x0066
Contact Lists:          0x006B, 0x006C, 0x006D, 0x006F
Network Settings:       0x0072, 0x0073, 0x0074, 0x0075, 0x0077
Feature Configuration:  0x007A, 0x007B, 0x007C, 0x007D, 0x007E
Display Settings:       0x0080, 0x0081, 0x0082, 0x0083, 0x0084, 0x0085
Advanced Features:      0x0087, 0x0088, 0x008F, 0x0093, 0x0097, 0x009A, 0x009B, 0x009D
Signaling:              0x00A1, 0x00A2, 0x00A5, 0x00A6, 0x00A7, 0x00A8, 0x00A9
Extended (0x0F**):      0x0F55, 0x0F80, 0x0F81, 0x0F82, 0x0F88, 0x0F8B, 0x0F8F...
                        (many more in the 0x0F** range)
```

### CodeplugRead Request (0x002E)

After getting the list of available records, CPS reads them in batches:

**Request format:**

```
XCMP Payload:
  00 2E        Opcode: CodeplugRead
  3E           Record count: 62 records in this batch
  01 00        Unknown flags

For each record:
  09           Entry length: 9 bytes
  01 04        Entry type flags
  80           Read flag
  00 0A        Record ID (big-endian)
  00 01        Instance (usually 0x0001)
  00 00 00     Padding/reserved
```

**Per-record entry (11 bytes):**
```
Offset  Size  Field
0x00    1     Entry length (0x09)
0x01    1     Type high (0x01)
0x02    1     Type low (0x04)
0x03    1     Flags (0x80 = read)
0x04    2     Record ID (big-endian)
0x06    2     Instance (usually 0x0001)
0x08    3     Reserved (0x00 0x00 0x00)
```

### CodeplugRead Response (0x802E)

**Response format:**

```
XCMP Payload:
  80 2E        Opcode: CodeplugReadReply

For each record:
  09 01 04     Header
  80           Flags
  00 0A        Record ID
  00 01        Instance
  00 00 00     Reserved
  [N bytes]    Record data
```

### CPS Batch Reading Pattern

CPS reads records in batches to optimize transfer:

1. **Batch size**: ~50-62 records per request
2. **Progress**: CPS shows progress as batches complete
3. **Order**: Records are read in the order returned by IshSessionStart
4. **Total time**: ~2-5 seconds for full codeplug read

---

## Channel Data Protocol (Record 0x0FFB)

### CRITICAL DISCOVERY (2026-01-31)

Channel configuration data is stored in **record 0x0FFB** as indexed records. This is distinctly different from other codeplug records.

### Channel Record Structure

| Field | Value | Description |
|-------|-------|-------------|
| Record ID | 0x0FFB | Channel configuration data |
| Record Size | 324 bytes (0x0144) | Each channel entry |
| Name Offset | 0x3C (60 bytes) | UTF-16LE encoded name (verified) |
| Name Max Length | 16 characters | 32 bytes UTF-16LE |

**IMPORTANT:** Batch requests for multiple channels don't work reliably. Read channels one at a time.

### Indexed Record Format

Channels are stored as indexed arrays. Unlike simple records, each channel has an **index** value:

```
[recordID: 0x0FFB] + [index: 0x00] = First channel
[recordID: 0x0FFB] + [index: 0x01] = Second channel
[recordID: 0x0FFB] + [index: 0x02] = Third channel
...
[recordID: 0x0FFB] + [index: 0x21] = Channel 34 (0x21 = 33 in decimal)
```

### Channel Metadata Request

Before reading channel data, CPS queries how many channels exist:

```
Request format (metadata query):
09 01 04 80 0F FB 00 01 00 00 00
── ───── ── ───── ───── ────────
│  │     │  │     │     └── Padding
│  │     │  │     └── Instance (0x0001)
│  │     │  └── Record ID (0x0FFB = channels)
│  │     └── Flags (0x80 = read)
│  └── Type flags (01 04 = metadata query)
└── Entry length (9 bytes)

Response format (81 04 = metadata):
81 04 00 80 0F FB 00 01 00 00 00 00 00 [count:4]
───── ── ── ───── ───── ─────────────────
│     │  │  │     │     └── Count of records (little-endian)
│     │  │  │     └── Instance
│     │  │  └── Record ID
│     │  └── Flags
│     └── Response flags (04 = metadata only)
└── Success (81 = response to request)

Example: 81 04 00 80 0F FB 00 01 00 00 00 22 00 00 00
         → 0x22 = 34 channels available
```

### Channel Data Request

To read actual channel data:

```
Request format (data read):
0B 01 00 80 0F FB 00 [idx] 01 44 00 00
── ───── ── ───── ── ──── ───── ─────
│  │     │  │     │  │    │     └── Padding
│  │     │  │     │  │    └── Size: 0x0144 (324 bytes, little-endian)
│  │     │  │     │  └── Channel index (0x00-0x21 for 34 channels)
│  │     │  │     └── Record ID high byte
│  │     │  └── Record ID: 0x0FFB
│  │     └── Flags (0x80 = read)
│  └── Type flags (01 00 = data read)
└── Entry length: 11 bytes (0x0B)

Example for channel 0:
0B 01 00 80 0F FB 00 00 01 44 00 00

Example for channel 5:
0B 01 00 80 0F FB 00 05 01 44 00 00
```

### Channel Data Response

```
Response format (81 00 = data follows):
01 52 81 00 00 80 0F FB 00 [idx] 01 44 00 00 01 44 [324 bytes of channel data]
───── ───── ── ── ───── ── ──── ───────────────────────────────────────────
│     │     │  │  │     │  │    └── Channel configuration data
│     │     │  │  │     │  └── Echoed index
│     │     │  │  │     └── Echoed record ID
│     │     │  │  └── Flags
│     │     │  └── Response status (00 = success with data)
│     │     └── Response opcode (81 = reply)
│     └── Payload length (0x0152 = 338 bytes including header)
└── XNL header

### Complete Channel Record Field Map (324 bytes)

Verified from XPR 3500e radio analysis (2026-01-31):

```
Offset  Size  Field                Description
──────────────────────────────────────────────────────────────────────
0x00    2     Flags1               Channel config flags (little-endian)
0x02    2     Flags2               Additional flags (little-endian)
0x04    4     Reserved1            Always 0x00000000
0x08    2     Unknown08            Unknown bytes
0x0A    4     Reserved2            Reserved
0x0E    1     ChannelMode          0x00 = Analog, 0x01 = Digital/DMR (VERIFIED)
0x0F    1     Unknown0F            Unknown
0x10    8     Reserved3            Reserved config area
0x18    1     ColorCode            DMR Color Code 0-15 (digital only) (VERIFIED)
0x19    1     Unknown19            Unknown
0x1A    2     Unknown1A            Unknown
0x1C    8     Reserved4            Reserved
0x24    4     RxFrequency          5 Hz units, little-endian (VERIFIED)
0x28    4     TxFrequency          5 Hz units, little-endian (VERIFIED)
0x2C    4     Unknown2C            Signaling config
0x30    2     RxCTCSS              0.1 Hz units, analog only (VERIFIED)
0x32    2     TxCTCSS              0.1 Hz units, analog only (VERIFIED)
0x34    8     Reserved5            Additional settings
0x3C    32    ChannelName          UTF-16LE, null-terminated (VERIFIED)
0x5C    20    PostNameConfig       Post-name configuration
0x70    1     Reference1           Scan list reference
0x71    1     Reference2           Contact reference
0x72    2     Reserved6            Reserved
0x74    4     TxContactID          DMR Contact ID (digital only)
0x77    1     PowerLevel           0x40/0x42 = High, 0x00 = Low (VERIFIED)
0x78    2     TOT                  Timeout timer in seconds
0x7A    1     RxGroupIndex         RX Group List index
0x7B    1     ScanListIndex        Scan List index
0x7C    200   ExtendedConfig       Additional configuration data
──────────────────────────────────────────────────────────────────────
Total: 324 bytes (0x0144)
```

### Field Details

#### Frequency Encoding (VERIFIED)

Frequencies are stored in **5 Hz units** (NOT 10 Hz):

```
RX Frequency (Hz) = ReadUInt32LE(data, 0x24) × 5
TX Frequency (Hz) = ReadUInt32LE(data, 0x28) × 5

Examples from actual radio:
- FRS01:     92,512,500 × 5 = 462,562,500 Hz = 462.5625 MHz
- FRS02:     92,517,500 × 5 = 462,587,500 Hz = 462.5875 MHz
- Spacing:        5,000 × 5 =      25,000 Hz = 25 kHz (FRS channel spacing)
- W4RAT Rpt: RX=447.550 MHz, TX=442.550 MHz (−5 MHz repeater offset)
```

#### Channel Mode (VERIFIED)

```
Offset 0x0E:
  0x00 = Analog
  0x01 = Digital (DMR)
```

#### CTCSS Tones (VERIFIED - Analog Only)

```
Offset 0x30-0x31: RX CTCSS (little-endian, 0.1 Hz units)
Offset 0x32-0x33: TX CTCSS (little-endian, 0.1 Hz units)

Valid range: 670-2541 (67.0 Hz - 254.1 Hz)
Value 0 = No tone

Examples:
- 670 → 67.0 Hz (common CTCSS tone)
- 744 → 74.4 Hz (verified from W4RAT Rpt channel)
- 1000 → 100.0 Hz
```

#### Power Level (VERIFIED)

```
Offset 0x77:
  0x00       = Low Power
  0x40, 0x42 = High Power
```

#### DMR Color Code (Digital Only)

```
Offset 0x18: Color Code value (0-15)
Only valid when ChannelMode (0x0E) = 0x01

Example: FRS01 as DMR has CC=0
```

### Verified Channel Examples

From XPR 3500e radio analysis:

| Channel | Mode | RX MHz | TX MHz | Offset | CTCSS | Power |
|---------|------|--------|--------|--------|-------|-------|
| OPERATIONS | Analog | 461.4625 | 461.4625 | Simplex | 67.0 Hz | High |
| W4RAT Rpt | Analog | 447.5500 | 442.5500 | −5 MHz | 74.4 Hz | High |
| FRS01 | Digital | 462.5625 | 462.5625 | Simplex | N/A | High |
| FRS02 | Digital | 462.5875 | 462.5875 | Simplex | N/A | High |
```

### Channel Name Extraction

Channel names are stored at offset 0x3C (60 bytes) as UTF-16LE:

```swift
// Extract channel name from 324-byte record
let nameOffset = 0x3C  // 60 bytes from record start (VERIFIED)
let nameLength = 32    // 16 characters max × 2 bytes each

let nameData = recordData[nameOffset..<(nameOffset + nameLength)]
if let name = String(data: Data(nameData), encoding: .utf16LittleEndian)?
    .trimmingCharacters(in: CharacterSet(["\0"])) {
    // name contains the channel name (e.g., "FRS01", "W4RAT Rpt")
}
```

### Frequency Extraction

Frequencies are stored in **5 Hz units** (NOT 10 Hz as originally assumed):

```swift
// Extract frequencies from 324-byte record
let rxFreq = UInt32(recordData[0x24]) |
            (UInt32(recordData[0x25]) << 8) |
            (UInt32(recordData[0x26]) << 16) |
            (UInt32(recordData[0x27]) << 24)
let txFreq = UInt32(recordData[0x28]) |
            (UInt32(recordData[0x29]) << 8) |
            (UInt32(recordData[0x2A]) << 16) |
            (UInt32(recordData[0x2B]) << 24)

// Convert from 5 Hz units to Hz
let rxFrequencyHz = rxFreq * 5  // e.g., 92512500 * 5 = 462,562,500 Hz
let txFrequencyHz = txFreq * 5
```

### Example Channel Names from Traffic Capture

From the analyzed XPR 3500e radio:

```
Channel 0:  "FRS01"
Channel 1:  "FRS02"
Channel 2:  "FRS03"
...
Channel 13: "FRS14"
Channel 14: "W4RAT Rpt"
...
```

### CPS Channel Reading Sequence

The complete sequence CPS uses to read all channels:

```
1. IshSessionStart (0x0105) → Get available record list
   - Response includes 0x0FFB in the list

2. CodeplugRead metadata (0x002E) for 0x0FFB
   - Request: 09 01 04 80 0F FB 00 01 00 00 00
   - Response: 81 04 ... [count=34]

3. CodeplugRead data (0x002E) for each channel index
   - Request batch: Multiple entries in single packet
     0B 01 00 80 0F FB 00 00 01 44 00 00  (channel 0)
     0B 01 00 80 0F FB 00 01 01 44 00 00  (channel 1)
     0B 01 00 80 0F FB 00 02 01 44 00 00  (channel 2)
     ...
   - Response: 81 00 ... [324 bytes] for each channel

4. Parse UTF-16LE names from offset 0x52 in each record
```

### Other Indexed Records

Similar indexed format is used for:

| Record ID | Description | Size per Entry |
|-----------|-------------|----------------|
| 0x0FFB | Channel configuration | 324 bytes |
| 0x0F8B | Contacts/accessories | 368 bytes |
| 0x0F82 | Zone configuration | Variable |
| 0x0F80 | General settings | Variable |

### Contact Data Record (0x0F8B)

Contact entries are also indexed:

```
Record ID: 0x0F8B
Size: 368 bytes (0x0170) per contact
Format: ASCII strings (NOT UTF-16LE)

Example contacts from traffic:
- "CORE_ACCY"
- "PMLN5097"
- "PMLN5111"
- "RLN5880"
- "PMMN4025"
```

### Implementation Example

```swift
// Step 1: Start read session
let sessionRequest = XCMPPacket.ishSessionStartRequest()
let sessionReply = try await sendAndReceive(sessionRequest)
let availableRecords = parseRecordIDs(from: sessionReply)

// Step 2: Read records in batches
let batchSize = 50
for batchStart in stride(from: 0, to: availableRecords.count, by: batchSize) {
    let batchEnd = min(batchStart + batchSize, availableRecords.count)
    let batch = Array(availableRecords[batchStart..<batchEnd])

    let readRequest = XCMPPacket.codeplugReadRequest(recordIDs: batch)
    let readReply = try await sendAndReceive(readRequest)

    // Process record data from reply
    parseRecordData(readReply)
}
```

### Why Programming Mode Fails for Reading

Our initial implementation attempted to use the Programming Mode sequence (0x0106 → 0x0300 → 0x0301 → 0x0108) for reading codeplugs. This failed with error 0x01 (invalid key) on the UnlockSecurity (0x0301) command.

**Root cause analysis:**
1. Programming Mode is designed for **WRITE** operations that modify the radio
2. The security unlock requires correctly encrypted radio key
3. Even with correct TEA encryption, the radio may reject keys for read-only sessions
4. CPS 2.0 never uses Programming Mode for reading - it uses IshSessionStart instead

**The fix:**
- For **reading**: Use IshSessionStart (0x0105) + CodeplugRead (0x002E)
- For **writing**: Use Programming Mode (0x0106 → 0x0300 → 0x0301 → 0x0108)

---

## Programming Mode Initialization (WRITE ONLY)

### Overview

**Programming Mode is only required for WRITE operations.**

For reading codeplugs, use the [CPS Read Protocol](#cps-read-protocol-ishsessionstart) instead.

Programming Mode is used when:
- Writing new codeplug data to the radio
- Cloning from one radio to another
- Firmware updates
- Tuning adjustments

### Initialization Sequence

The following sequence must be executed in order:

| Step | Opcode | Name | Parameters | Notes |
|------|--------|------|------------|-------|
| 1 | 0x0106 | IshProgramMode | 0x01 (enter) | Enter programming mode |
| 2 | 0x0300 | ReadRadioKey | None | Returns 32-byte radio key |
| 3 | - | Encrypt Key | - | TEA encryption with XNL key |
| 4 | 0x0301 | UnlockSecurity | 32-byte encrypted key | Validates encryption |
| 5 | 0x0108 | IshUnlockPartition | 0x01 (application) | Unlocks codeplug access |

### Radio Key Encryption

The 32-byte radio key returned by 0x0300 must be encrypted using TEA before sending to 0x0301.

**Encryption method:**
- Algorithm: TEA (Tiny Encryption Algorithm)
- Key: Same 16-byte key used for XNL authentication
- Delta: 0x790AB771 (MOTOTRBO-specific constant)
- Mode: ECB (each 8-byte block encrypted independently)
- Block processing: Encrypt 32 bytes as four 8-byte blocks

```swift
public static func encryptRadioKey(_ radioKey: Data) -> Data? {
    guard radioKey.count == 32 else { return nil }

    var result = Data()

    // Encrypt in four 8-byte blocks using TEA
    for blockIndex in 0..<4 {
        let blockStart = blockIndex * 8
        let block = radioKey[blockStart..<(blockStart + 8)]

        guard let encryptedBlock = teaEncrypt(Data(block)) else {
            return nil
        }
        result.append(encryptedBlock)
    }

    return result
}
```

### Programming Mode Actions (0x0106)

| Action | Value | Description |
|--------|-------|-------------|
| Exit | 0x00 | Exit programming mode |
| Enter | 0x01 | Enter programming mode |
| Clone | 0x02 | Enter clone mode |
| ExitNoReset | 0x03 | Exit without radio reset |
| OtapWrite | 0x04 | OTAP write mode |
| OtapRead | 0x05 | OTAP read mode |
| OtapExitCRC | 0x06 | Exit OTAP with checksum |
| Remote | 0x07 | Remote programming mode |

### Radio Partitions (0x0108)

| Partition | Value | Description |
|-----------|-------|-------------|
| Application | 0x01 | Main codeplug partition |
| DSP | 0x02 | DSP configuration |
| Tuning | 0x04 | RF tuning data |

### Error Codes

| Code | Meaning | Cause |
|------|---------|-------|
| 0x00 | Success | Operation completed |
| 0x01 | Invalid Key | TEA encryption incorrect or wrong mode |
| 0x02 | Locked | Partition already locked by another session |
| 0x03 | Not Supported | Radio doesn't support this mode |
| 0xFF | Timeout | Radio didn't respond |

### Example Write Initialization Flow

```
PC → Radio: 0x0106 0x01                    (Enter programming mode)
Radio → PC: 0x8106 0x00                    (Success)

PC → Radio: 0x0300                         (Read radio key)
Radio → PC: 0x8300 0x00 [32-byte key]      (Key returned)

[Encrypt key with TEA - 4 blocks of 8 bytes each]

PC → Radio: 0x0301 [32-byte encrypted]     (Unlock security)
Radio → PC: 0x8301 0x00                    (Success)

PC → Radio: 0x0108 0x01                    (Unlock application partition)
Radio → PC: 0x8108 0x00                    (Success)

-- Radio is now ready for write operations --
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
| 1.4 | 2026-01-31 | **COMPLETE FIELD MAP**: Documented all verified channel record fields. Updated name offset to 0x3C (was incorrectly 0x52). Added CTCSS parsing (0x30-0x33), power level (0x77), channel mode (0x0E). Frequency units confirmed as 5 Hz. |
| 1.3 | 2026-01-31 | **MAJOR**: Added Channel Data Protocol section. Documented indexed record format for channels (0x0FFB). |
| 1.2 | 2026-01-31 | **CRITICAL**: Added CPS Read Protocol section. Discovered that CPS uses IshSessionStart (0x0105) for reading, NOT Programming Mode. Programming Mode is only for writes. |
| 1.1 | 2026-01-31 | Added USB CDC-ECM connection details, timing considerations |
| 1.0 | 2026-01-30 | Initial release - verified implementation |

---

## Key Discoveries Summary

### Reading Codeplugs (What CPS Actually Does)

```
1. XNL Authentication (0x02 → 0x04 → 0x05 → 0x06 → 0x07)
2. B400 Handshake
3. Device Info Queries (0x0012, 0x0010, 0x000F, 0x0011, 0x001F)
4. IshSessionStart (0x0105) with params: 80 01 EE 00 00
   └─ Returns list of available record IDs
5. CodeplugRead (0x002E) in batches
   └─ Reads all records returned by session start
```

### Writing Codeplugs (When Programming Mode IS Required)

```
1. XNL Authentication
2. B400 Handshake
3. Enter Programming Mode (0x0106 0x01)
4. Read Radio Key (0x0300)
5. Encrypt Key with TEA (4 blocks × 8 bytes)
6. Unlock Security (0x0301 + encrypted key)
7. Unlock Partition (0x0108 0x01)
8. Perform write operations
9. Exit Programming Mode (0x0106 0x00)
```

### Why Our Initial Implementation Failed

| Symptom | Cause | Fix |
|---------|-------|-----|
| 0x0301 returns error 0x01 | Using Programming Mode for reads | Use IshSessionStart (0x0105) instead |
| No channel data returned | Wrong protocol for reading | Use 0x0105 → 0x002E sequence |
| Timeout after auth | Missing B400 handshake | Complete full B400 exchange |

---

*This document is based on reverse engineering of Motorola CPS 2.0 traffic captures and verified against XPR 3500e hardware.*
