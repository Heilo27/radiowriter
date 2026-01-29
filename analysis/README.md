# MOTOTRBO CPS 2.0 Analysis

This directory contains reverse engineering analysis of Motorola's MOTOTRBO CPS (Customer Programming Software) version 2.0.

---

## Analysis Documents

| Document | Status | Description |
|----------|--------|-------------|
| **MOTOTRBO_CPS_2.0_initial_analysis.md** | Complete | Comprehensive overview of installer structure, metadata, and initial findings |
| **technical_findings.md** | In Progress | Detailed technical analysis organized by topic (protocols, codeplug format, DLLs, etc.) |
| **NEXT_STEPS.md** | Active | Roadmap for continued analysis with phased approach |

---

## Current Phase

**Phase 0: Initial Reconnaissance** ✅ COMPLETE

We have analyzed the installer executable and extracted:
- Binary metadata and version information
- Digital signature verification
- System dependencies
- Compression format
- Build information

**Next Phase: Environment Setup**

The next step is to install CPS in a Windows VM and extract the actual application binaries for deeper analysis.

---

## Quick Reference

### Target Information
```
File: MOTOTRBO_CPS_2.0.exe
Size: 615 MB (645,078,392 bytes)
Type: PE32 executable (InstallShield)
Version: 2.122.70.0
Build Date: 2015-06-08
Signed By: Motorola Solutions, Inc.
```

### Analysis Limitations

The installer is compressed using InstallShield. To proceed with protocol and codeplug analysis, we need:
1. Windows VM with CPS installed
2. Extracted application binaries
3. USB protocol capture capability
4. Sample codeplug files

---

## Key Findings Summary

### What We Know
- ✅ Installer is authentic (verified digital signature)
- ✅ Uses standard Windows APIs for I/O
- ✅ Includes cryptographic libraries (CRYPT32.dll)
- ✅ Built with InstallShield 22.0.284
- ✅ Compressed with zlib 1.2.3

### What We Need to Discover
- ❓ Supported radio models
- ❓ USB communication protocol
- ❓ Codeplug binary format
- ❓ Protocol commands and responses
- ❓ USB Vendor/Product IDs
- ❓ Serial port parameters
- ❓ Authentication mechanism

---

## Methodology

Our reverse engineering approach follows industry best practices:

1. **Static Analysis** - Examine binaries without execution
   - String extraction
   - Import table analysis
   - Decompilation
   - Resource extraction

2. **Dynamic Analysis** - Observe runtime behavior
   - USB traffic capture
   - Process monitoring
   - Memory analysis
   - Network traffic (if any)

3. **Format Analysis** - Understand data structures
   - Codeplug file analysis
   - Binary diff comparison
   - Structure mapping
   - Checksum identification

4. **Implementation** - Build Swift equivalent
   - Protocol implementation
   - Codeplug parser
   - USB communication layer
   - GUI application

---

## Legal & Ethical Considerations

This analysis is conducted for:
- **Educational purposes** - Understanding DMR radio protocols
- **Interoperability** - Building compatible software
- **Research** - Documenting proprietary formats

We are **NOT**:
- Circumventing copy protection
- Extracting proprietary algorithms
- Redistributing Motorola software
- Violating intellectual property rights

All analysis focuses on protocol documentation and data format understanding to enable interoperable software development.

---

## Tools Used

### macOS Tools
- `file` - Identify file types
- `strings` - Extract readable strings
- `7z` - Archive extraction
- `xxd` / `hexdump` - Hex analysis

### Windows Tools (Required for Phase 2+)
- Ghidra - Free decompiler
- x64dbg - Debugger
- Wireshark + USBPcap - Protocol capture
- Sysinternals Suite - Process monitoring
- HxD - Hex editor

---

## Progress Tracking

### Milestones

- [x] Phase 0: Initial reconnaissance
- [ ] Phase 1: Environment setup
- [ ] Phase 2: Static binary analysis
- [ ] Phase 3: USB protocol capture
- [ ] Phase 4: Codeplug format analysis
- [ ] Phase 5: Swift implementation

### Estimated Timeline

- **Phase 0:** Complete (2 hours)
- **Phase 1:** 4 hours
- **Phase 2:** 16 hours
- **Phase 3:** 12 hours
- **Phase 4:** 20 hours
- **Phase 5:** 40 hours

**Total:** ~94 hours (~2-3 weeks)

---

## Contributing

This is an internal HeiloProjects research project. Analysis findings are documented for:
- Knowledge sharing within the team
- Future reference and implementation
- Protocol documentation

---

## Next Actions

See **NEXT_STEPS.md** for detailed roadmap.

**Immediate next step:**
1. Set up Windows 11 VM
2. Install MOTOTRBO CPS 2.0
3. Document installed file structure
4. Begin Phase 2 analysis

---

*Analysis conducted by Specter (Binary Analysis Agent)*
*Part of the MotorolaCPS Reverse Engineering Project*
*Last updated: 2026-01-29*
