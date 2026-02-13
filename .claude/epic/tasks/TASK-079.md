# TASK-079: Optimize UTF-16LE string scanning in parseCodeplugRecordData

**Status:** Pending
**Priority:** High
**Assignee:** Unassigned
**Created:** 2026-02-05
**Updated:** 2026-02-05
**Category:** Performance

---

## Description

`MOTOTRBOProgrammer.parseCodeplugRecordData()` scans entire data buffers (up to 50MB) byte-by-byte looking for UTF-16LE strings. This is O(n*m) complexity and takes 500-800ms for large codeplugs.

**Current Impact:**
- Radio read operations take 30-60% longer than necessary
- Poor user experience with progress bars that stall during parsing
- Scales poorly with larger radio models (new XPR 8000 series)

---

## Acceptance Criteria

- [ ] Parsing time reduced by at least 50% for typical codeplugs
- [ ] Algorithm complexity reduced from O(n*m) to O(n)
- [ ] All existing channels and zones still extracted correctly
- [ ] Performance verified with Instruments (Time Profiler)
- [ ] Unit tests pass for existing sample codeplugs

---

## Technical Details

**Location:** `/Packages/RadioHardware/Sources/RadioProgrammer/MOTOTRBOProgrammer.swift` line 1220-1280

**Current Algorithm:**
- Scans byte-by-byte looking for UTF-16LE patterns
- No indexing or preprocessing
- Rescans overlapping regions

**Optimization Options:**

1. **Pre-index record boundaries** (preferred):
   - Parse record headers (0x81 0x00 0x00 0x80) first
   - Only scan within known data records
   - Reduces search space by ~80%

2. **Boyer-Moore string search**:
   - Skip ahead when pattern doesn't match
   - Better for large buffers

3. **SIMD vector search**:
   - Use Accelerate framework
   - Scan 16 bytes at once for UTF-16LE patterns

**Recommended:** Option 1 (pre-indexing) for best balance of complexity and performance.

---

## Blockers

None - existing fallback algorithm can remain as safety net

---

## Related Tasks

- TASK-079 (this task)
