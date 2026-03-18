# RadioWriter

**Native macOS radio programming for MOTOTRBO radios.**

Program your Motorola radios without Windows. Read/write codeplugs, configure channels, tones, and settings — all from a Mac.

> **Not affiliated with Motorola Solutions, Inc.** MOTOTRBO, XCMP, and XNL are trademarks of Motorola Solutions. This is an independent interoperability project.

---

## Status

| Component | Status |
|-----------|--------|
| Protocol research (XCMP/XNL) | ✅ Complete |
| Swift package framework | ✅ Built |
| USB transport layer | ✅ Implemented |
| Radio discovery | ✅ Implemented |
| Authentication (ControlStation mode) | ⚠️ Partial — encryption constants required |
| Codeplug read/write | ⏸️ Blocked — pending auth |
| macOS UI | 🔲 Not started |

---

## Supported Radio Families

| Family | Models | Status |
|--------|--------|--------|
| XPR Series | XPR 3300, 3500, 3500e, 7350, 7550 | Primary target |
| APX Series | APX 900, 6000, 8000 | Planned |
| CP Series | CP200d, CP185 | Planned |
| CLP/CLP2 | CLP 1010, 1040 | Planned |
| DLR Series | DLR 1020, 1060 | Planned |

Don't see your radio? [Open an issue](https://github.com/Heilo27/radiowriter/issues).

---

## Architecture

RadioWriter is structured as four Swift packages:

```
radiowriter/
├── Packages/
│   ├── RadioCore/          # Foundation: types, utilities, error handling
│   ├── RadioModels/        # Radio model definitions and codeplug schemas
│   │   ├── RadioModelCore  # Shared model interfaces
│   │   ├── XPR, APX, CP200, CLP, CLP2, DLRx, ...  (per-family targets)
│   ├── RadioHardware/      # Hardware communication layer
│   │   ├── USBTransport    # USB device I/O
│   │   ├── RadioProgrammer # XCMP/XNL protocol implementation
│   │   └── Discovery       # USB radio discovery
│   └── AudioEngine/        # Audio processing (monitoring/playback)
├── docs/                   # Protocol research and documentation
│   ├── README.md           # Documentation index
│   ├── RESEARCH_SUMMARY.md # Executive overview of protocol research
│   └── protocols/          # XCMP/XNL spec, encryption details, Swift templates
├── analysis/               # Binary analysis and packet captures
├── Moto.Net/               # MIT-licensed C# reference implementation
└── LEGAL.md                # Legal disclaimer and compliance notes
```

**Dependency graph:**
```
AudioEngine  →  RadioCore
RadioModels  →  RadioCore
RadioHardware → RadioCore + RadioModels
```

---

## Requirements

- **macOS 14.0** (Sonoma) or later
- **Xcode 15.0** or later
- **Swift 5.9** or later
- Motorola MOTOTRBO radio with USB connection (CDC ECM driver)

---

## Build

### Xcode (recommended)

Open the workspace — this loads all packages and the app target together:

```
open MotorolaCPS.xcworkspace
```

Select the `CPSApp` scheme and press Cmd+B. Requires Xcode 15.0+.

### Command line

```bash
# Clone the repository
git clone https://github.com/Heilo27/radiowriter.git
cd radiowriter

# Build all packages
swift build --package-path Packages/RadioCore
swift build --package-path Packages/RadioModels
swift build --package-path Packages/RadioHardware
swift build --package-path Packages/AudioEngine

# Run unit and integration tests
swift test --package-path Packages/RadioCore
swift test --package-path Packages/RadioHardware
swift test --package-path Packages/RadioModels
swift test --package-path Packages/AudioEngine
```

Hardware integration tests require a physical radio — see [docs/TEST_STRATEGY.md](docs/TEST_STRATEGY.md).

---

## Quick Start

> **Prerequisites:** Encryption constants required for full authentication. See [docs/README.md](docs/README.md) and [docs/protocols/ENCRYPTION_DETAILS.md](docs/protocols/ENCRYPTION_DETAILS.md) for details on the current blocker.

### Discover connected radios

```swift
import Discovery

let discovery = RadioDiscovery()
let radios = try await discovery.scan()
for radio in radios {
    print(radio.model, radio.serialNumber)
}
```

### Connect and read codeplug (ControlStation mode)

```swift
import RadioHardware
import RadioModels

let programmer = RadioProgrammer(authMode: .controlStation)
try await programmer.connect(to: radio)
let codeplug = try await programmer.readCodeplug()
```

See [docs/protocols/IMPLEMENTATION_GUIDE.md](docs/protocols/IMPLEMENTATION_GUIDE.md) for complete Swift code templates.

---

## Protocol Documentation

