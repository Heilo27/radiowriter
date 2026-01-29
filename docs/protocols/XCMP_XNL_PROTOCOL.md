# XCMP/XNL Protocol Documentation

**Source Analysis:** Moto.Net C# implementation and xcmp-xnl-dissector Wireshark dissector
**Target:** MOTOTRBO radios (XPR 3500e via CDC ECM at 192.168.10.1)
**Transport:** UDP port 4002
**Date:** 2026-01-29

---

## Overview

The MOTOTRBO radio programming protocol consists of two layers:

1. **XNL (eXtended Network Layer)** - Network transport layer handling authentication, addressing, and packet routing
2. **XCMP (eXtended Command and Management Protocol)** - Application layer for radio control and codeplug operations

---

## XNL Layer (Network/Transport)

### Packet Structure

XNL packets have a 14-byte header followed by variable-length payload:

```
Offset  Size  Field              Description
------  ----  -----              -----------
0       2     Length             Total packet length (big-endian, includes header)
2       2     OpCode             XNL operation code
4       1     Protocol           0x00 = XNL only, 0x01 = XCMP encapsulated
5       1     Flags              Sequence flags (0-7, wraps around)
6       2     Destination        Destination address (big-endian)
8       2     Source             Source address (big-endian)
10      2     Transaction ID     Transaction identifier (big-endian)
12      2     Payload Length     Length of payload data
14      N     Payload            Payload data
```

### XNL OpCodes

```c#
public enum OpCode
{
    MasterStatusBroadcast   = 0x02,  // Radio broadcasts its presence/status
    DeviceMasterQuery       = 0x03,  // Query for master device
    DeviceAuthKeyRequest    = 0x04,  // Request authentication key
    DeviceAuthKeyReply      = 0x05,  // Reply with authentication key + challenge
    DeviceConnectionRequest = 0x06,  // Connect with encrypted challenge response
    DeviceConnectionReply   = 0x07,  // Connection accepted, XNL ID assigned
    DeviceSysMapRequest     = 0x08,  // Request system map
    DeviceSysMapBroadcast   = 0x09,  // Broadcast system map
    DataMessage             = 0x0b,  // Data packet (usually contains XCMP)
    DataMessageAck          = 0x0c   // Acknowledge data packet
}
```

### Address Format

- **Address:** 16-bit unsigned integer (big-endian)
- **0x0000:** Broadcast/unassigned
- **Dynamic assignment:** Master assigns XNL addresses during connection

---

## Authentication Handshake

The XNL authentication is a challenge-response mechanism using custom encryption.

### Step 1: Master Query (Optional)

Client can send a `DeviceMasterQuery` (0x03) to trigger a master status broadcast:

```
Packet: DeviceMasterQuery
  OpCode: 0x03
  Protocol: 0x00
  Flags: 0x00
  Destination: 0x0000
  Source: 0x0000
  Transaction ID: 0x0000
  Payload: (empty)
```

### Step 2: Master Status Broadcast

Radio sends periodic `MasterStatusBroadcast` (0x02):

```
Payload format:
  Offset  Size  Field
  0       2     Minor version
  2       2     Major version
  4       1     Device type (0x01 = repeater, 0x02 = subscriber radio)
  5       1     Device number
  6       1     Data traffic occurred flag
```

**Key information:**
- Client learns the master's address from the Source field
- Device type determines which encryption algorithm to use

### Step 3: Authentication Key Request

Client sends `DeviceAuthKeyRequest` (0x04):

```
Packet: DeviceAuthKeyRequest
  OpCode: 0x04
  Protocol: 0x00
  Flags: 0x00
  Destination: <master address from broadcast>
  Source: 0x0000
  Transaction ID: 0x0000
  Payload: (empty)
```

### Step 4: Authentication Key Reply

Radio replies with `DeviceAuthKeyReply` (0x05):

```
Payload format:
  Offset  Size  Field
  0       2     Temporary address (assigned to client for this handshake)
  2       8     Authentication key (challenge)
```

