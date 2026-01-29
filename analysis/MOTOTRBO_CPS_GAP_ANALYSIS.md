# MotoTRBO CPS 2.0 Gap Analysis

**Date:** 2026-01-29
**Purpose:** Compare official MotoTRBO CPS 2.0 with our Swift implementation

---

## Executive Summary

Analysis of the official MotoTRBO CPS 2.0 installer reveals it's a .NET application using a web-based architecture with 85+ DLLs. Our Swift implementation has solid foundations but needs verification of protocol details and expansion of radio model support.

---

## 1. Radio Families Comparison

### Official CPS Radio Support (from extracted DLLs)

| Family | Official Code | DLLs Found | Our Support |
|--------|---------------|------------|-------------|
| CLP | BL.Clp.* | Constants, Constraints, Extension, Trans, VirtualValues | ✅ Implemented |
| CLP2 | BL.Clp2.* | Constants, Constraints, Extension, Trans, VirtualValues | ✅ Implemented |
| CLP Nova | BL.ClpNova.* | Constants, Constraints, Extension, Trans, VirtualValues | ✅ Implemented |
| DLR | BL.DLRx.* | Constants, Constraints, Contact, Extension, Trans, VirtualValues | ✅ Implemented |
| DTR | BL.Dtr.* | Constants, Constraints, DataModel, Extention, Trans, VirtualValues | ✅ Implemented |
| Fiji (SL300) | BL.Fiji.* | Constants, Constraints, Extension, Trans, VirtualValues | ✅ Implemented |
| NewFiji | BL.NewFiji.* | Constants, Constraints, Extension, Trans, VirtualValues | ✅ Implemented |
| Nome (RM) | BL.Nome.* | Constants, Constraints, Extension, Trans, VirtualValues | ✅ Implemented |
| Renoir (RMU) | BL.Renoir.* | Constants, Constraints, DataModel, Extension, Trans, ValueCvt, VirtualValues | ✅ Implemented |
| Solo (RDU) | BL.Solo.* | Constants, Constraints, Extension, Trans, VirtualValues | ✅ Implemented |
| Sunb (CLS) | BL.Sunb.* | Constants, Constraints, Extension, Trans, VirtualValues | ✅ Implemented |
| Vanu (VL/RDU4100) | BL.Vanu.* | Constants, Constraints, Contact, Extension, Trans, ValueCvt, VirtualValues | ✅ Implemented |

### Missing in Our Implementation

~~1. **CLP Nova** - Newer CLP variant~~ ✅ Added 2026-01-29
~~2. **NewFiji** - Updated SL series~~ ✅ Added 2026-01-29

*All major radio families are now implemented.*

### Additional Models Needed

From `.wcp` template files found:
- CLU10100, CLU10103, CLU10400, CLU10403, CLU10600, CLU10603 (CLP variants)
- DLR1020BHLA, DLR1060BHLA, DLR110NBHLA (DLR variants)
- NMD20810, NMR20210, NUD20800, NUR20200/20203/41000/41003 (Nome variants)
- RMM2050, RMU2040/2043/2080, RMV2080 (Renoir variants)
- RU4100/4103/4160/4163, RV5100 (Vanu variants)

---

## 2. Protocol Analysis

### USB Identifiers

| Type | VID | PID | Description |
|------|-----|-----|-------------|
| FTDI | 0x0403 | 0x6001 | USB Serial Converter (programming cable) |
| FTDI | 0x0403 | 0x6010 | Dual Port USB Serial |
| FTDI | 0x0403 | 0x6011 | Quad Port USB Serial |
| Motorola | 0x0CAD | 0x1020/1021/1022 | Direct USB radios (CDC ECM) |

**Our Implementation:** ✅ Correct VID/PIDs defined in `USBDeviceInfo`

### Serial Communication

Based on official CPS analysis:

