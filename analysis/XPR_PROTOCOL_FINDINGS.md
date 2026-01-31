# XPR 3500e Protocol Findings

**Date:** 2026-01-29
**Radio:** XPR 3500e (MOTOTRBO DMR)
**Connection:** CDC ECM (USB Network Adapter)

---

## Network Configuration

When connected via USB, the XPR 3500e creates a CDC ECM network interface:

| Parameter | Value |
|-----------|-------|
| Radio IP | 192.168.10.1 |
| Host IP | 192.168.10.2 |
| Subnet | 255.255.255.0 |
| MAC (Radio) | 0a:00:3e:e5:d0:fc |

**Important:** This interface may become the default route on macOS, breaking internet connectivity. Fix by reordering network services in System Settings → Network.

---

## Discovered TCP Ports

| Port | Service | Description |
|------|---------|-------------|
| 8002 | **XNL/CPS** | **CPS Programming port - VERIFIED WORKING** |
| 8501 | AT Debug | Interactive debug interface with command prompt |
| 8502 | Unknown | No response to TCP probes |

---

## Discovered UDP Ports

| Port | Service | Description |
|------|---------|-------------|
| 4002 | XCMP/XNL | Control protocol (requires authentication) |
| 4005 | Unknown | Open but no response |
| 5016 | Unknown | Open but no response |
| 5017 | Unknown | Open but no response |
| 8002 | Unknown | Open on UDP |
| 8501 | AT Debug | Also available on UDP |
| 8502 | Unknown | Open on UDP |
| 50000 | IPSC | IP Site Connect / Data |
| 50001 | IPSC | IP Site Connect |
| 50002 | IPSC | IP Site Connect |

---

## XCMP/XNL Protocol ✅ VERIFIED WORKING

The MOTOTRBO radios use **XCMP/XNL** protocol for control and programming:

### Protocol Stack
```
Application Layer:    XCMP (Extended Command and Management Protocol)
Transport Layer:      XNL (Network Layer) - connection, heartbeat, encapsulation
Network Layer:        TCP port 8002 (for CPS/subscriber mode)
Physical Layer:       CDC ECM over USB
```

**Important:** Direct radio programming uses **TCP port 8002**, not UDP port 4002. UDP 4002 is used for repeater/network mode.

### Authentication Flow ✅ VERIFIED
1. PC sends `DeviceMasterQuery` (opcode 0x03)
2. Radio responds with `MasterStatusBroadcast` (opcode 0x02) containing master address
3. PC sends `DeviceAuthKeyRequest` (opcode 0x04) to master address
4. Radio responds with `DeviceAuthKeyReply` (opcode 0x05) containing 8-byte challenge
5. PC encrypts challenge with **TEA algorithm** using extracted key
6. PC sends `DeviceConnectionRequest` (opcode 0x06) with encrypted challenge
7. Radio responds with `DeviceConnectionReply` (opcode 0x07) with result code 0x00 = success!

### TEA Encryption Key ✅ VERIFIED WORKING

```swift
// Extracted from XnlAuthentication.dll (MOTOTRBO CPS 2.0)
// Raw bytes: 1D 30 96 5A 55 AA F2 0C C6 6C 93 BF 5B CD 5E BD

// CORRECT CONFIGURATION (2026-01-29):
// Use LITTLE-ENDIAN interpretation (as BitConverter.ToInt32 reads on x86/.NET)
let key: [UInt32] = [0x5A96301D, 0x0CF2AA55, 0xBF936CC6, 0xBD5ECD5B]

// CRITICAL: Motorola uses a CUSTOM delta, NOT the standard TEA delta!
let delta: UInt32 = 0x790AB771  // From IL: ldc.i4 2030745457
// Standard TEA delta would be 0x9E3779B9 - DO NOT USE THIS!

// Auth index for CPS mode
let authIndex: UInt8 = 0x00
```

**Source:** `XnlAuthentication.dll` → obfuscated class `iq` → field `a`
**Raw bytes:** `1D 30 96 5A 55 AA F2 0C C6 6C 93 BF 5B CD 5E BD`

**Critical Discoveries (2026-01-29):**
1. The delta constant `0x790AB771` is extracted from IL instruction `ldc.i4 2030745457`
2. Key must be interpreted as little-endian UInt32 values
3. Auth index 0x00 = CPS mode, 0x01 = Subscriber mode
4. DeviceConnectionReply result 0x01 still indicates success if assigned address is non-zero
5. Radio sends DeviceSysMapBroadcast (opcode 0x09) after connection established

