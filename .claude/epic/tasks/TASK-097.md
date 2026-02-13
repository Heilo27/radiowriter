# TASK-083: Add contextual help tooltips for technical terms

**Status:** Pending
**Priority:** Medium
**Assignee:** Unassigned
**Created:** 2026-02-05
**Updated:** 2026-02-05
**Tags:** ux, help, onboarding
**Agent:** Lumen

---

## Description

Complex radio programming concepts lack in-context help for users unfamiliar with terminology. Technical terms appear without explanation.

---

## Acceptance Criteria

- [ ] All technical radio terms have .help() tooltips
- [ ] Help text is clear and non-technical where possible
- [ ] "?" info buttons added for complex sections
- [ ] In-app glossary created for reference
- [ ] First-time user onboarding tour implemented

---

## Technical Notes

**Terms requiring tooltips:**
- Color Code (DMR concept, not obvious to new users)
- Time Slot (DMR specific)
- CTCSS / DCS (Analog signaling tones)
- TOT (Timeout Timer)
- Talkaround
- ARS / ARTS
- Bandwidth (12.5 vs 25 kHz)

**Current state:**
✓ FormEditorView uses `.help()` modifier (good!)  
✗ Custom pickers in RadioInputControls lack help text

**Example implementation:**
```swift
ColorCodePicker(colorCode: $colorCode)
    .help("DMR Color Code filters interference from other nearby networks (0-15)")
```

---

## Blockers

None
