# ASTRO Radio Protocol Analysis

> Analysis of Motorola ASTRO radio programming protocol extracted from `Common.Communication.AstroSequenceManager.dll` and related assemblies.

**Date:** 2026-01-29  
**Analyst:** Specter  
**Source:** Motorola CPS R23.00.01 (MOTOTRBO/ASTRO)  
**Confidence:** High for structure, Medium for specific opcodes (obfuscation present)

---

## Executive Summary

The ASTRO programming protocol builds on the XCMP (eXtended Control Message Protocol) and RCMP (Radio Control Message Protocol) foundation used in MOTOTRBO radios, with ASTRO-specific extensions for P25 trunking and advanced features.

### Key Findings

1. **Protocol Layer:** XCMP/RCMP over USB or network transport
2. **Session Management:** Component-based sessions with session IDs
3. **Codeplug Access:** ISH (Information Set Header) based data structures
4. **Authentication:** AES-based authentication for secure operations
5. **Differential Write:** Supports differential codeplug updates (delta programming)

---

## Protocol Architecture

```
┌─────────────────────────────────────┐
│  Application Layer                  │
│  (Sequence Manager)                 │
├─────────────────────────────────────┤
│  XCMP Messages                      │
│  (Component Session, Read, Write)   │
├─────────────────────────────────────┤
│  RCMP Base Protocol                 │
│  (Opcode, Result, Framing)          │
├─────────────────────────────────────┤
│  Transport Layer                    │
│  (USB, TCP/IP, RUDP)                │
└─────────────────────────────────────┘
```

---

## Core Classes and Responsibilities

### AstroCpsSequenceManager

Main sequencer for ASTRO radio programming operations.

**Implements:**
- `ICpsSequenceManager` - CPS programming interface
- `ISequenceManager` - Base sequencing
- `IFwdl` - Firmware download
- `IUpdatesMacAddress` - MAC address programming
- `IRadioParamSupport` - Radio parameter access
- `IQueryRadioStatus` - Status queries
- `IIshBlockSupport` - ISH data block operations
- `IDifferentialWritable` - Delta programming support
- `ILanguagePackSupport` - Language pack management
- `IDepotSequenceManager` - Depot programming features

### AstroFileSeqManager

Handles file-based codeplug operations for ASTRO radios.

**Key Methods:**
- `OpenSession(sessionID, operation)` - Establish programming session
- `CloseSession(sessionId, operation, pendingDeploy)` - Terminate session
- `ReadDevice(referencePba, sessionID)` - Read codeplug from radio
- `WriteDevice(writePBA, sessionID, password, hostedDepotOperation)` - Write codeplug to radio
- `ForceWriteDevice(writePBA, sessionID)` - Force write (skip validation)

### AstroManagedFileSeqManager

Managed file operations with enhanced error handling.

### AstroOtapRcmpMessageExecutor

OTAP (Over-The-Air Programming) message executor for wireless programming.

### AstroWifiFileSeqManager

Wi-Fi based programming for ASTRO radios with Wi-Fi capability.

### AstroWiFiRcmpMessageExecutor

RCMP message executor over Wi-Fi transport.

---

## XCMP Message Types

### XcmpComponentSession (Opcode: 0x010F / 0x810F)

Manages component programming sessions.

**Command Opcode:** `0x010F`  
**Reply Opcode:** `0x810F`

**Parameters:**
- `action` (uint16) - Session action (Open/Close/Query)
- `sessionID` (uint16) - Unique session identifier
- `data` (uint32) - Optional session data

**Actions:**
- Open Session
- Close Session
- Query Session Status
- Component Session

### XcmpComponentRead

Reads component data from radio.

**Component Types:**
| Value | Type | Description |
|-------|------|-------------|
| 0x00 | None | No component |
| 0x01 | IshCodeplug | ISH-based codeplug |
| 0x02 | NonIshCodeplug | Non-ISH codeplug |
| 0x03 | Arm | ARM processor firmware |
| 0x04 | Dsp | DSP processor firmware |
| 0x05 | Mace | MACE crypto processor |
| 0x06 | CouP | Control Unit Processor |
| 0x07 | LanguagePack | Voice language pack |
| 0x08 | LocalLangPack | Local language pack |
| 0x09 | LangSetupInfo | Language setup information |
| 0x0A | ToneFile | Tone/alert files |
| 0x0B | RoamingLog | Roaming history log |
| 0x0C | ErrorLog | Error/diagnostic log |
| 0x0E | ControlHeadFW | Control head firmware |
| 0x0F | ControlHeadCplg | Control head codeplug |
| 0x10 | EncryptionKey | Encryption key material |
| 0x11 | CurrentConfig | Active configuration |
| 0x12 | PossibleConfig | Available configurations |
| 0x13 | Pictures | User images/pictures |