| Parameter | Official Value | Our Value | Status |
|-----------|----------------|-----------|--------|
| Block Size | Unknown (likely 64) | 64 bytes | ⚠️ Needs verification |
| Enter Programming | Unknown | 0x02 (STX) | ⚠️ Needs verification |
| Exit Programming | Unknown | 0x45 ('E') | ⚠️ Needs verification |
| Read Command | Unknown | 0x52 ('R') | ⚠️ Needs verification |
| Write Command | Unknown | 0x57 ('W') | ⚠️ Needs verification |
| ACK | Unknown | 0x06 | ⚠️ Needs verification |
| Checksum | `CalculateChecksum` | Sum of bytes | ⚠️ Needs verification |

**Note:** The official CPS uses a web-based architecture (`CMT.Web.dll`) which may mean it communicates via HTTP to a local service rather than direct serial.

### Web Service Architecture

The official CPS appears to use:
- `RMCPSService` - Local service name
- `RMCPS.exe`, `RMCPSAgent.exe` - Main processes
- HTTP-based commands: `WebCmdReadCP`, `WebCmdImportVoice`
- XML opcodes: `XmlTextOpCodeReadCP`, `XmlTextOpCodeWriteRadioData`

**Implication:** Our direct serial approach may work for simpler radios but MOTOTRBO radios might require the service layer.

---

## 3. Codeplug Structure Analysis

### Official CPS Field Paths

From DLRx.Constants.dll:
```
/root/DY/Section1/pin
/root/DY/Section1/numOfChannels
/root/DY/Section1/vpUserModeEn
/root/DY/Section1/powerUpToneMode
/root/DY/Section1/ergoBtnMap4
/root/DY/Section2/pinLock
/root/DY/Section2/directContactId
/root/DY/Channels/Channel
/root/DY/Channels/addChannelEn
```

### Our Implementation

```swift
// XPRFields.swift - bit offsets
radioId: bitOffset 0, bitLength 32
radioAlias: bitOffset 32, bitLength 256
numberOfChannels: bitOffset 288, bitLength 8
channelBaseOffset: 2048 bits
channelStride: 512 bits per channel
```

### Comparison

| Aspect | Official CPS | Our Implementation |
|--------|--------------|-------------------|
| Format | XPath-like paths | Bit offsets |
| Structure | Hierarchical XML/binary | Flat with calculated offsets |
| String Encoding | Unknown | UTF-16 (configurable) |
| Frequency Units | Unknown | 100 Hz |

**Action Needed:** Extract actual binary offsets from `.ser` or `.wcp` files to verify our offsets.

---

## 4. Data Types & Constraints

### From Official CPS (DLRx)

```
MAX_PROG_MENU = 8
MAX_USER_MENU = 8
MAX_NUM_FAV_CONT_LIST = 10
MAX_NUM_GROUPS_IN_ONE_SCANLIST = 10
MAX_RADIONAME_LENGTH = 18
CRITICALCHANNUM = 1

Contact Types:
- CONTACT_UNUSED = 0xFF
- CONTACT_PRIVATE_TYPE = 0x01
- CONTACT_PUBLIC_GROUP_TYPE = 0x02
- CONTACT_PRIVATE_GROUP_TYPE = 0x03
- CONTACT_DLRX_PUB_GRP_TYPE = 0x04

Modes:
- MODE_PIN = 0
- MODE_GROUP = 1
- MODE_PRIVATE = 2
- MODE_PUBLIC = 3
```

### Our XPR Implementation

```swift
// Defined in XPRFields.swift
radioId: range 1-16776415
radioAlias: maxLength 16
numberOfChannels: range 1-255
volumeLevel: range 0-16
colorCode: range 0-15
```

**Gap:** We need to add contact type constants and verify mode values.

---

## 5. Transform Functions

### Official CPS Transforms (from BL.Clp.Trans.dll)

```csharp
// Codeplug version: byte[0] as char + byte[1:2] as decimal
UnpackTransform_Codeplug_Version -> "{0}{1:D2}.{2:D2}"

// Boolean inversions
UnpackTransform_Quiet_Mode -> !value
UnpackTransform_DisableSidetone -> !value
UnpackTransform_DisableBatterySave -> !value
UnpackTransform_DisableCodeplugReset -> !value

// Scan list packing
CLPPackScanList -> IScanListField.Value as string
```

### Our Implementation

