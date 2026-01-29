# XCMP Codeplug Read/Write Protocol Analysis

**Source:** MOTOTRBO CPS DLLs
- `Common.Communication.PcrSequenceManager.dll`
- `Common.Communication.RcmpWrapper.dll`
- `PCR.RadioDataTransporter.dll`

**Analysis Date:** 2026-01-29

---

## Key XCMP Commands

### 1. XcmpPsdtAccess (Opcode 0x010B / 267)

**Purpose:** Access PSDT (Persistent Storage Data Table) partitions for reading/writing codeplug data

**Constructor:**
```csharp
XcmpPsdtAccess(PsdtAccessAction action, string psdtSrcSectionId, string psdtTgtSectionId)
```

**PsdtAccessAction Enum:**
```csharp
enum PsdtAccessAction : byte {
    None           = 0x00,
    GetStartAddress = 0x01,  // Query start address of partition
    GetEndAddress   = 0x02,  // Query end address of partition
    Lock            = 0x03,  // Lock partition (prevent access)
    Unlock          = 0x04,  // Unlock partition (allow access)
    Erase           = 0x05,  // Erase partition contents
    Copy            = 0x06,  // Copy data between partitions
    ImageReorg      = 0x07   // Reorganize partition image
}
```

**Key Fields:**
- `psdtSrcSectionId`: Source partition ID (max 4 bytes ASCII)
- `psdtTgtSectionId`: Target partition ID (max 4 bytes ASCII)
- Returns: `PsdtAddress` (uint32) - Memory address of partition

**Broadcast Version:** `XcmpPsdtAccessBroadcast`
- Used for monitoring progress of PSDT operations
- Provides `Status` and `CompletionPercentage` properties

---

### 2. XcmpComponentSession (Opcode 0x010F / 271)

**Purpose:** Manage programming session lifecycle

**Constructor:**
```csharp
XcmpComponentSession(ushort action, ushort sessionID, uint data)
XcmpComponentSession(ushort action, ushort sessionID)
```

**Actions Enum (Flags):**
```csharp
enum Actions : ushort {
    None                  = 0x0000,
    Reset                 = 0x0001,  // Reset session state
    StartSession          = 0x0002,  // Begin programming session
    Snapshot              = 0x0004,  // Create snapshot of current state
    ValidateCRC           = 0x0008,  // Validate CRC of transferred data
    UnpackFiles           = 0x0010,  // Unpack compressed files
    Deploy                = 0x0020,  // Deploy configuration to radio
    DelayTOD              = 0x0040,  // Delay time-of-day activation
    SuppressPN            = 0x0080,  // Suppress part number checks
    Status                = 0x0100,  // Query session status
    ReadWrite             = 0x0200,  // Enable read/write operations
    CreateArchive         = 0x0400,  // Create archive from radio data
    ProgrammingIndicator  = 0x0800   // Show programming indicator on radio
}
```

**SessionReplyResult Enum:**
```csharp
enum SessionReplyResult : ushort {
    Success             = 0x0000,
    Failure             = 0x0001,
    InvalidParameter    = 0x0004,
    InvalidSessionID    = 0x0010,
    InvalidArchive      = 0x0011,
    Busy                = 0x0012
}
```

**Session Management:**
- Each session has a unique `sessionID` (ushort)
- Actions can be combined using bitwise OR (flags enum)
- Reply includes status and completed actions

---

### 3. XcmpComponentRead (Opcode: [NEEDS VERIFICATION])

**Purpose:** Read component data from radio (used for codeplug reading)

**Key Properties:**
- `Level` enum - Read level (radio, system, component)
- `ComponentType` enum - Type of component to read
- `ListMode` enum - How to retrieve component lists
- `ListStructure` enum - Structure of returned lists
- `NumberOfFiles` (ushort) - Count of files to read

**Usage Context:**
- Part of component-based read operations
- Works in conjunction with ComponentSession
- Supports reading multiple files/components

---

### 4. XcmpTransferData (Opcode: [NEEDS VERIFICATION])

**Purpose:** Transfer data blocks between CPS and radio

**DataType Enum:**
```csharp
enum DataType : byte {
    [Unknown_0]      = 0x00,
    [Unknown_1]      = 0x01,
    [Unknown_2]      = 0x02,
    [Unknown_3]      = 0x03,
    Fxp              = 0x04,  // FXP protocol data
    CompressFile     = 0x05   // Compressed file data
}
```

**Key Fields:**
- `Data` (byte[]) - Payload data
- Data type indicator
- Sequence/block identifiers

---

## Codeplug Read Sequence

Based on class hierarchy and method analysis:

```
1. START SESSION
   └─> XcmpComponentSession(StartSession | ReadWrite, sessionID)
       Reply: Success

2. QUERY PARTITION ADDRESS
   └─> XcmpPsdtAccess(GetStartAddress, "CODEPLUG_PARTITION_ID", "")
       Returns: Start address
   └─> XcmpPsdtAccess(GetEndAddress, "CODEPLUG_PARTITION_ID", "")
       Returns: End address

3. UNLOCK PARTITION (if needed)
   └─> XcmpPsdtAccess(Unlock, "CODEPLUG_PARTITION_ID", "")

4. READ COMPONENT DATA
   └─> XcmpComponentRead(...)
       Loop: Transfer data blocks via XcmpTransferData
       Monitor: XcmpPsdtAccessBroadcast for progress

5. CREATE ARCHIVE
   └─> XcmpComponentSession(CreateArchive, sessionID)

6. END SESSION
   └─> XcmpComponentSession(Reset, sessionID)
```

---

## Codeplug Write Sequence

Based on `WriteCodeplugInIsh` method analysis:

```
1. START SESSION
   └─> XcmpComponentSession(StartSession | ReadWrite | ProgrammingIndicator, sessionID)
       Reply: Success

2. UNLOCK PARTITION
   └─> XcmpPsdtAccess(Unlock, "TARGET_PARTITION", "")

3. ERASE PARTITION (optional)
   └─> XcmpPsdtAccess(Erase, "TARGET_PARTITION", "")

4. TRANSFER DATA
   └─> XcmpTransferData(CompressFile, data_block_1)
   └─> XcmpTransferData(CompressFile, data_block_2)
   └─> ... (continue for all blocks)
       Monitor: XcmpPsdtAccessBroadcast for progress

5. VALIDATE DATA
   └─> XcmpComponentSession(ValidateCRC, sessionID)

6. UNPACK AND DEPLOY
   └─> XcmpComponentSession(UnpackFiles | Deploy, sessionID)

7. SNAPSHOT (if needed)
   └─> XcmpComponentSession(Snapshot, sessionID)

8. LOCK PARTITION
   └─> XcmpPsdtAccess(Lock, "TARGET_PARTITION", "")

9. END SESSION
   └─> XcmpComponentSession(Reset, sessionID)
```

---

## Key Partition IDs

Common partition identifiers found in code (max 4 ASCII chars):

- `"CP"` - Codeplug partition (likely)
- `"ISH"` - ISH Handler related (mentioned in WriteCodeplugInIsh)
- `"BOOT"` - Boot partition
- `[NEEDS VERIFICATION] - Need to capture actual partition IDs from live traffic

---

## Session Management Details

### Session Lifecycle

1. **Initialization**
   - Generate unique session ID (ushort)
   - Send StartSession with appropriate flags

2. **Active Operations**
   - Session ID must be included in all subsequent commands
   - Radio tracks session state
   - Multiple actions can be combined in single request

3. **Status Monitoring**
   - Use XcmpPsdtAccessBroadcast for progress updates
   - Check CompletionPercentage (0-100)
   - Monitor Status field for success/failure

4. **Termination**
   - Always send Reset action to clean up
   - Session ID becomes invalid after reset

---

## Data Transfer Protocol

### Block Transfer

- Data transferred in blocks via XcmpTransferData
- Blocks can be compressed (DataType = CompressFile)
- Progress monitored via broadcast messages
- CRC validation after complete transfer

### Flow Control

From `PCRRPOperations` class analysis:
- Uses `UpdateProgressDelegate` callback pattern
- Monitors `XcmpPsdtAccessBroadcast.CompletionPercentage`
- Checks `XcmpPsdtAccessBroadcast.Status` for errors

---

## Important Classes

### Sequence Managers

| Class | Purpose |
|-------|---------|
| `PcrCpsSequenceManager` | Main codeplug operations coordinator |
| `PCRRPSequenceManager` | Repeater programming sequence manager |
| `PCRWiFiSequenceManager` | WiFi-based programming |
| `PcrMatrixDeviceSequenceManager` | Matrix radio programming |

### Helper Classes

| Class | Purpose |
|-------|---------|
| `PcrBootExecutor` | Boot mode operations executor |
| `PcrBootOperations` | Low-level boot operations (includes PsdtAccess) |
| `DeviceInfoFetcher` | Query radio device information |
| `PcrLanguageHelper` | Language pack management |

---

## Security Considerations

### Password Protection

- `XcmpCodeplugPasswordLock` - Lock codeplug with password
- Password handling in CommonSecurity class
- Secure connection via `XcmpSecureConnect`

### Encryption

- Certificate management via `XcmpCertificateManagement`
- Secure certificate handling via `XcmpSecureCertificateManagement`

---

## Next Steps for Implementation

### High Priority

1. **Capture Live Traffic**
   - Use Wireshark/tcpdump on USB interface
   - Decode actual XCMP packets
   - Verify partition IDs and exact command sequences

2. **Validate Opcodes**
   - Confirm XcmpComponentRead opcode
   - Confirm XcmpTransferData opcode
   - Document any additional commands used

3. **Block Transfer Details**
   - Determine block size limits
   - Understand sequencing/fragmentation
   - Document retry/error handling

### Medium Priority

4. **Partition Mapping**
   - Identify all partition IDs used by CPS
   - Map partitions to codeplug sections
   - Document partition size limits

5. **Compression Format**
   - Identify compression algorithm used
   - Document compressed file structure
   - Test decompression

### Low Priority

6. **Alternative Protocols**
   - Document FXP protocol usage
   - Understand OTA programming differences
   - Map WiFi vs USB protocol variations

---

## Confidence Levels

| Finding | Confidence | Notes |
|---------|------------|-------|
| XcmpPsdtAccess opcode | **HIGH** | Confirmed 0x010B from IL |
| PsdtAccessAction enum | **HIGH** | Complete enum extracted |
| XcmpComponentSession opcode | **HIGH** | Confirmed 0x010F from IL |
| ComponentSession actions | **HIGH** | Complete flags enum extracted |
| Read/Write sequences | **MEDIUM** | Inferred from method flow, needs verification |
| Partition IDs | **LOW** | Only "ISH" confirmed, others need capture |
| Block sizes | **LOW** | Not found in analyzed DLLs |
| XcmpTransferData opcode | **LOW** | Not found in IL dump |

---

## Tools Required

To implement this protocol:

1. **USB XCMP Transport** - Low-level USB communication
2. **XCMP Packet Builder** - Construct properly formatted commands
3. **Session Manager** - Track session state and IDs
4. **Progress Monitor** - Handle broadcast messages
5. **Data Compressor** - Handle compressed file transfers
6. **Partition Manager** - Track partition addresses and states

---

*Analysis performed using `monodis` on .NET assemblies*
*Further validation required through packet capture and testing*