### RCMP Base Messages

Common RCMP operations inherited by ASTRO:

**Device Info:**
- `RcmpReadUUID` - Read radio UUID
- `RcmpReadWriteModelNumber` - Model number access
- `RcmpReadWriteSerialNumber` - Serial number access
- `RcmpVersionInformation` - Firmware version query
- `RcmpHexVersionInformation` - Hex version info
- `RcmpRadioStatus` - Radio status query

**ISH Operations:**
- `RcmpReadIshItem` - Read single ISH item
- `RcmpWriteIshItem` - Write single ISH item
- `RcmpReadIshIDSet` - Read ISH ID set
- `RcmpReadIshTypeSet` - Read ISH type set
- `RcmpDeleteIshIDs` - Delete ISH items
- `RcmpIshUnlockPartition` - Unlock ISH partition
- `RcmpIshReorgControl` - ISH reorganization
- `RcmpIshProgramMode` - ISH programming mode

**Security:**
- `RcmpUnlockSecurity` - Unlock radio security
- `RcmpReadRadioKey` - Read security key
- `XcmpUnkill` - Unkill (reactivate) radio
- `XcmpSecureConnect` - Secure connection establishment

**Memory Access:**
- `RcmpReadMemory` - Direct memory read
- `RcmpWriteMemory` - Direct memory write
- `RcmpMemoryStreamRead` - Streamed memory read
- `RcmpMemoryStreamWrite` - Streamed memory write

**Boot/Flash:**
- `RcmpEraseFlash` - Erase flash memory
- `RcmpBootJumpExecution` - Jump to boot code
- `RcmpBootWriteCommit` - Commit boot write
- `XcmpEnterBootMode` - Enter bootloader mode

**Advanced Features:**
- `XcmpCertificateManagement` - Certificate operations
- `XcmpSecureCertificateManagement` - Secure cert operations
- `XcmpWiFiConnectivityTest` - Wi-Fi connectivity test
- `XcmpNetworkInfConfig` - Network interface config
- `XcmpFactoryReset` - Factory reset operation
- `XcmpCodeplugPasswordLock` - Codeplug password protection

**Language Packs:**
- `XcmpReadLanguagePackInfo` - Query language packs
- `XcmpWriteLanguagePack` - Write language pack
- `XcmpDeleteLanguagePack` - Delete language pack
- `XcmpDeleteTTSLanguagePack` - Delete TTS pack
- `XcmpWriteTTSLanguagePack` - Write TTS pack (new field, not in source)

**File/Data Access:**
- `XcmpFileAccess` - File system access
- `XcmpFtlAccess` - FTL (Flash Translation Layer) access
- `XcmpNandAccess` - NAND flash access
- `XcmpPsdtAccess` - PSDT access
- `XcmpTransferData` - Data transfer operations
- `XcmpSuperBundle` - Bundled operations

**Radio Update/Control:**
- `XcmpRadioUpdateControl` - Firmware update control
- `RcmpRadioReset` - Radio reset
- `RcmpDatecode` - Date code programming

**Test/Diagnostics:**
- `RcmpEnterTestMode` - Enter test mode
- `XcmpConnectivityTest` - Connectivity testing
- `RcmpTanapaNumber` - TANAPA number
- `RcmpRxFrequency` - Receive frequency setting
- `RcmpTxFrequency` - Transmit frequency setting
- `RcmpTransmit` - Transmit control
- `RcmpReceive` - Receive control
- `RcmpSoftpot` - Software potentiometer

---

## RCMP Reply Result Codes

