# Codeplug Format Documentation

This directory contains reverse-engineered documentation of Motorola radio codeplug formats.

---

## Analysis Status

### CLP (Commercial Line Portable) Family

**Status:** Partial - Architecture Understood, Offsets Need Verification

**Documents:**
- `CLP-Format-Analysis.md` - Comprehensive format analysis
- `../findings/2026-01-28-DLL-Analysis.md` - Technical DLL analysis

**Confidence Level:**
- Architecture & Patterns: ✓ **High**
- Transform Layer Requirements: ✓ **High**
- Field Naming Conventions: ✓ **High**
- Specific Byte Offsets: ⚠️ **Low** (needs hex dumps)
- File Header Structure: ⚠️ **Low** (needs sample files)

**Key Findings:**
1. CPS uses a transform layer for UI ↔ binary conversion
2. Many boolean fields use inverted storage ("Disable*" pattern)
3. Version stored as 3 bytes: `[char][major][minor]`
4. Channel data likely in structured blocks, not flat layout
5. Separate RX/TX fields for frequency, power, and PL tones

**Next Steps:**
- [ ] Obtain sample `.rdt` files for hex dump analysis
- [ ] Windows decompilation with ILSpy for full C# source
- [ ] Verify field offsets against actual codeplug data
- [ ] Document file header structure (magic bytes, CRC)
- [ ] Map channel block layout precisely

---

## Other Radio Families

### CLP2 (CLP Second Generation)
**Status:** Not Yet Analyzed
**DLLs:** `BL.Clp2.*.dll`

### CLPNova
**Status:** Not Yet Analyzed
**DLLs:** `BL.ClpNova.*.dll`

### DLRx (Digital License Radio)
**Status:** Not Yet Analyzed
**DLLs:** `BL.DLRx.*.dll`

### Business Radio Families
**Status:** Not Yet Analyzed
**DLLs:** `Motorola.Rbr.BD.*.dll`

---

## Analysis Tools

### macOS (Current Environment)
- **monodis** - .NET IL disassembler
- **strings** - Extract string constants
- **hexdump/xxd** - Binary file analysis

### Windows (Recommended for Deeper Analysis)
- **ILSpy** - Full C# decompilation
- **dnSpy** - Interactive debugging & decompilation
- **Wireshark + USBPcap** - USB protocol capture

### Cross-Platform
- **Ghidra** - NSA reverse engineering suite
- **ImHex** - Hex editor with pattern support

---

## Format Specification Template

When documenting a new codeplug format, include:

### Header Structure
```
Offset | Size | Type  | Description
-------|------|-------|-------------
0x00   | 4    | u32   | Magic bytes / signature
0x04   | 2    | u16   | Format version
...
```

### Field Layout
```
Field Name: <Descriptive Name>
Offset: 0xNNNN (decimal: NNNN)
Size: N bytes / M bits
Type: u8 / u16 / u32 / string / bool
Encoding: [Details]
Valid Range: [Min-Max or enum values]
Default: [Value]
Transform: [If UI differs from storage]
Dependencies: [Related fields]
```

### Example Data
```
Hex Dump:
00000000: 52 03 00 4D 79 52 61 64  69 6F 00 00 00 00 00 00  R..MyRadio......
00000010: 01 05 00 00 00 00 00 00  00 00 00 00 00 00 00 00  ................

Interpretation:
0x00-0x02: Version = "R03.00"
0x03-0x12: Radio Alias = "MyRadio" (null-padded)
0x13:      TX Power = 0x01 (High)
0x14:      Volume = 0x05 (level 5)
```

---

## Contributing

When adding new analysis:

1. Create a dated finding document in `../findings/`
2. Update the comprehensive format doc in this directory
3. Add sample hex dumps if available
4. Document confidence level for each finding
5. Cross-reference with Swift implementation
6. Note any discrepancies or unknowns

---

## Legal & Ethics

**Purpose:** Interoperability and education
**Approach:** Analyze publicly distributed software
**Restrictions:**
- No circumvention of copy protection
- No extraction of proprietary algorithms
- Focus on data format and protocol understanding
- Respect Motorola's intellectual property

**Compliance:** This research is conducted under fair use for interoperability purposes, following the precedent of clean-room reverse engineering methodologies.
