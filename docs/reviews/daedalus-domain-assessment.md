# Domain UX Evaluation: MotorolaCPS (RadioWriter)

**Evaluator:** Daedalus - Domain UX Evaluator
**Domain Profile:** Radio Programming Software / DMR / MOTOTRBO
**Evaluation Date:** 2026-02-02
**Version/Build:** Current development build

---

## Executive Summary

MotorolaCPS (branded as "RadioWriter") is a macOS-native radio programming application targeting MOTOTRBO XPR-series radios. The app demonstrates **solid foundational architecture** with proper codeplug parsing, zone/channel management, and contact handling. However, it exhibits **significant domain convention gaps** that would immediately signal to experienced radio operators that this is not a production-ready professional tool.

**Key Strengths:**
- Native macOS experience (unlike Windows-only CPS 2.0)
- Modern SwiftUI interface with good accessibility support
- Correct use of core DMR terminology (zones, channels, contacts, time slots, color codes)
- Three-pane layout familiar to professionals

**Critical Gaps:**
- Missing essential power-user features (cloning, CSV import/export, backup workflows)
- No codeplug validation or error checking
- Missing RepeaterBook/DMR database integration
- No undo/redo functionality
- Limited keyboard shortcuts for power users
- Missing critical DMR workflow features (talkgroup management, RX group visualization)

**Verdict: IMPROVEMENTS NEEDED** - The app has excellent bones but requires substantial feature additions to be considered a viable CPS alternative.

---

## Domain Convention Compliance

### Conventions Honored (Strengths)

1. **Zone/Channel Hierarchy (Industry Standard)**
   - File: `ZoneChannelView.swift`
   - The three-pane layout (Zones | Channels | Detail) matches the mental model from CPS 2.0, CHIRP, and other programming tools
   - Zones displayed as folders with channel counts is correct convention

2. **DMR Terminology Accuracy**
   - Color Code (0-15) correctly named and bounded
   - Time Slot (1 or 2) properly presented as segmented control
   - Contact types (Private Call, Group Call, All Call) properly differentiated
   - RX Group Lists and Scan Lists are properly separated concerns

3. **Frequency Display Convention**
   - File: `RadioInputControls.swift:8-97`
   - Frequencies displayed in MHz with 5 decimal places (standard)
   - Step increment/decrement buttons match professional tool patterns
   - Both RX and TX frequencies shown with offset calculation

4. **Channel Type Differentiation**
   - Digital (waveform icon, blue) vs Analog (waveform.path icon, orange) is clear
   - Channel mode picker correctly offers Digital/Analog as primary choice
   - Appropriate settings shown/hidden based on mode (CTCSS/DCS for analog, Color Code/Timeslot for digital)

5. **Power Level Indication**
   - High (H, red badge) / Low (L, green badge) matches industry convention
   - Visual hierarchy makes power level immediately scannable in channel lists

### Conventions Violated (Critical Issues)

1. **Missing "Read Before Write" Safety Pattern**
   - Industry Standard: CPS tools ALWAYS prompt to read current codeplug before writing
   - Current: Write button enabled without explicit read confirmation
   - Impact: Risk of overwriting radio with incomplete/test data
   - File: `ContentView.swift:152-159`

2. **No Codeplug Backup/Clone Workflow**
   - Industry Standard: Clone Express feature in CPS 2.0 is heavily used
   - Current: Clone button exists but action is empty (`// Clone action`)
   - File: `ContentView.swift:161-165`
   - Impact: Professionals won't trust a tool that can't backup their work

3. **Missing Validation Before Write**
   - Industry Standard: CPS validates entire codeplug before programming
   - Current: No pre-write validation, error checking, or summary
   - Impact: Invalid configurations could brick a radio or cause RF interference

4. **Non-Standard Contact ID Entry**
   - Industry Standard: DMR ID lookup with auto-complete from database
   - Current: Raw numeric text field with no validation
   - File: `ZoneChannelView.swift:1003-1008`
   - Impact: Easy to enter invalid IDs, no helper for looking up callsigns

5. **Missing "Dirty" State Indicator**
   - Industry Standard: Show unsaved changes indicator (dot in window title, etc.)
   - Current: No visual indication of unsaved modifications
   - Impact: Users may lose work by closing without saving

### Missing Essential Patterns

1. **No Import/Export to CSV**
   - EVERY professional CPS offers CSV import/export for channels/contacts
   - This is mandatory for fleet management and sharing configurations
   - CHIRP's killer feature is one-click RepeaterBook import

