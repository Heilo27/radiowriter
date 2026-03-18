# ``RadioModelCore``

Radio model registry, model definitions, and the parsed codeplug domain model for MOTOTRBO radios.

## Overview

RadioModelCore sits above RadioCore in the dependency stack. It defines what makes each supported radio unique — its codeplug size, channel count, frequency band, and the tree of field definitions that map binary offsets to named parameters.

### The RadioModel Protocol

Every supported radio is a concrete type conforming to ``RadioModel``. The protocol is purely static; there are no instances. It declares:

| Requirement | Purpose |
|-------------|---------|
| `identifier` | Stable machine string (e.g. `"CLP1010"`) |
| `displayName` | Human name shown in the UI (e.g. `"CLP 1010"`) |
| `family` | ``RadioFamily`` enum case |
| `codeplugSize` | Total binary size in bytes |
| `maxChannels` | Channel capacity |
| `frequencyBand` | ``FrequencyBand`` (name, lower/upper MHz, channel spacing kHz) |
| `nodes` | Root ``CodeplugNode`` array defining the field tree |
| `modelNumbers` | Hardware model number strings for auto-identification |
| `createDefault()` | Factory — returns a zeroed ``Codeplug`` |
| `validate(_:)` | Returns `[ValidationIssue]` |
| `applyDependencies(field:in:)` | Propagates inter-field effects |

### Registry

``RadioModelRegistry`` is the thread-safe (NSLock-guarded) global registry. Model types are registered at startup with ``RadioModelRegistry/register(_:)``. Lookups are by identifier string.

```swift
// Lookup a model type
if let modelType = RadioModelRegistry.model(for: "CLP1010") {
    let codeplug = modelType.createDefault()
}

// All models grouped by family
let grouped = RadioModelRegistry.byFamily
```

``RadioModelInfo`` is a value-type summary of a model suitable for populating list views. It includes a ``RadioModelInfo/Capabilities`` struct that tracks per-family read/write/verify support.

### Supported Radio Families

``RadioFamily`` lists every product family RadioWriter knows about:

| Case | Family code | Notes |
|------|------------|-------|
| `.apx` | APX | Read: experimental; Write: not implemented |
| `.clp` | CLP | Read + Write: stable |
| `.cp200` | CP200 | Read + Write: experimental |
| `.dlrx` | DLR | Read + Write: experimental |
| `.dtr` | DTR | Read + Write: experimental |
| `.fiji` | SL300 | Read + Write: experimental |
| `.nome` | RM | Read + Write: experimental |
| `.rdm` | RDM | Read + Write: experimental |
| `.renoir` | RMU | Read + Write: experimental |
| `.rmm` | RMM | Read + Write: experimental |
| `.solo` | RDU | Read + Write: experimental |
| `.sunb` | CLS | Read + Write: experimental |
| `.vanu` | VL/RDU4100 | Read + Write: experimental |
| `.xpr` | XPR | Read: stable; Write: in progress |

### Frequency Bands

``FrequencyBand`` provides named standard band ranges. Pre-defined values:

| Constant | Name | Range |
|----------|------|-------|
| `.uhf` | UHF | 400–470 MHz, 12.5 kHz spacing |
| `.vhf` | VHF | 136–174 MHz, 12.5 kHz spacing |
| `.frs` | FRS | 462.5625–467.7125 MHz, 12.5 kHz spacing |
| `.murs` | MURS | 151.82–154.6 MHz, 11.25 kHz spacing |
| `.dtr900` | 900 MHz ISM | 902–928 MHz, 12.5 kHz spacing |
| `.band700800` | 700/800 MHz | 764–870 MHz, 12.5 kHz spacing |

### Parsed Codeplug (MOTOTRBO Domain Model)

For MOTOTRBO radios (XPR, SL, DP, DM series), RadioModelCore provides ``ParsedCodeplug``: a strongly-typed Swift struct that mirrors the logical structure of the radio's configuration. This is the domain model used by `MOTOTRBOProgrammer` for reading and writing, and by the app layer for editing.

``ParsedCodeplug`` organizes settings into functional sections:

- **Device info** — model number, serial, firmware version (read-only from radio)
- **General settings** — radio ID, alias, intro screen, power-on password
- **Display settings** — backlight timing
- **Audio settings** — VOX, tones, audio enhancement
- **Timing** — TOT, group/private call hang time
- **Signaling** — radio check, remote monitor, emergency
- **GPS/GNSS** — positioning settings
- **Lone worker / Man down** — safety features
- **Zones and channels** — ``ParsedZone`` → ``ChannelData`` hierarchy
- **Contacts** — ``ParsedContact`` with DMR ID and call type
- **Scan lists** — ``ParsedScanList`` with priority channels
- **RX group lists** — ``ParsedRxGroupList``
- **Text messages** — ``PresetTextMessage`` (pre-programmed)
- **Emergency systems** — ``EmergencySystem``
- **Button assignments** — ``ButtonFunction`` per button × event

``ChannelData`` carries the full per-channel parameter set including DMR (color code, time slot, contact), analog (CTCSS/DCS), privacy/encryption, signaling, and MOTOTRBO-specific features.

### Validation

``ValidationIssue`` carries a ``ValidationIssue/Severity`` (`.error`, `.warning`, `.info`), an optional `fieldID`, and a human-readable message. Radio model types implement `validate(_:)` to check cross-field constraints that cannot be expressed as per-field ``FieldConstraint`` rules.

## Topics

### Protocol

- ``RadioModel``
- ``RadioModelRegistry``
- ``RadioModelInfo``

### Classification

- ``RadioFamily``
- ``FrequencyBand``
- ``ValidationIssue``

### MOTOTRBO Domain Model

- ``ParsedCodeplug``
- ``ChannelData``
- ``ParsedZone``
- ``ParsedContact``
- ``ContactCallType``
- ``ParsedScanList``
- ``ScanListMember``
- ``ParsedRxGroupList``
- ``PresetTextMessage``
- ``EmergencySystem``
- ``ButtonFunction``
