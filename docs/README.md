# MOTOTRBO XCMP/XNL Protocol Documentation

**Research Date:** 2026-01-29
**Target Radio:** XPR 3500e
**Purpose:** Native macOS radio programming application

---

## Overview

This directory contains comprehensive documentation of the MOTOTRBO XCMP/XNL protocol, reverse-engineered from open-source implementations for the purpose of creating a native macOS radio programming application.

**Key Achievement:** Complete protocol specification ready for Swift implementation.

---

## Documentation Index

### 1. Research Summary
**File:** [`RESEARCH_SUMMARY.md`](RESEARCH_SUMMARY.md)

**What it is:** Executive summary of the research project
**Read this if:** You want a high-level overview of findings, blockers, and next steps

**Contents:**
- Executive summary
- Key findings
- Authentication mechanism
- Implementation roadmap
- Critical blockers (encryption constants)
- Legal/ethical considerations
- Recommendations

---

### 2. Protocol Specification
**File:** [`protocols/XCMP_XNL_PROTOCOL.md`](protocols/XCMP_XNL_PROTOCOL.md)

**What it is:** Complete technical specification of the XCMP/XNL protocol
**Read this if:** You need to understand how the protocol works at the packet level

**Contents:**
- XNL layer (transport/network)
  - Packet structure (14-byte header)
  - OpCodes (0x02-0x0c)
  - Address format
- Authentication handshake (6 steps)
  - Master query/broadcast
  - Auth key request/reply
  - Connection request/reply
- XCMP layer (application)
  - Packet structure
  - OpCodes for radio operations
  - DeviceInitStatusBroadcast
  - CloneRead/Write for codeplug
- Data flow diagrams
- Error codes
- Implementation checklist

**Key takeaway:** Everything you need to know about packet formats and message flow.

---

### 3. Encryption Details
**File:** [`protocols/ENCRYPTION_DETAILS.md`](protocols/ENCRYPTION_DETAILS.md)

**What it is:** Deep dive into the TEA-variant encryption used for authentication
**Read this if:** You need to implement the encryption algorithms

**Contents:**
- Three encryption modes:
  - RepeaterIPSC (for repeaters)
  - ControlStation (for subscriber radios)
  - CPS (full access, proprietary DLL)
- TEA algorithm implementation
  - C# reference code
  - Swift template
  - Helper functions
- Big-endian integer conversion
- Decision tree for choosing encryption type
- Methods for obtaining constants
  - TRBOnet.Server.exe extraction
  - Reverse engineering
  - GPU-assisted brute force
- Security considerations
- Debugging tips

**Key takeaway:** How to implement the encryption, and where to get the constants.

---

### 4. Implementation Guide
**File:** [`protocols/IMPLEMENTATION_GUIDE.md`](protocols/IMPLEMENTATION_GUIDE.md)

**What it is:** Practical Swift code for implementing the protocol on macOS
**Read this if:** You're ready to start coding

**Contents:**
- Architecture overview (4 layers)
- Complete Swift code templates:
  - `XNLPacket` (data structures)
  - `XNLAddress` (addressing)
  - `XNLClient` (connection manager)
  - `XCMPClient` (command layer)
- UDP socket implementation (Network framework)
- Authentication handshake code
- Usage examples
- Testing strategy
- Missing pieces checklist

**Key takeaway:** Copy-paste ready Swift code to get started.

---

## Quick Start

### For Developers

1. **Understand the protocol:** Read [`protocols/XCMP_XNL_PROTOCOL.md`](protocols/XCMP_XNL_PROTOCOL.md)
2. **Learn encryption:** Read [`protocols/ENCRYPTION_DETAILS.md`](protocols/ENCRYPTION_DETAILS.md)
3. **Start coding:** Use [`protocols/IMPLEMENTATION_GUIDE.md`](protocols/IMPLEMENTATION_GUIDE.md) templates
4. **Get constants:** See "Obtaining Encryption Constants" below

### For Project Managers

1. Read [`RESEARCH_SUMMARY.md`](RESEARCH_SUMMARY.md) - Executive summary section
2. Note critical blocker: Encryption constants required
3. Review roadmap and timeline estimates
4. Assess legal/licensing requirements

### For Security Researchers

1. Read [`protocols/ENCRYPTION_DETAILS.md`](protocols/ENCRYPTION_DETAILS.md) - TEA analysis
2. Review [`protocols/XCMP_XNL_PROTOCOL.md`](protocols/XCMP_XNL_PROTOCOL.md) - Authentication flow
3. Source analysis in cloned repositories:
   - `Moto.Net/` - C# reference implementation
   - `xcmp-xnl-dissector/` - Wireshark Lua dissector
   - `codeplug/` - Python file format tools

---

## Critical Requirements

### Encryption Constants (BLOCKER)

