# Motorola CPS Reverse Engineering

**Status:** Active
**Created:** 2026-01-28
**Updated:** 2026-01-28

---

## Vision

Reverse engineer Motorola CPS (Customer Programming Software) to understand and document:
- Radio programming protocols
- Codeplug binary formats
- USB communication protocols
- Data structures and parameters

This enables interoperability research and cross-platform radio programming tools.

---

## Goals

1. **Document codeplug formats** for Business Radio series (.ctb/.rdt files)
2. **Map USB protocol** between CPS and radio hardware
3. **Identify encryption** used in programming/authentication
4. **Build parsing tools** for codeplug analysis

---

## Key Focus Areas

| Area | Priority | Status |
|------|----------|--------|
| Codeplug Format | High | Research |
| USB Protocol | High | Not Started |
| Data Model | Medium | Not Started |
| Encryption Analysis | Medium | Not Started |
| Tool Development | Low | Planning |

---

## Success Criteria

- [ ] Complete codeplug format documentation with byte-level detail
- [ ] USB protocol documented with command/response structures
- [ ] Working codeplug parser (read-only) in Swift or Python
- [ ] All findings documented with evidence and cross-references
