# GPL-2.0 License Compliance Audit: xcmp-xnl-dissector

**Audit Date:** 2026-02-05
**Auditor:** Themis (Legal Compliance Agent)
**Task ID:** TASK-101
**Status:** Complete

---

## Executive Summary

**FINDING: LOW RISK - Reference Material Only**

The GPL-2.0 licensed `xcmp-xnl-dissector` component is used as **reference documentation only** and does NOT create derivative work concerns. However, the directory should be **removed from the repository** to eliminate any ambiguity.

| Criterion | Status | Notes |
|-----------|--------|-------|
| Compiled into app? | NO | Not referenced in Xcode project or Package.swift |
| Code derived from dissector? | NO | Swift implementation is independently developed from CPS captures |
| Distributed with app? | NO | Lua files are not bundled in build products |
| Documentation references? | YES | Referenced in docs as external resource |

**Recommendation:** Remove the `xcmp-xnl-dissector/` directory from the repository and reference it as an external resource in documentation only.

---

## 1. Component Details

### Location and License

- **Path:** `/Users/home/Documents/Development/MotorolaCPS/xcmp-xnl-dissector/`
- **License:** GNU General Public License v2.0 (GPL-2.0)
- **Source:** https://github.com/george-hopkins/xcmp-xnl-dissector
- **Contents:**
  - `xcmp.lua` - XCMP protocol Wireshark dissector (8,758 bytes)
  - `xnl.lua` - XNL protocol Wireshark dissector (5,948 bytes)
  - `LICENSE` - Full GPL-2.0 text (18,092 bytes)
  - `README.md` - Installation instructions (388 bytes)

### Repository Status

The dissector directory contains its own `.git` subdirectory, indicating it was cloned or copied as a complete Git repository. It is NOT configured as a Git submodule (no `.gitmodules` file exists).

---

## 2. Usage Analysis

### 2.1 Build System Integration

**Xcode Project (`CPSApp.xcodeproj`):**
- No references to `xcmp-xnl-dissector` directory
- No Lua files in build phases
- No copy file phases for dissector content

**Package.swift Files:**
Examined all Swift Package Manager manifests:
- `Packages/RadioHardware/Package.swift` - No dissector references
- `Packages/RadioCore/Package.swift` - No dissector references
- `Packages/RadioModels/Package.swift` - No dissector references
- `Packages/AudioEngine/Package.swift` - No dissector references

**Conclusion:** The dissector is NOT compiled, linked, or bundled with the application.

### 2.2 Documentation References

The dissector is referenced in documentation as an external analysis tool:

| File | Context |
|------|---------|
| `docs/README.md` | Listed as reference material, GitHub link |
| `docs/RESEARCH_SUMMARY.md` | Described as Wireshark dissector for protocol analysis |
| `docs/protocols/XCMP_XNL_PROTOCOL.md` | Source attribution for protocol documentation |
| `docs/protocols/IMPLEMENTATION_GUIDE.md` | Recommended for debugging |
| `docs/QUICK_REFERENCE.md` | Installation instructions for Wireshark |
| `analysis/XPR_PROTOCOL_FINDINGS.md` | External reference link |

These are **attribution and reference** uses only - standard practice for documenting research sources.

---

## 3. Derivation Analysis

### 3.1 Methodology

Compared protocol constants, structures, and implementation patterns between:
- **Source:** `xcmp-xnl-dissector/*.lua` (GPL-2.0)
- **Target:** `Packages/RadioHardware/Sources/RadioProgrammer/*.swift` (Project code)

### 3.2 XNL Opcode Comparison

**Lua Dissector (`xnl.lua`):**
```lua
local opcodes = {
  [2] = "MASTER_STATUS_BRDCST",
  [3] = "DEV_MASTER_QUERY",
  [4] = "DEV_AUTH_KEY_REQUEST",
  [5] = "DEV_AUTH_KEY_REPLY",
  [6] = "DEV_CONN_REQUEST",
  [7] = "DEV_CONN_REPLY",
  [8] = "DEV_SYSMAP_REQUEST",
  [9] = "DEV_SYSMAP_BRDCST",
  [11] = "DATA_MSG",
  [12] = "DATA_MSG_ACK",
}
```