**What:** Six UInt32 constants per encryption mode (RepeaterIPSC, ControlStation)
**Why:** Required for TEA encryption during authentication handshake
**Status:** Not obtained, implementation blocked without them

**Options:**

1. **TRBOnet License** (Recommended)
   - Obtain licensed copy of TRBOnet software
   - Extract constants via reflection from `TRBOnet.Server.exe`
   - Classes: `NS.Enginee.Mototrbo.Utils.XNLRepeaterCrypter`, `NS.Enginee.Mototrbo.Utils.XNLMasterCrypter`
   - **Legal:** Yes, if properly licensed

2. **Reverse Engineering**
   - Analyze Motorola CPS binaries
   - Extract embedded constants
   - GPU-assisted brute force (computationally intensive)
   - **Legal:** Grey area, depends on jurisdiction and license agreements

3. **Limited Functionality**
   - Implement everything except authentication
   - Use for packet analysis/learning
   - No actual radio programming
   - **Legal:** Yes

### CPS Encryption (Optional)

**What:** Proprietary `XnlAuthenticationDotNet.dll`
**Why:** Required for authIndex 0x00 (full CPS access)
**Workaround:** Use authIndex 0x01 (ControlStation mode) for limited functionality

---

## Source Repositories

### Cloned Locally

- **Moto.Net**
  - Path: `/Users/home/Documents/Development/MotorolaCPS/Moto.Net/`
  - Language: C#
  - Quality: Production-grade
  - Completeness: ~80% of protocol
  - License: MIT (constants not included)

- **xcmp-xnl-dissector**
  - Path: `/Users/home/Documents/Development/MotorolaCPS/xcmp-xnl-dissector/`
  - Language: Lua (Wireshark)
  - Quality: Research-grade
  - Completeness: Major opcodes covered
  - License: Not specified

- **codeplug**
  - Path: `/Users/home/Documents/Development/MotorolaCPS/codeplug/`
  - Language: Python
  - Quality: Specific to file format
  - Completeness: File encryption only (not network protocol)
  - License: Not specified

### External References

- GitHub: [pboyd04/Moto.Net](https://github.com/pboyd04/Moto.Net)
- GitHub: [george-hopkins/xcmp-xnl-dissector](https://github.com/george-hopkins/xcmp-xnl-dissector)
- GitHub: [george-hopkins/codeplug](https://github.com/george-hopkins/codeplug)

---

## Testing Setup

### Hardware Requirements

- **Radio:** MOTOTRBO XPR 3500e (or similar)
- **Connection:** USB with CDC ECM driver
- **Network:** Radio appears at 192.168.10.1
- **Port:** UDP 4002

### Software Requirements

- **Wireshark:** For packet capture
  - Install xcmp-xnl-dissector plugins
  - Copy `*.lua` files to `~/.config/wireshark/plugins`
- **Motorola CPS:** For reference packet captures
- **Xcode:** For Swift development

### Validation Method

1. Capture CPS packets with Wireshark
2. Implement Swift version
3. Compare byte-for-byte with captures
4. Verify radio accepts packets

---

## Legal and Ethical Notes

### Intellectual Property

- MOTOTRBO is a trademark of Motorola Solutions, Inc.
- XCMP/XNL protocol may be proprietary
- This research is for **interoperability and educational purposes**
- All source projects state they are **not affiliated with Motorola**

### Recommended Use

- **Personal/Educational:** Fully supported
- **Commercial:** Obtain proper licenses from Motorola
- **Distribution:** Do not publicly share encryption constants
- **Respect:** Motorola's intellectual property rights

### Fair Use Considerations

- Reverse engineering for interoperability is protected in many jurisdictions
- DMCA Section 1201(f) (US) allows circumvention for interoperability
- EU Directive 2009/24/EC allows reverse engineering for interoperability
- **Consult legal counsel** for your specific situation

---

## Implementation Status

### Research Phase ✅ COMPLETE
- [x] Protocol specification documented
- [x] Encryption algorithms analyzed
- [x] Swift templates created
- [x] Testing strategy defined

### Development Phase ⏸️ BLOCKED
- [ ] Obtain encryption constants (BLOCKER)
- [ ] Implement Swift XNL layer
- [ ] Implement Swift XCMP layer
- [ ] Build macOS UI
- [ ] Test with real radio

### Blocker Resolution Required
**Next step:** Obtain encryption constants via one of the methods above

---

## Contact and Contributions

This documentation is part of the MotorolaCPS reverse engineering project.

**Project Location:** `/Users/home/Documents/Development/MotorolaCPS/`

For questions, see `.claude/PROJECT-CONTEXT.md` in the project root.

---

## Version History

- **2026-01-29:** Initial research and documentation completed
  - Protocol specification written
  - Encryption analysis completed
  - Swift implementation guide created
  - Source repositories analyzed

---

**Status:** Documentation complete, ready for implementation pending encryption constants.
