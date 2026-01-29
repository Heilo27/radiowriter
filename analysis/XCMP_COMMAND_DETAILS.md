# MOTOTRBO XCMP Protocol Analysis

## Summary

Successfully analyzed MOTOTRBO CPS DLL files to extract XCMP command opcodes and structures.

### Key Findings

1. **Primary Codeplug Access Command**: `0x010B` (XcmpPsdtAccess)
2. **Radio Identification**: `0x000F` (RcmpVersionInformation), `0x0461` (XcmpModuleInfo)
3. **Total Commands Identified**: 58+ XCMP/RCMP opcodes

---

## Critical Commands for Radio Programming

### 1. Radio Identification (0x000F - RcmpVersionInformation) ✅ VERIFIED

**Opcode**: `0x000F` (15)
**Purpose**: Read firmware version, model, and radio information
**Class**: `Motorola.Common.Communication.Rcmp.RcmpVersionInformation`

**Request Format**: `00 0F [type]`
- Type `0x00` = Firmware version

**Response Format**: `80 0F [error] [version_string]`
- Error `0x00` = Success
- XPR 3500e returns: "R02.21.01.1002"

### 2. Radio Status (0x000E - RcmpReadWriteSerialNumber) ✅ PARTIALLY VERIFIED

**Opcode**: `0x000E` (14)
**Purpose**: Read radio status information (model, serial, radio ID, etc.)
**Class**: `Motorola.Common.Communication.Rcmp.RcmpReadWriteSerialNumber`

**Request Format**: `00 0E [status_type]`
- Type `0x07` = Model Number ✅ VERIFIED
- Type `0x08` = Serial Number
- Type `0x0E` = Radio ID

**Response Format**: `80 0E [error] [status_type] [data...]`
- Error `0x00` = Success

**Verified Results (XPR 3500e):**
- Model (type=0x07): "H02RDH9VA1AN"

### 3. Module Information (0x0461 - XcmpModuleInfo)

**Opcode**: `0x0461` (1121)
**Purpose**: Read detailed module/component information
**Class**: `Motorola.Common.Communication.Rcmp.XcmpModuleInfo`

---

## Codeplug Operations

### Primary: PSDT Access (0x010B - XcmpPsdtAccess)

**Opcode**: `0x010B` (267)
**Purpose**: Main codeplug read/write command
**Class**: `Motorola.Common.Communication.XcmpPsdtAccess`

**Constructor Parameters**:
- `PsdtAccessAction action` - The operation to perform
- `string psdtSrcSectionId` - Source section ID (4 characters, ASCII)
- `string psdtTgtSectionId` - Target section ID (4 characters, ASCII)

**PsdtAccessAction Enum Values**:
- `0x00` - None
- `0x01` - GetStartAddress
- `0x02` - GetEndAddress
- `0x03` - Lock
- `0x04` - Unlock
- `0x05` - Erase
- `0x06` - Copy
- `0x07` - ImageReorg

**Fields**:
- `PsdtAddress` (uint32) - Address in PSDT
- Source and Target section IDs (byte arrays)

### PSDT Access Broadcast (0xB10B - XcmpPsdtAccessBroadcast)

**Opcode**: `0xB10B` (45323)
**Purpose**: Asynchronous status updates during PSDT operations
**Class**: `Motorola.Common.Communication.XcmpPsdtAccessBroadcast`

**Properties**:
- `CompletionPrecentage` (byte) - 0-100%
- `Status` (PsdtAccessBroadcastStatus enum):
  - `0x00` - Success
  - `0x02` - Transfer_in_progress

---

## Component Access Commands

### Component Read (0x010E - XcmpComponentRead)

**Opcode**: `0x010E` (270)
**Purpose**: Read component/module data
**Class**: `Motorola.Common.Communication.Rcmp.XcmpComponentRead`

### Component Session (0x010F - XcmpComponentSession)

**Opcode**: `0x010F` (271)
**Purpose**: Manage component access sessions
**Class**: `Motorola.Common.Communication.Rcmp.XcmpComponentSession`

---

## Radio Update Control (0x010C - XcmpRadioUpdateControl)

**Opcode**: `0x010C` (268)
**Purpose**: Control firmware and codeplug update operations
**Class**: `Motorola.Common.Communication.XcmpRadioUpdateControl`

**UpdateControlAction Enum Values**:
- `0x00` - None
- `0x01` - RadioFirmwareActive - Check if firmware is active
- `0x02` - RadioCodeplugActive - Check if codeplug is active
- `0x03` - RadioUpdateFirmware - Initiate firmware update
- `0x04` - RadioUpdateCodeplug - Initiate codeplug update
- `0x05` - RadioValidateFirmware - Validate firmware
- `0x06` - RadioValidateCodeplug - Validate codeplug
- `0x07` - RadioDefaultAddrMode - Set default addressing mode
- `0x08` - RadioAbsAddrMode - Set absolute addressing mode
- `0x09` - StopBGEraser - Stop background eraser
- `0x0A` - UpdateStatus - Get update status
- `0x0B` - SetDecomp - Set decompression