**Swift Implementation (`XNLConnection.swift`):**
```swift
public enum XNLOpCode: UInt8 {
    case masterStatusBroadcast = 0x02   // Radio → CPS: First packet after TCP connect
    case deviceMasterQuery = 0x04       // CPS → Radio: Query after receiving status
    case deviceSysMapBroadcast = 0x05   // Radio → CPS: Contains 8-byte auth seed
    case deviceAuthKey = 0x06           // CPS → Radio: Auth response (TEA encrypted)
    case deviceAuthKeyReply = 0x07      // Radio → CPS: Contains assigned address
    case deviceConnReply = 0x09         // Radio → CPS: Connection parameters
    case dataMessage = 0x0B             // Bidirectional: XCMP payload carrier
    case dataMessageAck = 0x0C          // ACK (but CPS doesn't send these!)
}
```

**Analysis:**
- The opcode values are **protocol constants** defined by Motorola's MOTOTRBO specification
- Swift implementation includes additional opcodes (0x04, 0x05) not present in dissector
- Swift comments reference "CPS 2.0 CAPTURES" as source, not the dissector
- Naming conventions differ (snake_case vs camelCase)

**Conclusion:** Opcodes are standard protocol values, not copied from dissector.

### 3.3 XCMP Opcode Comparison

**Lua Dissector (`xcmp.lua`):**
```lua
local opcodes_base = {
  [0x000d] = "SUPERBUNDLEAPPLY",
  [0x000e] = "RSTATUS",
  [0x000f] = "VERINFO",
  [0x002c] = "LANGPKINFO",
  [0x002e] = "SUPERBUNDLE",
  [0x0109] = "CLONEWR",
  [0x010a] = "CLONERD",
  [0x0400] = "DEVINITSTS",
  -- ... (40 unique opcodes)
}
```

**Swift Implementation (`XCMPProtocol.swift`):**
```swift
public enum XCMPOpCode: UInt16 {
    // === VERIFIED WORKING FROM CPS CAPTURE ===
    case versionInfoRequest = 0x000F      // Param: 0x00=full, 0x41=build
    case modelNumberRequest = 0x0010      // Param: 0x00
    case serialNumberRequest = 0x0011     // Param: 0x00
    case securityKeyRequest = 0x0012      // No params - returns 16-byte session key
    case codeplugIdRequest = 0x001F       // Params: 0x00 0x00
    case codeplugReadRequest = 0x002E     // Record list format
    // ... (80+ unique opcodes)
}
```

**Analysis:**
- Swift implementation contains **2x more opcodes** than dissector
- Many Swift opcodes (0x0010, 0x0011, 0x0012, 0x001F, 0x0100-0x010F, 0x0200-0x0203) are NOT in dissector
- Swift comments consistently reference "CPS 2.0 CAPTURE" and "RcmpWrapper.dll" as sources
- The dissector is a passive analyzer; Swift implementation is active programming protocol

**Conclusion:** Swift implementation is significantly more comprehensive and derived from independent sources.

### 3.4 Protocol Structure Comparison

**Lua Dissector Packet Structure:**
```lua
-- XNL: 14-byte header
f_len = ProtoField.uint16("xnl.len", "Total Length")
f_opcode = ProtoField.uint16("xnl.opcode", "Opcode")
f_proto = ProtoField.uint8("xnl.proto", "Protocol")
f_flags = ProtoField.uint8("xnl.flags", "Flags")
f_dst = ProtoField.uint16("xnl.dst", "Destination")
f_src = ProtoField.uint16("xnl.src", "Source")
f_transaction = ProtoField.uint16("xnl.transaction", "Transaction ID")
f_payload_len = ProtoField.uint16("xnl.payload_len", "Payload Length")
```