**The 8-byte authentication key is the challenge that must be encrypted.**

### Step 5: Device Connection Request

Client encrypts the 8-byte challenge and sends `DeviceConnectionRequest` (0x06):

```
Payload format:
  Offset  Size  Field
  0       2     Connection address (0x0000 for new connection)
  2       1     Connection type (0x0A typical)
  3       1     Authentication index (0x00 for CPS, 0x01 for control station)
  4       8     Encrypted authentication key
```

**Encryption selection:**
- `authIndex = 0x00` → Use CPS encryption (requires XnlAuthenticationDotNet.dll)
- `authIndex = 0x01` + Subscriber radio → Use ControlStation encryption
- `authIndex = 0x01` + Repeater → Use RepeaterIPSC encryption

### Step 6: Device Connection Reply

Radio accepts connection and assigns permanent XNL address (0x07):

```
Payload format:
  Offset  Size  Field
  0       1     Result code (0x01 = success)
  1       1     Transaction ID base
  2       2     Assigned XNL ID (use for all future communications)
  4       1     Connection type
  5       1     Connection number
  6       8     Connection auth info
```

**After this step, client uses the assigned XNL ID as its source address.**

---

## Encryption Algorithms

### TEA-Based Encryption

Both ControlStation and RepeaterIPSC use a TEA (Tiny Encryption Algorithm) variant:

```c#
public static byte[] Encrypt(byte[] data)  // 8 bytes in, 8 bytes out
{
    UInt32 dword1 = ArrayToInt(data, 0);  // First 4 bytes
    UInt32 dword2 = ArrayToInt(data, 4);  // Last 4 bytes

    UInt32 num1 = <Const1>;  // From config
    UInt32 num2 = <Const2>;
    UInt32 num3 = <Const3>;
    UInt32 num4 = <Const4>;
    UInt32 num5 = <Const5>;
    UInt32 num6 = <Const6>;

    for (int i = 0; i < 32; ++i)
    {
        num1 += num2;
        dword1 += (uint)(((int)dword2 << 4) + (int)num3 ^
                         (int)dword2 + (int)num1 ^
                         (int)(dword2 >> 5) + (int)num4);
        dword2 += (uint)(((int)dword1 << 4) + (int)num5 ^
                         (int)dword1 + (int)num1 ^
                         (int)(dword1 >> 5) + (int)num6);
    }

    return IntToArray(dword1) + IntToArray(dword2);
}
```

**Key points:**
- Algorithm is TEA-like with 32 rounds
- Requires 6 constants (different for ControlStation vs RepeaterIPSC)
- Constants are not public and must be derived or obtained
- Input/output is always 8 bytes
- All integers are big-endian

### CPS Encryption

For CPS-level access (authIndex = 0x00):
- Requires `XnlAuthenticationDotNet.dll` (proprietary)
- Method: `XnlAuthentication.EncryptAuthKey(byte[] data)`
- This enables higher-privilege operations like codeplug read/write

### Obtaining Encryption Constants

**Method 1:** Extract from TRBOnet.Server.exe
- Load assembly: `Assembly.LoadFrom("TRBOnet.Server.exe")`
- RepeaterIPSC: `NS.Enginee.Mototrbo.Utils.XNLRepeaterCrypter.Encrypt()`
- ControlStation: `NS.Enginee.Mototrbo.Utils.XNLMasterCrypter.Encrypt()`

**Method 2:** Reverse engineer from Motorola CPS
- Constants are embedded in CPS binaries
- GPU-assisted brute force may be required

---

## XCMP Layer (Application Protocol)

Once XNL connection is established, XCMP packets are sent inside XNL DataMessage (0x0b) packets.

### XCMP Packet Structure

```
Offset  Size  Field
------  ----  -----
0       2     OpCode (big-endian)
2       N     Data (opcode-specific)
```

### XCMP OpCodes

Request opcodes are even, replies are request | 0x8000, broadcasts are request | 0xb000:

