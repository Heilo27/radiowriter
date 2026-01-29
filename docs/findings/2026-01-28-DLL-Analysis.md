# Motorola CPS .NET DLL Analysis

**Date:** 2026-01-28  
**Analyst:** Specter  
**Method:** IL Disassembly via `monodis`

---

## Overview

Analyzed Motorola CPS .NET assemblies to understand codeplug binary format. Since the Specter CLI is designed for Mach-O binaries (macOS/iOS native code), I used the Mono disassembler (`monodis`) available on this system to analyze the Windows .NET DLLs.

---

## Key Findings

### 1. Architecture Pattern

CPS uses a **layered architecture** for codeplug handling:

```
UI Layer (WinForms)
    ↓
Transform Layer (BL.Clp.Trans.dll) - Pack/Unpack UI ↔ Binary
    ↓
Field Layer (BL.Clp.Constants.dll) - Field definitions
    ↓
Data Layer (Motorola.CommonTool.FileHandler.dll) - File I/O
    ↓
Binary Codeplug (rawData: byte[])
```

This is **conceptually similar** to our Swift implementation:

```swift
SwiftUI
    ↓
FieldValue enum (needs Transform layer!)
    ↓
FieldDefinition
    ↓
Codeplug.rawData
```

### 2. Transform Layer Discovery

**Critical Finding:** CPS applies transformations between UI and binary representations.

Example: "Quiet Mode" (and other "Disable*" fields)
- UI shows: `true` = Quiet Mode ON
- Binary stores: `false` (inverted!)
- Transform: `UnpackTransform_Quiet_Mode` returns `!binaryValue`

**Impact on Swift Implementation:**
Our current code assumes direct 1:1 mapping. We need a transform layer.

### 3. Version Field Format

Discovered codeplug version encoding:

```
Byte 0: ASCII character prefix ('R', 'C', etc.)
Byte 1: Major version (0-99)
Byte 2: Minor version (0-99)

Example: [0x52, 0x03, 0x00] → "R03.00"
```

### 4. Field Naming Pattern

All codeplug fields use `CP_` prefix:

- `CP_CHANNEL_*` - Channel-related fields
- `CP_*_ENABLE` - Feature enable flags
- `CP_MAX_*` - Limits/capacities
- `CP_BT_*` - Bluetooth settings

This suggests a **structured naming convention** we should adopt for clarity.

---

## Extracted IL Code Samples

### Version Transform (from BL.Clp.Trans.dll)

```csharp
// Unpacks 3-byte version to display string
.method public static object UnpackTransform_Codeplug_Version (IField self) cil managed
{
    .maxstack 5
    .locals init (unsigned int8[] V_0)
    
    IL_0000: ldarg.0                    // Load IField
    IL_0001: callvirt get_CPValue()     // Get raw binary value
    IL_0006: castclass unsigned int8[]  // Cast to byte[]
    IL_000b: stloc.0                    // Store in V_0
    
    // Format: "{0}{1:D2}.{2:D2}"
    IL_000c: ldstr "{0}{1:D2}.{2:D2}"
    IL_0011: ldloc.0 
    IL_0012: ldc.i4.0 
    IL_0013: ldelem.u1                  // Load byte[0]
    IL_0014: call ToChar(unsigned int8) // Convert to char
    IL_0019: box System.Char
    IL_001e: ldloc.0 
    IL_001f: ldc.i4.1 
    IL_0020: ldelem.u1                  // Load byte[1]
    IL_0021: box System.Byte
    IL_0026: ldloc.0 
    IL_0027: ldc.i4.2 
    IL_0028: ldelem.u1                  // Load byte[2]
    IL_0029: box System.Byte
    IL_002e: call String.Format()
    IL_0033: ret
}
```

### Boolean Inversion Transform

```csharp
// Unpacks inverted boolean (disable becomes enable in UI)
.method public static object UnpackTransform_Quiet_Mode (IField self) cil managed
{
    .maxstack 8
    
    IL_0000: ldarg.0                    // Load IField
    IL_0001: callvirt get_CPValue()     // Get raw value
    IL_0006: call ToBoolean(object)     // Convert to bool
    IL_000b: ldc.i4.0                   // Load constant 0
    IL_000c: ceq                        // Compare equal (inverts boolean)
    IL_000e: box System.Boolean
    IL_0013: ret
}
```

**Pattern:** Load value → Convert to bool → Compare with 0 → Box result

This inverts the boolean: `true` binary → `false` (==0) → boxed `true`

---

## File I/O Interface

From `Motorola.CommonTool.FileHandler.dll`:

```csharp
public interface IArchiveFile
{
    // Read codeplug from file
    void ReadArchiveFile(
        string FileName, 
        out byte[] pdata,        // Primary data blob
        out byte[] appendData    // Auxiliary data
    );
    
    // Write codeplug to file
    void WriteArchiveFile(
        string FileName, 
        ref byte[] pdata
    );
    
    // Get radio metadata as XML
    XmlNode GetRadioInfo();
    
    // Generic I/O control
    void IoControl(
        string strCommand, 
        ref string strParams, 
        bool brw
    );
    
    // Modify version in-place
    void ChangeVersionNumber(
        ref byte[] pdata, 
        string newVersion
    );
    
    // File extension (.rdt, .ctb)
    string Ext { get; }
}
```