| Code | Name | Description |
|------|------|-------------|
| 0x00 | Success | Operation succeeded |
| 0x01 | Failure | Operation failed |
| 0x02 | IncorrectMode | Radio in wrong mode |
| 0x03 | OpcodeNotSupported | Opcode not supported by radio |
| 0x04 | InvalidParameter | Invalid parameter value |
| 0x05 | ReplyTooBig | Reply exceeds maximum size |
| 0x06 | SecurityLocked | Security prevents operation |
| 0x07 | BundledOpcodeNotSupported | Bundled opcode not supported |
| 0x10 | LockSequenceFailure | Lock sequence failed |
| 0x10 | EraseInProgress | Flash erase in progress |
| 0x10 | Busy | Radio busy |
| 0x10 | PairDeviceFailure | Device pairing failed |
| 0x11 | BitLocked | BIT locked |
| 0x11 | LanguagePackNotExist | Language pack not found |
| 0x11 | PasswordVerificationFailure | Password verification failed |
| 0x12 | BitUnlocked | BIT unlocked |
| 0x12 | RadioIsLocked | Radio is locked |
| 0x12 | TTSLanguagePackNotExist | TTS language pack not found |
| 0x13 | VoltageNotStable | Voltage not stable for operation |
| 0x14 | ProgramFailure | Programming operation failed |
| 0x16 | TransferComplete | Transfer completed |
| 0x17 | RequestNotRXed | Request not received |
| 0x40 | SoftpotOperationNotSupported | Softpot operation not supported |
| 0x41 | SoftpotTypeNotSupported | Softpot type not supported |
| 0x42 | SoftpotValueOutOfRange | Softpot value out of range |
| 0x80 | FlashWriteFailure | Flash write failed |
| 0x81 | IshItemNotFound | ISH item not found |
| 0x82 | IshOffsetOutOfRange | ISH offset out of range |
| 0x83 | IshInsufficientPartitionSpace | ISH partition space insufficient |
| 0x84 | IshPartitionDoesNotExist | ISH partition does not exist |
| 0x85 | IshPartitionReadOnly | ISH partition is read-only |
| 0x86 | IshReorgNeeded | ISH reorganization needed |
| 0x87 | Undefined | Undefined error |

---

## Certificate Management

### Certificate Types

| Value | Type | Description |
|-------|------|-------------|
| 0x00 | NoCertificate | No certificate |
| 0x01 | BaseCertificate | Base security certificate |
| 0x02 | WiFiCertificate | Wi-Fi authentication cert |
| 0x03 | WOCCertificate | WOC certificate |
| 0x04 | RadioCentral | Radio Central certificate |
| 0x05 | IoT | IoT certificate |
| 0x06 | BackupPtt | Backup PTT certificate |
| 0x81 | BasebandProcessorAuthKey | Baseband auth key |

### Certificate Operations

| Value | Operation | Description |
|-------|-----------|-------------|
| 0x00 | NoFunction | No operation |
| 0x01 | Enrollment | Certificate enrollment |
| 0x02 | ReEnrollment | Certificate re-enrollment |
| 0x03 | GeneratePlatformKeyPair | Generate platform key pair |
| 0x04 | DeleteCertificate | Delete certificate |
| 0x08 | EraseCertificateCN | Erase certificate CN |
| 0x80 | GetCertificateStatus | Query certificate status |
| 0x81 | GetPlatformPublicKeyInfo | Get platform public key |
| 0x82 | ReadCMFESN | Read CMF ESN |

---

## Programming Workflow

### Read Device Sequence

```
1. EnterReadProgramMode()
   - Puts radio in read mode
   
2. OpenSession(sessionID, RadioOperation.Read)
   - Establishes programming session
   - Returns session parameters
   
3. ReadDeviceInfo()
   - Reads basic device information
   - Model, serial, version
   
4. ReadExtendedDeviceInfo()
   - Reads extended info
   - Digital signature, capabilities
   
5. ReadCodeplug()
   - Reads codeplug via ISH items
   - Can be full or partial
   
6. CloseSession(sessionID, RadioOperation.Read, false)
   - Terminates session
   
7. ExitReadProgramMode()
   - Returns radio to normal operation
```

### Write Device Sequence

```
1. EnterWriteProgramMode()
   - Puts radio in write mode
   
2. OpenSession(sessionID, RadioOperation.Write)
   - Establishes programming session
   
3. ValidateCodeplugVersion()
   - Verifies codeplug compatibility
   
4. UpdatePINPasswordBeforeWrite()
   - Updates authentication if needed
   
5. WriteRadioCodeplug() OR WriteRadioDifferentialCodeplug()
   - Full write or differential write
   - Writes via ISH items
   
6. UpdateMacAddressBeforeWrite()
   - Updates MAC if changed
   
7. WriteValidation()
   - Validates written data
   
8. CloseSession(sessionID, RadioOperation.Write, false)
   - Terminates session
   
9. ExitWriteProgramMode()
   - Returns radio to normal operation
```

