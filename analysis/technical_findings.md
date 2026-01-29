# Technical Findings - MOTOTRBO CPS 2.0

**Analysis Date:** 2026-01-29
**Analyst:** Specter

---

## 1. Supported Radio Models

### Status: NEEDS VERIFICATION

The installer is too large (615 MB) to contain only the setup launcher. This suggests the application bundle includes:
- Complete CPS application suite
- Radio firmware images
- Driver packages
- Documentation
- Model-specific configuration templates

**Expected models** (based on typical MOTOTRBO CPS 2.0 product coverage):
- XPR series (portable/mobile)
- DP series (portable)
- DM series (mobile)
- SL series (portable)
- DR series (repeater)

**Action required:** Extract and analyze installed application to find model database/configuration files.

---

## 2. Communication Protocol

### Status: LIMITED DATA

#### Extracted Information

**Installer Dependencies:**
```
KERNEL32.dll    - Core Windows APIs including serial/file I/O
ADVAPI32.dll    - Registry and service management
CRYPT32.dll     - Cryptographic operations
```

**Expected Protocol Stack:**
```
Application Layer:    CPS GUI → Configuration Management
Transport Layer:      USB Virtual COM or Native USB
Physical Layer:       USB 2.0 connection to radio
```

#### USB/Serial Communication

**Indicators found:**
- Standard Windows serial I/O functions (ReadFile, WriteFile)
- USB-related string fragments (requires cleanup for verification)

**Likely implementation:**
- USB CDC (Communications Device Class) for virtual serial
- OR vendor-specific USB protocol
- Standard serial parameters (8N1)

**Status:** Actual protocol commands, packet structure, and timing parameters require extraction from the installed CPS application binaries.

---

## 3. Codeplug Structure

### Status: PRELIMINARY INDICATORS

#### File Extensions Identified
```
.rdt    - Radio Data Template (likely main codeplug format)
.xml    - XML configuration/metadata
.dat    - Data files
.bin    - Binary data/firmware
.cfg    - Configuration files
```

#### Suspected Format (DMR Codeplug)
```
[Header Block]
  - Magic/Signature bytes
  - Version identifier
  - Radio model ID
  - Timestamp
  - Checksum/CRC
  
[Channel Data]
  - Analog channels
  - Digital (DMR) channels
  - Channel parameters (freq, power, bandwidth)
  
[Zone/Group Data]
  - Zone definitions
  - Channel assignments
  
[DMR-Specific Data]
  - Contact list (digital IDs)
  - Talk groups
  - Call lists
  - Radio ID
  
[Security Data]
  - Privacy keys (if used)
  - Encryption settings
  
[Footer]
  - Verification checksum
```

**Status:** This structure is based on typical DMR codeplug organization. Actual format requires:
1. Sample .rdt files
2. Hex analysis
3. Comparison with programmed radio behavior

---

## 4. DLL Dependencies

### Confirmed Dependencies

#### System Libraries
| DLL | Purpose |
|-----|---------|
| KERNEL32.dll | Core Windows APIs, memory, file I/O, threads |
| USER32.dll | Windows UI framework, message handling |
| GDI32.dll | Graphics rendering |
| gdiplus.dll | Enhanced graphics (GDI+) |
| ADVAPI32.dll | Registry, services, security |
| SHELL32.dll | Shell operations, file operations |
| OLEAUT32.dll | OLE automation |
| COMCTL32.dll | Common controls (UI widgets) |
| CRYPT32.dll | Cryptographic services, certificate validation |
| RPCRT4.dll | RPC runtime (for inter-process communication) |
| VERSION.dll | Version resource management |
| ole32.dll | OLE/COM infrastructure |
| msi.dll | Windows Installer services |

#### Custom Libraries
| DLL | Purpose |
|-----|---------|
| ISSetup.dll | InstallShield setup engine |

### Communication Stack (Expected)

Based on typical Motorola CPS architecture, the installed application likely includes:
```
CPS.exe                     - Main application
MotorolaUSB.dll            - USB communication layer (expected name)
RadioProtocol.dll          - Protocol implementation (expected name)
DeviceDriver.dll           - Device abstraction (expected name)
```

**Status:** Actual DLL names and functions require analysis of installed application directory.

