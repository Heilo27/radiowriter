# Changelog

All notable changes to RadioWriter are documented here.

Format: [CalVer](https://calver.org/) — `YYYY.MM.DD`

---

## 2026.02.15

- Code quality pass across the codebase: SwiftLint compliance, dead code removal, import cleanup

## 2026.02.02

### Features

- **DMR ID lookup** — Optional user-initiated lookup against RadioID.net; resolves DMR IDs to subscriber info
- **Undo/redo** — Full undo/redo support for codeplug edits (Cmd+Z / Cmd+Shift+Z)
- **Inline channel editing** — Edit channel parameters directly in the channel list; no modal required
- **CSV import/export** — Import and export channels and contacts as CSV for backup and migration
- **Clone** — Clone radio codeplug from connected radio; unsaved changes indicator added
- **Write verification** — After writing a codeplug, reads it back and compares to verify successful programming
- **Search and filter** — Search/filter channels and contacts by name or frequency
- **Pre-write validation** — Validates codeplug before writing; surfaces errors before touching the radio
- **Backup workflow** — Prompts to save a backup before writing a new codeplug

### Fixes

- Fixed critical bugs in codeplug parsing
- Added comprehensive accessibility support (VoiceOver labels, focus management)

## 2026.01.31

- Editable channel fields with proper input controls and accessibility support
- Documented complete channel record binary format with verified field offsets

## 2026.01.30

### Features

- **Settings editing** — Editable general radio settings panel, matching CPS 2.0 capability
- **Comprehensive codeplug editing** — Zones, channels, contacts, and scan lists all editable
- **Radio settings reading** — Full settings read from radio matching Motorola CPS 2.0 data model

### Fixes

- Fixed XNL multi-command sessions: message ID now increments correctly across commands

## 2026.01.29

### Protocol implementation

- **XNL authentication** — Complete XNL challenge-response authentication for MOTOTRBO radios
- **XCMP protocol layer** — Full XCMP command/response implementation including CloneRead and typed data support
- **Multi-protocol support** — Programmer framework extended for TETRA, LTE, and ASTRO protocol families
- **Network radio detection** — USB-Ethernet (CDC ECM) discovery for modern MOTOTRBO radios

### Encryption

- Extracted MOTOTRBO CPS 2.0 encryption keys via CPS analysis
- Extracted Business Radio CPS keys for codeplug decryption
- All keys documented with source attribution in `CPSKeys.swift` and `XNLEncryption.swift`

### UI

- Radio status indicator (green when connected)
- Inspector panel layout adjustments
- Menu reorganization: Trunking merged into Advanced menu

### Documentation

- XCMP/XNL protocol whitepaper and spec
- Codeplug format documentation with field offsets

## 2026.01.28

- Initial README and MIT LICENSE

## 2026.01.23

- Initial project: macOS app scaffold with XcodeGen, welcome-first navigation flow
- 20+ radio model definitions added (XPR, APX, CP, CLP, DLR families)
- Project cleaned: tracked binaries removed, `.gitignore` updated

---

Motorola, MOTOTRBO, and related marks are trademarks of Motorola Solutions, Inc. RadioWriter is not affiliated with or endorsed by Motorola Solutions.
