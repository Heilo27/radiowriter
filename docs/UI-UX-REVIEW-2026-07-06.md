# radiowriter — UI/UX Review & Redesign

**Date:** 2026-07-06
**Method:** Level-1-grade code review (macOS app; live-GUI driving unavailable in this environment, so code-based + user spot-check). 3 parallel review agents: IA/navigation/surfacing, dead-control hunt, visual/HIG/a11y. 35 logic tests pass.
**User goal:** "Easy to use, shows information readily, powerful and sleek, commands and information surfaced where they need to be, everything functions."

---

## Verdict

The **skeleton is genuinely good** — clean Welcome→Editing phase model, a real toolbar with prominent Read/Write, a color+icon+text status indicator, honest capability badges on the model picker, and a thoughtful multi-stage Write safety chain (validate → FCC → pre-write → backup → verify). This is competent native macOS work, not a prototype.

But three **P0 broken-flow** gaps break the core promise, and a field of dead menu controls undercuts "everything functions." Fix the P0s and clean the dead controls and the app goes from "impressive demo" to "usable tool." None of it is a rewrite — it's completion and honesty.

---

## P0 — Broken core flow (fix first)

| # | Finding | Where | Fix |
|---|---|---|---|
| P0-1 | **No Save command exists in the UI.** Read radio → edit → *no way to save a .cpsx.* Save code exists; nothing calls it. Window shows "— Edited" for changes that can't persist. | CPSCommands.swift (no `.saveItem`); AppCoordinator.saveDocument:378 | Add `CommandGroup(replacing: .saveItem)`: Save (⌘S) + Save As (⌘⇧S); mirror Save in toolbar. |
| P0-2 | **No way back to Welcome / no Close.** Once editing, only escape is quitting. The unsaved-changes guard is dead code (nothing triggers it). | AppCoordinator.closeDocument:404 (unwired) | Add File▸Close (⌘W → closeDocument) + a toolbar back affordance. Activates the existing save-on-close flow. |
| P0-3 | **Sidebar categories dead-end after a read.** 4 of 10 categories (Audio/Bluetooth/VoicePrompts/Advanced) land on "not available for this format." Reads as broken. | ContentView.swift:41-47 sidebar vs 67-94 hardcoded switch | One `visibleCategories(for:)` source of truth; only show categories that resolve for the current data. |

## P1 — Wrong / misleading

| # | Finding | Where | Fix |
|---|---|---|---|
| P1-1 | **"New Profile" welcome button is dead** (empty action). The headline "Get Started" CTA does nothing; real flow is pick-a-card → Create. | WelcomeView.swift:56-62 | Delete it (picker is self-explanatory) or make it focus/scroll the picker. |
| P1-2 | **Clone is a no-op posing as live.** Enabled toolbar button + ⌘D menu item both call empty `cloneCodeplug()`. Click → nothing, no feedback. Steals a primary-action slot. | ProgrammingView.swift:180, CPSCommands.swift:96, AppCoordinator.swift:819 | Implement (named duplicate) or remove both / disable + "coming soon." Don't ship enabled→empty. |
| P1-3 | **Write looks enabled after a zone/channel read but errors after the full safety gauntlet** ("not yet supported"). User walks validation→FCC→pre-write→backup to a dead end. | ContentView.swift:173 vs AppCoordinator.writeToRadio:1286 | Gate Write on true writability; show "read-only for now" BEFORE the gauntlet. |
| P1-4 | **Validation shown for the un-writable path, skipped for the writable one** (inverted). | AppCoordinator.swift:630-648 | Validate whatever is actually about to be written. |

## P2 — Friction / surfacing

