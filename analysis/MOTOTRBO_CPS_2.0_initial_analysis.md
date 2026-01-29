# MOTOTRBO CPS 2.0 - Initial Binary Analysis

**Date:** 2026-01-29
**Analyst:** Specter
**Target:** MOTOTRBO_CPS_2.0.exe
**Size:** 615 MB (645,078,392 bytes)

---

## Executive Summary

MOTOTRBO CPS 2.0 is Motorola's Customer Programming Software for DMR digital radios. The analyzed file is an InstallShield installer (version 22.0.284) containing the complete CPS application suite.

**Key Findings:**
- PE32 executable signed by Motorola Solutions, Inc. (DigiCert SHA2 Assured ID)
- Build date: June 8, 2015
- Product version: 2.122.70.0
- Installer format: InstallShield Setup Launcher

---

## Binary Metadata

### File Information
```
Type: PE32 executable (GUI) Intel 80386
Platform: Windows (32-bit)
Size: 645,078,392 bytes (615 MB)
Subsystem: Windows GUI
Image Base: 0x400000
Created: 2015-06-08 00:20:34
```

### Digital Signature
```
Signer: Motorola Solutions, Inc.
Email: robert.adamczyk@motorolasolutions.com
Certificate Authority: DigiCert SHA2 Assured ID Code Signing CA
Root CA: DigiCert Assured ID Root CA
Valid: 2021-05-12 to 2023-05-17
```

### Version Information
```
FileVersion: 2.122.70.0
ProductVersion: 2.122.70.0
CompanyName: Motorola Solutions, Inc.
ProductName: MOTOTRBO CPS 2.0
InternalName: Setup
FileDescription: Setup Launcher Unicode
```

---

## Architecture Analysis

### Installer Structure

**Installer Type:** InstallShield 22.0.284 (Unicode)
**Internal Build:** 154432

The executable is a setup launcher that contains:
1. Setup engine (InstallShield)
2. Compressed application files (614 MB data blob)
3. Digital certificate chain
4. Installation metadata

### Core Dependencies

#### System DLLs
```
KERNEL32.dll    - Core Windows APIs
USER32.dll      - Windows UI framework
GDI32.dll       - Graphics Device Interface
ADVAPI32.dll    - Advanced Windows services
SHELL32.dll     - Windows Shell functions
OLEAUT32.dll    - OLE Automation
COMCTL32.dll    - Common Controls
CRYPT32.dll     - Cryptographic services
RPCRT4.dll      - RPC runtime
gdiplus.dll     - GDI+ graphics
VERSION.dll     - Version resource APIs
```

#### Custom Components
```
ISSetup.dll     - InstallShield setup library
msi.dll         - Windows Installer
```

---

## Preliminary Protocol Findings

### [NEEDS VERIFICATION] Communication Patterns

Based on string analysis and typical Motorola CPS architecture:

#### Expected Communication Stack
```
CPS Application
    ↓
USB/Serial Driver Layer
    ↓
Protocol Handler (likely proprietary)
    ↓
Radio Hardware
```

### [NEEDS VERIFICATION] Suspected File Formats

#### Configuration Files
- **Extension patterns identified:** `.rdt`, `.xml`, `.dat`, `.bin`, `.cfg`
- **Likely codeplug format:** Binary with XML metadata
- **Data files found:** `BetaMarker.dat`, `EvalMarker.dat`

### [UNKNOWN] Protocol Commands

Common Motorola CPS commands (based on industry knowledge, not yet confirmed in binary):
```
- Enter Programming Mode
- Read Codeplug
- Write Codeplug
- Verify Codeplug
- Clone Radio
- Update Firmware
- Exit Programming Mode
```

**Status:** These patterns need to be verified through deeper analysis of the extracted application binaries.

---

## Radio Model Support

### [NEEDS VERIFICATION] MotoTRBO Product Lines

Based on typical MOTOTRBO CPS 2.0 coverage (industry knowledge):

#### Portable Radios
- XPR 3000 series
- XPR 6000 series
- XPR 7000 series
- SL 300 series
- SL 4000 series
- DP 2000 series
- DP 3000 series
- DP 4000 series

