# Level 1 Diagnostic — radiowriter

**Date:** 2026-07-06
**Scope:** Full-ship sweep after the UI/UX rework (Save/Close, inspector, status strip, write-gating, channel Table, native List, SettingRow removal).
**Method:** macOS-adapted L1 (no iOS simulator phase — macOS app). Phase 1 integration gate (47 unit tests) + 3 parallel review agents (correctness/integration, architecture/security, stability/spec) + autonomous fix loop.

---

## Phase 1 — Integration gate: ✅ PASS
47 unit tests across RadioCore (35), RadioModels (6), RadioHardware (6) — all green. App + all packages build clean.

## Phase 2 — Parallel review findings

### 🔴 P0 — Data loss (FIXED in loop)
**P0-1 — Save silently writes an EMPTY .cpsx after a radio read.** *Found independently by BOTH the correctness and stability agents.* After Read-from-radio → edit → ⌘S, `saveDocument` serialized only the companion `Codeplug` whose `rawData` was empty (AppCoordinator.swift:1152-1156) — never `parsedCodeplug`. Valid-looking file, zero channel data, all edits lost on reopen. Save button was enabled, inviting it. Also: `markAsClean()` defined but never called → "Edited" never cleared after save.
→ **FIX:** Made the `ParsedCodeplug` graph `Codable`; parsed data now round-trips through `.cpsx` losslessly; `markAsClean()` called on save success. Round-trip unit test added.

### 🟢 P0 — Verified CLEAR
- **Write safety gate INTACT** — `writeCodeplug` throws `notImplemented` as its first statement, before any radio I/O. Traced every caller; UI rework created no bypass. A bricked radio is unreachable. (Confirmed by hand + architecture agent.)
- **Security** — no holes; `git ls-files` confirms zero proprietary Motorola binaries/decompiled source tracked (correctly gitignored).
- **P0-2 (file-backed dirty tracking)** — DOWNGRADED to non-issue: verified `FormEditorView`/`ChannelEditorView` mutate exclusively via `Codeplug.setValue`, so `hasUnsavedChanges` is accurate.

### 🟠 P1 — Wrong behavior (FIXED in loop)
- **P1-1 — Dirty flag flipped on no-op edits** (ParsedCodeplug not Equatable → didSet used a nil-check, not value comparison; undo-to-original still showed "Edited"). → **FIX:** ParsedCodeplug now Equatable; didSet gates on `oldValue != new`.
- **P1-2 — Inline detail-pane echo** — selecting a different channel fired every field's `.onChange` → spurious "Edit Channel" undo steps + false dirty. → **FIX:** `isSwitchingChannel` suppression flag guards `pushUpdate()` during the programmatic reset (mirrors the coordinator's `isUndoingOrRedoing` pattern).

### 🟡 P2 — Minor (FIXED where trivial)
- **P2 — Dead TEA-key logger** (`printTestVectors`, never called, logged keys `privacy: .public`). → **FIX:** removed.
- **P2 — Manual-IP entry unvalidated** (robustness, not security — `NWEndpoint.Host` is injection-safe). → **FIX:** Connect gated on valid IPv4 format with a hint.
- **P2-3 — Stale `selectedCategory`** not reconciled against `visibleCategories`. → **FIX:** `.onChange(of: visibleCategories)` snaps selection to a valid category.

### ⚪ P3 — Logged, not fixed (correct for L1)
- AppCoordinator trending toward god-object (1730 lines) — maintainability trajectory, not a bug. Suggested seams: BackupManager, CSVImportExportController, move CodeplugComparator out.
- Table `#` column non-monotonic under a non-index sort (cosmetic).
- P1-1 (serial-radio read lands in a different editor) — spec gap for serial radios; the XPR/network path (the user's radio) is wired end-to-end and correct.

---

## Read→Edit→Save→Write verdict
- **Read (XPR/network):** ✅ end-to-end
- **Edit (zones/channels):** ✅ undoable, bounds-safe, a11y preserved
- **Save:** ✅ FIXED — parsed data now persists losslessly (was P0 data-loss)
- **Write to radio:** ✅ honestly gated (refuses, never silently fails; safety gate un-bypassable)

## Accessibility: ✅ no regression
Rotors intact; new controls (Table, status strip, inspector, Save/Close) all carry labels; color never the sole signal.

---

## Fix-loop status — ✅ CONVERGED (1 cycle)

All P0/P1/P2 findings fixed and re-verified. No new issues introduced.

**Re-verification gate (all green):**
- Full app build: **BUILD SUCCEEDED**
- Test suite: **50 tests pass** (RadioCore 35, RadioModels 6 + 3 new round-trip, RadioHardware 6) — including the new `ParsedCodeplugRoundTripTests` (lossless Codable round-trip, rawData-bridge round-trip, binary-not-misdetected) that proves the P0 fix.

**Safety invariants re-confirmed after all churn:**
- ✅ Write gate intact (throw is first statement in `writeCodeplug`, no bypass)
- ✅ `markAsClean()` now called on save success (dirty flag clears)
- ✅ Zero empty-action / dead controls
- ✅ Dirty flag gates on `oldValue != new` (Equatable)
- ✅ Inline-edit echo suppressed (`isSwitchingChannel` / `pushUpdate()`)

**Verdict: PASS.** The Read→Edit→Save→Write loop is now genuinely complete and safe. The one P0 (data-loss on save) that the rework had introduced is fixed with a proving test. Write remains correctly gated; the radio cannot be bricked.

**Deferred (P3, non-blocking, logged for future):** AppCoordinator decomposition (god-object trajectory); Table `#` column relabel under non-index sort; serial-radio read → parsed-editor path (XPR/network path is complete).
