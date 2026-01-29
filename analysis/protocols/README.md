# TETRA Protocol Analysis

Analysis of Motorola TETRA radio programming protocols extracted from Customer Programming Software (CPS) DLLs.

---

## Documents

| Document | Description | Confidence |
|----------|-------------|------------|
| [TETRA-Protocol-Analysis.md](./TETRA-Protocol-Analysis.md) | Complete protocol specification: opcodes, commands, sequences | High |
| [TETRA-Security-Analysis.md](./TETRA-Security-Analysis.md) | Encryption, authentication, key management | Medium |

---

## Quick Reference

### Connection Sequence
```
1. Terminal ID Request (0x06) → Terminal ID Confirm (0x07)
2. Version Report Request (0x01) → Confirm (0x02) → Reply (0x04)
3. Reset Request (0x03, mode=0x02) → Status Indication (0x00)
```

### Read Codeplug
```
Request:  0xF511 [addr:4] [len:2]
Response: 0xFF80 [data] [checksum:2]
```

### Write Codeplug
```
Request:  0xFF17 [addr:4] [len:2] [data] [checksum:2]
Response: 0xF484 (success) or 0xF485 (failure)
```

---

## Protocol Layers

1. **AT Protocol** - Serial-style AT commands (CR-terminated)
2. **RP Protocol** - Radio Programming high-level (8-bit opcodes)
3. **SBEP Protocol** - Subscriber Boot Execution (ACK/NACK)
4. **Data Protocol** - Memory read/write (16-bit opcodes)

---

## Key Findings

### Architecture
- Four-layer protocol stack (vs. two for MOTOTRBO)
- Dedicated boot protocol (SBEP)
- Extended opcodes for larger transfers (EX_ variants)
- FDT (Flash Data Table) for structured memory access

### Security
- Dual-key cryptography (encryption + authentication)
- Password validation system
- Encrypted firmware downloads
- Key storage in FDT KEYS section

### Compression
- LZRW3, FastLZ, LZRW3A support
- Integrated with encryption (CompressMixFile)
- Used for firmware and codeplug transfers

### Radio Models
- `CommConfigManager` provides model database
- `TetraRadioModelInfo` contains model metadata
- Properties: BandType, ProductLine, FlashPackSupport
- Platform detection: Gemstone, Milan2, etc.

---

## FDT Magic Numbers

| Magic | ASCII | Purpose |
|-------|-------|---------|
| `0x46445452` | FDTR | FDT Record |
| `0x43504C47` | CPLG | Codeplug Data |
| `0x4B455953` | KEYS | Encryption Keys |
| `0x4C4F4744` | LOGD | Log Data |
| `0x52454C49` | RELI | Release Info |
| `0x4653504B` | FSPK | Flash Pack |
| `0x464D5752` | FMWR | Firmware |

---

## Source Files Analyzed

```
Common.Communication.TetraSequenceManager.dll  (463 KB)
Common.Communication.TetraMessage.dll          (226 KB)
Common.Communication.TetraSecurity.dll         ( 97 KB)
Common.Communication.TetraUtility.dll          (496 KB)
```

**Decompilation:** monodis (Mono IL disassembler)
**Obfuscation:** Dotfuscator 4.39.0.8792

---

## Next Steps

### Protocol Validation
- [ ] Capture live USB traffic during programming
- [ ] Verify opcode interpretations against real data
- [ ] Document exact message framing (headers, lengths, checksums)
- [ ] Test compression algorithm implementations

### Security Analysis
- [ ] Identify specific encryption algorithm (likely AES)
- [ ] Analyze key derivation from passwords
- [ ] Document authentication flow
- [ ] Test HMAC/CMAC implementation

### Memory Mapping
- [ ] Extract MemMapRecord definitions for radio models
- [ ] Document FDT record structures
- [ ] Map codeplug parameter layouts
- [ ] Identify trunking configuration fields

### Model Database
- [ ] Extract full radio model list from XML config
- [ ] Document model-specific memory maps
- [ ] Identify platform variants (Gemstone, Milan2, etc.)
- [ ] Map hardware IDs to model numbers

---

## Tools & Techniques

### Decompilation
```bash
# Extract IL from .NET DLL
monodis --output=output.il input.dll

# Search for patterns
grep -E "opcode|command" output.il
```

### Analysis
```bash
# Find class definitions
grep "\.class" output.il

# Extract constants
grep "\.field.*literal" output.il

# Find method signatures
grep "\.method.*public" output.il
```

### Traffic Capture
```bash
# USB packet capture (future work)
# Use Wireshark or USBPcap on Windows
# Filter for vendor ID/product ID of radio
```

---

## Legal & Ethical Notice

This analysis is conducted for:
- **Educational purposes** - Understanding radio protocols
- **Interoperability** - Building compatible software
- **Security research** - Identifying vulnerabilities

This analysis does **NOT**:
- Extract proprietary encryption keys
- Circumvent copy protection
- Enable unauthorized radio access
- Violate DMCA anti-circumvention provisions

All findings are based on:
- Publicly distributed software binaries
- Standard reverse engineering techniques
- Observable protocol behavior
- Documented cryptographic standards

---

## References

### TETRA Standards
- ETSI EN 300 392 (TETRA Voice + Data)
- ETSI TS 100 392-2 (Air Interface)
- ETSI EN 300 396 (Direct Mode Operation)

### Cryptography
- NIST FIPS 197 (AES)
- RFC 2104 (HMAC)
- RFC 5869 (HKDF)

### Tools
- [Mono Project](https://www.mono-project.com/) - monodis IL disassembler
- [dnSpy](https://github.com/dnSpy/dnSpy) - .NET debugger/decompiler
- [ILSpy](https://github.com/icsharpcode/ILSpy) - .NET decompiler

---

**Analyst:** Specter  
**Date:** 2026-01-29  
**Project:** Motorola CPS Reverse Engineering  
**Status:** Initial protocol analysis complete