2. **No DMR ID Database Integration**
   - Essential for amateur DMR: lookup callsign from DMR ID
   - Services: RadioID.net, DMR-MARC database
   - Should auto-populate contact names from IDs

3. **No RepeaterBook Integration**
   - Amateur operators expect to query nearby repeaters
   - CHIRP and RT Systems both support this
   - Critical for rapid codeplug building

4. **No Template/Starter Codeplug Library**
   - New users need example configurations to start from
   - Community codeplugs are a huge part of DMR onboarding

5. **No Firmware Version Checking**
   - CPS 2.0 validates firmware compatibility before operations
   - Mismatch can cause codeplug corruption

---

## Practitioner Workflow Assessment

### Workflow Efficiency

**Rating:** Adequate - Significant Friction Detected

The app handles basic browse/edit workflows but falls short on the batch operations and data import patterns that professionals rely on daily.

### Common Task Analysis

| Task | Industry Standard | RadioWriter Current | Friction Points |
|------|-------------------|---------------------|-----------------|
| **Add 50 repeater channels** | Import CSV from RepeaterBook in 30 seconds | Manual entry one-by-one | No import functionality |
| **Clone radio to 10 identical units** | Clone Express workflow | Not implemented | Clone button empty |
| **Backup before editing** | Automatic prompt, one-click backup | Manual, no dedicated backup workflow | Risk of data loss |
| **Look up contact by callsign** | Type callsign, auto-complete with DMR ID | Must know DMR ID, no lookup | Knowledge barrier for beginners |
| **Add talkgroup to multiple channels** | Batch edit selected channels | Edit each channel individually | Repetitive work |
| **Verify codeplug before write** | Automatic validation with error list | None | Potential for invalid configs |
| **Undo accidental change** | Cmd+Z standard | Not implemented | No recovery from mistakes |

### Keyboard-First Usability

**Current Keyboard Support:**
- Cmd+R: Read from radio (good)
- Cmd+Shift+W: Write to radio (good)
- Cmd+D: Clone (assigned but not functional)
- Escape/Return: Standard sheet interactions

**Missing Power-User Shortcuts:**
- No keyboard navigation between zones/channels
- No quick-jump to channel by number
- No keyboard shortcut for adding channels/contacts
- No Cmd+Z/Shift+Cmd+Z for undo/redo
- No Cmd+F for finding channels by name/frequency

---

## Interaction Fidelity

### Controls Behave as Expected

1. **Frequency Stepper Controls** (`RadioInputControls.swift:8-97`)
   - Plus/minus buttons with configurable step size
   - Direct numeric input with MHz units
   - Proper bounds checking

2. **Timeslot Segmented Control** (`RadioInputControls.swift:196-223`)
   - Binary choice (TS1/TS2) presented as segmented picker
   - Matches professional tool convention

3. **Color Code Picker** (`RadioInputControls.swift:170-192`)
   - All 16 values (0-15) available in dropdown
   - Prefixed with "CC" for clarity

4. **CTCSS/DCS Pickers** (`RadioInputControls.swift:99-168`)
   - Standard tone lists
   - DCS with polarity toggle (N/I)
   - Correct octal display format for DCS (D023, D754, etc.)

### Controls Behave Differently (Minor Issues)

1. **Channel Name Length**
   - CPS 2.0: Strict 16-character limit with visual counter
   - RadioWriter: No visible limit or character counter
   - File: `ZoneChannelView.swift:956` (TextField without maxLength)

2. **Contact ID Field**
   - CPS 2.0: Validates 1-16777215 range immediately
   - RadioWriter: Plain number field, validation unclear
   - File: `ZoneChannelView.swift:1003-1008`

3. **Zone Name Entry**
   - CPS 2.0: Limited to 16 characters
   - RadioWriter: No visible limit
   - Files: `AddZoneSheet`, `RenameZoneSheet` in `ZoneChannelView.swift`

### Controls Missing or Non-Functional

1. **Undo/Redo Stack**
   - Critical for professional tools
   - No implementation found

2. **Clone Functionality**
   - Button exists, action is placeholder
   - File: `ContentView.swift:161-165`

3. **Multi-Select Editing**
   - Can't select multiple channels to edit properties in batch
   - Essential for fleet management

4. **Drag-and-Drop Reordering**
   - Channels in zones should be draggable
   - Current list doesn't support reordering (though `onMove` exists for scan list members)