```swift
// ValueTransform.swift
public enum ValueTransform: Sendable {
    case none
    case invert
    case scale(multiplier: Double)
    case offset(value: Int)
}
```

**Gap:** We have basic transforms but may need more complex version parsing.

---

## 6. Encryption

### Official CPS

- Uses `CRYPT32.dll` (Windows Crypto API)
- Configuration files (config.xml, GUI.xml) appear encrypted
- `.ser` files (Java serialized) may contain encrypted data

### Our Implementation

- No encryption currently implemented
- Should consider if radios require encrypted communication

---

## 7. Recommended Actions

### High Priority

1. **Verify Protocol Commands**
   - Capture USB traffic from Windows VM running CPS
   - Compare with our 0x02/0x52/0x57/0x45 protocol

2. **Extract Binary Offsets**
   - Parse `.wcp` template files for actual field layouts
   - Compare with our bitOffset values

3. ~~**Add Missing Radio Families**~~ ✅ Done
   - ~~Implement CLP Nova (BL.ClpNova.*)~~ ✅ Added: CLP1010e, CLP1013e, CLP1040e, CLP1043e, CLP1060e, CLP1063e, CLP1080e
   - ~~Implement NewFiji (BL.NewFiji.*)~~ ✅ Added: CLS1410e, CLS1413e, VLR150e

### Medium Priority

4. **Implement Contact Types**
   - Add CONTACT_UNUSED (0xFF)
   - Add CONTACT_PRIVATE/PUBLIC/GROUP types

5. **Add Transform Functions**
   - Version parsing: `{major}{minor:02}.{patch:02}`
   - Boolean inversions for "Disable*" fields

6. **Verify String Encoding**
   - Check if UTF-16 LE is correct for all fields

### Low Priority

7. **Consider Web Service Layer**
   - For MotoTRBO radios that may require service communication

8. **Add Model Variants**
   - Expand from base models to include BHLA, BBL, etc. variants

---

## 8. Files for Further Analysis

### Priority Files to Decompile

1. `Motorola.CommonTool.CPService.dll` - Service layer
2. `Motorola.Rbr.BD.Cp.dll` - Codeplug handling
3. `Motorola.Rbr.BD.Transform.dll` - Data transforms
4. `CMT.Web.dll` - Web communication layer

### Template Files to Parse

1. `.wcp` files - Wildcard codeplug templates
2. `.ser` files - Java serialized codeplug definitions (may need decryption)

### Tools Needed

- ILSpy or dnSpy for .NET decompilation
- Java deserializer for `.ser` files
- Hex editor for binary template analysis

---

## 9. Current Implementation Status

| Component | Status | Completeness |
|-----------|--------|--------------|
| Radio Detection (USB) | ✅ Working | 90% |
| Radio Detection (Network) | ✅ Working | 85% |
| RadioProgrammer Protocol | ⚠️ Needs verification | 60% |
| XPR Field Definitions | ⚠️ Needs verification | 70% |
| CLP/CLP2 Fields | ✅ Implemented | 80% |
| DLRx Fields | ✅ Implemented | 75% |
| Binary Packing | ✅ Implemented | 85% |
| Binary Unpacking | ✅ Implemented | 85% |
| Codeplug Serialization | ✅ Implemented | 80% |

**Overall Estimate:** 75% complete for basic functionality

---

## 10. Conclusion

Our Swift implementation has a solid architecture that mirrors the official CPS structure. The main gaps are:

1. **Protocol verification** - Need to confirm our command bytes match
2. **Field offset verification** - Need to validate against real codeplugs
3. ~~**Missing radio models** - CLP Nova, NewFiji not implemented~~ ✅ Added 2026-01-29
4. **Transform functions** - Need version parsing and boolean inversions

**Update 2026-01-29:** CLP Nova (7 models) and NewFiji (3 models) families have been implemented, bringing all major radio families identified in the official CPS to our Swift implementation.

With USB traffic capture and template file parsing, we can close the remaining gaps and achieve full compatibility with MotoTRBO radios.

---

*Generated by Specter binary analysis and manual comparison*
*MotorolaCPS Reverse Engineering Project*