```c#
public enum XCMPOpCode
{
    // System/Status
    DeviceinitStatusBroadcast = 0xB400,  // Radio init status
    RadioStatusRequest        = 0x000E,  // Query radio status
    RadioStatusReply          = 0x800E,
    VersionInfoRequest        = 0x000F,  // Get version info
    VersionInfoReply          = 0x800F,

    // CPS Operations
    CPS_TanapaNumberRequest   = 0x001F,  // Get serial number
    CPS_TanapaNumberReply     = 0x801F,
    CPS_SuperBundleRequest    = 0x002E,  // Bulk codeplug operation
    CPS_SuperBundleReply      = 0x802E,

    // Codeplug Read/Write
    CloneReadRequest          = 0x010A,  // Read codeplug data
    CloneReadReply            = 0x810A,
    CloneWriteRequest         = 0x0109,  // Write codeplug data (NEEDS VERIFICATION)
    CloneWriteReply           = 0x8109,

    // Radio Control
    TransmitPowerLevelRequest = 0x0408,
    TransmitPowerLevelReply   = 0x8408,
    RadioPowerRequest         = 0x040A,  // Shutdown/restart radio
    RadioPowerReply           = 0x840A,
    ChannelSelectRequest      = 0x040D,  // Change channel
    ChannelSelectReply        = 0x840D,
    AlarmStatusRequest        = 0x042E,
    AlarmStatusReply          = 0x842E,

    // Broadcasts
    RRCtrlBroadcast           = 0xB41C,  // Remote control broadcast
}
```

### DeviceInitStatusBroadcast (0xB400)

Radio sends this during XNL initialization:

```
Offset  Size  Field
------  ----  -----
0       2     OpCode (0xB400)
2       1     Major version
3       1     Minor version
4       1     Patch version
5       1     Product ID
6       1     Initialization status (0=STATUS, 1=COMPLETE, 2=UPDATE)
7       1     Device type (1=RF Transceiver, 10=IP Peripheral)
8       2     Status code
10      1     Attribute length
11      N     Attributes (key-value pairs)
```

**Attributes:**
```
Key   Name
---   ----
0x00  Device Family
0x02  Display
0x03  Speaker
0x04  RF Band
0x05  GPIO
0x07  Radio Type
0x09  Keypad
0x0D  Channel Knob
0x0E  Virtual Personality
0x11  Bluetooth
0x13  Accelerometer
0x14  GPS
```

Client must respond with its own DeviceInitStatusBroadcast if Init != COMPLETE.

### CloneReadRequest (0x010A)

Read codeplug data from radio:

**Format 1 (Zone/Channel):**
```
Offset  Size  Field
------  ----  -----
0       2     OpCode (0x010A)
2       1     0x80
3       1     0x01
4       2     Zone ID
6       1     0x80
7       1     0x02
8       2     Channel ID
10      1     0x00
11      1     Data type (0x0F = channel name)
```

**Format 2 (Index-based):**
```
Offset  Size  Field
------  ----  -----
0       2     OpCode (0x010A)
2       2     Index type
4       2     Index number
6       2     Data type
```

### CloneReadReply (0x810A)

```
Offset  Size  Field
------  ----  -----
0       2     OpCode (0x810A)
2       1     Error code (0 = success)
3       2     0x8001 (zone marker)
5       2     Zone ID
7       2     0x8002 (channel marker)
9       2     Channel ID
11      2     Data type
13      2     Data length
15      N     Data payload
```

### Error Codes

```
0x00  Success
0x02  Incorrect Mode
0x03  Unsupported Opcode
0x04  Invalid Parameter
0x05  Reply Too Big
0x06  Security Locked
0x07  Unavailable Function
0x??  ReInitXNL - XNL connection needs to be re-established
```

---

## Data Flow

### Sending XCMP Commands

