# CLP Codeplug Format Analysis

**Analysis Date:** 2026-01-28
**Analyst:** Specter
**Source:** Motorola CPS .NET DLLs (analysis/extracted_app/App_Executables/bin/)
**Method:** IL disassembly using `monodis`, string analysis

---

## Executive Summary

The Motorola CLP (Commercial Line Portable) family uses a proprietary binary codeplug format for storing radio configuration. Analysis of the CPS .NET assemblies reveals:

- **Format:** Binary with structured field layout
- **Encoding:** Mixed bit-level and byte-level field packing
- **Field Naming:** Prefix-based organization (CP_*)
- **Architecture:** Transform layer for UI value mapping
- **File Extensions:** `.rdt` (radio data), `.ctb` (codeplug template)

---

## Key DLL Components

### Core Libraries

| DLL | Purpose | Key Findings |
|-----|---------|--------------|
| `BL.Clp.Constants.dll` | Field constant definitions | Contains `CP_*` field name constants |
| `BL.Clp.Trans.dll` | Value transformations | Pack/Unpack functions for UI ↔ binary conversion |
| `BL.Clp.VirtualValues.dll` | Computed/derived fields | Virtual fields calculated from raw data |
| `BL.Clp.Constraints.dll` | Field validation rules | Range checks, dependencies |
| `Motorola.CommonTool.FileHandler.dll` | File I/O | `ReadArchiveFile`/`WriteArchiveFile` methods |
| `Motorola.CommonTool.Transform.dll` | Core transformation engine | Base transform infrastructure |

---

## Field Naming Conventions

From string analysis of `BL.Clp.Constants.dll`:

```
CP_CHANNEL_RX_BAND          - Receive frequency band
CP_CHANNEL_TX_BAND          - Transmit frequency band
CP_CHANNEL_NAME             - Channel display name
CP_CHANNEL_NAME_BLOCK       - Channel name storage block
CP_CHANNEL_BLOCK            - Channel data block
CP_CHANNEL_RX_PL            - RX Private Line (CTCSS/DCS)
CP_CHANNEL_TX_PL            - TX Private Line (CTCSS/DCS)
CP_CHANNEL_RX_FREQ          - RX frequency
CP_CHANNEL_TX_FREQ          - TX frequency
CP_CHANNEL_REPEATER         - Repeater mode flag
CP_CHANNEL_RX_POWER         - RX power level
CP_CHANNEL_TX_POWER         - TX power level
CP_CHANNEL_INSCANLIST       - Include in scan list
CP_DISABLE_CHANNEL          - Channel enable/disable flag
CP_FREQ_POWERLEVEL          - Frequency-dependent power setting
CP_ADD_CHANNEL_ENABLE       - Allow adding channels
CP_DELETE_CHANNEL_ENABLE    - Allow deleting channels
CP_POWER_CONTROL_ENABLE     - Enable power control
CP_MAX_CHANNELS             - Maximum channel count
CP_NUMBER_CHANNELS          - Current channel count
CP_MAX_CALLTONES            - Maximum call tone count
CPCALLTONE                  - Call tone configuration
CP_BT_SIDE_TONE             - Bluetooth side tone
INVERTED_CUSTOM_PL_OFFSET   - Custom PL tone offset
BDPowerLevelItem            - Power level item
CHANNEL_NAME_FORMAT         - Channel name formatting
```

---

## Transform Functions

From `BL.Clp.Trans.dll` IL disassembly:

### Version Field

```csharp
UnpackTransform_Codeplug_Version(IField self)
{
    byte[] value = (byte[])self.CPValue;
    return String.Format("{0}{1:D2}.{2:D2}", 
        Convert.ToChar(value[0]),  // Letter prefix (e.g., 'R')
        value[1],                   // Major version
        value[2]);                  // Minor version
}
```

**Format:** 3 bytes = `[ASCII char][major][minor]` → "R03.00"

### Boolean Inversions

Several fields use inverted logic (UI shows opposite of storage):