### Differential Write Sequence

```
1. DifferentialWriteSupported(sessionID, operation)
   - Query if radio supports differential write
   
2. OpenSession(sessionID, RadioOperation.Write)
   
3. WriteRadioDifferentialCodeplug(deltaData)
   - Writes only changed ISH items
   - Much faster than full write
   
4. CloseSession(sessionID, RadioOperation.Write, false)
```

---

## ISH (Information Set Header) Structure

ISH is Motorola's structured data format for codeplug storage.

### ISH Item Structure

```
ISH Item:
  - Type ID (uint16)        - Item type identifier
  - Instance (uint8)        - Instance number
  - Partition (uint8)       - Storage partition
  - Offset (uint32)         - Offset within partition
  - Length (uint16)         - Data length
  - Data (byte[])           - Actual data
```

### ISH Operations

**Read Operations:**
- `ReadIshItems(ishHeaders)` - Read multiple ISH items
- `ReadItemsByIshHeaders(ishHeaders)` - Read by ISH header list
- `ReadIshIDSet()` - Read all ISH IDs
- `ReadIshTypeSet()` - Read all ISH types

**Write Operations:**
- `WriteIshItems(ishItems)` - Write multiple ISH items
- `SetCodeplug(codeplugData)` - Set entire codeplug

**Management:**
- `DeleteIshIDs(ids)` - Delete ISH items
- `IshUnlockPartition(partition)` - Unlock partition for writing
- `IshReorgControl(action)` - Reorganize ISH storage

---

## Security & Authentication

### Authentication Flow

```
1. ReadUnkillChallengeValue()
   - Radio provides challenge
   
2. Compute response using authAES
   - AES encryption of challenge with key
   
3. UnkillRadio(authenticationValue)
   - Send authentication response
   - Radio unlocks if valid
```

### Security Operations

- `UnlockSecurity()` - Unlock security-locked radio
- `ReadRadioKey()` - Read radio encryption key
- `UpdateExternalDataModemPasswordBeforeWrite()` - Update external modem password
- `UpdateWiFiPasswordBeforeWrite()` - Update Wi-Fi password
- `ValidateLocalPassword(password)` - Validate programming password

---

## Network Programming

### Wi-Fi Programming

**Sequence:**
```
1. FactoryReset() (if needed)
   - Reset radio to factory state
   
2. ConnectToWiFiAccessPoint(ssid, password, securityType)
   - Connect radio to Wi-Fi AP
   
3. EnrollWiFiCertificate(ssid, password, securityType, ntp1, ntp2, timeout)
   - Enroll Wi-Fi certificate for secure connection
   
4. Proceed with normal programming over Wi-Fi transport
```

### OTAP (Over-The-Air Programming)

Uses `AstroOtapRcmpMessageExecutor` for wireless codeplug updates.

---

## Firmware Update

### FWDL (Firmware Download) Operations

```
1. SetFWDLConfig(tg, version)
   - Set firmware download configuration
   
2. SwitchRadioMode(DeviceMode.FWDLMode)
   - Put radio in firmware download mode
   
3. Transfer firmware via component read/write
   - Use XcmpComponentRead/Write for firmware
   
4. QueryRadioUpdateStatus()
   - Poll update progress
   
5. SendFPGAReset(fileType)
   - Reset FPGA after update
```

---

## Key Differences from MOTOTRBO Protocol

### ASTRO-Specific Features

1. **Component Session Management**
   - More complex session types
   - Archive sessions for fleet management
   - Component-based sessions (ISH, firmware, etc.)

2. **Enhanced Security**
   - Certificate management (XcmpCertificateManagement)
   - Secure connect (XcmpSecureConnect)
   - Platform key pair generation
   - CMF ESN reading

3. **Advanced Connectivity**
   - Wi-Fi programming support
   - Network interface configuration
   - OTAP (Over-The-Air Programming)

4. **Depot Programming**
   - `DepotForceWriteDevice()` - Fleet management features
   - Archive sessions
   - Hosted depot operations

5. **Enhanced Diagnostics**
   - Connectivity testing (CAN, Ethernet, RS232, USB, SD, SSI, BT, GPS, WiFi)
   - Test mode entry
   - Module info queries
   - PSDT access

