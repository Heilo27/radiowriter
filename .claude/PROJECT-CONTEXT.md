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
