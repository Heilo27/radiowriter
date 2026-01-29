# Next Steps - MOTOTRBO CPS Reverse Engineering

**Updated:** 2026-01-29
**Status:** Phase 0 Complete (Initial Reconnaissance)

---

## Current Status

We have completed initial reconnaissance of the MOTOTRBO CPS 2.0 installer. The file is confirmed authentic (digitally signed by Motorola Solutions) and contains the complete application suite compressed within an InstallShield installer.

**What we know:**
- Installer structure and metadata
- Code signing certificate chain
- System DLL dependencies
- Build date and version info

**What we need:**
- Actual application binaries
- Protocol implementation details
- Codeplug format specifications
- USB communication parameters

---

## Phase 1: Environment Setup

### 1.1 Windows Analysis Environment

**Required:**
- Windows 10/11 VM (VMware Fusion or Parallels)
- At least 20 GB disk space
- USB passthrough enabled

**Installation:**
```bash
# On macOS host
# 1. Create Windows 11 VM
# 2. Install MOTOTRBO CPS 2.0
# 3. Note installation directory
# 4. Take snapshot before analysis
```

**Tools to install in VM:**
- IDA Pro Free or Ghidra (decompiler)
- x64dbg (debugger)
- Process Monitor (Sysinternals)
- USBPcap for Wireshark
- Hex editor (HxD or 010 Editor)
- Dependency Walker

### 1.2 Extract Application Files

**Location (expected):**
```
C:\Program Files (x86)\Motorola\MOTOTRBO CPS 2.0\
```

**Files to collect:**
```
/Applications/
  ├── CPS.exe                 # Main application
  ├── *.dll                   # Support libraries
  ├── Drivers/                # USB driver package
  ├── Templates/              # Radio model templates
  ├── Documentation/          # Any included docs
  └── Firmware/               # Radio firmware images
```

**Actions:**
1. Install CPS on Windows VM
2. Catalog all installed files
3. Copy entire directory to shared folder
4. Transfer to macOS for analysis

---

## Phase 2: Static Binary Analysis

### 2.1 String Extraction

**Windows binaries to analyze:**
```
Priority 1: CPS.exe (main application)
Priority 2: Communication DLLs (USB/serial layer)
Priority 3: Protocol handler DLLs
```

**Extract:**
```bash
# On Windows VM
strings64.exe CPS.exe > CPS_strings.txt
strings64.exe *.dll > DLL_strings.txt
```

**Search for:**
- Radio model identifiers (XPR, DP, DM, SL series)
- USB Vendor/Product IDs
- Protocol commands
- Error messages
- Configuration file paths
- Serial port parameters

### 2.2 Decompilation

**Tool:** Ghidra (free) or IDA Pro

**Targets:**
1. Main CPS.exe - entry point, initialization
2. USB communication DLL - I/O functions
3. Protocol handler - command implementation
4. Codeplug parser - read/write routines

**Focus areas:**
```c
// Find functions related to:
void* connectRadio(char* port);
int readCodeplug(void* handle, byte* buffer, size_t length);
int writeCodeplug(void* handle, byte* data, size_t length);
bool verifyRadioModel(void* handle, char* expectedModel);
```

### 2.3 Import Table Analysis

**Tool:** Dependency Walker or PE Explorer

**Look for:**
- Serial/USB I/O functions (CreateFile, ReadFile, WriteFile)
- Cryptographic functions (CryptImportKey, CryptEncrypt)
- Registry operations (model database storage)
- Network functions (online activation/updates?)

---

## Phase 3: Dynamic Analysis (USB Protocol Capture)

### 3.1 USB Traffic Capture Setup

**Requirements:**
- Test radio (XPR, DP, or DM series)
- Programming cable (USB to radio interface)
- Wireshark with USBPcap plugin

**Setup:**
```
1. Install USBPcap on Windows VM
2. Connect radio via USB
3. Start Wireshark capture on USB port
4. Launch CPS application
5. Perform operations and capture traffic
```

### 3.2 Capture Scenarios

**Session 1: Radio Detection**
```
1. Connect radio
2. Launch CPS
3. Let CPS auto-detect radio
4. Note: How does CPS identify the radio model?
```

**Session 2: Read Codeplug**
```
1. Connect radio
2. CPS → Radio → Read
3. Capture entire read session
4. Save codeplug file
5. Compare with captured USB traffic
```

**Session 3: Write Codeplug**
```
1. Modify codeplug (change channel name)
2. CPS → Radio → Write
3. Capture entire write session
4. Verify change on radio
```

**Session 4: Enter/Exit Programming Mode**
```
1. Manual programming mode entry
2. Capture handshake
3. Exit programming mode
4. Document command sequence
```

### 3.3 Protocol Analysis

**Wireshark filters:**
```
usb.src == "host"     # Commands from CPS
usb.dst == "host"     # Responses from radio
```

**Document:**
- Packet structure (header, command, data, checksum)
- Command codes for each operation
- Response codes (ACK, NAK, error codes)
- Timing requirements
- Block sizes
- Retry logic

---

## Phase 4: Codeplug Format Analysis

### 4.1 Sample Collection

**Obtain multiple .rdt files:**
- Different radio models
- Same model, different configurations
- Minimal vs. full configurations

### 4.2 Hex Analysis

**Tools:** 010 Editor (with templates) or HxD

