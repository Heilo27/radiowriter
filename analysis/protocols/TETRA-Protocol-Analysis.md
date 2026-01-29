# TETRA Radio Programming Protocol Analysis

**Source:** `Common.Communication.TetraSequenceManager.dll` and `Common.Communication.TetraMessage.dll`
**Date:** 2026-01-29
**Analyst:** Specter

---

## Executive Summary

The TETRA (Terrestrial Trunked Radio) programming protocol consists of three primary communication layers:

1. **RP (Radio Programming) Protocol** - High-level programming commands
2. **SBEP (Subscriber Boot Execution Protocol)** - Boot/firmware operations
3. **AT Command Protocol** - Serial AT-style control commands

This protocol differs from PCR/MOTOTRBO in several key areas:
- More sophisticated message framing
- Dedicated boot protocol (SBEP)
- Enhanced security features
- Support for trunking and encryption operations

---

## Protocol Layers

### Layer 1: RP (Radio Programming) Protocol

The RP protocol is the primary high-level interface for radio configuration.

#### RP Message Types (Opcodes)

| Opcode | Value | Direction | Purpose |
|--------|-------|-----------|---------|
| `RP_STATUS_INDICATION` | `0x00` | Radio → CPS | Radio status notification |
| `RP_PARAMETER_VERSION_REPORT_REQUEST` | `0x01` | CPS → Radio | Request parameter version |
| `RP_PARAMETER_VERSION_REPORT_CONFIRM` | `0x02` | Radio → CPS | Confirm version report |
| `RP_RESET_REQUEST` | `0x03` | CPS → Radio | Request radio reset |
| `RP_PARAMETER_VERSION_REPORT_REPLY` | `0x04` | Radio → CPS | Version report response |
| `RP_REJECT_INDICATION` | `0x05` | Radio → CPS | Command rejected |
| `RP_TERMINAL_ID_REQUEST` | `0x06` | CPS → Radio | Request terminal ID |
| `RP_TERMINAL_ID_CONFIRM` | `0x07` | Radio → CPS | Terminal ID response |

#### RP Reset Modes

| Mode | Value | Description |
|------|-------|-------------|
| `RP_RESET_MODE_NORMAL` | `0x00` | Normal operation mode |
| `RP_RESET_MODE_CHARGING` | `0x01` | Charging mode |
| `RP_RESET_MODE_PROGRAMMING` | `0x02` | Programming mode |
| `RP_RESET_MODE_RP` | `0x03` | RP protocol mode |

#### RP Message Structure

```
Message Format:
[Message Type: 1 byte = 0x00 (RP_MESSAGE_TYPE)]
[Command: 1 byte (RP opcode)]
[Payload: variable length]
```

---

### Layer 2: SBEP (Subscriber Boot Execution Protocol)

SBEP handles low-level boot operations, firmware loading, and memory access.

#### SBEP Status Codes

| Status | Value | Meaning |
|--------|-------|---------|
| `SBEPST_ACK` | `0x50` | Command acknowledged |
| `SBEPST_NACK` | `0x60` | Command not acknowledged |
| `Undefined` | `0x70` | Undefined status |

#### SBEP Flags

| Flag | Value | Purpose |
|------|-------|---------|
| `SBEP_NON_FLAG` | `0x00000000` | No special flags |
| `SBEP_A4S2` | `0x00000001` | A4S2 mode flag |
| `SBEP_READ_LENGTH_0` | `0x00000002` | Read with zero length |

#### SBEP Operations

SBEP provides:
- Memory read/write operations
- Checksum verification
- Firmware upload
- Boot sequence control

---

### Layer 3: Data Transfer Protocol

The data transfer layer handles codeplug read/write operations using extended opcodes.

#### Read Commands

| Command | Value | Description |
|---------|-------|-------------|
| `READ_DATA_REQ` | `0xF511` | Standard read request |
| `EX_READ_DATA_REQ` | `0xF741` | Extended read request |
| `READ_DATA_REPLY` | `0xFF80` | Read response |
| `EX_READ_DATA_REPLY` | `0xFFB0` | Extended read response |

#### Write Commands

| Command | Value | Description |
|---------|-------|-------------|
| `WRITE_DATA_REQ` | `0xFF17` | Standard write request |
| `EX_WRITE_DATA_REQ` | `0xFF47` | Extended write request |
| `GOOD_WRITE_REPLY` | `0xF484` | Write successful |
| `BAD_WRITE_REPLY` | `0xF485` | Write failed |
| `EX_GOOD_WRITE_REPLY` | `0xF5B4` | Extended write successful |
| `EX_BAD_WRITE_REPLY` | `0xF5B5` | Extended write failed |

#### Utility Commands