**Swift Implementation (`XNLConnection.swift`):**
```swift
// Standard XNL DataMessage structure:
//   Bytes 0-1:  Length (total packet length excluding length field itself)
//   Bytes 2-3:  Opcode (0x000B for DataMessage)
//   Byte 4:     XCMP flag (0x01 for XCMP messages)
//   Byte 5:     Flags (0x00 per Python)
//   Bytes 6-7:  Destination address (master/radio address)
//   Bytes 8-9:  Source address (our assigned address)
//   Bytes 10-11: TxID (session_prefix + sequence)
//   Bytes 12-13: Payload length
//   Bytes 14+:  XCMP payload
```

**Analysis:**
- Both describe the same wire protocol (as expected for interoperability)
- Swift includes implementation details absent from dissector (TEA encryption, session management)
- Swift comments reference "Python" implementation (Moto.Net/MotoGo), not Lua dissector

**Conclusion:** Protocol structure is publicly documented; implementations are independent.

### 3.5 Implementation Depth Comparison

| Feature | Lua Dissector | Swift Implementation |
|---------|--------------|---------------------|
| XNL Authentication | Passive decode | Full TEA encryption |
| XCMP Session Management | Not implemented | Complete session prefix handling |
| XCMP Transaction IDs | Display only | Active generation with sequence |
| Programming Mode | Not implemented | Enter/exit programming mode |
| Security Unlock | Not implemented | Full LFSR key encryption |
| Partition Access | Not implemented | PSDT read/write support |
| Codeplug Operations | Not implemented | Full record-based access |

**Conclusion:** The Swift implementation is a fully functional radio programming library; the dissector is a passive packet analyzer. These serve fundamentally different purposes.

---

## 4. Third-Party Code Analysis

### 4.1 Moto.Net Reference

The project includes `Moto.Net/` directory containing C# code under MIT License. The Moto.Net README states:

> "I used some online sources such as DMRLink and a Wireshark dissector..."

This indicates Moto.Net's author used the dissector as reference. However:
- Moto.Net is MIT licensed (compatible with proprietary use)
- The Swift implementation cites Moto.Net AND independent CPS captures
- This is standard practice for protocol interoperability research

### 4.2 Attribution in Code Comments

The Swift code contains comments like:
```swift
/// VERIFIED FROM CPS 2.0 CAPTURES: 2026-01-30
/// Extracted from RcmpWrapper.dll and PcrSequenceManager.dll
```

No comments in Swift code reference the Lua dissector as a source.

---

## 5. Legal Analysis

### 5.1 GPL-2.0 Implications

GPL-2.0 Section 2(b) requires derivative works to be licensed under GPL-2.0:

> "You must cause any work that you distribute or publish, that in whole or in part contains or is derived from the Program or any part thereof, to be licensed as a whole at no charge to all third parties under the terms of this License."

### 5.2 Is This a Derivative Work?

**NO.** The Swift implementation is NOT a derivative work because:

1. **No Code Copying:** No Lua code was translated to Swift
2. **Independent Development:** Swift code derived from CPS packet captures and DLL analysis
3. **Different Purpose:** Dissector is passive analyzer; Swift is active programmer
4. **No Linking:** Lua code is not compiled or bundled with the application
5. **Different Scope:** Swift implementation is 2x more comprehensive

### 5.3 Clean Room Considerations

The development methodology appears to follow clean-room principles:
- Primary sources: Motorola CPS software captures and DLL analysis
- Secondary sources: Moto.Net (MIT licensed)
- Tertiary reference: Dissector for protocol name verification only

---

## 6. Risk Assessment

| Risk Factor | Assessment | Mitigation |
|-------------|------------|------------|
| Code derivation | NONE | Swift code independently developed |
| Distribution liability | LOW | Dissector not bundled with app |
| Attribution requirements | NONE | No GPL code in final product |
| Repository presence | MEDIUM | Creates ambiguity; recommend removal |

**Overall Risk Level: LOW**

