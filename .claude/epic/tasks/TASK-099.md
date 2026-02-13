# TASK-085: Standardize loading states across views

**Status:** Pending
**Priority:** Medium
**Assignee:** Unassigned
**Created:** 2026-02-05
**Updated:** 2026-02-05
**Tags:** ux, consistency, feedback
**Agent:** Lumen

---

## Description

Loading states are inconsistent across views. Some show progress, others show nothing, leading to user uncertainty.

---

## Acceptance Criteria

- [ ] All views use consistent ProgressView styling
- [ ] Indeterminate ProgressView for unknown duration
- [ ] Determinate ProgressView(value:) with percentage for known progress
- [ ] Descriptive text accompanies all loading indicators ("Loading channels...")
- [ ] Controls disabled during loading
- [ ] Cancel option provided where appropriate

---

## Technical Notes

**Good examples:**
- ProgrammingView: Clear progress with percentage (lines 28-42)
- DMRIDLookupView: Good loading state (lines 109-118)

**Needs improvement:**
- WelcomeView: No loading indicator when scanning for radios
- ContactsView: Assumes instant loading
- General pattern missing for async operations

**Standard pattern:**
```swift
if isLoading {
    ProgressView("Loading channels...")
        .progressViewStyle(.linear)
} else {
    // Content
}
```

---

## Blockers

None
