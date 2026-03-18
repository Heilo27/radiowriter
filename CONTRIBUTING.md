# Contributing to RadioWriter

RadioWriter is an independent, open-source macOS application for programming Motorola MOTOTRBO radios. It is built via clean-room reverse engineering of the XCMP/XNL protocols.

Contributions are welcome. This project has strict legal and technical requirements that every contributor must understand before submitting work. Read this document in full. Read [LEGAL.md](LEGAL.md) for the complete legal framework.

---

## Table of Contents

1. [Clean-Room Requirements](#clean-room-requirements)
2. [NDA Disqualification](#nda-disqualification)
3. [Approved Information Sources](#approved-information-sources)
4. [What We Need](#what-we-need)
5. [What We Do Not Accept](#what-we-do-not-accept)
6. [Contributor Agreement](#contributor-agreement)
7. [Development Environment](#development-environment)
8. [Code Quality Standards](#code-quality-standards)
9. [Source Attribution](#source-attribution)
10. [Pull Request Process](#pull-request-process)
11. [Responsible Disclosure](#responsible-disclosure)
12. [Regulatory Reminder](#regulatory-reminder)

---

## Clean-Room Requirements

**This is the most critical section. Read it before writing a single line of code.**

This project employs clean-room reverse engineering methodology. The people writing implementation code must not have been exposed to the proprietary source they are reimplementing. Protocol analysis and Swift implementation are deliberately separated.

### The Core Rule

Do not contribute anything derived from knowledge obtained under NDA or from direct decompilation of Motorola CPS, TUNER, or radio firmware.

### Separation of Analysis and Implementation

If you are conducting binary analysis — reading decompiled IL, tracing CPS behavior, studying firmware — **do not simultaneously write Swift implementation for the same component.**

The required process:
1. Document findings in `docs/findings/` or `analysis/` (packet formats, field offsets, protocol behavior)
2. Implementation follows in a separate effort, based only on the documented findings, not the decompiled source

This separation is what makes the project legally defensible under DMCA Section 1201(f).

### Document Before Implementing

New protocol behavior should appear in `docs/` before it appears in Swift code. This makes the source of knowledge traceable and auditable.

### Flag Uncertainty

If you are unsure whether something is publicly available or proprietary, say so. Use `[NEEDS VERIFICATION]` in documentation, or ask in an issue before including it in code.

---

## NDA Disqualification

**If you have signed a Non-Disclosure Agreement with Motorola Solutions, Inc., do not contribute to this project.**

This includes:
- Current or former Motorola employees with access to CPS, radio firmware, or internal protocol documentation under NDA
- Partners or contractors who received proprietary Motorola protocol specifications under a confidentiality agreement
- Anyone who has accessed Motorola Radio Management, WAVE, or partner portal documentation under NDA terms

If you are uncertain whether your past employment or agreements disqualify you, do not contribute until you have consulted a lawyer.

**Prior exposure disclosure.** If you have previously reviewed decompiled Motorola CPS source code through other means (public leak, prior employer, etc.), disclose this when submitting protocol-sensitive contributions. In some cases it may be appropriate for you to contribute only to areas where that knowledge could not influence the implementation.

---

## Approved Information Sources

Contributions may only be derived from:

| Source | Examples |
|--------|----------|
| MIT-licensed open-source implementations | [Moto.Net](https://github.com/pboyd04/Moto.Net) (MIT), [xcmp-xnl-dissector](https://github.com/george-hopkins/xcmp-xnl-dissector), [codeplug](https://github.com/george-hopkins/codeplug) |
| Network/USB traffic analysis | Wireshark captures from your legitimately owned hardware |
| Published technical documentation | FCC filings, amateur radio community docs, manufacturer datasheets |
| Direct behavioral observation | Black-box testing of inputs/outputs on your own radio |

When using open-source references, note the license and link to the specific file or commit in your PR description.

### What Is Not an Approved Source

- Decompiled or disassembled Motorola CPS, TUNER, or firmware
- Motorola documentation obtained under NDA
- Screenshots or excerpts from Motorola internal documentation
- Information relayed from someone with NDA access

---

## What We Need

### Radio Model Definitions

Additional radio families are planned. Model definitions live in `Packages/RadioModels/Sources/`. Each family requires:
- A `*Model.swift` conforming to `RadioModel`
- A `*Fields.swift` with codeplug field definitions
- Tests in `Packages/RadioModels/Tests/`

Study an existing family (`XPRModel.swift`, `CLPModel.swift`) for the pattern. Open an issue before starting — coordinate so efforts are not duplicated.

### Hardware Testing

The project needs people with physical MOTOTRBO hardware to:
- Verify Wireshark captures match what the implementation sends and receives
- Test radio discovery and connection on hardware not yet validated
- Capture packet traces for unsupported radio families

Open an issue with your hardware model before doing this.

### macOS UI

The UI layer has not been started. It will be a SwiftUI macOS app targeting macOS 14.0+. Watch the issue tracker for when this opens up.

### Protocol Documentation

Packet traces or documented protocol behavior from approved sources are welcome in `docs/protocols/`. Documentation contributions carry the same clean-room requirements as code.

### Bug Reports

Open an issue with:
- Radio model and firmware version
- macOS version
- Expected vs. actual behavior
- Relevant log output (see Logging below)

---

## What We Do Not Accept

Do not submit:

- Code extracted or adapted from decompiled Motorola binaries
- Proprietary encryption keys, authentication constants, or seed values not already documented in this project
- Motorola firmware images, DLL files, or binary assets
- Screenshots or excerpts from Motorola proprietary documentation
- Information obtained under NDA with Motorola Solutions
- Third-party GPL-licensed code without explicit compatibility review (this project is MIT)

If a PR contains any of the above, it will be closed without merge.

If you are unsure whether something qualifies, open an issue and ask. The answer is usually: document the observation, not the proprietary artifact.

---

## Contributor Agreement

By submitting a pull request, you represent and warrant that:

1. Your contribution is original work or derived from properly licensed open-source code
2. You have **not** viewed, decompiled, or reverse-engineered Motorola CPS or firmware for the purpose of writing your contribution
3. You are **not** bound by any NDA with Motorola Solutions covering the subject matter of your contribution
4. You will **not** submit any proprietary Motorola code, binaries, or constants not already included in this project
5. You understand and accept the legal framework in [LEGAL.md](LEGAL.md)
6. You agree to license your contribution under the MIT License

This is not a CLA you sign — it is a representation you make by submitting. If you cannot make these representations truthfully, do not submit.

---

## Development Environment

### Requirements

| Tool | Minimum Version |
|------|----------------|
| macOS | 14.0 (Sonoma) |
| Xcode | 15.0 |
| Swift | 5.9 |
| SwiftLint | Latest |

Hardware is not required for most contributions. Protocol documentation, Swift package work, and model definitions can all be done without a physical radio.

### Setup

```bash
git clone https://github.com/Heilo27/radiowriter.git
cd radiowriter

# Install SwiftLint if not already installed
brew install swiftlint

# Build all packages
swift build --package-path Packages/RadioCore
swift build --package-path Packages/RadioModels
swift build --package-path Packages/RadioHardware
swift build --package-path Packages/AudioEngine

# Run tests
swift test --package-path Packages/RadioCore
swift test --package-path Packages/RadioModels
swift test --package-path Packages/RadioHardware
swift test --package-path Packages/AudioEngine
```

Or open any `Package.swift` in Xcode.

### Project Structure

```
Packages/
├── RadioCore/       # Foundation: types, utilities, error handling
├── RadioModels/     # Radio model definitions and codeplug schemas
├── RadioHardware/   # XCMP/XNL protocol implementation, USB transport
└── AudioEngine/     # Audio processing

docs/
├── protocols/       # XCMP/XNL spec, encryption details
├── codeplugs/       # Codeplug format documentation
└── findings/        # Timestamped research notes

analysis/            # Raw tool output (Wireshark captures, disassembly)
Moto.Net/            # MIT-licensed C# reference implementation
```

---

## Code Quality Standards

### SwiftLint

All source files in `Packages/*/Sources/` are linted via SwiftLint. Configuration is in [`.swiftlint.yml`](.swiftlint.yml).

Run lint before submitting:

```bash
swiftlint lint
```

PRs with SwiftLint errors will not be merged. The thresholds in `.swiftlint.yml` are tuned for this domain — protocol parsers legitimately have high cyclomatic complexity and long function bodies. Do not raise thresholds to suppress new warnings; fix the code or justify the exception in your PR.

Key rules:
- No `force_unwrap`, `force_cast`, or `force_try` without an inline comment explaining why it is safe
- No `print()` statements — use `os.Logger` (see below)
- `modifier_order` — access control must follow the enforced ordering
- Line length: warning at 160 characters, error at 300

### Logging

Use `os.Logger` via the `RadioLog` singleton in `RadioLogger.swift`. Never use `print()`.

```swift
// Correct
RadioLog.xcmp.debug("Received packet: \(data.hex)")
RadioLog.programmer.info("Connected to radio \(serialNumber)")
RadioLog.xnl.error("Authentication timeout after \(elapsed)ms")

// Wrong — SwiftLint will flag this
print("Connected")
```

Log level usage:
- `debug` — Protocol traces, hex dumps, raw packet contents. Stripped in release builds automatically by the OS.
- `info` — Connection events, session milestones.
- `error` — Protocol failures, connection drops, timeouts.

Do not log sensitive information (codeplug contents, authentication material) at `info` or above. Those levels survive in production logs.

Available log categories match the subsystem `com.heiloprojects.motorolacps`:

| Category | Usage |
|----------|-------|
| `usb` | USB transport: device enumeration, connect/disconnect |
| `xnl` | XNL connection: authentication, packet I/O |
| `xcmp` | XCMP protocol: commands, responses, opcode handling |
| `programmer` | High-level operations: identify, read codeplug |
| `crypto` | TEA encryption: key operations, test vectors |

### Error Handling

Use typed errors (`enum` conforming to `Error`) rather than untyped throws where callers need to distinguish failure modes. Protocol-level errors should propagate through the stack rather than being swallowed or logged and discarded.

Use `async`/`await` for asynchronous operations. No completion handler callbacks in new code.

### Testing

New protocol features require tests. Run the full suite before opening a PR:

```bash
swift test --package-path Packages/RadioCore
swift test --package-path Packages/RadioModels
swift test --package-path Packages/RadioHardware
swift test --package-path Packages/AudioEngine
```

All tests must pass. If a test fails for a reason unrelated to your change, open a separate issue rather than including a fix in your PR.

Existing test targets:
- `RadioCore/Tests/` — Binary packing/unpacking, codeplug serialization
- `RadioHardware/Tests/RadioHardwareTests/` — Mock connection layer, protocol unit tests
- `RadioHardware/Tests/IntegrationTests/` — Workflow tests (require hardware or mocks)
- `RadioModels/Tests/` — Model parsing

### Documentation Comments

Public API (types, methods, properties visible outside their module) must have Swift doc comments (`///`). Internal implementation does not require docs but benefits from inline comments explaining protocol-specific decisions.

---

## Source Attribution

Every piece of protocol knowledge in this project must be traceable to an approved source.

### In documentation

```markdown
**Source:** Observed via Wireshark USB capture during CPS read operation (2026-01-29)
**Source:** Derived from Moto.Net MIT-licensed implementation (pboyd04/Moto.Net, `XnlConnection.cs:142`)
**Source:** FCC filing ID IHDT6EXYR, Section 6.3
**Source:** Black-box behavioral testing — XPR 3500 + CPS 16.0
```

### In Swift code

```swift
// Source: Wireshark capture, CPS→radio during XCMP session initiation
let sessionInitOpcode: UInt16 = 0x0110

/// XNL authentication delta.
/// Source: Static analysis of XnlAuthentication.dll, obfuscated class `iq`, field `a`.
/// Cross-referenced against Moto.Net MIT-licensed reference.
static let teaDelta: UInt32 = 0x790AB771
```

### Unknown attribution

If you know the behavior but cannot attribute it, mark it explicitly rather than leaving it silent:

```markdown
**Source:** [NEEDS VERIFICATION] — behavior observed but source not documented
```

---

## Pull Request Process

1. **Open an issue first** for non-trivial changes. Discuss the approach before building it. This avoids wasted effort and legal review surprises. Protocol-sensitive proposals in particular benefit from upfront discussion.

2. **Fork the repository** and work on a feature branch:
   ```bash
   git checkout -b feature/radio-model-xpr7550
   git checkout -b fix/xcmp-auth-handshake
   git checkout -b docs/codeplug-clp-format
   ```

3. **Keep PRs focused.** One logical change per PR. A PR that adds a radio model, fixes a USB timeout, and refactors the serializer is three PRs.

4. **SwiftLint must pass** with no new errors.

5. **All tests must pass.**

6. **Include in the PR description:**
   - What does this change do?
   - What hardware or conditions did you test with?
   - For protocol changes: what are the information sources? Confirm clean-room compliance.

7. **Legal review is part of code review.** Protocol implementation PRs will be reviewed for clean-room compliance, not just correctness. Expect questions about sources. Thorough attribution speeds this up significantly.

PRs are merged by maintainers. There is no timeline guarantee.

---

## Responsible Disclosure

If you discover security vulnerabilities in MOTOTRBO radio systems during research:

1. Do not publicly disclose vulnerabilities that could endanger public safety communications
2. Report serious issues to Motorola Solutions through their official security disclosure channel before any public disclosure
3. Allow reasonable time for remediation — typically 90 days
4. Consider the safety implications: these radios are used by public safety agencies

For vulnerabilities in RadioWriter itself, open a GitHub issue marked `[SECURITY]` or contact the maintainer directly.

---

## Regulatory Reminder

Programming two-way radios is a licensed activity in most jurisdictions. Contributions that facilitate radio programming carry the same user responsibilities described in [LEGAL.md](LEGAL.md):

- Never configure radios for frequencies or power levels outside your license authority
- FCC Part 90/95/97 compliance is the user's responsibility, not the project's
- Amateur operators: encryption use is generally prohibited under 47 CFR § 97.113

Do not contribute codeplug templates or default configurations that would program radios outside normal licensed parameters.

---

## Questions

Open an issue. Legal questions related to contribution eligibility are taken seriously — ask before submitting if you are uncertain.

For the complete legal framework — DMCA Section 1201(f) basis, EU Directive 2009/24/EC, clean-room methodology details, encryption constants rationale — read [LEGAL.md](LEGAL.md) in full.

This project does not provide legal advice. Consult qualified counsel for your specific situation.

---

*RadioWriter is not affiliated with Motorola Solutions, Inc. MOTOROLA, MOTOTRBO, XCMP, XNL, and related marks are trademarks of Motorola Solutions, Inc.*