---

## 5. Protocol Constants

### Status: NOT YET EXTRACTED

The installer itself contains only setup code and compressed application data. Protocol constants (command bytes, response codes, timing values) are embedded in the application binaries.

#### Expected Constants (Industry Standard Pattern)

**Command Categories:**
```
0x0x - Handshake/Status
0x1x - Read operations
0x2x - Write operations
0x3x - Erase operations
0x4x - Verify operations
0xFx - Special/Utility commands
```

**Response Codes:**
```
ACK (0x06)  - Command accepted
NAK (0x15)  - Command rejected/error
```

**Timing:**
```
Command timeout: 1000-5000 ms
Inter-byte delay: 0-50 ms
Block size: 16-256 bytes (typical)
```

**Status:** These are educated guesses based on Motorola patterns. Actual values require:
1. Decompilation of protocol handler DLL
2. USB traffic capture and analysis
3. Protocol reverse engineering

---

## 6. Compression & Encryption

### Installer Level

**Compression:**
- Uses zlib 1.2.3 (confirmed via strings: "deflate 1.2.3 Copyright 1995-2005 Jean-loup Gailly")
- InstallShield compression for application data

**Code Signing:**
- DigiCert SHA2 Assured ID certificate
- Valid signature chain
- Signed by: Motorola Solutions, Inc.

### Application Level (Expected)

**Codeplug Security:**
- Optional password protection
- Optional encryption (model-dependent)
- CRC/checksum for data integrity

**Radio Communication:**
- Challenge-response authentication (expected)
- Encrypted firmware updates (expected)
- Secure bootloader mode (expected)

**Status:** Application-level security mechanisms require analysis of installed CPS and radio communication sessions.

---

## Key Technical Gaps

| Area | Current Status | Required Action |
|------|----------------|-----------------|
| **Radio Models** | Unknown | Extract model database from installed app |
| **Protocol Commands** | Unknown | Decompile protocol handler DLL |
| **Packet Structure** | Unknown | USB traffic capture |
| **Codeplug Format** | Suspected structure | Hex analysis of sample files |
| **USB VID/PID** | Unknown | Check driver INF files |
| **Baud Rate** | Unknown | Extract from config or code |
| **Authentication** | Unknown | Protocol analysis |
| **Encryption** | Unknown | Crypto library analysis |

---

## Recommendations

### Phase 1: Installation & Extraction
1. Install CPS 2.0 in Windows VM
2. Locate installation directory (typically `C:\Program Files (x86)\Motorola\MOTOTRBO CPS 2.0\`)
3. Catalog all executables and DLLs
4. Extract driver files (INF, SYS, DLL)
5. Locate documentation files

### Phase 2: Static Analysis
1. Decompile main CPS executable (IDA Pro/Ghidra)
2. Analyze USB/serial communication DLLs
3. Extract string tables (model names, error messages, commands)
4. Identify protocol handler functions
5. Map data structures

### Phase 3: Dynamic Analysis
1. Set up USB protocol capture (Wireshark + USBPcap)
2. Connect test radio (XPR, DP, or DM series)
3. Capture programming session:
   - Enter programming mode
   - Read codeplug
   - Write codeplug
   - Exit programming mode
4. Analyze captured packets
5. Document protocol flow

### Phase 4: Codeplug Reverse Engineering
1. Collect sample .rdt files for different radio models
2. Hex dump and compare
3. Identify fixed fields vs. variable data
4. Map known settings to byte offsets
5. Document format specification

### Phase 5: Implementation
1. Build Swift library for codeplug parsing
2. Implement USB communication protocol
3. Create radio detection logic
4. Develop read/write operations
5. Add verification and error handling

---

## Risk Assessment

| Risk | Impact | Mitigation |
|------|--------|------------|
| Proprietary protocol | High | Reverse engineering via traffic capture |
| Authentication/encryption | Medium | Analyze auth handshake, use legitimate keys |
| Model-specific variations | Medium | Build model database, test each variant |
| USB driver requirements | Low | Use CDC virtual serial or libusb |
| Firmware compatibility | High | Version checking, read-only operations first |

---

*This analysis represents preliminary findings from installer examination only. Comprehensive protocol documentation requires full application analysis and live radio testing.*
