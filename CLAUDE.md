# Motorola CPS - Reverse Engineering Project

> Reverse engineering Motorola Customer Programming Software to understand radio programming protocols, data formats, and codeplug structures.

---

## Project Overview

**Type:** Reverse Engineering / Protocol Analysis
**Target:** Motorola CPS (Customer Programming Software)
**Goal:** Understand and document radio programming protocols and codeplug formats

---

## Key Agents

| Agent | Role in This Project |
|-------|---------------------|
| **Specter** | Primary — Binary analysis, decompilation, symbol discovery |
| **Vulcan** | Architecture of any reimplementation efforts |
| **Prometheus** | Data format documentation, codeplug parsing |
| **Athena** | Knowledge capture of discovered protocols |
| **Clio** | Documentation of findings |

---

## Project Structure

```
MotorolaCPS/
├── CLAUDE.md              # This file
├── .claude/
│   └── PROJECT-CONTEXT.md # Detailed project context
├── analysis/              # Specter analysis outputs
├── docs/                  # Protocol documentation
│   ├── protocols/         # Communication protocols
│   ├── codeplugs/         # Codeplug format docs
│   └── findings/          # Research findings
├── tools/                 # Custom analysis tools
└── references/            # Reference materials
```

---

## Workflow

### Analysis Pipeline

```
1. IDENTIFY   → Locate binaries and components of interest
2. ANALYZE    → Use Specter for decompilation and symbol analysis
3. DOCUMENT   → Record findings in docs/
4. VERIFY     → Cross-reference with known behavior
5. IMPLEMENT  → Build tools/parsers as needed
```

### Key Focus Areas

- **Codeplug Format** — Binary structure of radio configuration files
- **USB Protocol** — Communication between CPS and radio hardware
- **Encryption** — Any crypto used in programming/authentication
- **Data Structures** — Internal representations of radio parameters

---

## Conventions

- Document all findings with evidence (hex dumps, traces, etc.)
- Use structured markdown for protocol documentation
- Tag unknowns clearly with `[UNKNOWN]` or `[NEEDS VERIFICATION]`
- Cross-reference official Motorola documentation where available
- Keep analysis reproducible — document tools and steps used

---

## Privacy & Legal

**See [LEGAL.md](LEGAL.md) for the full legal disclaimer, including reverse engineering compliance, regulatory warnings, and contribution guidelines.**

- This is for educational/interoperability research purposes under DMCA Section 1201(f) and EU Directive 2009/24/EC
- Follow clean-room methodology — separate analysis from implementation
- Follow responsible disclosure practices for any security findings
- Do not distribute proprietary binaries, encryption keys, or Motorola source code
- Focus on protocol documentation and interoperability
- Users are responsible for FCC Part 90/95/97 compliance when programming radios

---

## Quick Reference

```bash
# Analyze a CPS binary
/specter:analyze /path/to/CPS.app --focus storage

# Search knowledge base for prior findings
pantheon-kb search "motorola codeplug"

# Store a new finding
# Document in docs/findings/ and notify Athena
```
