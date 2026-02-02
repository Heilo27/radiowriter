import SwiftUI
import RadioCore

// MARK: - Focused Value Keys

struct FocusedAppCoordinatorKey: FocusedValueKey {
    typealias Value = AppCoordinator
}

extension FocusedValues {
    var appCoordinator: AppCoordinator? {
        get { self[FocusedAppCoordinatorKey.self] }
        set { self[FocusedAppCoordinatorKey.self] = newValue }
    }
}

/// App-level menu commands connected to the focused window's AppCoordinator.
struct CPSCommands: Commands {
    @FocusedValue(\.appCoordinator) var coordinator

    private var hasRadio: Bool {
        guard let coord = coordinator else { return false }
        return !coord.detectedDevices.isEmpty
    }

    private var hasCodeplug: Bool {
        coordinator?.parsedCodeplug != nil || coordinator?.currentDocument?.codeplug != nil
    }

    private var canReadRadio: Bool {
        guard let coord = coordinator else { return false }
        return coord.connectionState.isDisconnected && !coord.detectedDevices.isEmpty
    }

    private var canWriteRadio: Bool {
        hasCodeplug && hasRadio
    }

    var body: some Commands {
        // Replace the default Undo/Redo with codeplug-aware versions
        CommandGroup(replacing: .undoRedo) {
            Button("Undo \(coordinator?.undoActionName ?? "")") {
                coordinator?.undo()
            }
            .keyboardShortcut("z", modifiers: [.command])
            .disabled(coordinator?.canUndo != true)
            .accessibilityLabel("Undo last codeplug change")

            Button("Redo \(coordinator?.redoActionName ?? "")") {
                coordinator?.redo()
            }
            .keyboardShortcut("z", modifiers: [.command, .shift])
            .disabled(coordinator?.canRedo != true)
            .accessibilityLabel("Redo last undone change")
        }

        CommandGroup(after: .newItem) {
            Button("New from Template...") {
                // Open template picker
            }
            .keyboardShortcut("n", modifiers: [.command, .shift])
            .accessibilityLabel("Create new profile from template")

            Divider()

            Button("Import Legacy CPS File...") {
                // Import .cps file
            }
            .keyboardShortcut("i", modifiers: [.command, .shift])
            .accessibilityLabel("Import legacy CPS codeplug file")
        }

        CommandMenu("Radio") {
            Button("Read from Radio") {
                Task {
                    await coordinator?.readFromRadio()
                }
            }
            .keyboardShortcut("r", modifiers: [.command])
            .disabled(!canReadRadio)
            .accessibilityLabel("Read codeplug from connected radio")
            .accessibilityHint(hasRadio ? "Downloads the codeplug from the radio" : "Connect a radio first")

            Button("Write to Radio") {
                coordinator?.writeToRadioWithBackupPrompt()
            }
            .keyboardShortcut("w", modifiers: [.command, .shift])
            .disabled(!canWriteRadio)
            .accessibilityLabel("Write codeplug to connected radio")
            .accessibilityHint(hasCodeplug ? "Uploads the codeplug to the radio" : "Load or read a codeplug first")

            Divider()

            Button("Clone for Fleet") {
                coordinator?.cloneCodeplug()
            }
            .keyboardShortcut("d", modifiers: [.command])
            .disabled(!hasCodeplug)
            .accessibilityLabel("Clone codeplug for programming multiple radios")

            Button("Reset Radio") {
                // Reset
            }
            .disabled(!hasRadio)
            .accessibilityLabel("Reset radio to factory defaults")

            Divider()

            Button("Compare with Radio...") {
                // Diff view
            }
            .disabled(!hasCodeplug || !hasRadio)
            .accessibilityLabel("Compare codeplug with radio contents")

            Divider()

            Button("Backup Now") {
                guard let coord = coordinator else { return }
                do {
                    if coord.parsedCodeplug != nil {
                        try coord.createBackup(source: .parsedCodeplug)
                    } else {
                        try coord.createBackup(source: .currentDocument)
                    }
                } catch {
                    // Error handled by coordinator
                }
            }
            .keyboardShortcut("b", modifiers: [.command, .shift])
            .disabled(!hasCodeplug)
            .accessibilityLabel("Create backup of current codeplug")

            Button("Show Backups Folder") {
                coordinator?.openBackupFolder()
            }
            .accessibilityLabel("Open backup folder in Finder")
        }

        CommandMenu("Tools") {
            // CSV Import/Export
            Menu("Import") {
                Button("Channels from CSV...") {
                    coordinator?.showingImportChannelsDialog = true
                }
                .disabled(coordinator?.parsedCodeplug == nil)
                .accessibilityLabel("Import channels from CSV file")

                Button("Contacts from CSV...") {
                    coordinator?.showingImportContactsDialog = true
                }
                .disabled(coordinator?.parsedCodeplug == nil)
                .accessibilityLabel("Import contacts from CSV file")
            }

            Menu("Export") {
                Button("Channels to CSV...") {
                    coordinator?.showingExportChannelsDialog = true
                }
                .disabled(!hasCodeplug)
                .accessibilityLabel("Export channels to CSV file")

                Button("Contacts to CSV...") {
                    coordinator?.showingExportContactsDialog = true
                }
                .disabled(!hasCodeplug)
                .accessibilityLabel("Export contacts to CSV file")
            }

            Divider()

            Button("DMR ID Lookup") {
                coordinator?.showingDMRIDLookup = true
            }
            .keyboardShortcut("l", modifiers: [.command, .option])
            .accessibilityLabel("Look up DMR IDs from RadioID.net database")

            Button("Frequency Planner") {
                // Open frequency planner
            }
            .keyboardShortcut("f", modifiers: [.command, .option])
            .accessibilityLabel("Open frequency planning tool")

            Button("Fleet Overview") {
                // Open fleet overview
            }
            .accessibilityLabel("View fleet radio overview")

            Divider()

            Button("Generate Report...") {
                // Generate report
            }
            .keyboardShortcut("p", modifiers: [.command, .shift])
            .disabled(!hasCodeplug)
            .accessibilityLabel("Generate codeplug report")

            Button("Export to XML...") {
                // Export XML
            }
            .disabled(!hasCodeplug)
            .accessibilityLabel("Export codeplug to XML format")
        }

        // View menu additions
        CommandGroup(after: .sidebar) {
            Divider()

            Button("Show Inspector") {
                // Toggle inspector - would need additional FocusedValue for this
            }
            .keyboardShortcut("i", modifiers: [.command, .option])
            .accessibilityLabel("Toggle inspector panel")

            Button("Expand All Sections") {
                // Expand all disclosure groups
            }
            .accessibilityLabel("Expand all settings sections")

            Button("Collapse All Sections") {
                // Collapse all disclosure groups
            }
            .accessibilityLabel("Collapse all settings sections")
        }

        // Help menu additions
        CommandGroup(after: .help) {
            Divider()

            Button("Keyboard Shortcuts") {
                // Show keyboard shortcuts window
            }
            .keyboardShortcut("/", modifiers: [.command])
            .accessibilityLabel("Show keyboard shortcuts reference")

            Button("Radio Programming Guide") {
                // Open documentation
            }
            .accessibilityLabel("Open radio programming documentation")
        }
    }
}