5. **Search/Filter**
   - Search field exists in toolbar but appears decorative
   - No filtering of channels/contacts by search text

---

## Precision & Professional Requirements

### Measurement & Input

**Frequency Precision:**
- Display: 5 decimal places (e.g., 461.46250 MHz) - correct
- Input: Accepts full precision - correct
- Step options: Multiple step sizes available - correct

**Missing Precision Features:**
- No direct frequency entry validation against band limits
- No duplex offset shortcuts (e.g., "+5 MHz" standard offset button)
- No automatic offset calculation from frequency (amateur band plan lookup)

### Accuracy & Repeatability

**Concerns:**
1. No checksum or validation of codeplug before write
2. No "verify after write" functionality
3. No comparison between radio contents and pending changes
4. No serial number / radio tracking for fleet management

---

## Visual Testing Observations

*(Based on code review - live testing not performed)*

### Layout & Information Hierarchy

**Strengths:**
- Three-column NavigationSplitView matches macOS conventions
- Inspector panel provides contextual help
- Collapsible detail sections (DisclosureGroup) reduce overwhelm
- Clear visual distinction between digital and analog channels

**Concerns:**
- Channel list could show more info at a glance (e.g., TX offset, talkgroup)
- No visual indicator for channel mode (simplex vs repeater) in list
- Zone list doesn't show total channel count across all zones in header
- No progress/status for long codeplug reads

### Empty States

**Good:**
- ContentUnavailableView used appropriately throughout
- Clear calls-to-action ("Add Zone", "Add Channel", etc.)

**Could Improve:**
- No onboarding or first-time user guidance
- No links to documentation or help resources

---

## Domain-Specific Issues

### Critical (Blocks Professional Use)

1. **No Codeplug Backup/Restore Mechanism**
   - Every professional MUST backup before making changes
   - No file save dialog, no explicit backup workflow
   - Risk: Data loss is unrecoverable

2. **No Validation Before Write**
   - CPS 2.0 validates entire codeplug, shows error list
   - Missing: Duplicate channel names, invalid frequency ranges, orphaned references
   - Risk: Could program invalid configuration to radio

3. **No Write Verification**
   - After write, should read-back and compare
   - No verification that radio received correct data
   - Risk: Silent failures could cause operational issues

### High (Significant Friction)

4. **No CSV Import/Export**
   - Fleet managers need to bulk-edit in Excel
   - Amateur operators need RepeaterBook import
   - File: No import/export code found anywhere

5. **No DMR Database Integration**
   - Amateur DMR users rely on RadioID.net lookups
   - Contact list management without this is tedious
   - Should support downloading entire database for offline use

6. **No Undo/Redo**
   - Standard expectation in any editor
   - One wrong edit could corrupt hours of work

7. **Channel Editor Modal is Cumbersome**
   - Must open sheet to edit any property
   - Industry standard: inline editing or property inspector
   - File: `ChannelEditorSheet` in `ZoneChannelView.swift:940-1115`

### Medium (Deviates from Convention)

8. **Talkgroup Management Workflow Missing**
   - DMR users think in terms of talkgroups first, then channels
   - No dedicated talkgroup manager (separate from contacts)
   - Should support viewing "which channels use this talkgroup"

9. **RX Group Visualization**
   - Can't see which channels reference an RX Group List
   - No reverse lookup from contact to channels that use it
   - File: `RxGroupListsView.swift` - good but needs bidirectional links

10. **No Channel Cloning**
    - Common workflow: duplicate channel, change one frequency
    - Must manually recreate all settings

11. **Scan List Building UX**
    - Three-pane layout is good
    - Missing: drag-and-drop from channel list
    - Missing: visual indicator of scan priority

### Low (Minor Variance)

12. **Inspector Panel Underutilized**
    - Currently shows category descriptions only
    - Could show contextual help, validation warnings, quick stats

13. **No Dark Mode Optimization**
    - SwiftUI handles basic dark mode
    - No explicit styling for radio-specific visual elements

14. **Toolbar Density**
    - Professional tools often have more toolbar options
    - Could add: quick-add channel, frequency calculator, DMR ID lookup

---

## Platform vs Domain Tension

