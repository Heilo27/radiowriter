# TASK-084: Improve CSV import/export documentation and validation

**Status:** Pending
**Priority:** Medium
**Assignee:** Unassigned
**Created:** 2026-02-05
**Updated:** 2026-02-05
**Tags:** ux, documentation, import-export
**Agent:** Lumen

---

## Description

CSV import/export features lack documentation about expected format. Users must guess the format or have prior knowledge.

---

## Acceptance Criteria

- [ ] "Download Template" button added to export empty CSV with headers
- [ ] Format requirements shown before import (required columns, data format, example row)
- [ ] Specific error messages for malformed CSV: "Row 5: Frequency must be between 136-174 MHz"
- [ ] Link to full format specification document
- [ ] Preview includes format validation warnings

---

## Technical Notes

**Current state:**
✓ CSV import/export exists (CSVImportView)  
✓ Preview before import  
✗ No template download  
✗ No visible format documentation

**Recommendations:**
1. Template CSV with example row and comments
2. Inline format guide in import dialog
3. Row-specific error messages during validation
4. Color-coded preview (green=valid, yellow=warning, red=error)

**Format requirements to document:**
- Frequencies in MHz (e.g., 462.5625)
- Boolean values (true/false or 1/0)
- DMR IDs as integers
- Character limits for names

---

## Blockers

None