**Status:** ✅ Authentication verified working! XCMP communication established.

### Authentication Modes ✅ VERIFIED

| Mode | AuthIndex | Keys | Status |
|------|-----------|------|--------|
| CPS | 0x00 | XnlAuthentication.dll keys | ✅ **WORKING** |
| ControlStation/Subscriber | 0x01 | XNLControlConst1-6 | Not needed |
| RepeaterIPSC | varies | XNLConst1-6 | For repeaters only |

**For XPR 3500e (regular radio):**
- `MasterStatusBroadcast.Type` = 2 (regular radio, not repeater)
- **CPS mode (authIndex 0x00) works** for programming
- DeviceConnectionReply result 0x01 indicates CPS connection accepted
- Assigned address provided (incrementing from 0x0002)

### XCMP Communication ✅ VERIFIED WORKING

After XNL authentication, XCMP commands can be sent via XNL Data Messages (opcode 0x0B).

**Observed XCMP Traffic:**

| Opcode | Direction | Description |
|--------|-----------|-------------|
| 0x0400 | Request | DevInitStatus - check radio programming readiness |
| 0x8400 | Reply | DevInitStatus reply (data: 0x03 = ready?) |
| 0xB400 | Broadcast | Periodic status broadcast (~1/sec) |
| 0xB410 | Broadcast | Another status broadcast type |
| 0x000E | Request | Version Info Request |
| 0x800E | Reply | Version Info Reply (minimal for XPR 3500e) |

**XCMP Packet Format (within XNL Data payload):**
```
+----------------+----------------+
| Opcode (2B BE) | Data...        |
+----------------+----------------+
```

**DevInitStatus Reply Codes:**
- 0x03 = Observed response (meaning TBD)

### Message Structure (XNL)
```
Offset  Size  Field
0-1     2B    Total Length (big-endian)
2       1B    Protocol ID (0x00)
3       1B    OpCode
4       1B    Reserved (0x00)
5       1B    Flags (increments 0-7)
6-7     2B    Destination Address (big-endian)
8-9     2B    Source Address (big-endian)
10-11   2B    Transaction ID (big-endian)
12-13   2B    Data Length (big-endian)
14+     var   Payload data
```

**XNL Opcodes:**
| Opcode | Name | Description |
|--------|------|-------------|
| 0x02 | MasterStatusBroadcast | Radio announces presence |
| 0x03 | DeviceMasterQuery | Request master info |
| 0x04 | DeviceAuthKeyRequest | Request auth challenge |
| 0x05 | DeviceAuthKeyReply | 8-byte challenge |
| 0x06 | DeviceConnectionRequest | Send encrypted response |
| 0x07 | DeviceConnectionReply | Auth result + assigned addr |
| 0x09 | DeviceSysMapBroadcast | System map after connection |
| 0x0B | DataMessage | XCMP command container |
| 0x0C | DataMessageAck | ACK for data message |