| Conflict | Platform Expectation (Apple HIG) | Domain Expectation (CPS/CHIRP) | Recommendation |
|----------|----------------------------------|--------------------------------|----------------|
| **Inspector location** | Right side trailing panel | Properties often on right, outliner on left (matches current) | Current layout is acceptable synthesis |
| **Modal editing** | Sheets for focused tasks | Inline editing, property inspectors | Consider inline editing for quick changes, keep sheet for full editor |
| **Keyboard shortcuts** | Standard Mac shortcuts | CPS uses function keys, custom shortcuts | Provide customizable shortcuts, default to Mac conventions |
| **Window layout** | Single window with navigation | CPS 2.0 has multiple floating windows | Single window is cleaner, matches modern tools like CHIRP |
| **Progress indication** | Determinate progress bars | CPS shows detailed operation log | Add progress indicator + optional detail log |

---

## Recommendations

### Immediate (Critical for Domain Credibility)

1. **Implement Codeplug Backup Workflow**
   - Add "Save As" with automatic timestamped backup
   - Add "Backup Before Write" prompt
   - Store backups in known location with radio serial number
   - Estimated effort: Medium

2. **Add Pre-Write Validation**
   - Validate all required fields populated
   - Check for duplicate names, invalid frequency ranges
   - Display error/warning list before allowing write
   - Estimated effort: Medium

3. **Implement CSV Import/Export**
   - Start with channels, then contacts
   - Use format compatible with CHIRP or CPS
   - Consider RepeaterBook query import
   - Estimated effort: High

4. **Add Undo/Redo Support**
   - Track changes to codeplug state
   - Standard Cmd+Z / Shift+Cmd+Z
   - Show undo history if possible
   - Estimated effort: Medium

### Short-term (Reduce Friction)

5. **DMR ID Database Integration**
   - Download RadioID.net database
   - Auto-complete contacts by callsign or ID
   - Show callsign in channel lists
   - Estimated effort: Medium

6. **Inline Channel Editing**
   - Allow editing common fields directly in channel row
   - Keep full editor sheet for advanced options
   - Estimated effort: Medium

7. **Implement Clone Functionality**
   - Clone channel within zone
   - Clone zone with all channels
   - Clone entire codeplug to new radio
   - Estimated effort: Medium

8. **Search/Filter Implementation**
   - Filter channels by name, frequency, type
   - Filter contacts by name, ID, type
   - Quick-jump to matching items
   - Estimated effort: Low

### Long-term (Enhance Domain Fidelity)

9. **RepeaterBook Integration**
   - Query API for nearby repeaters
   - One-click import to zone
   - Keep repeater data updated
   - Estimated effort: High

10. **Talkgroup-Centric View**
    - Dedicated talkgroup manager
    - Show which channels use each talkgroup
    - Support Brandmeister/DMR-MARC talkgroup lists
    - Estimated effort: High

11. **Fleet Management Features**
    - Multi-radio codeplug comparison
    - Batch programming multiple radios
    - Template-based codeplug generation
    - Estimated effort: Very High

12. **Codeplug Diff Tool**
    - Compare two codeplugs side-by-side
    - Show added/removed/changed items
    - Support merging changes
    - Estimated effort: High

### Optional (Nice-to-Have)

13. **Frequency Calculator Tool**
    - Offset calculator
    - Band plan reference
    - Part 95 frequency compliance checker

14. **Tutorial/Onboarding Mode**
    - First-launch wizard
    - Tooltips explaining DMR concepts
    - Sample codeplugs for common setups

15. **Export to Other Formats**
    - Support AnyTone, OpenGD77, CHIRP formats
    - Enable cross-platform codeplug sharing

---

## Comparison Reference

### Motorola CPS 2.0 (Official Tool)

**Strengths Relative to RadioWriter:**
- Complete feature coverage for all MOTOTRBO radios
- Robust validation and error checking
- Clone Express for fleet management
- Firmware management integrated
- Professional support available

**Weaknesses:**
- Windows-only (macOS users must use VM/Wine)
- Complex, overwhelming interface for beginners
- Requires Motorola account to download
- Separate software versions for different radio series

### CHIRP (Open Source)

**Strengths Relative to RadioWriter:**
- RepeaterBook integration (killer feature for amateurs)
- Spreadsheet-like channel editing (fast bulk changes)
- Supports 100+ radio models
- Cross-platform (macOS, Windows, Linux)

**Weaknesses:**
- No MOTOTRBO support (proprietary protocol)
- No DMR features (analog only)
- Interface is dated, not native Mac feel

### qdmr (Open Source DMR)

**Strengths Relative to RadioWriter:**
- Multi-vendor DMR support (including some Motorola)
- Cross-platform with good macOS support
- Device-independent codeplug format
- Repeater auto-completion
- Well-documented

