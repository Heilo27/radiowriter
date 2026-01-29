# XCMP Command Reference - Quick Lookup

**Source:** Decompiled MOTOTRBO CPS DLLs
**Date:** 2026-01-29

---

## Command Opcodes

| Opcode (Hex) | Opcode (Dec) | Command Name | Purpose |
|--------------|--------------|--------------|---------|
| `0x010B` | 267 | XcmpPsdtAccess | Access PSDT partitions (read/write codeplug) |
| `0x010F` | 271 | XcmpComponentSession | Manage programming sessions |
| `0x810F` | 33039 | XcmpComponentSession (Reply) | Session command reply |
| [TBD] | [TBD] | XcmpComponentRead | Read component data from radio |
| [TBD] | [TBD] | XcmpTransferData | Transfer data blocks |
| [TBD] | [TBD] | XcmpCodeplugPasswordLock | Lock codeplug with password |
| [TBD] | [TBD] | XcmpFactoryReset | Factory reset command |
| [TBD] | [TBD] | XcmpEnterBootMode | Enter boot mode |
| [TBD] | [TBD] | XcmpSecureConnect | Establish secure connection |

---

## XcmpPsdtAccess (0x010B)

**Actions:**
```
0x00 - None
0x01 - GetStartAddress  // Query partition start address
0x02 - GetEndAddress    // Query partition end address
0x03 - Lock             // Lock partition
0x04 - Unlock           // Unlock partition
0x05 - Erase            // Erase partition
0x06 - Copy             // Copy partition data
0x07 - ImageReorg       // Reorganize partition image
```

**Packet Format:**
```
[XCMP Header]
[Opcode: 0x010B (2 bytes)]
[Action: byte]
[Source Partition ID: 4 bytes ASCII, null-padded]
[Target Partition ID: 4 bytes ASCII, null-padded]
```

**Reply:**
```
[XCMP Header]
[Opcode: 0x810B (reply bit set)]
[Status: byte]
[PsdtAddress: uint32, if GetStartAddress/GetEndAddress]
```

---

## XcmpComponentSession (0x010F)

**Actions (Flags - can be combined):**
```
0x0000 - None
0x0001 - Reset                 // Reset session
0x0002 - StartSession          // Start programming session
0x0004 - Snapshot              // Create snapshot
0x0008 - ValidateCRC           // Validate CRC
0x0010 - UnpackFiles           // Unpack compressed files
0x0020 - Deploy                // Deploy configuration
0x0040 - DelayTOD              // Delay time-of-day
0x0080 - SuppressPN            // Suppress part number checks
0x0100 - Status                // Query status
0x0200 - ReadWrite             // Enable read/write
0x0400 - CreateArchive         // Create archive
0x0800 - ProgrammingIndicator  // Show programming indicator
```

**Common Combinations:**
```
StartSession | ReadWrite               = 0x0202  // Start read session
StartSession | ReadWrite | ProgrammingIndicator = 0x0A02  // Start write session
CreateArchive                           = 0x0400  // Create codeplug archive
UnpackFiles | Deploy                    = 0x0030  // Unpack and deploy
ValidateCRC                             = 0x0008  // Validate transferred data
Reset                                   = 0x0001  // End session
```

**Packet Format:**
```
[XCMP Header]
[Opcode: 0x010F (2 bytes)]
[Action: ushort (2 bytes)]
[Session ID: ushort (2 bytes)]
[Data: uint32 (4 bytes), optional]
```

**Reply:**
```
[XCMP Header]
[Opcode: 0x810F (reply bit set)]
[Result: ushort]
  0x0000 - Success
  0x0001 - Failure
  0x0004 - InvalidParameter
  0x0010 - InvalidSessionID
  0x0011 - InvalidArchive
  0x0012 - Busy
[Completed Actions: ushort]
```

---

## XcmpPsdtAccessBroadcast

**Purpose:** Unsolicited progress updates during PSDT operations

**Packet Format:**
```
[XCMP Header]
[Opcode: broadcast variant]
[Status: byte]
  0x00 - InProgress
  0x01 - Complete
  0x02 - Error
[Completion Percentage: byte (0-100)]
```

---

## Typical Command Sequences

### Read Codeplug
```
1. XcmpComponentSession (StartSession | ReadWrite)
   → Reply: Success, SessionID=1234

2. XcmpPsdtAccess (GetStartAddress, "CP\0\0", "")
   → Reply: Address=0x08000000

3. XcmpPsdtAccess (GetEndAddress, "CP\0\0", "")
   → Reply: Address=0x08100000

4. XcmpPsdtAccess (Unlock, "CP\0\0", "")
   → Reply: Success

5. XcmpComponentRead (...)
   → Data transfer begins
   → XcmpPsdtAccessBroadcast: 25% complete
   → XcmpPsdtAccessBroadcast: 50% complete
   → XcmpPsdtAccessBroadcast: 100% complete

6. XcmpComponentSession (CreateArchive, SessionID=1234)
   → Reply: Success

7. XcmpComponentSession (Reset, SessionID=1234)
   → Reply: Success
```

### Write Codeplug
```
1. XcmpComponentSession (StartSession | ReadWrite | ProgrammingIndicator)
   → Reply: Success, SessionID=5678

2. XcmpPsdtAccess (Unlock, "CP\0\0", "")
   → Reply: Success

3. XcmpPsdtAccess (Erase, "CP\0\0", "")
   → Reply: Success

4. XcmpTransferData (CompressFile, block1)
5. XcmpTransferData (CompressFile, block2)
   ... continue for all blocks
   → XcmpPsdtAccessBroadcast: Progress updates

6. XcmpComponentSession (ValidateCRC, SessionID=5678)
   → Reply: Success

7. XcmpComponentSession (UnpackFiles | Deploy, SessionID=5678)
   → Reply: Success

8. XcmpPsdtAccess (Lock, "CP\0\0", "")
   → Reply: Success

9. XcmpComponentSession (Reset, SessionID=5678)
   → Reply: Success
```

---

## Partition IDs (Confirmed)

| ID | Purpose | Notes |
|----|---------|-------|
| `"CP"` | Codeplug | Main configuration storage |
| `"ISH"` | ISH Handler | [Purpose unknown, needs investigation] |
| `"BOOT"` | Boot | Boot partition |

*Note: Partition IDs are 4-byte ASCII strings, null-padded*

---

## Implementation Checklist

- [ ] Implement XcmpPsdtAccess command builder
- [ ] Implement XcmpComponentSession command builder
- [ ] Session ID generator (ushort, unique per session)
- [ ] Progress monitoring via XcmpPsdtAccessBroadcast
- [ ] Partition address tracking
- [ ] Error handling for all reply result codes
- [ ] [NEEDS CAPTURE] XcmpComponentRead command structure
- [ ] [NEEDS CAPTURE] XcmpTransferData command structure
- [ ] [NEEDS CAPTURE] Actual partition IDs from live traffic
- [ ] [NEEDS CAPTURE] Block size limits for data transfer
- [ ] [NEEDS CAPTURE] Compression format identification

---

*This is a living document - update as more details are discovered*