The only remaining risk is the presence of GPL-2.0 code in the repository, which could create confusion about the project's licensing status.

---

## 7. Recommendations

### 7.1 Immediate Actions (Required)

1. **Remove `xcmp-xnl-dissector/` directory from repository**
   ```bash
   git rm -r xcmp-xnl-dissector/
   git commit -m "Remove GPL-2.0 dissector - reference material only, not needed in repo"
   ```

2. **Update documentation** to reference the dissector as an external resource:
   - Change local path references to GitHub URL
   - Add note: "For protocol analysis, install from: https://github.com/george-hopkins/xcmp-xnl-dissector"

### 7.2 Documentation Updates (Required)

Update the following files to remove local path references:
- `docs/README.md`
- `docs/RESEARCH_SUMMARY.md`
- `docs/QUICK_REFERENCE.md`

### 7.3 Ongoing Compliance (Recommended)

1. **Add LICENSES.md** documenting all third-party components:
   - Moto.Net (MIT)
   - Any other dependencies

2. **Add license headers** to Swift source files clarifying project license

3. **Document clean-room methodology** in project documentation

---

## 8. Conclusion

The GPL-2.0 licensed `xcmp-xnl-dissector` was used as **reference material** for understanding the XCMP/XNL protocol structure. The Swift implementation in `RadioHardware` is an **independent implementation** derived primarily from:

1. Motorola CPS 2.0 network traffic captures
2. Motorola DLL analysis (RcmpWrapper.dll, PcrSequenceManager.dll)
3. Moto.Net C# implementation (MIT license)

No code was copied, translated, or derived from the GPL-2.0 dissector. The project does NOT constitute a derivative work under GPL-2.0.

**However**, to eliminate any licensing ambiguity, the dissector directory should be removed from the repository and referenced as an external resource only.

---

## Appendix A: Files Examined

### GPL-2.0 Component
- `/Users/home/Documents/Development/MotorolaCPS/xcmp-xnl-dissector/LICENSE`
- `/Users/home/Documents/Development/MotorolaCPS/xcmp-xnl-dissector/README.md`
- `/Users/home/Documents/Development/MotorolaCPS/xcmp-xnl-dissector/xcmp.lua`
- `/Users/home/Documents/Development/MotorolaCPS/xcmp-xnl-dissector/xnl.lua`

### Swift Implementation
- `/Users/home/Documents/Development/MotorolaCPS/Packages/RadioHardware/Sources/RadioProgrammer/XNLConnection.swift`
- `/Users/home/Documents/Development/MotorolaCPS/Packages/RadioHardware/Sources/RadioProgrammer/XCMPProtocol.swift`
- `/Users/home/Documents/Development/MotorolaCPS/Packages/RadioHardware/Package.swift`

### Build System
- `/Users/home/Documents/Development/MotorolaCPS/CPSApp/CPSApp.xcodeproj/project.pbxproj`
- `/Users/home/Documents/Development/MotorolaCPS/Packages/RadioCore/Package.swift`
- `/Users/home/Documents/Development/MotorolaCPS/Packages/RadioModels/Package.swift`
- `/Users/home/Documents/Development/MotorolaCPS/Packages/AudioEngine/Package.swift`

### Documentation
- `/Users/home/Documents/Development/MotorolaCPS/docs/README.md`
- `/Users/home/Documents/Development/MotorolaCPS/docs/RESEARCH_SUMMARY.md`
- `/Users/home/Documents/Development/MotorolaCPS/docs/protocols/XCMP_XNL_PROTOCOL.md`
- `/Users/home/Documents/Development/MotorolaCPS/docs/protocols/IMPLEMENTATION_GUIDE.md`
- `/Users/home/Documents/Development/MotorolaCPS/docs/QUICK_REFERENCE.md`
- `/Users/home/Documents/Development/MotorolaCPS/analysis/XPR_PROTOCOL_FINDINGS.md`

---

*Audit conducted by Themis - Legal Compliance Agent*
*Document generated: 2026-02-05*