### Resources
- [george-hopkins/xcmp-xnl-dissector](https://github.com/george-hopkins/xcmp-xnl-dissector) - Wireshark dissector
- [pboyd04/Moto.Net](https://github.com/pboyd04/Moto.Net) - C# XNL/XCMP implementation
- [nox-x/mototrbo-dmr-test-toolkit](https://github.com/nox-x/mototrbo-dmr-test-toolkit) - Protocol test cases

---

## AT Debug Interface (Port 8501)

### Connection
- Protocol: TCP
- Port: 8501
- Encoding: ASCII with \r\n line endings

### Welcome Banner
```
(C) Copyright 2021 MOTOROLA SOLUTIONS, INC. ALL RIGHTS RESERVED

Welcome to AT debug
```

### Available Commands (from `?` help)

| Command | Description |
|---------|-------------|
| `ERR:DUMP` | Reports status of Reset Capture's in FLASH and current Arming configuration |
| `ERR:RCARM` | Manually Arms reset capture |
| `ERR:RCDISARM` | Manually DisArms reset capture |
| `ERR:CLEAR` | Clears out any previously captured image |
| `ERR:CAPTURE` | Forces a reset capture |
| `ERR:CAPTURE_DSP` | Forces a reset capture (DSP) |
| `VER` | Display radio version info |

### VER Command Output
```
Welcome to Host radio debugger.
Welcome to Dsp radio debugger.
```

**Note:** The VER command doesn't return detailed model/serial information in the current firmware. Additional commands may need to be discovered.

---

## Protocol Research Needed

### High Priority
1. **Programming Port** - Neither 8002 nor 8502 responded to probes. The actual codeplug read/write may use:
   - A different port (scan 20000-65535 range)
   - A binary protocol with specific handshake
   - Raw socket communication

2. **Model Identification** - Need to find command that returns:
   - Model number (e.g., "MDH02RDH9XA1AN")
   - Serial number
   - Firmware version
   - Frequency band (UHF/VHF)

3. **Codeplug Protocol** - Need to reverse engineer:
   - Read codeplug command sequence
   - Write codeplug command sequence
   - Block size and addressing
   - Checksum/verification method

### Medium Priority
4. **AT Debug Commands** - May have undocumented commands for:
   - Memory read/write
   - Diagnostic information
   - Factory reset
   - Firmware info

---

## Comparison with Windows CPS

The MOTOTRBO CPS 2.0 uses:
- .NET assemblies (easier to decompile)
- Namespace: `Motorola.Rbr.BD.*` (RBR = Radio Business Radio)
- "BlackDiamond" internal codename

Key DLLs to analyze:
- `Motorola.CommonTool.CPService.dll` - Communication service
- `Motorola.CommonTool.DL.dll` - Data layer
- `BL.*.Trans.dll` - Model-specific transforms

---

## Next Steps

### Immediate ✅ COMPLETED
1. ~~**Port scanning**~~ ✅ Completed - Found UDP ports 4002, 5016, 5017, 50000-50002
2. ~~**XCMP/XNL analysis**~~ ✅ Completed - Disassembled DLLs
3. ~~**Authentication research**~~ ✅ Completed - Extracted TEA key and custom delta

### Current Priority
4. **Test XNL Authentication** - Reconnect radio and test with correct delta (0x78E7B771)
5. **XCMP Protocol** - Analyze `Common.Communication.PcrSequenceManager.dll` (518KB) for codeplug operations
6. **Radio Identification** - Implement XCMP command to read model/serial/firmware

### Short Term
7. **Wireshark capture** - Capture real CPS traffic to see XCMP codeplug read/write sequence
8. **CommandHandler analysis** - Study `Motorola.CommonCPS.RadioManagement.CommandHandler.dll` (1.6MB)
9. **CodeplugConverter** - Analyze for codeplug file format

### DLLs Available for Analysis
Located in `/Users/home/.wine_mototrbo/drive_c/MOTOTRBO/`:
- `XnlAuthentication.dll` ✅ Analyzed - TEA encryption
- `Common.Communication.XNL.dll` ✅ Analyzed - XNL protocol layer
- `Common.Communication.PcrSequenceManager.dll` - PCR/XPR sequence operations
- `Motorola.CommonCPS.RadioManagement.CommandHandler.dll` - Command handling
- `CodeplugConverter.dll` - Codeplug format conversion

### Long Term
10. **Motorola ADK** - Consider applying for official developer access
11. **Community resources** - Connect with ham radio communities who have researched this

---

## Extracted Encryption Keys

### Business Radio CPS Keys (from secure.dll)

These keys are used for encrypting CPS configuration files (config.xml, etc.):

```
Algorithm: Triple DES (3DES)
Key:       HAVNCPSCMTTUNERAIRTRACER  (24 bytes ASCII)
IV:        VEDKDJSP                   (8 bytes ASCII)
```

**Source:** `secure.dll` → `CSecureConstants` class
- `DefStrKey = "HAVNCPSCMTTUNERAIRTRACER"`
- `DefStrIV = "VEDKDJSP"`

**Confirmed identical across versions:** r09.10, r09.11, r11.00

### Admin/License Key (from CMT.Web.dll)

Used for license validation in the CPS software:

```
Admin Key: MOTOROLACHENGDUSITERBRTEAMCOM  (28 characters)
```

**Source:** `CMT.Web.dll` → `WebLicense.ADMINKEY`

### Radio Family Codenames (from BL.*.dll)

The Business Radio CPS uses internal codenames for different radio families:

| Codename | Radio Series | DLL File |
|----------|--------------|----------|
| CLP | CLP series (original) | BL.Clp.*.dll |
| CLP2 | CLP series (2nd gen) | BL.Clp2.*.dll |
| ClpNova | CLP Nova series | BL.ClpNova.*.dll |
| Sunb | CLS series | BL.Sunb.*.dll |
| DLRx | DLR series (digital) | BL.DLRx.*.dll |
| Dtr | DTR series | BL.Dtr.*.dll |
| Fiji | SL series (original) | BL.Fiji.*.dll |
| NewFiji | SL series (new) | BL.NewFiji.*.dll |
| Nome | RMx series | BL.Nome.*.dll |
| Renoir | Unknown | BL.Renoir.*.dll |
| Solo | Unknown | BL.Solo.*.dll |
| Vanu | Unknown | BL.Vanu.*.dll |

### MOTOTRBO CPS Keys ✅ EXTRACTED AND VERIFIED

The XPR 3500e uses **MOTOTRBO CPS 2.0** which uses TEA encryption for XNL authentication:

#### XNL Authentication Key (TEA) ✅ VERIFIED
```
Algorithm: TEA (Tiny Encryption Algorithm) - 32 rounds
Key:       1D 30 96 5A 55 AA F2 0C C6 6C 93 BF 5B CD 5E BD
Delta:     0x78E7B771 (MOTOTRBO custom, NOT standard 0x9E3779B9!)
```

**Source:** `XnlAuthentication.dll` from MOTOTRBO CPS 2.0 extracted via Wine
**Extraction method:** `monodis` disassembly of .NET assembly
**Key location:** Class `iq`, field `a` at data offset D_00002050
**Delta location:** IL_0092/IL_0095 in encrypt/decrypt methods

#### Codeplug Encryption Keys (For File Storage)
- Codeplug encryption key (43-char Base64) - stored in `cpservices.dll`
- Codeplug IV (22-char Base64)
- Signing password (22-char Base64)
- Signing certificate (.pfx)

**Status:** Not yet extracted - only needed for reading/writing codeplug files, not for radio communication.

### Key Differences

| CPS Version | Supported Radios | Key Location | Status |
|-------------|------------------|--------------|--------|
| Business Radio CPS | CLP, CLS, DLR, DTR, RMx, SL (Fiji) | secure.dll | ✅ Extracted |
| MOTOTRBO CPS 2.0 | XPR, SL (new), DP, DM, DR | cpservices.dll | ❌ Not extracted |

---

## Verified Radio Information (XPR 3500e)

| Field | Value | XCMP Command |
|-------|-------|--------------|
| Model Number | H02RDH9VA1AN | `0x000E type=0x07` |
| Firmware Version | R02.21.01.1002 | `0x000F type=0x00` |

---

## Code Implementation Status

| Component | Status |
|-----------|--------|
| NetworkConnection | ✅ Implemented |
| MOTOTRBOProgrammer | ✅ Basic structure, identification stub |
| Auto-detection | ✅ Detects radio on network |
| Auto-transition | ✅ Opens programming view |
| XNL Authentication | ✅ TEA key (LE) + custom delta (0x790AB771) verified |
| XNL Connection | ✅ TCP port 8002 - **VERIFIED WORKING** (2026-01-29) |
| XCMP Communication | ✅ Packets exchanged, data received |
| XCMP VersionInfo | ✅ `0x000F` returns firmware version |
| XCMP RadioStatus/Model | ✅ `0x000E type=0x07` returns model number |
| Sequential Commands | ⚠️ Issue: Radio caches first response (see Known Issues) |
| Codeplug Read | ❌ Need XCMP protocol implementation |
| Codeplug Write | ❌ Need XCMP protocol implementation |

### Known Issues

**Sequential XCMP Commands Return Cached Response**
When sending multiple XCMP commands on the same TCP connection, the radio may return the first response for all subsequent commands. The TxID in responses matches the first command, not the current one.

**Workarounds:**
1. Use a fresh TCP connection for each command (verified working)
2. Investigate proper XNL flow control (ACKs, sequence numbers)
3. Add longer delays between commands (not fully verified)

---

## References

- [george-hopkins/codeplug](https://github.com/george-hopkins/codeplug) - Motorola codeplug tools
- [OpenRTX/dmrconfig](https://github.com/OpenRTX/dmrconfig) - DMR radio config utility
- [qdmr](https://dm3mat.darc.de/qdmr/) - Cross-platform DMR codeplug tool