| Command | Value | Description |
|---------|-------|-------------|
| `CHECKSUM_REQ` | `0xF612` | Request checksum |
| `CHECKSUM_REPLY` | `0xF381` | Checksum response |
| `EX_CHECKSUM_REQ` | `0xF942` | Extended checksum request |
| `EX_CHECKSUM_REPLY` | `0xF3B1` | Extended checksum response |
| `STATUS_REQ` | `0xF114` | Request status |
| `STATUS_REPLY` | `0xF583` | Status response |
| `EX_STATUS_REQ` | `0xF144` | Extended status request |
| `EX_STATUS_REPLY` | `0xF6B3` | Extended status response |
| `CONFIGURATION_REQ` | `0xF113` | Request configuration |
| `CONFIGURATION_REPLY` | `0xF482` | Configuration response |
| `UNSUPPORTED_OPCODE_REPLY` | `0xF186` | Opcode not supported |

#### Write Status Codes (SM Layer)

| Status | Value | Meaning |
|--------|-------|---------|
| `SM_GOOD_WRITE_REPLY` | `0x01` | Write succeeded |
| `SM_BAD_WRITE_REPLY` | `0x02` | Write failed |
| `SM_UNDEFINED_WRITE_REPLY` | `0x03` | Write status undefined |

---

### Layer 4: AT Command Protocol

The AT protocol provides serial-style control commands.

#### AT Command Terminators

| Character | Value | Purpose |
|-----------|-------|---------|
| `CR` | `0x0D` | Carriage return (command terminator) |
| Line Feed | `0x0A` | Line feed |
| Escape | `0x1B` | Escape character |
| Backspace | `0x08` | Backspace |
| Space | `0x20` | Space character |

---

## Compression Support

TETRA supports multiple compression algorithms for data transfer:

| Algorithm | Value | Description |
|-----------|-------|-------------|
| `NO_COMPRESSION` | `0x00` | No compression |
| `LZRW3_COMPRESSION` | `0x01` | LZRW3 algorithm |
| `FASTLZ_COMPRESSION` | `0x02` | FastLZ algorithm |
| `LZRW3A_COMPRESSION` | `0xFF` | LZRW3A variant |

---

## FDT (Flash Data Table) Support

The TETRA sequence manager implements FDT operations for structured radio memory access.

### FDT Magic Numbers

| Type | Value | Description |
|------|-------|-------------|
| `FDTR` | `0x46445452` | FDT record marker |
| `FTRP` | `0x46545250` | FDT radio parameters |
| `FMWR` | `0x464D5752` | FDT firmware |
| `CPLG` | `0x43504C47` | Codeplug data |
| `FSPK` | `0x4653504B` | Flash pack |
| `KEYS` | `0x4B455953` | Encryption keys |
| `LOGD` | `0x4C4F4744` | Log data |
| `RELI` | `0x52454C49` | Release info |

### FDT Operations

```csharp
class TetraPhysicalAddressSeqMgr
{
    CommRC DoReadFDT(out byte[] data);
    CommRC DoWriteFDT(byte[] data);
}
```

### FDT State Values

| State | Value | Meaning |
|-------|-------|---------|
| `FDT_READY` | `0x00000000` | FDT ready for operations |

---

## Authentication & Connection Sequence

### Connection Flow

```
1. CPS → Radio: RP_TERMINAL_ID_REQUEST (0x06)
2. Radio → CPS: RP_TERMINAL_ID_CONFIRM (0x07)
3. CPS → Radio: RP_PARAMETER_VERSION_REPORT_REQUEST (0x01)
4. Radio → CPS: RP_PARAMETER_VERSION_REPORT_CONFIRM (0x02)
5. Radio → CPS: RP_PARAMETER_VERSION_REPORT_REPLY (0x04)
6. CPS → Radio: RP_RESET_REQUEST (0x03) with mode = RP_RESET_MODE_PROGRAMMING (0x02)
7. Radio → CPS: RP_STATUS_INDICATION (0x00)
```

### Rejection Handling

When the radio rejects a command:
```
Radio → CPS: RP_REJECT_INDICATION (0x05)
[Payload contains rejection reason]
```

Rejection reasons include:
- `RP_BAD_BATTERY` - Battery voltage too low
- Other reasons (obfuscated in the binary)

---

## Codeplug Read/Write Operations

### Read Sequence

```
1. CPS → Radio: READ_DATA_REQ (0xF511) or EX_READ_DATA_REQ (0xF741)
   [Address: 4 bytes (little-endian)]
   [Length: 2 bytes (little-endian)]

2. Radio → CPS: READ_DATA_REPLY (0xFF80) or EX_READ_DATA_REPLY (0xFFB0)
   [Data: requested bytes]
   [Checksum: 2 bytes]
```

### Write Sequence

```
1. CPS → Radio: WRITE_DATA_REQ (0xFF17) or EX_WRITE_DATA_REQ (0xFF47)
   [Address: 4 bytes (little-endian)]
   [Length: 2 bytes (little-endian)]
   [Data: variable]
   [Checksum: 2 bytes]

2. Radio → CPS: GOOD_WRITE_REPLY (0xF484) or BAD_WRITE_REPLY (0xF485)
   (or extended versions: 0xF5B4 / 0xF5B5)
```

### Checksum Calculation

```
1. CPS → Radio: CHECKSUM_REQ (0xF612) or EX_CHECKSUM_REQ (0xF942)
   [Address: 4 bytes]
   [Length: 2 bytes]

2. Radio → CPS: CHECKSUM_REPLY (0xF381) or EX_CHECKSUM_REPLY (0xF3B1)
   [Checksum: 2 bytes]
```