Full XCMP/XNL protocol research is documented in [`docs/`](docs/README.md):

- [Research Summary](docs/RESEARCH_SUMMARY.md) — High-level findings and roadmap
- [XCMP/XNL Protocol Spec](docs/protocols/XCMP_XNL_PROTOCOL.md) — Packet formats, opcodes, auth handshake
- [Encryption Details](docs/protocols/ENCRYPTION_DETAILS.md) — TEA encryption, constants, methods to obtain
- [Implementation Guide](docs/protocols/IMPLEMENTATION_GUIDE.md) — Swift templates ready to use

---

## Logging

RadioHardware uses `os.Logger` for structured, production-safe logging.

**Subsystem:** `com.heiloprojects.motorolacps`

| Category | Usage |
|----------|-------|
| `usb` | USB transport layer: device enumeration, connect/disconnect, serial port events |
| `xnl` | XNL connection layer: authentication, packet send/receive, socket operations |
| `xcmp` | XCMP protocol layer: commands, responses, opcode handling |
| `programmer` | High-level programmer operations: identify, read codeplug, zone/channel parsing |
| `crypto` | TEA encryption: key operations, test vectors |
| `tetra` | TETRA protocol operations |
| `lte` | LTE/broadband protocol operations |
| `xprtest` | XPRTest CLI tool: connection tests, channel analysis, debug sessions |

**Log levels:**
- `debug` — Protocol traces, hex dumps, packet contents. **Stripped automatically in release builds** by the OS.
- `info` — Connection events, session milestones.
- `error` — Protocol failures, connection drops, timeouts.

**Usage in code:**
```swift
RadioLog.xnl.debug("Received packet: \(data.hex)")
RadioLog.programmer.info("Connected to radio at \(host)")
RadioLog.xcmp.error("Timeout waiting for response")
```

**View logs (Console.app or terminal):**
```bash
# Stream all RadioWriter logs
log stream --predicate 'subsystem == "com.heiloprojects.motorolacps"'

# Filter by category
log stream --predicate 'subsystem == "com.heiloprojects.motorolacps" AND category == "xcmp"'

# Include debug level (stripped in release — only available in debug builds)
log stream --predicate 'subsystem == "com.heiloprojects.motorolacps"' --level debug
```

---

## Legal

See [LEGAL.md](LEGAL.md) for the full disclaimer. Key points:

- This project is for **interoperability and educational research** under DMCA §1201(f) and EU Directive 2009/24/EC
- Built from open-source references (Moto.Net, codeplug) using clean-room methodology
- **No Motorola proprietary binaries, firmware, or source code included**
- **Encryption constants are included** and documented in `CPSKeys.swift` and `XNLEncryption.swift`. They were extracted via static analysis of Motorola CPS software components and independently cross-referenced against the MIT-licensed [Moto.Net](https://github.com/pboyd04/Moto.Net) project. Inclusion is justified under DMCA §1201(f) for interoperability — see LEGAL.md for full discussion.
- Users are responsible for FCC Part 90/95/97 compliance when programming licensed radios

Licensed under [MIT](LICENSE). See also:

- [docs/TERMS_OF_SERVICE.md](docs/TERMS_OF_SERVICE.md) — Terms of use
- [docs/PRIVACY_POLICY.md](docs/PRIVACY_POLICY.md) — Data handling and privacy
- [docs/SECURITY_MODEL.md](docs/SECURITY_MODEL.md) — Security model and threat analysis

---

## Code Style

This project uses [SwiftLint](https://github.com/realm/SwiftLint) for style enforcement.

```bash
# Install
brew install swiftlint

# Lint (run from project root)
swiftlint lint
```

SwiftLint runs automatically as a build phase in CPSApp. Configuration is in [`.swiftlint.yml`](.swiftlint.yml) at the project root. Thresholds are tuned for SwiftUI view code and protocol implementation (XCMP/XNL parsers legitimately have high cyclomatic complexity).

Key rules enforced:
- `force_unwrapping` / `force_cast` / `force_try` — warnings, prefer safe alternatives
- `line_length` — warning at 160 chars, error at 300
- `modifier_order` — consistent access control ordering
- `no_print_statements` — use `os.Logger` instead

---

## Contributing

Pull requests welcome. See [LEGAL.md](LEGAL.md) for clean-room methodology requirements before contributing.

Areas needing help:
- Obtaining encryption constants (see LEGAL.md for compliant approaches)
- Radio model definitions for additional families
- macOS UI (not started)
- Hardware testing with physical radios

---

Motorola, MOTOTRBO, XCMP, XNL, and related marks are trademarks of Motorola Solutions, Inc. This project is not affiliated with or endorsed by Motorola Solutions.