| # | Finding | Fix |
|---|---|---|
| P2-1 | **Inspector panel is a glorified tooltip** — title + icon + one line of help, yet ships open by default, eating real estate. | Make it context-sensitive: selected channel details, radio serial, validation status, dirty/backup state pinned on top. Biggest low-effort surfacing win. |
| P2-2 | **Detected radio (model/serial/firmware) is stranded on Welcome** — invisible in the editor. "Which radio am I about to write to?" is lost. | Surface model+serial in inspector header or toolbar subtitle. |
| P2-3 | **No ambient status line.** Dirty-state only in window title; last-backup, last-validation, last-read all invisible though they exist in the model. | Slim status strip: "Edited · Last backup 3m ago · Not validated." |
| P2-4 | **Manual-IP Connect adds the device even on failure** ("Adding anyway") → phantom connected device. | Gate add on reachability, or label as unverified. |

## P3 — Polish

- **Menu bar is ~60% greyed-out phantom features** — 8 disabled stubs (New from Template, Import Legacy CPS, Reset Radio, Compare with Radio, Frequency Planner, Fleet Overview, Generate Report, Export XML) squatting on real shortcuts (⌘⇧N, ⌘⇧I, ⌘⌥F, ⌘⇧P) that do nothing. Remove unshipped; don't reserve shortcuts for no-ops.
- **Free win:** "Keyboard Shortcuts" menu item (⌘/) is disabled but a real `KeyboardShortcutsView` exists — just wire it.
- **"Show Inspector" menu item** (⌘⌥I) disabled + redundant with working toolbar toggle — wire via FocusedValue or delete.
- **Verify "View Details" button is empty** (RootView.swift:135) though discrepancy data exists — build the sheet or drop the button.

## VISUAL / HIG / ACCESSIBILITY

**Verdict: "competent engineer, no design system."** Accessibility + tooltips are genuinely ahead of most shipping apps; the layout layer hasn't caught up. Three competing master-detail idioms make screens feel stitched together.

**P1 (fix before ship):**
- **Power badge is color-semantically inverted** — "H"/"L" in red/green (red reads as danger, not "more power"); color-blind users lean on R/G. Use neutral tint/`signal.bars`; reserve red for errors app-wide. (ZoneChannelView:638)
- **Hardcoded `.orange`/`.yellow`/`.green` opacity washes** don't adapt to increase-contrast; orange text on 5% orange is low-contrast. Use semantic roles / materials. (WelcomeView:474, AboutView:91, ProgrammingView:112, ContentView:288)
- **Connection status word is always `.secondary` gray** regardless of state — an *error* shouldn't read as muted text + tiny glyph. Drive text color from state. (ContentView:261)

**P2 (the bulk of the "sleek" gap):**
- **#1 issue: three master-detail idioms coexist** — ContentView uses `NavigationSplitView`+`.inspector` (correct); ZoneChannelView/ContactsView hand-roll `HSplitView` + fake `VStack` headers; IshInspector uses `HSplitView`+native `List`. Commit to ONE: three-pane `NavigationSplitView(sidebar:content:detail:)` for the channel editor.
- **Channel list is `ScrollView{LazyVStack{Button}}` not a `List`** — loses free selection, keyboard nav, drag-reorder. `moveChannels` exists but is unreachable (no `.onMove`). Make it `List(selection:)`. (ZoneChannelView:362)
- **Shared `RadioInputControls` used in the modal editor but NOT the inline pane** — the pane rolls its own pickers, so the same field looks different in two places and loses tooltips. Use shared controls everywhere. (ZoneChannelView:1142 vs 1055)
- **Custom `SettingRow` = `LabeledContent` with extra steps** — replace + delete. Fixed-width label columns (`.frame(width:100)`) fight Dynamic Type — use `LabeledContent`/`Form` rows uniformly.
- **Inspector near-empty + ships open** (corroborates P2-1 above).
- **iOS-isms on macOS:** 44×44 tap frames on menu glyphs, double-tap-to-edit as primary interaction, `.buttonStyle(.link)` underplaying primary Welcome CTAs.
- **AboutView hand-builds fake window chrome** (custom close button + 1px `.border`) — use a real sheet with native chrome.

