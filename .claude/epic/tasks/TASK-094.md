# TASK-080: Improve error messages with actionable guidance

**Status:** Pending
**Priority:** Medium
**Assignee:** Unassigned
**Created:** 2026-02-05
**Updated:** 2026-02-05
**Tags:** ux, error-handling
**Agent:** Lumen

---

## Description

Error messages are often technical and don't provide clear next steps for users. System errors are shown directly without context or suggestions.

---

## Acceptance Criteria

- [ ] All error messages provide context-specific guidance
- [ ] Technical details hidden behind "Show Details" disclosure
- [ ] Concrete next steps suggested ("Try: Check USB connection")
- [ ] Error recovery actions provided where appropriate (Retry, Cancel, Get Help)
- [ ] Generic "unknown error" fallback eliminated or improved

---

## Technical Notes

**Current problematic examples:**
- `"Failed to open file: \(error.localizedDescription)"` (RootView:63)
- `"Could not reach radio at \(ipAddress)"` (WelcomeView:332)
- Generic fallback: `"An unknown error occurred"` (RootView:94)

**Improvement pattern:**
```swift
"""
Could not open codeplug file.

Try:
• Check the file isn't open in another app
• Verify the file isn't corrupted
• Ensure you have read permissions

Technical details: \(error.localizedDescription)
"""
```

---

## Blockers

None
