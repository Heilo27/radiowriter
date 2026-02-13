# TASK-082: Complete keyboard navigation support

**Status:** Pending
**Priority:** Medium
**Assignee:** Unassigned
**Created:** 2026-02-05
**Updated:** 2026-02-05
**Tags:** accessibility, keyboard
**Agent:** Lumen

---

## Description

Table and list views lack full keyboard navigation support. Power users and accessibility users rely on keyboard shortcuts for efficiency.

---

## Acceptance Criteria

- [ ] Cmd+A for select all in table views
- [ ] Space bar for selection toggle
- [ ] Return/Enter for editing selected row
- [ ] Delete key for removing selected items
- [ ] Cmd+C/V for copy/paste channels
- [ ] Tab navigation through form controls works correctly
- [ ] All keyboard shortcuts documented in Help menu

---

## Technical Notes

**Implementation approaches:**
- Use `.onKeyPress()` modifier for key handling
- Use `FocusState` for form navigation
- Register keyboard shortcuts in menu commands for discoverability

**Standard macOS shortcuts to support:**
- Navigation: Arrow keys, Home, End, Page Up/Down
- Selection: Cmd+A, Shift+Click, Cmd+Click
- Editing: Return (open), Delete (remove), Cmd+C/V (copy/paste)

---

## Blockers

None