#### Mobile Radios
- XPR 4000 series
- XPR 5000 series
- DM 3000 series
- DM 4000 series

#### Repeaters
- DR 3000 series
- SLR 5000 series

**Note:** Actual model support needs verification from extracted application files and documentation.

---

## USB/Serial Communication

### Expected Communication Interface

#### USB Connection
```
Vendor ID (VID): [NEEDS EXTRACTION]
Product ID (PID): [NEEDS EXTRACTION]
Interface Class: CDC/Serial or Vendor-Specific
```

#### Serial Parameters (Typical)
```
Baud Rate: 9600, 19200, 38400, 57600, or 115200
Data Bits: 8
Parity: None
Stop Bits: 1
Flow Control: RTS/CTS or None
```

**Status:** These values need to be extracted from the installed application binaries or DLLs.

---

## Codeplug Structure

### [UNKNOWN] Binary Format

Typical Motorola codeplug structure (to be verified):
```
Header:
  - Magic bytes/signature
  - Format version
  - Radio model identifier
  - Checksum/CRC

Configuration Blocks:
  - General Settings
  - Channel List
  - Zone/Group Configuration
  - Contact List (for DMR)
  - Scan Lists
  - Privacy Keys
  - Emergency Settings
  
Footer:
  - Verification checksum
  - Optional signature
```

**Status:** Actual format requires analysis of sample codeplug files or decompiled read/write routines.

---

## Encryption & Security

### Certificate-Based Signing

The installer is properly code-signed with industry-standard certificates (DigiCert), indicating:
- Authentic Motorola software
- Integrity verification
- Standard Windows SmartScreen acceptance

### [UNKNOWN] Radio Programming Security

Expected security features (to be verified):
- Radio authentication (password or crypto challenge)
- Codeplug encryption (optional, model-dependent)
- Firmware signature verification

---

## Next Steps

### Immediate Actions

1. **Extract Installer Contents**
   - Use InstallShield extraction tools
   - Locate main CPS executable and DLLs
   - Extract any embedded documentation

2. **Application Binary Analysis**
   - Analyze main CPS.exe
   - Decompile USB/serial communication DLLs
   - Extract protocol constants and commands

3. **Sample Codeplug Analysis**
   - Obtain sample .rdt files
   - Analyze binary structure
   - Document field layouts

4. **USB Traffic Capture**
   - Set up Windows VM with CPS installed
   - Use USB protocol analyzer (Wireshark + USBPcap)
   - Capture read/write/program sessions

### Analysis Priorities

| Priority | Task | Expected Outcome |
|----------|------|------------------|
| **HIGH** | Extract and analyze main CPS application | Protocol handler location, command definitions |
| **HIGH** | USB traffic capture | Packet structure, command sequences |
| **MEDIUM** | Codeplug format reverse engineering | Binary layout, field definitions |
| **MEDIUM** | DLL dependency analysis | Communication stack, crypto libraries |
| **LOW** | Documentation extraction | Official protocol specs (if included) |

---

## Tools Required

### For Continued Analysis

- **Windows Analysis:**
  - IDA Pro or Ghidra (decompiler)
  - x64dbg (debugger)
  - Dependency Walker (DLL analysis)
  - Process Monitor (Sysinternals)

- **Protocol Analysis:**
  - Wireshark with USBPcap
  - Serial port monitor
  - USB protocol analyzer

- **Binary Analysis:**
  - Hex editor (010 Editor, HxD)
  - Binary diff tool
  - Pattern recognition tools

---

## Legal & Ethical Notes

**Purpose:** Educational/Interoperability research
**Scope:** Protocol documentation for compatible software development
**Restrictions:** 
- No circumvention of copy protection
- No extraction of proprietary algorithms
- Responsible disclosure of security issues
- Respect for Motorola intellectual property

**Distribution:** Findings are for internal development use only. Do not distribute proprietary binaries or extracted code.

---

## References

- InstallShield Setup Launcher (version 22.0.284)
- DigiCert Code Signing Certificate Chain
- Motorola Solutions MOTOTRBO product line

**Analysis Status:** PRELIMINARY - Requires deeper investigation

---

*Generated by Specter - Binary Analysis Agent*
*Part of the MotorolaCPS Reverse Engineering Project*
