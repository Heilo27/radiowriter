# MOTOTRBO XCMP Command Opcodes

Extracted from MOTOTRBO CPS DLL analysis (Common.Communication.RcmpWrapper.dll)

## Radio Identification & Information Commands

| Opcode | Name | Purpose |
|--------|------|---------|
| 0x000E | RcmpReadWriteSerialNumber | Read/Write radio serial number |
| 0x000F | RcmpVersionInformation | Get firmware version information |
| 0x0013 | RcmpDatecode | Read radio datecode |
| 0x0017 | RcmpDiscoverRemoteDevice | Discover remote radios |
| 0x001F | RcmpTanapaNumber | Read TANAPA number |
| 0x0025 | RcmpReadWriteCodeplugAttribute | Read/Write codeplug attributes |
| 0x002C | XcmpReadLanguagePackInfo | Read language pack information |
| 0x0461 | XcmpModuleInfo | Read module/component information |

## Codeplug Read/Write Operations

| Opcode | Name | Purpose |
|--------|------|---------|
| 0x010B | XcmpPsdtAccess | PSDT (codeplug) access - primary read/write |
| 0xB10B | XcmpPsdtAccessBroadcast | PSDT access broadcast/status messages |
| 0x010E | XcmpComponentRead | Read component data |
| 0x010F | XcmpComponentSession | Component session management |
| 0x0025 | RcmpReadWriteCodeplugAttribute | Read/Write codeplug metadata/attributes |
| 0x00FF | XcmpCodeplugPasswordLock | Codeplug password lock/unlock |

## Memory & Data Access Commands

| Opcode | Name | Purpose |
|--------|------|---------|
| 0x0201 | RcmpReadMemory | Direct memory read (boot mode) |
| 0x0443 | XcmpNandAccess | NAND flash access |
| 0x0444 | XcmpFtlAccess | Flash Translation Layer access |
| 0x0445 | XcmpFileAccess | File system access |
| 0x0446 | XcmpTransferData | Data transfer operations |

## ISH (Item Store Handler) Commands

| Opcode | Name | Purpose |
|--------|------|---------|
| 0x0100 | RcmpReadIshItem | Read ISH item |
| 0x000C | RcmpWriteIshItem | Write ISH item |
| 0x0102 | RcmpDeleteIshIDs | Delete ISH items by ID |
| 0x0103 | XcmpISHDeleteType | Delete ISH items by type |
| 0x0104 | RcmpReadIshIDSet | Read ISH ID set |
| 0x0105 | RcmpReadIshTypeSet | Read ISH type set |
| 0x0106 | RcmpIshProgramMode | ISH programming mode control |
| 0x0107 | RcmpIshReorgControl | ISH reorganization |
| 0x0108 | RcmpIshUnlockPartition | Unlock ISH partition |

## Boot Mode & Update Commands

| Opcode | Name | Purpose |
|--------|------|---------|
| 0x0200 | XcmpEnterBootMode | Enter boot/programming mode |
| 0x0002 | RcmpBootWriteCommit | Commit boot mode writes |
| 0x0203 | RcmpEraseFlash | Erase flash memory |
| 0x0204 | RcmpBootJumpExecution | Jump to execution |
| 0x0009 | XcmpRadioUpdateControl | Radio update control |
| 0x010C | XcmpRadioUpdateControl | Radio update control (alternate) |

## Connection & Session Management

| Opcode | Name | Purpose |
|--------|------|---------|
| 0x0018 | RcmpRemoteConnect | Connect to remote radio |
| 0x0019 | RcmpRemoteDisconnect | Disconnect from remote radio |
| 0x001E | XcmpConnectivityTest | Test connectivity |
| 0x003D | XcmpSecureConnect | Secure connection establishment |

## Radio Control Commands

| Opcode | Name | Purpose |
|--------|------|---------|
| 0x000A | RcmpRxFrequency | Set RX frequency |
| 0x000B | RcmpTxFrequency | Set TX frequency |
| 0x000D | RcmpRadioReset | Reset radio |
| 0x0010 | RcmpRxBerControl | RX BER test control |
| 0x0011 | RcmpRxBerSyncReport | RX BER sync report |
| 0x003F | XcmpFactoryReset | Factory reset |
| 0x046C | XcmpUnkill | Unkill radio |

## Language Pack Commands

| Opcode | Name | Purpose |
|--------|------|---------|
| 0x002B | XcmpWriteTTSLanguagePack | Write TTS language pack |
| 0x002C | XcmpReadLanguagePackInfo | Read language pack info |

## Security & Encryption Commands

| Opcode | Name | Purpose |
|--------|------|---------|
| 0x0300 | RcmpReadRadioKey | Read radio encryption key |
| 0x0301 | RcmpUnlockSecurity | Unlock security features |
| 0x0480 | XcmpCertificateManagement | Certificate management |
| 0x048A | XcmpSecureCertificateManagement | Secure certificate management |
| 0x00FF | XcmpCodeplugPasswordLock | Codeplug password protection |

## Utility Commands

| Opcode | Name | Purpose |
|--------|------|---------|
| 0x0432 | XcmpDateTime | Read/write date/time |
| 0x002E | XcmpSuperBundle | Super bundle operations |
| 0x0207 | RcmpRemoteDuplicateSetup | Remote duplicate setup |
| 0x0208 | FpgaOperation | FPGA operations |

## Broadcast/Status Messages

| Opcode | Name | Purpose |
|--------|------|---------|
| 0x0006 | RcmpMemoryStreamStatusBroadcast | Memory stream status |
| 0x3440 | RcmpMemoryStreamReadBroadcast | Memory stream read broadcast |
| 0xB10B | XcmpPsdtAccessBroadcast | PSDT access status/progress |

## Key Insights

1. **Primary Codeplug Access**: `0x010B` (XcmpPsdtAccess) appears to be the main command for codeplug read/write operations
2. **Radio Identification**: Use `0x000F` (RcmpVersionInformation), `0x000E` (RcmpReadWriteSerialNumber), and `0x0461` (XcmpModuleInfo)
3. **Boot Mode Required**: Some commands (0x0201, 0x0203, 0x0204) require boot mode (0x0200)
4. **ISH vs PSDT**: ISH commands handle individual items, PSDT handles full codeplug structures
5. **Broadcast Messages**: Commands ending in "Broadcast" are unsolicited messages from the radio

## Notes

- These opcodes are for MOTOTRBO radios using the XCMP protocol
- Command structure: Opcode (2 bytes) + payload data
- Response opcodes typically match request opcodes
- Boot mode commands require entering boot mode first (0x0200)
- PSDT = Persistent Stored Data Table (the codeplug)