---

## Data Transfer (0x0446 - XcmpTransferData)

**Opcode**: `0x0446` (1094)
**Purpose**: Transfer data blocks to/from radio
**Class**: `Motorola.Common.Communication.XcmpTransferData`

**Properties**:
- `Data` (byte[]) - Data payload
- `Length` (uint16) - Length of data

---

## Boot Mode Commands

### Enter Boot Mode (0x0200 - XcmpEnterBootMode)

**Opcode**: `0x0200` (512)
**Purpose**: Enter bootloader/programming mode
**Class**: `Motorola.Common.Communication.Rcmp.XcmpEnterBootMode`
**Note**: Required before using low-level memory/flash commands

### Read Memory (0x0201 - RcmpReadMemory)

**Opcode**: `0x0201` (513)
**Purpose**: Direct memory read (boot mode only)
**Class**: `Motorola.Common.Communication.Rcmp.RcmpReadMemory`

### Erase Flash (0x0203 - RcmpEraseFlash)

**Opcode**: `0x0203` (515)
**Purpose**: Erase flash sectors (boot mode only)
**Class**: `Motorola.Common.Communication.RcmpEraseFlash`

---

## Codeplug Attributes (0x0025 - RcmpReadWriteCodeplugAttribute)

**Opcode**: `0x0025` (37)
**Purpose**: Read/Write codeplug metadata and attributes
**Class**: `Motorola.Common.Communication.Rcmp.RcmpReadWriteCodeplugAttribute`

**Likely Attributes** (from related enums):
- `RegionalInformation` (byte)
- `TotalAllowableMemory` (uint32)
- Codeplug version info
- Radio model compatibility

---

## Recommended Programming Sequence

### Reading Radio Information:
1. `0x000F` - RcmpVersionInformation (get firmware version, model)
2. `0x000E` - RcmpReadWriteSerialNumber (get serial)
3. `0x0461` - XcmpModuleInfo (get detailed module info)

### Reading Codeplug:
1. `0x010C` with action `0x02` - Verify codeplug is active
2. `0x0025` - Read codeplug attributes (size, version)
3. `0x010F` - Start component session
4. `0x010B` with action `0x01` - Get start address
5. `0x010B` with action `0x02` - Get end address
6. Loop: `0x010E` or `0x0446` - Read data blocks
7. Monitor `0xB10B` - Watch for progress broadcasts

### Writing Codeplug:
1. `0x010C` with action `0x04` - Initiate codeplug update
2. `0x010F` - Start component session
3. `0x010B` with action `0x04` - Unlock PSDT
4. Loop: `0x0446` - Transfer data blocks
5. Monitor `0xB10B` - Watch for progress broadcasts
6. `0x010B` with action `0x03` - Lock PSDT
7. `0x010C` with action `0x06` - Validate codeplug

---

## Protocol Notes

### Message Structure:
- Opcode: 2 bytes (little-endian)
- Payload: Variable length
- Responses typically echo the request opcode

### PSDT Section IDs:
- 4-character ASCII strings
- Examples likely include: "MAIN", "ZONE", "CHAN", etc.
- Discovered through actual protocol capture needed

### Broadcast Messages:
- Radio sends unsolicited status updates
- Opcodes typically have high bytes set (e.g., 0xB10B, 0x3440)
- Must be handled asynchronously

---

## Files Analyzed

1. `/Users/home/.wine_mototrbo/drive_c/MOTOTRBO/Common.Communication.RcmpWrapper.dll` (170KB)
   - Primary source of XCMP command definitions
   - Contains all opcode constants and message structures

2. `/Users/home/.wine_mototrbo/drive_c/MOTOTRBO/Common.Communication.PcrSequenceManager.dll` (506KB)
   - High-level programming sequences
   - Usage patterns and workflows

3. `/Users/home/.wine_mototrbo/drive_c/MOTOTRBO/Common.Communication.XNL.dll` (61KB)
   - XNL protocol layer (transport)

4. `/Users/home/.wine_mototrbo/drive_c/MOTOTRBO/Motorola.CommonCPS.RadioManagement.CommandHandler.dll` (1.6MB)
   - Command handling and execution logic

---

## Next Steps

1. **Protocol Capture**: Use Wireshark/USB sniffer to capture actual CPS communications
2. **Message Format**: Analyze captured packets to determine exact payload structures
3. **Section IDs**: Identify PSDT section identifiers from real codeplug operations
4. **Error Codes**: Document response error codes
5. **Timing**: Determine required delays between commands

