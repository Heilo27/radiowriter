# TASK-081: Add progress feedback for all long-running operations

**Status:** Pending
**Priority:** Medium
**Assignee:** Unassigned
**Created:** 2026-02-05
**Updated:** 2026-02-05
**Tags:** ux, feedback
**Agent:** Lumen

---

## Description

Some long operations lack progress feedback, leaving users uncertain if the app is working or frozen.

---

## Acceptance Criteria

- [ ] DMRIDLookupView "Refresh Database" button shows progress after click
- [ ] CSV import/export shows progress indication
- [ ] All operations > 1 second show ProgressView with descriptive text
- [ ] Estimated time shown where calculable
- [ ] Cancel option provided for long operations

---

## Technical Notes

**Missing progress indicators:**
- DMRIDLookupView: "Refresh Database" button (lines 51-56) gives no feedback
- CSV import/export operations
- Validation could show time estimate

**Good examples to follow:**
- ProgrammingView: Excellent progress with percentage and time estimate
- DMRIDLookupView loading state machine (lines 105-129)

---

## Blockers

None
