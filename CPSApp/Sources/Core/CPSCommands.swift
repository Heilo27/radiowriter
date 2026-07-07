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

        // Save / Save As — the core persistence commands.
        CommandGroup(replacing: .saveItem) {
            Button("Save") {
                coordinator?.save()
            }
            .keyboardShortcut("s", modifiers: [.command])
            .disabled(!hasCodeplug)
            .accessibilityLabel("Save codeplug")

            Button("Save As...") {
                coordinator?.saveAs()
            }
            .keyboardShortcut("s", modifiers: [.command, .shift])
            .disabled(!hasCodeplug)
            .accessibilityLabel("Save codeplug to a new file")

            Divider()

            Button("Close") {
                coordinator?.closeDocument()
            }
            .keyboardShortcut("w", modifiers: [.command])
            .disabled(!hasCodeplug)
            .accessibilityLabel("Close and return to the welcome screen")
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

            Button("Backup Now") {
                guard let coord = coordinator else { return }
                do {
                    if coord.parsedCodeplug != nil {
                        try coord.createBackup(source: .parsedCodeplug)
                    } else {
                        try coord.createBackup(source: .currentDocument)
                    }
                } catch {
                    coord.connectionState = .error(error.localizedDescription)
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

                Divider()

                Button("Download Channel Template...") {
                    coordinator?.showingExportChannelTemplateDialog = true
                }
                .accessibilityLabel("Download empty channel CSV template with headers and example rows")

                Button("Download Contact Template...") {
                    coordinator?.showingExportContactTemplateDialog = true
                }
                .accessibilityLabel("Download empty contact CSV template with headers and example rows")
            }

            Divider()

            Button("DMR ID Lookup") {
                coordinator?.showingDMRIDLookup = true
            }
            .keyboardShortcut("l", modifiers: [.command, .option])
            .accessibilityLabel("Look up DMR IDs from RadioID.net database")
        }

        // Help menu additions
        CommandGroup(after: .help) {
            Divider()

            Button("Keyboard Shortcuts") {
                coordinator?.showingKeyboardShortcuts = true
            }
            .keyboardShortcut("/", modifiers: [.command])
            .accessibilityLabel("Show keyboard shortcuts reference")

            Divider()

            Button("About RadioWriter") {
                coordinator?.showingAboutWindow = true
            }
            .accessibilityLabel("Show information about RadioWriter")
        }
    }
}
