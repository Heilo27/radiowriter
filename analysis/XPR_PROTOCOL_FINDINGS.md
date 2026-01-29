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
| 8002 | Unknown | No response to TCP probes |
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

## XCMP/XNL Protocol (Key Discovery)

The MOTOTRBO radios use **XCMP/XNL** protocol for control and programming:

### Protocol Stack
```
Application Layer:    XCMP (Extended Command and Management Protocol)
Transport Layer:      XNL (Network Layer) - connection, heartbeat, encapsulation
Network Layer:        UDP (typically port 4002)
Physical Layer:       CDC ECM over USB
```

### Authentication Required
XCMP/XNL requires a **challenge-response authentication** with developer keys:
1. PC requests authentication info from radio
2. Radio returns challenge data
3. PC encrypts challenge with developer keys (provided by Motorola)
4. PC sends encrypted response to radio
5. Radio verifies and grants access

**Important:** Developer keys are proprietary and provided by Motorola under NDA.

### Message Structure (XNL)
```
+----------------+----------------+----------------+----------------+
| Protocol ID    | Length (2B)    | OpCode (1B)    | Flags (1B)     |
+----------------+----------------+----------------+----------------+
| Transaction ID | Source Addr    | Dest Addr      | Payload...     |
+----------------+----------------+----------------+----------------+
```

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

### Immediate
1. ~~**Port scanning**~~ ✅ Completed - Found UDP ports 4002, 5016, 5017, 50000-50002
2. **XCMP/XNL analysis** - Study the Wireshark dissector to understand message structure
3. **Authentication research** - Find if keys can be extracted from CPS installation

### Short Term
4. **Wireshark capture** - Capture CPS traffic in Windows VM with XCMP/XNL dissector
5. **Moto.Net study** - Analyze C# implementation for protocol structure
6. **codeplug-prepare** - Check if this tool can extract keys from CPS

### Long Term
7. **Motorola ADK** - Consider applying for official developer access
8. **Community resources** - Connect with ham radio communities who have researched this

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

### MOTOTRBO CPS Keys (Not Yet Extracted)

The XPR 3500e uses **MOTOTRBO CPS 2.0** (separate software) which has different keys:
- Codeplug encryption key (43-char Base64)
- Codeplug IV (22-char Base64)
- Signing password (22-char Base64)
- Signing certificate (.pfx)

**Source:** `cpservices.dll` in MOTOTRBO CPS installation

**Note:** The MOTOTRBO CPS 2.0 installer uses InstallShield with proprietary compression.
We were unable to extract `cpservices.dll` from `mototrbo-cps-na-2.0.exe`.
A Windows VM with the actual CPS installed may be required.

### Key Differences

| CPS Version | Supported Radios | Key Location | Status |
|-------------|------------------|--------------|--------|
| Business Radio CPS | CLP, CLS, DLR, DTR, RMx, SL (Fiji) | secure.dll | ✅ Extracted |
| MOTOTRBO CPS 2.0 | XPR, SL (new), DP, DM, DR | cpservices.dll | ❌ Not extracted |

---

## Code Implementation Status

| Component | Status |
|-----------|--------|
| NetworkConnection | ✅ Implemented |
| MOTOTRBOProgrammer | ✅ Basic structure, identification stub |
| Auto-detection | ✅ Detects radio on network |
| Auto-transition | ✅ Opens programming view |
| Codeplug Read | ❌ Protocol unknown |
| Codeplug Write | ❌ Protocol unknown |

---

## References

- [george-hopkins/codeplug](https://github.com/george-hopkins/codeplug) - Motorola codeplug tools
- [OpenRTX/dmrconfig](https://github.com/OpenRTX/dmrconfig) - DMR radio config utility
- [qdmr](https://dm3mat.darc.de/qdmr/) - Cross-platform DMR codeplug tool