**Process:**
```
1. Open .rdt file in hex editor
2. Identify header:
   - Magic bytes
   - Version number
   - Model identifier
   - Checksum location
3. Map known fields:
   - Find a channel name you programmed
   - Note byte offset
   - Identify format (ASCII, UTF-16, binary)
4. Compare files:
   - Diff two files with minimal changes
   - Identify changed bytes
   - Map to configuration changes
```

### 4.3 Format Documentation

**Create specification:**
```markdown
# MOTOTRBO Codeplug Format (.rdt)

## Header (bytes 0-63)
Offset | Length | Type   | Description
-------|--------|--------|-------------
0x00   | 4      | ASCII  | Magic "TRBO"
0x04   | 2      | uint16 | Format version
0x06   | 2      | uint16 | Model ID
...

## Channel Block (repeating structure)
Offset | Length | Type   | Description
-------|--------|--------|-------------
0x00   | 16     | ASCII  | Channel name
0x10   | 4      | uint32 | RX frequency (Hz)
0x14   | 4      | uint32 | TX frequency (Hz)
...
```

---

## Phase 5: Swift Implementation

### 5.1 Codeplug Parser

**Create Swift package:**
```swift
// Sources/MotoTRBO/Codeplug.swift
struct Codeplug {
    var header: CodeplugHeader
    var channels: [Channel]
    var zones: [Zone]
    var contacts: [Contact]
    
    init(fromFile path: URL) throws
    func write(to path: URL) throws
}
```

### 5.2 USB Communication Layer

**Use IOKit or third-party library:**
```swift
// Sources/MotoTRBO/RadioCommunicator.swift
class RadioCommunicator {
    func detectRadios() -> [RadioInfo]
    func connect(to radio: RadioInfo) throws -> RadioConnection
    func readCodeplug(from connection: RadioConnection) throws -> Codeplug
    func writeCodeplug(_ codeplug: Codeplug, to connection: RadioConnection) throws
}
```

### 5.3 Protocol Implementation

**Based on captured traffic:**
```swift
// Sources/MotoTRBO/Protocol.swift
enum RadioCommand: UInt8 {
    case enterProgramMode = 0x01  // Example values
    case readBlock = 0x10
    case writeBlock = 0x20
    case exitProgramMode = 0xFF
}

struct RadioPacket {
    var command: RadioCommand
    var data: Data
    var checksum: UInt16
    
    func encode() -> Data
    static func decode(_ data: Data) throws -> RadioPacket
}
```

---

## Milestone Checklist

### Phase 1: Setup
- [ ] Windows VM configured
- [ ] CPS 2.0 installed
- [ ] Analysis tools installed
- [ ] Application files extracted

### Phase 2: Static Analysis
- [ ] Strings extracted and categorized
- [ ] Main executable decompiled
- [ ] Communication DLLs analyzed
- [ ] Import table documented

### Phase 3: Protocol Capture
- [ ] USB capture environment set up
- [ ] Radio detection session captured
- [ ] Read codeplug session captured
- [ ] Write codeplug session captured
- [ ] Protocol documented

### Phase 4: Codeplug Analysis
- [ ] Sample .rdt files collected
- [ ] Header format identified
- [ ] Channel structure mapped
- [ ] Full format documented

### Phase 5: Implementation
- [ ] Swift package created
- [ ] Codeplug parser implemented
- [ ] USB communication layer built
- [ ] Protocol implementation complete
- [ ] Read operation tested
- [ ] Write operation tested

---

## Resource Requirements

### Hardware
- Mac with USB-C ports (for radio connection)
- Test radio (XPR7550e, DP4800, or similar)
- Programming cable (Motorola PMKN4010 or equivalent)

### Software (Windows VM)
- Windows 10/11 Professional
- MOTOTRBO CPS 2.0 (provided)
- Wireshark with USBPcap
- Ghidra or IDA Pro
- Hex editor

### Software (macOS)
- Xcode with Swift
- USB debugging tools
- Hex Fiend or similar

### Time Estimate
- Phase 1: 4 hours
- Phase 2: 16 hours
- Phase 3: 12 hours
- Phase 4: 20 hours
- Phase 5: 40 hours

**Total:** ~92 hours (~2-3 weeks full-time)

---

## Success Criteria

### Minimum Viable Implementation
1. Successfully detect connected MotoTRBO radio
2. Read codeplug from radio to file
3. Parse codeplug structure (channels, zones)
4. Display configuration in GUI
5. Modify configuration
6. Write codeplug back to radio
7. Verify radio operates with new configuration

### Extended Goals
- Support multiple radio models (XPR, DP, DM series)
- Import/export codeplugs to standard formats
- Codeplug validation and error checking
- Template library for common configurations
- Firmware version detection
- Clone radio feature

---

## Risk Mitigation

| Risk | Mitigation Strategy |
|------|---------------------|
| **Protocol encryption** | Capture and analyze auth handshake; implement same auth |
| **Model-specific variations** | Build model database; implement per-model handlers |
| **Bricking radio** | Implement read-only mode first; extensive validation before writes |
| **USB driver issues** | Use native IOKit or libusb; test with multiple cables |
| **Legal concerns** | Focus on interoperability; don't extract firmware or proprietary code |

---

## Next Immediate Action

**Start here:**
1. Set up Windows VM
2. Install MOTOTRBO CPS 2.0
3. Explore application directory
4. Document file structure
5. Report findings → Create Phase 1 completion report

**Estimated time:** 4 hours

---

*This roadmap will be updated as analysis progresses and new findings emerge.*
