# XCMP/XNL Quick Reference Card

**Target:** XPR 3500e at 192.168.10.1:4002 (UDP)

---

## XNL Packet Structure (14 bytes + payload)

```
Offset  Type    Field           Endian
0       UInt16  Length          Big
2       UInt16  OpCode          Big
4       UInt8   Protocol        (0=XNL, 1=XCMP)
5       UInt8   Flags           (0-7 cycling)
6       UInt16  Destination     Big
8       UInt16  Source          Big
10      UInt16  Transaction ID  Big
12      UInt16  Payload Length  Big
14      Data    Payload
```

---

## XNL OpCodes

```
0x02  MasterStatusBroadcast   ← Radio announces presence
0x03  DeviceMasterQuery       → Trigger broadcast
0x04  DeviceAuthKeyRequest    → Request auth challenge
0x05  DeviceAuthKeyReply      ← 8-byte challenge
0x06  DeviceConnectionRequest → Encrypted challenge
0x07  DeviceConnectionReply   ← XNL ID assigned
0x08  DeviceSysMapRequest     → Request system map
0x09  DeviceSysMapBroadcast   ← System map
0x0b  DataMessage             ↔ XCMP data transport
0x0c  DataMessageAck          ← Acknowledgment
```

---

## Authentication Flow

```
1. → DeviceMasterQuery (0x03)
   ← MasterStatusBroadcast (0x02) - Learn master address

2. → DeviceAuthKeyRequest (0x04)
   ← DeviceAuthKeyReply (0x05) - Get 8-byte challenge

3. Encrypt challenge:
   - Get device type from broadcast
   - Choose encryption: RepeaterIPSC or ControlStation
   - Run 32-round TEA

4. → DeviceConnectionRequest (0x06)
   Payload: [addr(2)] [type(1)] [authIdx(1)] [encrypted(8)]

5. ← DeviceConnectionReply (0x07)
   Payload: [result(1)] [txBase(1)] [xnlID(2)] ...

6. Use assigned XNL ID for all future packets
```

---

## XCMP Packet Structure

```
Offset  Type    Field
0       UInt16  OpCode (Big-endian)
2       Data    Payload
```

---

## XCMP OpCodes (Request | Reply)

```
SYSTEM/STATUS:
0x000E | 0x800E   RadioStatus
0x000F | 0x800F   VersionInfo
0xB400           DeviceInitStatusBroadcast

CPS OPERATIONS:
0x001F | 0x801F   TanapaNumber (serial)
0x002E | 0x802E   SuperBundle
0x010A | 0x810A   CloneRead (codeplug)
0x0109 | 0x8109   CloneWrite

RADIO CONTROL:
0x0408 | 0x8408   TransmitPowerLevel
0x040A | 0x840A   RadioPower (shutdown)
0x040D | 0x840D   ChannelSelect
0x042E | 0x842E   AlarmStatus
```

---

## CloneRead Request Format

**Zone/Channel read (e.g., channel name):**
```swift
var data = Data()
data.append(0x80)                           // Zone marker
data.append(0x01)
data.append(contentsOf: [UInt8(zone >> 8), UInt8(zone & 0xFF)])
data.append(0x80)                           // Channel marker
data.append(0x02)
data.append(contentsOf: [UInt8(channel >> 8), UInt8(channel & 0xFF)])
data.append(0x00)
data.append(dataType)                       // 0x0F = channel name
```

**Index-based read:**
```swift
var data = Data()
data.append(contentsOf: [UInt8(indexType >> 8), UInt8(indexType & 0xFF)])
data.append(contentsOf: [UInt8(index >> 8), UInt8(index & 0xFF)])
data.append(contentsOf: [UInt8(dataType >> 8), UInt8(dataType & 0xFF)])
```

---

## TEA Encryption (32 rounds)

```swift
func encryptTEA(_ data: Data, constants: [UInt32]) -> Data {
    var dword1 = arrayToInt(data, offset: 0)  // Bytes 0-3
    var dword2 = arrayToInt(data, offset: 4)  // Bytes 4-7

    var num1 = constants[0]  // Initial
    let num2 = constants[1]  // Delta
    let num3 = constants[2]  // Key1
    let num4 = constants[3]  // Key2
    let num5 = constants[4]  // Key3
    let num6 = constants[5]  // Key4

    for _ in 0..<32 {
        num1 = num1 &+ num2

        let t1 = ((dword2 << 4) &+ num3) ^
                 (dword2 &+ num1) ^
                 ((dword2 >> 5) &+ num4)
        dword1 = dword1 &+ t1

        let t2 = ((dword1 << 4) &+ num5) ^
                 (dword1 &+ num1) ^
                 ((dword1 >> 5) &+ num6)
        dword2 = dword2 &+ t2
    }

    var result = Data(count: 8)
    intToArray(dword1, data: &result, offset: 0)
    intToArray(dword2, data: &result, offset: 4)
    return result
}
```