**Weaknesses:**
- Limited MOTOTRBO support
- Less polished UI than RadioWriter
- Smaller community than CHIRP

### Lessons to Draw

1. **From CHIRP:** One-click repeater database import is essential for amateur adoption
2. **From CPS 2.0:** Pre-write validation prevents costly mistakes
3. **From qdmr:** Device-independent format enables sharing and backup
4. **From RT Systems:** Good keyboard shortcuts and batch editing justify premium pricing

---

## Verdict

**IMPROVEMENTS NEEDED**

### Justification

RadioWriter demonstrates solid technical foundations and a clean macOS-native interface that would appeal to users frustrated with Windows-only CPS. The core data model is correct, terminology is accurate, and the UI follows reasonable patterns.

However, the application lacks essential professional workflow features that every CPS user expects: backup/restore, validation, import/export, and undo/redo. An experienced radio operator would recognize within 30 seconds that this is an early-stage tool not ready for production use.

The app is positioned well for amateur radio DMR enthusiasts who want a Mac-native experience, but must address the critical gaps before professionals would trust it with their fleet configurations.

### Conditions for Domain Approval

Before this tool can be considered domain-approved for professional use:

- [ ] **Codeplug backup/restore workflow** implemented and tested
- [ ] **Pre-write validation** with error reporting
- [ ] **CSV import/export** for channels and contacts
- [ ] **Undo/redo** functionality
- [ ] **DMR ID database** integration (RadioID.net or similar)
- [ ] **Clone channel/zone** functionality
- [ ] **Search/filter** working in channel and contact lists

### Potential Differentiators

If the above conditions are met, RadioWriter could differentiate itself through:

1. **macOS-native experience** (no VM required for Mac users)
2. **Modern, clean UI** (vs. dated CPS 2.0 interface)
3. **RepeaterBook integration** (one-click local repeater import)
4. **Cross-platform codeplug format** (share between RadioWriter and other tools)
5. **Amateur-friendly** (DMR ID lookup, talkgroup management)

---

## Appendix: File Reference

### Core Views Evaluated

| File | Purpose | Key Issues |
|------|---------|------------|
| `ContentView.swift` | Main app layout | Clone action empty, no dirty indicator |
| `ZoneChannelView.swift` | Zone/channel management | Channel editor modal is cumbersome |
| `ContactsView.swift` | DMR contacts | No DMR ID lookup |
| `ScanListsView.swift` | Scan list management | Good layout, missing drag-drop |
| `RxGroupListsView.swift` | RX group management | Good but no reverse lookup |
| `GeneralSettingsView.swift` | Radio settings | Good coverage of settings |
| `WelcomeView.swift` | Startup screen | Good radio detection flow |
| `RadioInputControls.swift` | Custom input widgets | Well-implemented controls |

### Missing Components

| Expected Component | Industry Standard | Status |
|--------------------|-------------------|--------|
| CSV Import/Export | All CPS tools | Not implemented |
| Undo Manager | Standard editor | Not implemented |
| Validation Engine | CPS 2.0 | Not implemented |
| DMR Database Sync | qdmr, N0GSG Contact Manager | Not implemented |
| RepeaterBook Query | CHIRP | Not implemented |
| Codeplug Comparison | Fleet management tools | Not implemented |

---

*Evaluated by Daedalus - Domain UX Evaluator*
*"The master craftsman builds the tools he needs."*

---

## Sources Referenced

### Domain Research

- [DMR Codeplug Programming Basics](https://www.jeffreykopcak.com/2017/06/11/dmr-in-amateur-radio-programming-a-code-plug/)
- [Rocky Mountain Ham - Intro to DMR](https://www.rmham.org/intro-to-dmr/)
- [MOTOTRBO CPS 2.0 User Guide](https://www.radiotronics.co.uk/mototrbo-cps2-user-guide)
- [qdmr - Open Source DMR CPS](https://dm3mat.darc.de/qdmr/)
- [CHIRP Radio Programming](https://chirpmyradio.com/projects/chirp/wiki/Home)
- [BrandMeister Talkgroups](https://brandmeister.network/?page=talkgroups)
- [RadioID.net DMR Database](https://radioid.net/)
- [RT Systems Radio Programming](https://www.rtsystemsinc.com/)
- [N0GSG DMR Contact Manager](http://n0gsg.com/contact-manager/)
- [FCC Part 95 Personal Radio Services](https://www.ecfr.gov/current/title-47/chapter-I/subchapter-D/part-95)