6. **Language Pack Management**
   - TTS (Text-To-Speech) language packs
   - Local language packs
   - Language setup information

---

## Code Examples (Hypothetical Usage)

### Opening a Session

```csharp
// Create sequence manager
var sequenceManager = new AstroCpsSequenceManager(rcmpWrapper, sessionParam);

// Open session for reading
ushort sessionID = 1;
sequenceManager.OpenSession(sessionID, RadioOperation.Read);

// Read device info
var deviceInfo = sequenceManager.ReadExtendedDeviceInfo();
Console.WriteLine($"Model: {deviceInfo.ModelNumber}");
Console.WriteLine($"Serial: {deviceInfo.SerialNumber}");

// Read codeplug
var pba = sequenceManager.ReadDevice(referencePba, sessionID);

// Close session
sequenceManager.CloseSession(sessionID, RadioOperation.Read, false);
```

### Writing with Differential Update

```csharp
// Check if differential write supported
bool isDifferentialCapable = sequenceManager.DifferentialWriteSupported(
    sessionID, 
    RadioOperation.Write
);

if (isDifferentialCapable)
{
    // Use differential write (faster)
    sequenceManager.WriteRadioDifferentialCodeplug(deltaCodeplug);
}
else
{
    // Fall back to full write
    sequenceManager.WriteRadioCodeplug(fullCodeplug);
}
```

---

## Transport Layers

### USB Transport

Standard XCMP over USB using device-specific endpoints.

### TCP/IP Transport

XCMP over TCP/IP with configurable port (default: varies by model).

### RUDP (Reliable UDP) Transport

Custom Motorola RUDP implementation for unreliable networks.

**Assembly:** `Common.Communication.RUDP.dll`

---

## Related Assemblies

| Assembly | Purpose |
|----------|---------|
| `Common.Communication.AstroSequenceManager.dll` | ASTRO sequence management |
| `Common.Communication.RcmpWrapper.dll` | RCMP/XCMP message definitions |
| `Common.Communication.IshHandler.dll` | ISH data structure handling |
| `Common.Communication.CommonInterface.dll` | Common interfaces |
| `Common.Communication.CommunicationPipe.dll` | Transport abstraction |
| `Common.Communication.PcrSequenceManager.dll` | PCR (non-ASTRO) sequencer |
| `CommonLib.dll` | Common utilities and data types |
| `Pba.dll` | Parameter Block Archive (codeplug) |
| `AcpCryptoLib.dll` | ACP crypto operations |
| `AES.dll` | AES encryption |

---

## Limitations & Observations

### Code Obfuscation

The assemblies are obfuscated with Dotfuscator:
- Method names are mangled (a, b, c, d, etc.)
- Control flow is obfuscated with opaque predicates
- Constants are encoded
- Only public API surface remains readable

### Incomplete Opcode Extraction

Due to obfuscation, only the following opcodes were definitively extracted:
- **XcmpComponentSession:** Command `0x010F`, Reply `0x810F`

Other opcodes are embedded in obfuscated constructors and would require:
- Runtime instrumentation
- Traffic capture and analysis
- Deobfuscation tools

### Protocol Reverse Engineering Recommendations

1. **Network Capture:** Use Wireshark with USB or TCP capture to observe actual XCMP traffic
2. **Runtime Hooking:** Hook .NET methods at runtime to capture opcode values
3. **Known Patterns:** Compare with documented MOTOTRBO opcodes (similar base)
4. **Hardware Analysis:** Use USB protocol analyzer for low-level capture

---

## Next Steps

1. **Traffic Capture Analysis**
   - Capture real CPS programming session
   - Extract opcodes from wire format
   - Document message structures

2. **Comparative Analysis**
   - Compare with PCR/MOTOTRBO protocol documentation
   - Identify ASTRO-specific extensions
   - Map component types to functionality

3. **ISH Structure Documentation**
   - Reverse engineer ISH item types
   - Document codeplug layout
   - Create ISH parser/builder

4. **Implementation**
   - Build XCMP message parser
   - Implement session management
   - Create codeplug read/write tools

---

## References

- Motorola CPS R23.00.01
- ASTRO Sequence Manager DLL
- RCMP Wrapper DLL
- ISH Handler DLL

---

**Analysis Status:** Structural understanding complete, opcode extraction partial  
**Confidence Level:** High for API surface, Medium for protocol internals  
**Recommended Validation:** Live traffic capture and comparison