1. Create XCMP packet (e.g., `CloneReadRequest`)
2. Wrap in XNL `DataPacket`:
   - OpCode: 0x0b (DataMessage)
   - Protocol: 0x01 (XCMP)
   - Source: assigned XNL ID
   - Destination: master address
   - Transaction ID: incrementing counter
   - Flags: 0-7 cycling counter
3. Send UDP packet to 192.168.10.1:4002
4. Wait for reply
5. Radio sends XNL DataMessageAck (0x0c) to acknowledge receipt
6. Radio sends XNL DataMessage with XCMP reply

### Transaction Management

- Transaction IDs increment for each request
- Flags cycle 0→7→0 for data messages
- Retry failed packets up to 3 times (5 second timeout)
- If 3 retries fail, reinitialize XNL connection

---

## Implementation Checklist for macOS App

### Phase 1: XNL Connection
- [ ] Send DeviceMasterQuery (optional, or wait for broadcast)
- [ ] Listen for MasterStatusBroadcast
- [ ] Parse master address and device type
- [ ] Send DeviceAuthKeyRequest
- [ ] Receive DeviceAuthKeyReply with challenge
- [ ] Implement encryption (TEA variant)
  - [ ] Obtain/derive the 6 encryption constants
  - [ ] Implement big-endian integer conversion
  - [ ] 32-round TEA encryption
- [ ] Send DeviceConnectionRequest with encrypted challenge
- [ ] Receive DeviceConnectionReply with assigned XNL ID
- [ ] Store XNL ID for future communications

### Phase 2: XCMP Communication
- [ ] Wait for DeviceInitStatusBroadcast (0xB400)
- [ ] Send DeviceInitStatusBroadcast response if needed
- [ ] Implement transaction ID management
- [ ] Implement retry logic with timeouts
- [ ] Handle DataMessageAck acknowledgments

### Phase 3: Codeplug Operations
- [ ] VersionInfoRequest - get radio firmware version
- [ ] TanapaNumberRequest - get serial number
- [ ] RadioStatusRequest - get current radio status
- [ ] CloneReadRequest - read codeplug data
- [ ] Parse CloneReadReply responses
- [ ] Map codeplug data types to readable structures

### Phase 4: Error Handling
- [ ] Handle encryption failures
- [ ] Detect "ReInitXNL" error and reconnect
- [ ] Handle timeout/retry logic
- [ ] Validate packet checksums (if any)

---

## Constants and Keys

### Required Constants

1. **XNL Encryption (6 constants per algorithm type):**
   - RepeaterIPSC: XNLConst1-6
   - ControlStation: XNLControlConst1-6

2. **CPS Authentication:**
   - XnlAuthenticationDotNet.dll (proprietary)

### Obtaining Constants

**Legal/Recommended:**
- License Motorola SDK/CPS development tools
- Extract from licensed TRBOnet.Server.exe copy
- Use existing open-source implementations as reference (educational use)

**Not Recommended:**
- Reverse engineering Motorola CPS without license
- Distributing extracted constants publicly

---

## References

- **Moto.Net:** https://github.com/pboyd04/Moto.Net
- **xcmp-xnl-dissector:** https://github.com/george-hopkins/xcmp-xnl-dissector
- **codeplug tools:** https://github.com/george-hopkins/codeplug

---

## Notes

- XPR 3500e uses CDC ECM network interface at 192.168.10.1
- XNL/XCMP operates on UDP port 4002
- Encryption constants are proprietary and not included in open-source implementations
- For full CPS functionality, CPS-level encryption (authIndex 0x00) is required
- Some operations may work with ControlStation encryption (authIndex 0x01)

---

## Unknown/Needs Verification

- [ ] Exact CloneWriteRequest packet format
- [ ] Complete list of data types for CloneRead/Write
- [ ] Checksum/CRC validation (if used)
- [ ] Exact meaning of all DeviceInitStatusBroadcast attributes
- [ ] Complete codeplug memory map structure
- [ ] UDP vs TCP usage (port 8002 mentioned in dissector for TCP)
