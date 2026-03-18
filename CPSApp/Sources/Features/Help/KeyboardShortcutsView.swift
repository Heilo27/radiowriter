import SwiftUI

/// Displays all keyboard shortcuts available in the app.
struct KeyboardShortcutsView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    shortcutSection("Channel List", shortcuts: [
                        ("↑ / ↓", "Navigate channels"),
                        ("Return", "Edit selected channel"),
                        ("Space", "Edit selected channel"),
                        ("Delete", "Delete selected channel(s)"),
                        ("Cmd+A", "Select all channels"),
                        ("Cmd+C", "Copy selected channel"),
                        ("Cmd+V", "Paste copied channel"),
                        ("Cmd+Click", "Add to selection"),
                        ("Shift+Click", "Range select"),
                        ("Double-Click", "Open full channel editor"),
                    ])

                    shortcutSection("Zone List", shortcuts: [
                        ("↑ / ↓", "Navigate zones"),
                        ("Return", "Rename selected zone"),
                        ("Delete", "Delete selected zone"),
                    ])

                    shortcutSection("Contact List", shortcuts: [
                        ("↑ / ↓", "Navigate contacts"),
                        ("Return", "Edit selected contact"),
                        ("Delete", "Delete selected contact"),
                        ("Double-Click", "Open contact editor"),
                    ])

                    shortcutSection("Radio", shortcuts: [
                        ("Cmd+R", "Read from radio"),
                        ("Cmd+Shift+W", "Write to radio"),
                        ("Cmd+Shift+B", "Backup codeplug"),
                        ("Cmd+D", "Clone codeplug for fleet"),
                    ])

                    shortcutSection("Editing", shortcuts: [
                        ("Cmd+Z", "Undo"),
                        ("Cmd+Shift+Z", "Redo"),
                        ("Cmd+S", "Save codeplug file"),
                    ])

                    shortcutSection("Tools", shortcuts: [
                        ("Cmd+Option+L", "DMR ID Lookup"),
                        ("Cmd+Shift+P", "Generate report"),
                    ])

                    shortcutSection("Navigation", shortcuts: [
                        ("Tab", "Move to next form control"),
                        ("Shift+Tab", "Move to previous form control"),
                        ("Escape", "Close sheet or cancel"),
                        ("Cmd+/", "Show this shortcuts reference"),
                    ])
                }
                .padding()
            }
            .navigationTitle("Keyboard Shortcuts")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .frame(minWidth: 500, minHeight: 500)
    }

    @ViewBuilder
    private func shortcutSection(_ title: String, shortcuts: [(String, String)]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
                .foregroundStyle(.primary)

            VStack(spacing: 0) {
                ForEach(Array(shortcuts.enumerated()), id: \.offset) { index, shortcut in
                    HStack {
                        Text(shortcut.1)
                            .foregroundStyle(.primary)
                        Spacer()
                        Text(shortcut.0)
                            .font(.system(.body, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color.secondary.opacity(0.15), in: RoundedRectangle(cornerRadius: 5))
                    }
                    .padding(.vertical, 7)
                    .padding(.horizontal, 12)
                    .background(index % 2 == 0 ? Color.clear : Color.secondary.opacity(0.05))
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
            )
        }
    }
}

#Preview {
    KeyboardShortcutsView()
}
