# ``RadioCore``

Foundation types for the RadioWriter codeplug data model, binary I/O, serialization, and field value transforms.

## Overview

RadioCore is the lowest-level package in RadioWriter. It defines the universal data model that every radio model, hardware driver, and UI layer builds on. It has no dependencies on other RadioWriter packages.

The central type is ``Codeplug``, an `@Observable` class holding raw binary data and providing bit-accurate field access via ``FieldDefinition``. Every radio stores its configuration as a flat binary blob; RadioCore gives that blob a typed, validated interface.

### Data Model

A codeplug is organized as a tree of ``CodeplugNode`` objects. Each node represents either a named group of fields (for example, *General Settings*) or a repeating section (for example, *Channels*, which repeats N times at a fixed stride). Leaf nodes contain ``FieldDefinition`` values that describe the type, bit offset, and validation rules of a single field.

Fields are read and written through ``Codeplug/getValue(for:)`` and ``Codeplug/setValue(_:for:)``. The `setValue` method validates the new value against the field's ``FieldConstraint`` before writing and returns a ``ConstraintResult``.

### Field Types

``FieldValueType`` enumerates every storage type a field can have:

- Integer scalars: `uint8`, `uint16`, `uint32`, `int8`, `int16`, `int32`
- `bool` (single bit)
- `string(maxLength:encoding:)` — null-padded fixed-length strings
- `bytes(count:)` — raw byte arrays
- `enumeration([EnumOption])` — named enum values stored as UInt16
- `bitField(bitCount:)` — arbitrary-width packed integer

All field types are represented at runtime by ``FieldValue``, a tagged-union enum that carries the concrete Swift value.

### Serialization

``CodeplugSerializer`` serializes codeplugs to and from RadioWriter's native `.cpsx` file format. The format has two versions:

| Version | Key derivation | Notes |
|---------|---------------|-------|
| v1 | SHA-256 (no salt) | Legacy — insecure, read-only support |
| v2 | PBKDF2-HMAC-SHA256, 100,000 rounds, 16-byte salt | Current default |

The binary layout of a `.cpsx` file is:

```
[Magic: "CPSX" 4 bytes]
[Format version: UInt16 LE]
[Metadata JSON length: UInt32 LE]
[Metadata JSON: UTF-8]
[Model identifier length: UInt16 LE]
[Model identifier: UTF-8]
[Encrypted flag: UInt8]
[Salt length: UInt16 LE]   ← v2 only
[Salt: N bytes]            ← v2 only
[Payload length: UInt32 LE]
[Payload: LZFSE compressed, optionally AES-256-GCM encrypted]
[Original data length: UInt32 LE]
```

Encryption uses AES-256-GCM via CryptoKit. Compression uses Apple's LZFSE algorithm from the system Compression framework.

### Binary Packing and Unpacking

For radio families whose codeplug fields do not align to byte boundaries, ``BinaryPacker`` and ``BinaryUnpacker`` provide bit-accurate write and read operations. Both types track a `bitPosition` cursor and support seeking to arbitrary bit or byte offsets.

Both types also expose ``BinaryPacker/writeField(_:definition:)`` and ``BinaryUnpacker/readField(definition:)`` which apply a ``FieldDefinition``'s type and offset automatically.

### Value Transforms

Radio binary formats often store values in hardware units that differ from the user-facing representation. The ``ValueTransform`` protocol formalizes the mapping:

| Transform | Raw type | Display type | Example |
|-----------|----------|--------------|---------|
| ``FrequencyTransform`` | `UInt32` (100 Hz units) | `String` (MHz) | `4625000 → "462.5000"` |
| ``PowerLevelTransform`` | `UInt8` (enum index) | `String` | `0x01 → "High"` |
| ``CTCSSToneTransform`` | `UInt8` (tone index) | `String` (Hz) | `12 → "100.0 Hz"` |
| ``InvertedBoolTransform`` | `Bool` | `Bool` | CPS "Disable*" fields |
| ``VersionTransform`` | `(UInt8, UInt8, UInt8)` | `String` | `(0x52, 3, 0) → "R03.00"` |
| ``LinearScaleTransform`` | `Int` | `String` | `7 → "47%"` |
| ``IdentityTransform`` | `T` | `T` | Pass-through |

## Topics

### Codeplug Model

- ``Codeplug``
- ``CodeplugMetadata``
- ``CodeplugNode``

### Field Definitions

- ``FieldDefinition``
- ``FieldValueType``
- ``FieldValue``
- ``FieldCategory``
- ``EnumOption``

### Validation

- ``FieldConstraint``
- ``ConstraintResult``

### Serialization

- ``CodeplugSerializer``
- ``SerializationError``

### Binary I/O

- ``BinaryPacker``
- ``BinaryUnpacker``

### Value Transforms

- ``ValueTransform``
- ``FrequencyTransform``
- ``PowerLevelTransform``
- ``CTCSSToneTransform``
- ``InvertedBoolTransform``
- ``VersionTransform``
- ``LinearScaleTransform``
- ``IdentityTransform``