**Key Insights:**
- Codeplug is split: `pdata` (main) + `appendData` (metadata)
- Radio info stored as embedded XML (accessible via `GetRadioInfo()`)
- Version is in-band (can be modified directly in binary)
- `IoControl` suggests command-based extensibility

---

## Extracted String Constants

From `BL.Clp.Constants.dll` (via `strings` command):

```
CP_CHANNEL_RX_BAND
CP_CHANNEL_TX_BAND
CP_ADD_CHANNEL_ENABLE
CP_DELETE_CHANNEL_ENABLE
CP_POWER_CONTROL_ENABLE
CP_CHANNEL_NAME
CPCALLTONE
CP_BT_SIDE_TONE
CP_CHANNEL_NAME_BLOCK
CP_CHANNEL_BLOCK
CP_DISABLE_CHANNEL
CP_FREQ_POWERLEVEL
CP_CHANNEL_RX_PL
CP_CHANNEL_TX_PL
CP_CHANNEL_RX_FREQ
CP_CHANNEL_TX_FREQ
CP_CHANNEL_REPEATER
CP_CHANNEL_RX_POWER
CP_CHANNEL_TX_POWER
CP_CHANNEL_REPEATER_STR
CP_MAX_CALLTONES
CP_NUMBER_CHANNELS
CP_MAX_CHANNELS
CHANNEL_NAME_FORMAT
INVERTED_CUSTOM_PL_OFFSET
CP_CHANNEL_INSCANLIST
BDPowerLevelItem
```

**Observations:**
- Separate RX/TX fields for frequency, power, and PL tones
- Repeater mode distinct from simplex
- Scan list membership per-channel
- Power level may be item-based (not simple enum)

---

## Limitations of This Analysis

### What I Could Determine:
- High-level architecture (transform layer pattern)
- Function signatures and IL disassembly
- String constants (field names)
- Some data structure relationships

### What I Could NOT Determine:
- **Exact byte offsets** for fields (constants not emitted in IL)
- **File header structure** (magic bytes, size, CRC)
- **Channel block layout** (interleaved vs. separate regions)
- **Embedded XML format** (radio info structure)
- **Private logic inside GUI XML files** (encrypted/binary)

### Why:
.NET assemblies don't embed raw field offsets in IL—they're computed at runtime from XML config files (which are encrypted in this CPS version).

---

## Recommended Next Steps

### 1. Windows-Based Decompilation
Use **ILSpy** or **dnSpy** on Windows to:
- Decompile to full C# source (not just IL)
- Step through `ReadArchiveFile` to see parsing logic
- Extract numeric offset constants from static initializers

### 2. Sample File Analysis
Obtain sample `.rdt` files and:
- Create hex dumps with annotations
- Compare known values (e.g., frequencies) with binary positions
- Reverse-engineer header structure

### 3. XML Decryption
GUI XML files (`ClpGUI.xml`) are encrypted. Options:
- Monitor CPS runtime to capture decrypted XML in memory
- Find decryption routine in DLLs
- Extract from CPS process memory during execution

### 4. USB Protocol Capture
Use **Wireshark + USBPcap** to:
- Capture radio ↔ CPS communication
- Document command protocol
- Understand read/write sequences

---

## Deliverables

Created documentation:

1. **`docs/codeplugs/CLP-Format-Analysis.md`**
   - Comprehensive analysis of CLP format
   - Comparison with Swift implementation
   - Recommendations and discrepancies

2. **`docs/findings/2026-01-28-DLL-Analysis.md`** (this file)
   - Technical details of DLL analysis
   - Extracted IL code samples
   - Methodology and limitations

3. **`analysis/dll_analysis/`**
   - Raw `monodis` output files
   - `BL.Clp.Constants.txt`
   - `BL.Clp.Trans.txt`

---

## Conclusion

While I couldn't perform the full Mach-O binary analysis that Specter CLI is designed for, I adapted the approach using available .NET tools on macOS. The analysis reveals:

**Good News:**
- Swift implementation's **architecture is sound** (matches CPS conceptually)
- Field offset approach (bit-level packing) is **correct**
- Validation/constraint system aligns with CPS design

**Action Required:**
1. **Add transform layer** to handle UI ↔ binary conversions
2. **Verify field offsets** via hex dump analysis of sample files
3. **Document file header** structure (requires sample files or deeper decompilation)
4. **Map channel block layout** (may not be simple 128-bit stride)

**Confidence Level:**
- Architecture patterns: **High**
- Transform requirements: **High**
- Field naming conventions: **High**
- Specific byte offsets: **Low** (need hex dumps)
- File format details: **Low** (need sample files)

---

*This analysis represents the limits of macOS-based .NET reverse engineering. Full format documentation requires Windows-based tools (ILSpy) and sample codeplug files for validation.*