- `UnpackTransform_Quiet_Mode` - Returns `!CPValue`
- `PackTransform_Quiet_Mode` - Stores `!UIValue`
- `UnpackTransform_DisableSidetone` - Returns `!CPValue`
- `UnpackTransform_DisableCodeplugReset` - Returns `!CPValue`
- `UnpackTransform_DisableBatterySave` - Returns `!CPValue`
- `UnpackTransform_DisableBTSidetone` - Returns `!CPValue`
- `UnpackTransform_DisableTpt` - Returns `!CPValue`

**Pattern:** "Disable*" fields in UI are stored inverted in binary

### Scan List Transform

```csharp
CLPUnpackScanList(IField self)
```

**Purpose:** Transforms bit-packed scan list membership into UI representation

---

## File I/O Architecture

From `Motorola.CommonTool.FileHandler.dll`:

```csharp
interface IArchiveFile
{
    void ReadArchiveFile(string FileName, byte[] pdata, byte[] appendData);
    void WriteArchiveFile(string FileName, byte[] pdata);
    XmlNode GetRadioInfo();
    void IoControl(string strCommand, string strParams, bool brw);
    void ChangeVersionNumber(byte[] pdata, string newVersion);
    string Ext { get; }
}
```

**Architecture:**
- File I/O abstracted through `IArchiveFile` interface
- `pdata` = primary codeplug data blob
- `appendData` = auxiliary/metadata
- Version stored in-band (modifiable via `ChangeVersionNumber`)
- Radio info stored in embedded XML

---

## Comparison with Swift Implementation

### Current Swift Model (RadioCore)

```swift
// From Packages/RadioCore/Sources/RadioCore/DataModel/

struct Codeplug {
    - rawData: Data                // ✓ Matches CPS approach
    - bitOffset/bitLength access   // ✓ Matches CPS bit-level packing
    - getValue/setValue methods    // ✓ Similar to IField interface
    - Constraint validation        // ✓ Matches BL.Clp.Constraints.dll
    - FieldDefinition structure    // ✓ Similar to CPS field metadata
}
```

### Field Definitions (CLP)

```swift
// From Packages/RadioModels/Sources/CLP/CLPFields.swift

radioAlias: bitOffset=0, bitLength=128 (16 bytes)
txPower: bitOffset=128, bitLength=8 (enum: 0=low, 1=high)
volumeLevel: bitOffset=136, bitLength=8 (range: 0-10)
voxEnabled: bitOffset=144, bitLength=1 (bool)
voxSensitivity: bitOffset=152, bitLength=8
toneVolume: bitOffset=160, bitLength=8
squelchLevel: bitOffset=168, bitLength=8 (enum)
totTimeout: bitOffset=176, bitLength=8
scanEnabled: bitOffset=184, bitLength=1

// Channels start at bitOffset=256
channel1Frequency: bitOffset=256, bitLength=32
// Each channel: stride=128 bits (16 bytes)
```

---

## Discrepancies & Recommendations

### 1. Field Offset Accuracy

**Issue:** Current Swift implementation uses hardcoded offsets (e.g., `bitOffset=0` for radioAlias). CPS DLLs indicate a more complex header structure.

**Evidence:**
- `CP_CHANNEL_BLOCK` suggests structured blocks, not flat offsets
- `Codeplug_Version` at unknown offset
- Potential header before channel data

**Recommendation:**
- Disassemble a sample `.rdt` file to map actual header structure
- Compare hex dumps with CPS loaded values
- Document header fields (magic bytes, version, checksum, etc.)

### 2. Transform Layer Missing

**Issue:** Swift implementation doesn't handle inverted boolean logic or format conversions.

**Evidence:**
- CPS uses `UnpackTransform_*` / `PackTransform_*` for many fields
- "Disable*" fields store inverted values
- Version string formatted from 3-byte binary

