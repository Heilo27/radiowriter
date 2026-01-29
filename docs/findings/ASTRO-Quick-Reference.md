# ASTRO Protocol Quick Reference

> Essential information for ASTRO radio programming protocol implementation.

---

## Key Opcodes

| Message | Command | Reply | Purpose |
|---------|---------|-------|---------|
| XcmpComponentSession | 0x010F | 0x810F | Session management |

*Note: Additional opcodes require traffic capture due to code obfuscation.*

---

## Component Types (XcmpComponentRead)

| ID | Type | Description |
|----|------|-------------|
| 0x01 | IshCodeplug | Codeplug data (ISH format) |
| 0x03 | Arm | ARM firmware |
| 0x04 | Dsp | DSP firmware |
| 0x07 | LanguagePack | Voice pack |
| 0x10 | EncryptionKey | Crypto keys |

---

## Programming Sequence

### Read
```
EnterReadProgramMode()
→ OpenSession(sessionID, Read)
→ ReadDeviceInfo()
→ ReadCodeplug()
→ CloseSession(sessionID, Read)
→ ExitReadProgramMode()
```

### Write
```
EnterWriteProgramMode()
→ OpenSession(sessionID, Write)
→ ValidateCodeplugVersion()
→ WriteRadioCodeplug()  // or WriteRadioDifferentialCodeplug()
→ CloseSession(sessionID, Write)
→ ExitWriteProgramMode()
```

---

## ISH Item Structure

```
struct IshItem {
    uint16 typeId;
    uint8  instance;
    uint8  partition;
    uint32 offset;
    uint16 length;
    byte[] data;
}
```

---

## Reply Codes

| Code | Meaning |
|------|---------|
| 0x00 | Success |
| 0x01 | Failure |
| 0x03 | Opcode not supported |
| 0x06 | Security locked |
| 0x81 | ISH item not found |
| 0x84 | ISH partition does not exist |

---

## Next Analysis Tasks

1. Capture live programming traffic
2. Extract remaining opcodes
3. Document ISH type IDs
4. Map codeplug structure

---

**See:** ASTRO-Protocol-Analysis.md for full details
