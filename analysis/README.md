# MOTOTRBO CPS Reverse Engineering Analysis

Analysis of Motorola Customer Programming Software DLLs to understand XCMP protocol and codeplug formats.

## Key Documents

### Protocol Analysis (Network Captures)
1. **[XNL_XCMP_Protocol_Comparison.md](XNL_XCMP_Protocol_Comparison.md)** - Comparative analysis of two CPS sessions
2. **[XNL_XCMP_Packet_Formats.md](XNL_XCMP_Packet_Formats.md)** - Byte-level packet format reference
3. **[Protocol_Flow_Diagram.md](Protocol_Flow_Diagram.md)** - Visual protocol flow and state machines

### DLL Analysis (Static Reverse Engineering)
4. **[XCMP_OPCODES.md](XCMP_OPCODES.md)** - Complete list of 58+ XCMP command opcodes
5. **[XCMP_COMMAND_DETAILS.md](XCMP_COMMAND_DETAILS.md)** - Detailed command structures and sequences

## Quick Reference

### Radio Identification
- `0x000F` - RcmpVersionInformation
- `0x000E` - RcmpReadWriteSerialNumber  
- `0x0461` - XcmpModuleInfo

### Codeplug Operations
- `0x010B` - XcmpPsdtAccess (primary read/write)
- `0xB10B` - XcmpPsdtAccessBroadcast (status updates)
- `0x010E` - XcmpComponentRead
- `0x010F` - XcmpComponentSession
- `0x0025` - RcmpReadWriteCodeplugAttribute

### Update Control
- `0x010C` - XcmpRadioUpdateControl
- `0x0446` - XcmpTransferData

## Analysis Tools Used

- **monodis** - .NET IL disassembler
- **Python scripts** - Opcode extraction from IL code
- **Manual analysis** - Understanding class structures and enums

## DLL Files Analyzed

Located in: `/Users/home/.wine_mototrbo/drive_c/MOTOTRBO/`

- `Common.Communication.RcmpWrapper.dll` (170KB) - XCMP protocol definitions ⭐
- `Common.Communication.PcrSequenceManager.dll` (506KB) - Programming sequences
- `Common.Communication.XNL.dll` (61KB) - Transport layer
- `Motorola.CommonCPS.RadioManagement.CommandHandler.dll` (1.6MB) - Command handlers

## Decompiled IL Files

Located in: `dll-decompilation/`

- `RcmpWrapper_full.il` (1.4MB)
- `PcrSequenceManager_full.il` (4.7MB)
- `XNL_full.il` (483KB)
- `CommandHandler_full.il` (16MB)

## Key Findings

### From Network Captures (2026-01-30)
1. **XNL Authentication** uses TEA encryption with 8-byte challenge/response
2. **Transaction ID Correlation** - XNL_KEY offset 0x0F becomes XCMP transaction prefix
3. **Deterministic Encryption** - Device ID (0x0012) produces identical ciphertext across sessions
4. **XCMP Commands Mapped**:
   - 0x0010: Model Number → "H02RDH9VA1AN"
   - 0x000F: Serial/Version → "211036" or "R02.21.01.1001"
   - 0x0011: DSP Firmware → "867TXM0273"
   - 0x0012: Device ID (15 bytes encrypted)
5. **Response Flag** - All XCMP responses OR 0x8000 with command code

### From DLL Analysis (2026-01-29)
6. **PSDT (Persistent Stored Data Table)** is Motorola's term for the codeplug
7. **Section IDs** are 4-character ASCII strings identifying codeplug sections
8. **Broadcast messages** use high-byte opcodes (0xB10B, 0x3440)
9. **Boot mode** (0x0200) required for low-level memory operations
10. **Component sessions** (0x010F) manage data access lifecycle

## Analysis Confidence

- **Opcodes**: HIGH - Direct extraction from DLL constants
- **Command names**: HIGH - From class names
- **Enum values**: HIGH - From IL code
- **Payload structures**: MEDIUM - Inferred from constructors
- **Section IDs**: LOW - Need protocol capture
- **Exact formats**: LOW - Need packet analysis

## Critical Blockers

### 🔴 TEA Key Extraction Required
Cannot authenticate with radio without the 16-byte TEA key.

**Options:**
1. Disassemble CPS.exe with Specter (focus on crypto functions)
2. Memory dump during CPS session
3. Test key derivation from radio identity (model + serial + magic)
4. Extract from known plaintext (challenge/response pairs)

## Next Steps

### Priority 1: Complete Authentication
1. ✅ Document XNL authentication flow (DONE)
2. ✅ Map transaction ID correlation (DONE)
3. ⚠️ **Extract TEA key** (BLOCKER)
4. Implement TEA encryption/decryption
5. Test authentication with live radio

### Priority 2: Expand Command Set
1. Capture full codeplug read/write session
2. Map memory read/write commands (0x010B PSDT)
3. Identify section IDs for codeplug sections
4. Document error response codes
5. Understand data format for each command

## Legal Notes

This analysis is for educational and interoperability purposes. No proprietary code is redistributed. Analysis focuses on protocol documentation and open-source implementation possibilities.

---

**Analysis Date**: 2026-01-29
**Analyst**: Specter (AI Binary Analyst)
**CPS Version**: MOTOTRBO CPS (Wine installation)