**Recommendation:**
- Add `Transform` protocol to FieldDefinition
- Implement `InvertedBoolTransform`, `VersionTransform`, etc.
- Apply during `getValue`/`setValue`

### 3. Channel Block Structure

**Issue:** Current 128-bit channel stride may not match CPS layout.

**Evidence:**
- CPS has separate `CP_CHANNEL_NAME_BLOCK` vs `CP_CHANNEL_BLOCK`
- Names may be stored in a separate region, not interleaved

**Recommendation:**
- Verify channel layout with hex dump analysis
- Check if channel names are stored contiguously vs. per-channel
- Confirm frequency encoding (CPS shows "in 100 Hz units")

### 4. Private Line (PL) Tones

**Issue:** Current implementation uses simple `uint8` for TX/RX tone codes. CPS indicates more complexity.

**Evidence:**
- `INVERTED_CUSTOM_PL_OFFSET` suggests custom tone support
- Separate RX/TX fields confirmed

**Recommendation:**
- Map tone codes to actual CTCSS/DCS frequencies
- Document "inverted custom PL" encoding
- Add enumeration for standard tone codes

### 5. Power Level Encoding

**Issue:** Current enum (0=low, 1=high) may be oversimplified.

**Evidence:**
- `CP_FREQ_POWERLEVEL` suggests frequency-dependent power
- `BDPowerLevelItem` indicates structured power data

**Recommendation:**
- Check if power varies by frequency/channel
- Document `BDPowerLevelItem` structure
- Consider power as channel-specific, not global

### 6. File Format Header

**Issue:** No documented file header structure (magic bytes, size, checksum).

**Missing:**
- File signature/magic bytes
- Version field location
- Radio info (model, serial) storage
- Checksum/CRC validation

**Recommendation:**
- Analyze `ReadArchiveFile` implementation to find header parsing
- Document `.rdt` vs `.ctb` format differences
- Add header validation to Swift implementation

---

## Next Steps

1. **Hex Dump Analysis**
   - Obtain sample `.rdt` files
   - Create annotated hex dumps with field mappings
   - Verify offsets match Swift implementation

2. **Deeper IL Analysis**
   - Decompile `ReadArchiveFile` to C# (using ILSpy on Windows)
   - Map exact file format parsing logic
   - Document header structure

3. **Transform Implementation**
   - Add transform layer to Swift `FieldDefinition`
   - Port `UnpackTransform_*` functions
   - Test with known codeplug values

4. **Channel Layout Verification**
   - Confirm 128-bit stride assumption
   - Map channel name storage location
   - Document repeater offset encoding

5. **Extended Field Discovery**
   - Analyze `BL.Clp.VirtualValues.dll` for computed fields
   - Document scan list bit packing
   - Map bluetooth settings structure

---

## Known Unknowns

- [ ] Exact file header format (magic bytes, size fields)
- [ ] Codeplug version field location
- [ ] Channel name block layout (interleaved vs. separate)
- [ ] Frequency encoding verification (confirmed 100 Hz units?)
- [ ] Repeater offset encoding
- [ ] Scan list bit-packing details
- [ ] Custom PL tone encoding
- [ ] Bluetooth settings structure
- [ ] Embedded XML location/format (radio info)
- [ ] Checksum/validation algorithm

---

## Tools Used

- `monodis` - Mono IL disassembler (Homebrew: `mono`)
- `strings` - GNU strings utility
- `file` - File type identification

## References

- `/Users/home/Documents/Development/MotorolaCPS/analysis/dll_analysis/` - Disassembly outputs
- `/Users/home/Documents/Development/MotorolaCPS/Packages/RadioCore/` - Swift implementation
- `/Users/home/Documents/Development/MotorolaCPS/Packages/RadioModels/Sources/CLP/` - CLP field definitions

---

*Analysis limited by .NET DLL format. Full format reverse engineering requires:*
*1. Windows system with ILSpy/dnSpy for full C# decompilation*
*2. Sample codeplug files for hex analysis*
*3. USB protocol capture during read/write operations*
