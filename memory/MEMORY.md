# RadioWriter Project Memory

## Project Overview
Native macOS CPS app for programming Motorola MOTOTRBO radios. Swift/SwiftUI, macOS 14+.
- **App target**: CPSApp (Xcode project)
- **Packages**: RadioCore, RadioModels, RadioHardware, AudioEngine
- **Protocol**: XCMP over XNL (TCP) for radio communication

## Architecture
- `AppCoordinator` (@Observable @MainActor) — central state, undo manager, document management
- `ParsedCodeplug` — domain model from radio reads (zones, channels, contacts, scan lists, rx groups)
- `CodeplugDocument` + `Codeplug` — traditional file-based document model
- Undo pattern: `updateZones/updateContacts/updateRxGroupLists/updateScanLists/updateGeneralSettings` methods register with UndoManager

## Key File Paths
- `CPSApp/Sources/Core/AppCoordinator.swift` (1277 lines) — coordinator, undo methods
- `CPSApp/Sources/Core/ContentView.swift` — main 3-column layout
- `CPSApp/Sources/Core/RootView.swift` — app shell
- `CPSApp/Sources/Features/Codeplug/` — per-category editing views
- `CPSApp/Sources/Features/RadioConfiguration/ChannelEditorView.swift` — Table-based channel editor
- `CPSApp/Sources/Services/DMRIDService.swift` — RadioID.net lookup, @MainActor singleton
- `Packages/RadioHardware/Sources/RadioProgrammer/` — XNL/XCMP protocol impl
- `Packages/AudioEngine/Sources/AudioEngine/VoicePromptManager.swift`

## SourceKit False Positives
`No such module 'RadioCore'` appears in SourceKit for CPSApp files. This is a false positive — RadioCore is a proper Xcode project dependency and compiles correctly. Do not chase these errors.

## Undo Pattern (Correct Way)
```swift
// Views must route mutations through coordinator methods
coordinator.updateContacts(newContacts, actionName: "Delete Contact")
coordinator.updateRxGroupLists(newLists, actionName: "Add RX Group")
coordinator.updateScanLists(newLists, actionName: "Edit Scan List")
coordinator.updateGeneralSettings({ $0.radioID = newValue }, actionName: "Edit Radio ID")

// WRONG — bypasses undo:
coordinator.parsedCodeplug?.contacts = newContacts
```

## Completed Fixes (Feb 2026 review session)

### Hardware Layer (agent a371c90df7dc5b0f9 — complete)
- XNLConnection: framed receive (length-prefix), removed 500ms per-command sleeps, socket close on auth failure
- XCMPProtocol: unknown opcode returns nil instead of silently mapping to radioStatusRequest
- RadioProgrammer: defer { state = .idle } on readCodeplug/writeCodeplug
- RadioModelRegistry: NSLock protecting mutable static dict
- VoicePromptManager: @MainActor, async URLSession read replacing blocking Data(contentsOf:)

### Direct Fixes (this session)
- XNLConnection: recv pointer arithmetic (withUnsafeMutableBufferPointer)
- ContentView: replaced stub body with real NavigationSplitView + .inspector()
- ChannelEditorView: replaced stub body with real Table() using existing ChannelRow/binding()

### Pending (agents running)
- Agent a3aab07eff9e1ecee: AppCoordinator fixes + view undo bypass (ContactsView, RxGroupListsView, ScanListsView, GeneralSettingsView, CSVImportView)
- Agent ae36bc26568af3020: DMRIDService, DMRIDLookupView, CPSCommands, CodeplugValidator, CodeplugSerializer, BackupBrowserView

## Known Issues (Not Yet Fixed)
- `cloneCodeplug()` in AppCoordinator is an empty stub
- VoicePromptManager.loadFromCodeplug() and packForRadio() are stubs (Speex encoding not implemented)
- Write path for ParsedCodeplug not implemented (blocks radio programming of parsed reads)
- RadioProgrammer 2-byte offset limit (64KB) — only affects radios with >64KB codeplugs

## Build Notes
- SwiftLint configured as build phase (`.swiftlint.yml` at repo root)
- os.Logger used throughout (no print() statements)
- Minimum target: macOS 14
