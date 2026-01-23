import SwiftUI

/// App-level menu commands.
struct CPSCommands: Commands {
    var body: some Commands {
        CommandGroup(after: .newItem) {
            Button("New from Template...") {
                // Open template picker
            }
            .keyboardShortcut("n", modifiers: [.command, .shift])

            Divider()

            Button("Import Legacy CPS File...") {
                // Import .cps file
            }
            .keyboardShortcut("i", modifiers: [.command, .shift])
        }

        CommandMenu("Radio") {
            Button("Read from Radio") {
                // Read radio
            }
            .keyboardShortcut("r", modifiers: [.command, .shift])

            Button("Write to Radio") {
                // Write radio
            }
            .keyboardShortcut("w", modifiers: [.command, .shift])

            Divider()

            Button("Clone Radio") {
                // Clone
            }

            Button("Reset Radio") {
                // Reset
            }

            Divider()

            Button("Compare with Radio...") {
                // Diff view
            }
        }

        CommandMenu("Tools") {
            Button("Frequency Planner") {
                // Open frequency planner
            }
            .keyboardShortcut("f", modifiers: [.command, .option])

            Button("Fleet Overview") {
                // Open fleet overview
            }

            Divider()

            Button("Generate Report...") {
                // Generate report
            }
            .keyboardShortcut("p", modifiers: [.command, .shift])

            Button("Export to XML...") {
                // Export XML
            }
        }
    }
}