---

## Constants (REQUIRED - NOT PUBLIC)

```swift
// RepeaterIPSC (device type 0x01, authIdx 0x01)
let repeaterConsts: [UInt32] = [
    0x????????,  // Const1
    0x????????,  // Const2 (delta)
    0x????????,  // Const3
    0x????????,  // Const4
    0x????????,  // Const5
    0x????????   // Const6
]

// ControlStation (device type 0x02, authIdx 0x01)
let controlConsts: [UInt32] = [
    0x????????,  // Const1
    0x????????,  // Const2 (delta)
    0x????????,  // Const3
    0x????????,  // Const4
    0x????????,  // Const5
    0x????????   // Const6
]
```

---

## Big-Endian Helpers

```swift
// Bytes to UInt32 (big-endian)
func arrayToInt(_ data: Data, offset: Int) -> UInt32 {
    var result: UInt32 = 0
    for i in 0..<4 {
        result = (result << 8) | UInt32(data[offset + i])
    }
    return result
}

// UInt32 to bytes (big-endian)
func intToArray(_ value: UInt32, data: inout Data, offset: Int) {
    var val = value
    for i in (0..<4).reversed() {
        data[offset + i] = UInt8(val & 0xFF)
        val >>= 8
    }
}
```

---

## Transaction Management

```swift
class XNLClient {
    private var transactionID: UInt16 = 0
    private var flags: UInt8 = 0

    func sendDataMessage(_ xcmpData: Data) {
        let packet = XNLPacket(
            opCode: .dataMessage,
            isXCMP: true,
            flags: flags,
            destination: masterAddress,
            source: assignedAddress,
            transactionID: transactionID,
            payload: xcmpData
        )

        transactionID += 1
        flags = (flags + 1) % 8  // Cycle 0-7

        send(packet)
    }
}
```

---

## Error Codes (XCMP Replies)

```
0x00  Success
0x02  Incorrect Mode
0x03  Unsupported Opcode
0x04  Invalid Parameter
0x05  Reply Too Big
0x06  Security Locked
0x07  Unavailable Function
0x??  ReInitXNL - Reconnect required
```

---

## Wireshark Filter

```
udp.port == 4002
```

Dissector: Install `xcmp-xnl-dissector/*.lua` to `~/.config/wireshark/plugins`

---

## Testing Checklist

- [ ] UDP socket sends/receives on 192.168.10.1:4002
- [ ] Can decode MasterStatusBroadcast
- [ ] Encryption produces correct output (validate vs capture)
- [ ] Authentication completes, XNL ID assigned
- [ ] Can send XCMP VersionInfoRequest
- [ ] Can parse XCMP replies
- [ ] Transaction IDs match request/reply
- [ ] Retry logic works on timeout

---

## Common Data Types (CloneRead)

```
0x0F  Channel Name
0x??  [UNKNOWN - discover via experimentation]
```

---

## DeviceInitStatusBroadcast

```
Offset  Field
0       UInt16  OpCode (0xB400)
2       UInt8   Major version
3       UInt8   Minor version
4       UInt8   Patch version
5       UInt8   Product ID
6       UInt8   Init status (0=STATUS, 1=COMPLETE, 2=UPDATE)
7       UInt8   Device type (1=RF Transceiver, 10=IP Peripheral)
8       UInt16  Status code
10      UInt8   Attribute length
11      Pairs   Key-Value attributes
```

**If init != COMPLETE:** Send your own DeviceInitStatusBroadcast response

---

## Retry/Timeout

- **Timeout:** 5 seconds per request
- **Retries:** 3 attempts
- **On failure:** Re-initialize XNL connection

---

## Encryption Decision Tree

```
MasterStatusBroadcast.payload[4] = device type

if authIndex == 0x00:
    Use CPS encryption (XnlAuthenticationDotNet.dll)
else if authIndex == 0x01:
    if deviceType == 0x01:
        Use RepeaterIPSC constants
    else if deviceType == 0x02:
        Use ControlStation constants
```

---

**For full details, see:** `docs/protocols/XCMP_XNL_PROTOCOL.md`