---

## Key Classes & Interfaces

### Core Sequence Managers

```csharp
namespace Motorola.Common.Communication.SequenceManager
{
    class TetraRPSeqManager : ICpsSequenceManager, ISequenceManager, 
                              IFwdl, IUpdatesMacAddress, IRadioParamSupport,
                              IQueryRadioStatus, IIshBlockSupport, 
                              IDifferentialWritable, ILanguagePackSupport,
                              ITetraSeqMgrSpecialOperation
    {
        TetraCommPipe transportPipe;
        TetraDeviceInfo deviceInfo;
        DeviceMode mode;
        TetraRadioType radioType;
        
        // Core operations
        PasswordStatus ValidateLocalPassword(string password);
        byte QueryRadioUpdateStatus();
        // ... many more operations
    }
    
    class TetraPhysicalAddressSeqMgr
    {
        CommRC DoReadFDT(out byte[] data);
        CommRC DoWriteFDT(byte[] data);
    }
    
    class TetraBaseSbepSeqManager
    {
        // Base class for SBEP operations
    }
}
```

### Message Classes

```csharp
namespace Motorola.Common.Communication
{
    abstract class ATBaseMessage : IMessage, IDisposable
    {
        byte[] replyMessageBuffer;
        int readTimeout;
        // AT command execution
    }
    
    abstract class RPBaseMessage : IMessage
    {
        // RP protocol messages
    }
    
    abstract class SBEPBaseMessage : IMessage
    {
        SbepMessageExecutor executor;
        int readTimeout;
        // SBEP protocol messages
    }
}
```

---

## Differences from PCR/MOTOTRBO Protocol

| Feature | MOTOTRBO/PCR | TETRA |
|---------|--------------|-------|
| **Protocol Layers** | 2 (AT + Data) | 4 (AT + RP + SBEP + Data) |
| **Boot Protocol** | None | SBEP with ACK/NACK |
| **Opcodes** | 8-bit | 8-bit (RP) / 16-bit (Data) |
| **Extended Commands** | No | Yes (EX_ variants) |
| **Compression** | Basic | Multiple algorithms |
| **FDT Support** | Limited | Full structured access |
| **Reset Modes** | 2 | 4 (including RP mode) |
| **Authentication** | Simple | Multi-step with version check |

---

## TETRA-Specific Features

### Trunking Support

Evidence of trunking configuration:
- Dedicated FDT section for trunking parameters
- Radio type enumeration includes trunked variants
- Trunking state management in sequence manager

### Encryption/Security

The protocol includes:
- Dedicated KEYS FDT section (`0x4B455953`)
- Password validation (`ValidateLocalPassword`)
- Security-related message flow
- Key management interfaces

### Radio Modes

```csharp
enum DeviceMode
{
    // Multiple modes including:
    Normal = 0,
    // ... 
    Programming = 7
}

enum TetraRadioType
{
    // Radio variants
    // (specific values obfuscated)
}
```

---

## Implementation Notes

### Message Framing

All messages appear to use:
- Length-prefixed frames
- Checksum validation
- Timeout-based reception

### Error Handling

The protocol provides multiple error indication methods:
- `RP_REJECT_INDICATION` for RP layer
- `SBEPST_NACK` for SBEP layer
- `BAD_WRITE_REPLY` for data layer
- `UNSUPPORTED_OPCODE_REPLY` for unknown commands

### Threading & Synchronization

```csharp
// Evidence of thread-safe operations
AutoResetEvent syncEvent;
object lockObject;
Monitor.Enter/Exit patterns
```

---

## Memory Map Support

The sequence manager references:
```csharp
class MemMapRecord
{
    string MemMapID;
    SerializableDictionary<string, List<MemMapUnit>> MapDefinition;
}

class MemMapVersionMapRecord
{
    // Version-specific memory maps
}
```

Suggests radio memory is structured into named regions with version-dependent layouts.

---

## Recommendations for Implementation

1. **Start with RP Protocol**: Implement connection/authentication sequence first
2. **Use Extended Commands**: Prefer EX_ variants for larger transfers
3. **Implement FDT Support**: Essential for structured codeplug access
4. **Handle All Error Paths**: Protocol has rich error reporting
5. **Support Compression**: Implement at least FASTLZ for efficiency
6. **Version Checking**: Always exchange version info before programming
7. **Respect Reset Modes**: Use correct mode for each operation type

---

## Next Steps

- [ ] Analyze `Common.Communication.TetraSecurity.dll` for encryption details
- [ ] Analyze `Common.Communication.TetraUtility.dll` for radio models/configs
- [ ] Reverse engineer actual message parsers for binary formats
- [ ] Capture live USB traffic to verify protocol interpretation
- [ ] Document specific FDT record structures
- [ ] Map memory regions for specific TETRA radio models

---

## Legal Notice

This analysis is for educational and interoperability purposes only. It documents publicly observable protocol behavior from distributed software binaries. No proprietary algorithms or copyrighted code are reproduced.

**Analyst:** Specter  
**Date:** 2026-01-29  
**Status:** Initial Analysis Complete

