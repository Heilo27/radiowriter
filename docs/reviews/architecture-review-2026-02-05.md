# Architecture Review - MotorolaCPS

**Date:** 2026-02-05
**Reviewer:** Vulcan (Architecture Agent)
**Scope:** Full codebase architecture review

---

## Executive Summary

The MotorolaCPS project has a **solid foundational architecture** with proper package separation and dependency flow. However, the codebase has accumulated technical debt in the form of oversized files, duplicated domain models, and incomplete Swift 6 concurrency adoption. This review identified 11 new issues to track (TASK-076 through TASK-086).

### Overall Health: **B** (Good with notable issues)

| Category | Grade | Notes |
|----------|-------|-------|
| Package Structure | A | Clean boundaries, correct dependency flow |
| Dependency Management | A | No circular deps, packages isolated |
| Code Organization | C | Several god classes, duplicate models |
| Concurrency Safety | C | Mixed patterns, @unchecked Sendable |
| Technical Debt | C | Needs decomposition of large files |
| Test Coverage | C | Domain well tested, hardware layer lacking |

---

## Package Structure Analysis

### Current Architecture

```
Packages/
├── RadioCore/           ← Foundation (ZERO external dependencies)
│   └── DataModel, Binary, Serialization, Transform, Constants
├── RadioModels/         ← Depends on: RadioCore only
│   └── RadioModelCore + 16 radio family modules
├── RadioHardware/       ← Depends on: RadioCore, RadioModels
│   └── USBTransport, RadioProgrammer, Discovery
└── AudioEngine/         ← Independent (no package dependencies)
    └── VoicePromptManager

CPSApp/                  ← App layer (depends on all packages)
├── Core/               ← App entry, coordinators
├── Features/           ← Feature modules
├── Components/         ← Shared UI components
└── Services/           ← App-level services
```

### Dependency Flow: CORRECT

```
              CPSApp
                │
    ┌───────────┼───────────┐
    ▼           ▼           ▼
AudioEngine  RadioHardware  (direct)
                │
        ┌───────┴───────┐
        ▼               ▼
   RadioModels      (direct)
        │
        ▼
   RadioCore
```

**Verdict:** Package boundaries are well-enforced. No SwiftUI imports in domain packages. Dependencies flow correctly downward.

---

## Issues Found

### Critical (Blocks Ship Quality)

| ID | Issue | Location | Impact |
|----|-------|----------|--------|
| TASK-076 | Duplicate domain models (ParsedCodeplug vs XPRCodeplug) | RadioHardware + RadioModels | Maintenance burden, inconsistency |

### High Priority (Should Fix Soon)

| ID | Issue | Location | Impact |
|----|-------|----------|--------|
| TASK-077 | MOTOTRBOProgrammer is 1671 lines | RadioProgrammer/ | Hard to maintain/test |
| TASK-078 | XCMPProtocol.swift is 2898 lines | RadioProgrammer/ | Unmaintainable |
| TASK-079 | @unchecked Sendable violations | Multiple packages | Concurrency unsafety |

### Medium Priority (Plan for Sprint)

| ID | Issue | Location | Impact |
|----|-------|----------|--------|
| TASK-080 | Mixed concurrency patterns | RadioHardware, CPSApp | Hard to reason about safety |
| TASK-081 | Thread-unsafe RadioModelRegistry | RadioModelCore | Latent race condition |
| TASK-082 | AppCoordinator is 1462 lines | CPSApp/Core | SRP violation |
| TASK-083 | ZoneChannelView is 1555 lines | CPSApp/Features | UI maintenance burden |
| TASK-086 | Missing hardware test coverage | RadioHardware | Regression risk |

### Low Priority (Backlog)

| ID | Issue | Location | Impact |
|----|-------|----------|--------|
| TASK-084 | ObservableObject vs @Observable | DMRIDService | Inconsistency |
| TASK-085 | Untracked TODO comments | RadioProgrammerFactory | Forgotten work |

---

## File Size Analysis

Files exceeding recommended 500-line limit:

| File | Lines | Issue |
|------|-------|-------|
| XCMPProtocol.swift | 2898 | **5.8x over limit** - needs major decomposition |
| MOTOTRBOProgrammer.swift | 1671 | **3.3x over limit** - god class |
| ZoneChannelView.swift | 1555 | **3.1x over limit** - extract subviews |
| AppCoordinator.swift | 1462 | **2.9x over limit** - extract managers |
| XNLConnection.swift | 1083 | **2.2x over limit** - acceptable for protocol impl |
| RadioDetector.swift | 989 | **2x over limit** - borderline |
| RadioProgrammerFactory.swift | 976 | **2x over limit** - borderline |

---

## Concurrency Analysis

### Swift 6 Readiness: PARTIAL

The codebase uses a mix of:

1. **Modern Swift Concurrency (Good)**
   - `XNLConnection` - actor
   - `MOTOTRBOProgrammer` - actor
   - `USBConnection` - actor protocol
   - async/await throughout

2. **Legacy Patterns (Needs Migration)**
   - `DispatchQueue.global` in DMRIDService
   - `NSLock` in RadioDetector inner classes
   - `DispatchQueue` for NWConnection callbacks

3. **Unsafe Markers (Risk)**
   - 6 instances of `@unchecked Sendable`
   - Bypasses compiler safety checks
   - Potential for data races

### Recommendation

Adopt Swift 6 strict concurrency mode incrementally:
1. Enable strict concurrency per-module
2. Fix @unchecked Sendable violations
3. Migrate remaining DispatchQueue usage

---

## Strengths

1. **Clean Package Boundaries** - No boundary violations detected
2. **Protocol-Based Design** - RadioModel, USBConnection protocols enable extensibility
3. **Actor Usage** - Critical communication classes are actors
4. **Value Types** - Domain types (FieldDefinition, FrequencyBand) are properly Sendable
5. **Test Foundation** - Core binary packing/unpacking well tested
6. **Transform Layer** - Clean separation of binary/display values

---

## Recommendations

### Immediate (This Sprint)

1. **Consolidate Domain Models (TASK-076)**
   - Choose XPRCodeplug as canonical type
   - Make ParsedCodeplug a factory/builder
   - Reduces cognitive load and bug surface

2. **Decompose XCMPProtocol (TASK-078)**
   - Extract to 4 files: Client, Commands, PacketBuilder, ResponseParser
   - Each under 800 lines

### Next Sprint

3. **Fix @unchecked Sendable (TASK-079)**
   - Codeplug/XPRCodeplug: Consider @MainActor isolation with @Observable
   - Inner classes: Convert to actors

4. **Decompose God Classes (TASK-077, TASK-082)**
   - MOTOTRBOProgrammer: Extract domain types, parsing, AT commands
   - AppCoordinator: Extract managers for documents, backup, programming

### Backlog

5. **Standardize Concurrency (TASK-080)**
   - Create migration guide for DispatchQueue -> async/await
   - Document when NSLock is acceptable

6. **Increase Test Coverage (TASK-086)**
   - Add protocol abstractions for socket operations
   - Enable mocking of hardware communication

---

## Metrics

| Metric | Current | Target |
|--------|---------|--------|
| Max file size | 2898 lines | 800 lines |
| @unchecked Sendable count | 6 | 0 |
| Test coverage (estimated) | ~40% | 70% |
| Circular dependencies | 0 | 0 |
| SwiftUI in packages | 0 | 0 |

---

## Sign-off

This review identifies 11 architectural issues requiring attention. The package structure is sound, but the codebase needs file decomposition and concurrency modernization to achieve production quality.

**Vulcan** — Architecture Smith

---

*Tasks created: TASK-076 through TASK-086*
