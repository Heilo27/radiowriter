# Test Strategy

**Document Version:** 1.0
**Date:** 2026-02-25

---

## Philosophy

RadioWriter tests are divided by dependency. Unit and integration tests run without hardware. Hardware tests are gated by environment variable and require a physical radio. UI tests run against the built app.

The goal is a fast, reliable test suite for CI, with a separate hardware-gated suite for release qualification.

---

## Test Categories

### 1. Unit Tests (No hardware, no network)

Located in `Packages/*/Tests/`. Run with `swift test` per package.

| Package | Test File | What It Covers |
|---------|-----------|----------------|
| RadioCore | `BinaryPackerTests.swift` | Binary packing: multi-type round-trips, byte order, boundary conditions |
| RadioCore | `BinaryUnpackerTests.swift` | Binary unpacking: field extraction, offset correctness, edge cases |
| RadioCore | `CodeplugTests.swift` | Codeplug data model: create, read/write fields, validation |
| RadioCore | `SerializerTests.swift` | `.cpsx` file format: round-trip without encryption, PBKDF2-encrypted round-trip, wrong password rejection, format version compatibility |
| RadioHardware | `MockConnectionTests.swift` | USB transport mock: connect/disconnect state, queued response dispatch |
| AudioEngine | `VoicePromptTests.swift` | VoicePromptManager: initial state, add/remove prompts |
| RadioModels | `CLPModelTests.swift` | CLP model definitions: default codeplug creation, field value correctness |

**Total:** ~1503 lines of test code across 8 files.

### 2. Integration Tests (Mock hardware)

Located in `Packages/RadioHardware/Tests/IntegrationTests/`.

| File | What It Covers |
|------|----------------|
| `RadioWorkflowTests.swift` | Full codeplug read/write workflow via `MockConnection`. Tests the RadioProgrammer protocol sequence: enter programming mode → read blocks → exit. Verifies data integrity, checksum validation, and multi-block reconstruction. |

These tests run without physical hardware by using `MockConnection` with queued protocol responses.

### 3. Hardware Integration Tests (Physical radio required)

Located in `Packages/RadioHardware/Tests/RadioHardwareTests/XPRConnectionTests.swift`.

Gated by environment variable:

```bash
RADIO_HW_TESTS=1 swift test --package-path Packages/RadioHardware --filter XPRConnectionTests
```

Optional override for non-standard radio IP:

```bash
RADIO_HOST=192.168.10.1 RADIO_HW_TESTS=1 swift test ...
```

These tests require a Motorola XPR radio connected via USB (CDC ECM at `192.168.10.1`, XNL port 8002). They test live authentication, session establishment, and real codeplug read/write. They are not run in CI.

### 4. UI Tests (App required)

Located in `CPSApp/UITests/`.

| File | What It Covers |
|------|----------------|
| `WelcomeWorkflowTests.swift` | Welcome screen navigation, new/open codeplug entry points |
| `NavigationFlowTests.swift` | Tab/sidebar navigation, view transitions |
| `ChannelEditingTests.swift` | Inline channel editing: field input, validation, save behavior |
| `CodeplugFileWorkflowTests.swift` | Open/save/close codeplug files, unsaved changes indicator |
| `CSVImportExportTests.swift` | CSV import and export for channels and contacts |
| `KeyboardShortcutTests.swift` | Standard macOS keyboard shortcuts (Cmd+S, Cmd+Z, etc.) |
| `RadioCommunicationTests.swift` | UI flows for connect, read, write, and clone operations |
| `ValidationWorkflowTests.swift` | Pre-write validation: error surfaces, warning dismissal |
| `CPSAppUITestCase.swift` | Shared base class for UI test setup and helpers |

UI tests run against the full app build. They are integration-level — they exercise real app state, not mocks.

---

## How to Run Tests

### Unit and integration tests (per package)

```bash
# RadioCore (serializer, binary packing, codeplug model)
swift test --package-path Packages/RadioCore

# RadioHardware (mock connection, workflow integration)
swift test --package-path Packages/RadioHardware

# RadioModels (model definitions)
swift test --package-path Packages/RadioModels

# AudioEngine (voice prompt manager)
swift test --package-path Packages/AudioEngine
```

### All packages (sequential)

```bash
for pkg in RadioCore RadioModels RadioHardware AudioEngine; do
    swift test --package-path "Packages/$pkg"
done
```

### Hardware integration tests

```bash
RADIO_HW_TESTS=1 swift test --package-path Packages/RadioHardware --filter XPRConnectionTests
```

Connect the XPR radio via USB before running. The radio must appear as a CDC ECM network device.

### UI tests

Run via Xcode: open `MotorolaCPS.xcworkspace`, select the UITest scheme, press Cmd+U.

Or via command line:

```bash
xcodebuild test -workspace MotorolaCPS.xcworkspace -scheme CPSApp -destination 'platform=macOS'
```

---

## Coverage

### Well-covered areas

- Binary serialization and deserialization (BinaryPacker/Unpacker)
- Codeplug file format, including encryption (SerializerTests)
- RadioProgrammer protocol sequence via mock connection
- CLP model structure and default values
- Core UI workflows (editing, navigation, file handling, CSV)

### Known gaps

| Area | Gap | Notes |
|------|-----|-------|
| XNL/XCMP protocol parsing | No unit tests for individual packet types or edge cases | Protocol logic is exercised only via hardware tests |
| RadioModels coverage | Only CLPModelTests exists; XPR, APX, CP200, DLR models lack tests | Radio model definitions are largely untested |
| AudioEngine | Only smoke-level tests (manager lifecycle, add/remove) | Actual audio rendering is not tested |
| Error handling paths | Connection drop mid-programming, partial reads, malformed responses | Mock tests cover happy path only |
| Hardware integration | Only XPR 3500e tested with physical hardware | Other supported families not covered |

---

## CI Expectations

The following must pass on every commit:

- All unit tests across all four packages
- RadioHardware integration tests (mock-based)

Hardware tests and UI tests are not run in automated CI. Hardware tests run pre-release against physical radios. UI tests run pre-release via Xcode.

---

## Related Documents

- [SECURITY-AUDIT.md](SECURITY-AUDIT.md) — Encryption key audit and security posture
- [SECURITY_MODEL.md](SECURITY_MODEL.md) — Security model and threat analysis
