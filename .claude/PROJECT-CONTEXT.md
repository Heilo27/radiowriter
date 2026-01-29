# PROJECT-CONTEXT.md — Motorola CPS

## Project Identity

- **Name:** Motorola CPS Reverse Engineering
- **Type:** Reverse Engineering / Protocol Analysis
- **Status:** Research Phase
- **Primary Agent:** Specter (binary analysis)

---

## What Is Motorola CPS?

Motorola CPS (Customer Programming Software) is proprietary Windows software used to program Motorola two-way radios. It allows users to:

- Configure radio frequencies and channels
- Set power levels, tones, and signaling
- Program features like scan lists, emergency settings
- Read/write radio configuration (codeplugs) via USB

### Target Radio Families

Document which radio families are being analyzed:

- [ ] CP200 series
- [ ] XPR series (MOTOTRBO)
- [ ] APX series
- [ ] Other: _________________

---

## Research Goals

1. **Codeplug Format** — Understand the binary format of .ctb/.rdt files
2. **USB Protocol** — Document the USB communication protocol
3. **Data Model** — Map radio parameters to binary offsets
4. **Interoperability** — Enable cross-platform radio programming

---

## Known Information

### File Extensions

| Extension | Purpose | Notes |
|-----------|---------|-------|
| `.ctb` | Codeplug template | Template/default config |
| `.rdt` | Radio data | Actual radio configuration |
| `.mdf` | Model definition | Radio model parameters |
| `.key` | License key | Software activation |

### Tools in Use

- **Specter** — macOS binary decompiler (primary)
- **Ghidra** — NSA reverse engineering tool (supplementary)
- **Wireshark** — USB capture and protocol analysis
- **xxd/hexdump** — Binary inspection

---

## Architecture Decisions

### ADR-001: Documentation Format

All protocol findings documented in structured markdown with:
- Byte offset tables
- Bit-field diagrams
- Example hex dumps
- Cross-references to official docs

### ADR-002: Tool Development

Any parsing/programming tools built in:
- **Swift** for macOS-native tools
- **Python** for quick prototyping and analysis scripts

---

## Patterns

### Binary Documentation Pattern

```markdown
## [Structure Name]

**Offset:** 0xNNNN
**Size:** N bytes

| Offset | Size | Type | Description |
|--------|------|------|-------------|
| 0x00   | 2    | u16  | Field name  |
| 0x02   | 1    | u8   | Field name  |

### Notes
- Byte order: Little-endian
- [Additional context]
```

### Protocol Documentation Pattern

```markdown
## [Command Name]

**Direction:** Host → Radio / Radio → Host
**Command ID:** 0xNN

### Request
| Byte | Value | Description |
|------|-------|-------------|
| 0    | 0xNN  | Command ID  |

### Response
| Byte | Value | Description |
|------|-------|-------------|
| 0    | 0xNN  | Status      |
```

---

## File Organization

```
analysis/          → Raw Specter/Ghidra output
docs/protocols/    → Cleaned protocol documentation
docs/codeplugs/    → Codeplug format documentation
docs/findings/     → Timestamped research notes
tools/             → Custom analysis/parsing tools
references/        → Official docs, datasheets, etc.
```

---

## Session Notes

_Add notes about current research focus, open questions, and next steps here._

### Open Questions

- What encryption (if any) is used for codeplug files?
- Is the USB protocol documented anywhere publicly?
- Are there differences between CPS versions for different radio families?

### Next Steps

1. Locate CPS binaries for analysis
2. Capture USB traffic during a programming session
3. Begin codeplug format documentation

---

## Session Notes (2026-01-28)

### Analysis Completed: CLP Codeplug Format

**Analyst:** Specter
**Method:** .NET IL disassembly using `monodis`

**Key Discoveries:**

1. **Transform Layer Architecture**
   - CPS uses Pack/Unpack functions to convert between UI and binary
   - Many boolean fields stored inverted ("Disable*" pattern)
   - Version field: 3 bytes = [ASCII char][major][minor] → "R03.00"

2. **Field Naming Convention**
   - All codeplug fields use `CP_` prefix
   - `CP_CHANNEL_*` for channel data
   - `CP_*_ENABLE` for feature flags
   - `CP_MAX_*` for limits

3. **File I/O Structure**
   - Codeplug split into `pdata` (main) + `appendData` (metadata)
   - Radio info stored as embedded XML
   - Version modifiable in-place

4. **Swift Implementation Assessment**
   - Architecture is sound ✓
   - Bit-level packing approach correct ✓
   - Missing: Transform layer (high priority)
   - Uncertain: Exact field offsets (need verification)
   - Unknown: File header structure

**Documentation Created:**
- `docs/codeplugs/CLP-Format-Analysis.md` - Comprehensive format doc
- `docs/codeplugs/README.md` - Index and templates
- `docs/findings/2026-01-28-DLL-Analysis.md` - Technical details
- `analysis/dll_analysis/` - Raw IL disassembly outputs

**Confidence Levels:**
- Architecture patterns: **High**
- Transform requirements: **High**
- Field naming: **High**
- Byte offsets: **Low** (needs hex dumps)
- File format: **Low** (needs sample files)

### Open Questions

1. What is the exact file header structure (magic bytes, size, CRC)?
2. Are channel names stored interleaved or in a separate block?
3. How is frequency encoded (confirmed 100 Hz units)?
4. What is the "inverted custom PL" encoding?
5. How is power level structured (simple enum or frequency-dependent)?
6. What is the scan list bit-packing format?

### Next Steps

1. **Immediate (macOS):**
   - [ ] Locate or create sample `.rdt` files
   - [ ] Hex dump analysis to verify field offsets
   - [ ] Compare known values with binary positions

2. **Windows-based (when available):**
   - [ ] Decompile with ILSpy for full C# source
   - [ ] Step through `ReadArchiveFile` logic
   - [ ] Extract encrypted GUI XML configuration

3. **Swift Implementation:**
   - [ ] Add `Transform` protocol to `FieldDefinition`
   - [ ] Implement `InvertedBoolTransform`
   - [ ] Implement `VersionTransform` (3-byte format)
   - [ ] Verify and correct field offsets
   - [ ] Add file header parsing

4. **Protocol Analysis (future):**
   - [ ] USB capture with Wireshark
   - [ ] Document read/write command protocol
   - [ ] Map radio ↔ CPS communication

### Limitations Encountered

**Tool Mismatch:**
- Specter CLI designed for Mach-O binaries (macOS/iOS native)
- Motorola CPS is .NET (Windows PE/COFF format)
- Adapted using `monodis` (Mono IL disassembler)

**Cannot Determine from IL:**
- Exact numeric offsets (computed at runtime from XML)
- File header structure (parsed in binary I/O)
- Channel block layout (defined in encrypted XML)
- Embedded XML format (runtime decryption)

**Requires:**
- Windows system with ILSpy/dnSpy for full C# decompilation
- Sample codeplug files for hex analysis
- USB protocol capture for communication mapping