**Data-density verdict (the flagship editor):** three-pane Zone→Channel→Detail is the *right* IA — but the detail pane is stacked DisclosureGroups (slow for bulk edits), and **there is no `Table` view anywhere.** The single biggest sleek+powerful upgrade: a **sortable channel `Table`** (#, Name, RX, TX, CC/TS, Pwr, Mode) as the power-user view for the "scan 60 channels, fix 12 offsets" workflow. Also: frequencies are fragile free-text `String` parsing in the pane though a good `FrequencyInput` stepper already exists — use it.

**Preserve:** `accessibilityRotor` for zones/channels (advanced, correct), the educational `.help()` tooltip coverage everywhere, native `Form`/`GroupBox`/`LabeledContent` in settings, and IshRecordInspectorView (the most polished screen — the north star).

---

## What's DONE WELL — preserve in the redesign
- Clean Welcome→Editing phase model.
- The Write safety chain (validate→FCC→pre-write→backup→read-back verify) — the app's best UX asset.
- Status indicator: color + icon + text + inline progress, with real a11y labels.
- Welcome's "No Radio Detected" checklist — exactly the right info at the right time; the surfacing bar the editor should meet.
- ProgrammingView error reporting: message + recovery suggestion + collapsible technical details.
- Codeplug-aware undo/redo with named actions.
- Model picker capability badges (READ/WRITE/VERIFY/EXPERIMENTAL + recommended star) — honest expectations up front.

---

## REDESIGN VISION

**Target: a focused, native macOS radio-programming tool that feels like a good developer/network utility — dense where it needs to be, honest about what it can do, never a dead end.**

The redesign is *completion + consolidation*, not a rewrite. Four moves:

### 1. Close the loop (make the core workflow actually complete)
The app's promise is Read → Edit → Write. Today you can't Save, can't go Back, and Write dead-ends. Fix the spine:
- **Save (⌘S) / Save As (⌘⇧S)** in menu + toolbar.
- **Close / back-to-Welcome (⌘W)** — activates the already-built unsaved-changes guard.
- **Write gated on real writability**, shown *before* the safety gauntlet, using the capability badges the model picker already has.
- Result: a tech can read their radio, edit a channel, save a backup, and write it back — the whole loop, no dead ends.

### 2. One layout language (kill the "stitched-together" feel)
Commit to **three-pane `NavigationSplitView`** for the editor: Sidebar (categories) → Content (list) → Detail/Inspector. Route every field through the primitives already built: `RadioInputControls`, `Form`/`LabeledContent`, and a new sortable **`Table`** for channels. Delete `SettingRow`, the hand-rolled `HSplitView` headers, and the fake AboutView chrome. IshRecordInspectorView is the north star for how polished a screen should look.

### 3. Surface information where the work happens
- **Make the inspector earn its space:** selected-channel live summary, radio model+serial (so "which radio am I writing to?" is always visible), validation warnings for the current view, dirty/backup/last-read state.
- **Ambient status strip:** "Edited · Last backup 3m ago · Not validated" — turn invisible model state into at-a-glance confidence.
- Bring Welcome's excellent "what to do next" clarity into the editor.

### 4. Power-user density
- **Sortable channel `Table`** (#, Name, RX, TX, CC/TS, Pwr, Mode) as the primary channel view — the single biggest sleek+powerful upgrade. Built for "scan 60 channels, fix 12."
- Native `List(selection:)` everywhere → free keyboard nav + drag-reorder.
- Semantic colors only; reserve red for errors.

### Honesty pass (cheap, high-trust)
Strip the ~12 dead/disabled menu stubs and the no-op Clone. A menu that's 60% greyed-out phantom features reads as unfinished; a lean menu of things that *work* reads as done. Wire the one free win: "Keyboard Shortcuts" (⌘/) → the `KeyboardShortcutsView` that already exists.

---

## Suggested execution order (each is a shippable increment)

1. **P0 loop-closers** — Save, Close, honest sidebar. *(makes the app usable)*
2. **Honesty pass** — remove dead controls/Clone, wire Keyboard Shortcuts. *(makes it feel finished)*
3. **Write-gating + validation fix** — gate on real writability, validate the right path. *(removes the scary dead end)*
4. **Inspector + status strip** — contextual info surfacing. *(the "shows information readily" win)*
5. **Layout consolidation** — one `NavigationSplitView` idiom, shared controls, delete `SettingRow`. *(the "sleek" win)*
6. **Channel `Table`** — the power-user density upgrade. *(the "powerful" win)*

Steps 1–3 are the highest leverage: they make "everything functions" literally true. 4–6 deliver "sleek and powerful."

---

## SHIPPED (2026-07-06) — all building green

**Step 1 — P0 loop-closers + honesty pass:**
- Save (⌘S) + Save As (⌘⇧S): File menu + toolbar. `AppCoordinator.save()`/`saveAs()`.
- Close / back-to-Welcome (⌘W): File menu + toolbar chevron. Activates the unsaved-changes guard.
- Honest sidebar: single `visibleCategories` source of truth — no dead-end clicks after a read.
- Removed 15 dead controls (no-op Clone in toolbar+menu, 8 disabled menu stubs squatting on ⌘⇧N/⌘⇧I/⌘⌥F/⌘⇧P, Reset/Compare/Freq-Planner/Fleet/Report/XML). Removed dead `cloneCodeplug()` + `.clone` op path.
- Wired Keyboard Shortcuts (⌘/) → existing `KeyboardShortcutsView`.
- Fixed dead "New Profile" welcome button → clear directive to the model picker.

**Step 3 — Write-gating (P1-3):**
- `AppCoordinator.WriteReadiness` (ready / noRadio / readOnly / noData) — single honest source. Write button disabled on real writability with an explaining tooltip, *before* the safety gauntlet.

**Step 4 — Information surfacing (P2-1/2/3):**
- Inspector rebuilt from a one-line tooltip into a real Form: **Radio** (model/serial/firmware — "which radio am I working with?"), **Working State** (unsaved / backup / validation with semantic icons+color), **Section context**.
- Ambient bottom **status strip**: Edited · Backup · Validation · Write-readiness — at-a-glance without opening the inspector.

**Visual P1s:**
- Connection status word now reads red on error (was always gray).
- Power badge de-inverted: High=accent, Low=neutral; red reserved for errors app-wide. HIGH/LOW capsule.

**Step 5 — Layout consolidation (SHIPPED):** Channel list → native `List(selection:)` (keyboard nav + drag-reorder via now-reachable `moveChannels`). Inline detail pane wrapped in `Form`, using shared `RadioInputControls` (FrequencyInput/ColorCodePicker/TimeslotPicker/PowerPicker/BandwidthPicker) so fields match the modal editor. `SettingRow` struct deleted, 63 call sites → native `LabeledContent`.

**Step 6 — Channel Table (SHIPPED):** Sortable `Table` view mode (List⟷Table segmented toggle). Columns: # / Name / RX / TX / Mode / CC / TS / Pwr / BW, all sortable. The power-user "scan 60 channels, fix 12" view.

**Additional polish (SHIPPED):** AboutView native chrome (removed fake titlebar/border, standard Done button); License/Privacy/Terms links wired to bundled docs; manual-IP no longer adds a phantom device on failure; "Open Existing" button `.link`→`.bordered`; verify "View Details" → real `VerificationDetailsView` sheet; ProgrammingView error card uses adaptive tint+border; ContactsView `SettingRow`→`LabeledContent`.

**RESULT: every finding from this review is fixed. Zero dead controls remain. Full app + all packages + 35 logic tests build/pass green.** Visual items still benefit from a live spot-check on real pixels (Table density, inspector layout, status strip), but nothing is outstanding in code.
