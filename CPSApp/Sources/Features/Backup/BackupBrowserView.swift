import SwiftUI

/// Browse, restore, and delete codeplug backups.
struct BackupBrowserView: View {
    @Environment(AppCoordinator.self) private var coordinator
    @Environment(\.dismiss) private var dismiss

    @State private var backups: [BackupInfo] = []
    @State private var selectedBackup: BackupInfo?
    @State private var showingDeleteConfirmation = false
    @State private var backupToDelete: BackupInfo?
    @State private var showingRestoreConfirmation = false
    @State private var backupToRestore: BackupInfo?
    @State private var errorMessage: String?
    @State private var showingError = false
    @State private var isRestoring = false

    var body: some View {
        NavigationStack {
            Group {
                if backups.isEmpty {
                    emptyStateView
                } else {
                    backupList
                }
            }
            .navigationTitle("Backup Browser")
            .frame(minWidth: 520, minHeight: 360)
            .toolbar {
                ToolbarItemGroup(placement: .primaryAction) {
                    Button {
                        coordinator.openBackupFolder()
                    } label: {
                        Label("Show in Finder", systemImage: "folder")
                    }
                    .accessibilityLabel("Open backup folder in Finder")

                    Button {
                        refreshBackups()
                    } label: {
                        Label("Refresh", systemImage: "arrow.clockwise")
                    }
                    .accessibilityLabel("Refresh backup list")
                }

                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .overlay {
                if isRestoring {
                    ProgressView("Restoring backup...")
                        .padding(24)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                }
            }
        }
        .onAppear { refreshBackups() }
        .confirmationDialog(
            "Delete Backup",
            isPresented: $showingDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                if let backup = backupToDelete {
                    deleteBackup(backup)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            if let backup = backupToDelete {
                Text("Delete \"\(backup.displayName)\" from \(backup.formattedDate)? This cannot be undone.")
            }
        }
        .confirmationDialog(
            "Restore Backup",
            isPresented: $showingRestoreConfirmation,
            titleVisibility: .visible
        ) {
            Button("Restore", role: .destructive) {
                if let backup = backupToRestore {
                    restoreBackup(backup)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            if let backup = backupToRestore {
                Text("Restore \"\(backup.displayName)\" from \(backup.formattedDate)? Unsaved changes to the current codeplug will be lost.")
            }
        }
        .alert("Error", isPresented: $showingError) {
            Button("OK") {}
        } message: {
            Text(errorMessage ?? "An unknown error occurred.")
        }
    }

    // MARK: - Subviews

    private var emptyStateView: some View {
        ContentUnavailableView {
            Label("No Backups", systemImage: "tray")
        } description: {
            Text("Backups are created automatically before writing to a radio, or manually via Radio > Backup Now.")
        } actions: {
            Button("Open Backup Folder") {
                coordinator.openBackupFolder()
            }
        }
    }

    private var backupList: some View {
        List(backups, selection: $selectedBackup) { backup in
            BackupRow(backup: backup)
                .tag(backup)
                .contextMenu {
                    if !backup.isParsedFormat {
                        Button {
                            backupToRestore = backup
                            showingRestoreConfirmation = true
                        } label: {
                            Label("Restore", systemImage: "arrow.counterclockwise")
                        }
                    }

                    Button(role: .destructive) {
                        backupToDelete = backup
                        showingDeleteConfirmation = true
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
        }
        .listStyle(.inset)
    }

    // MARK: - Actions

    private func refreshBackups() {
        do {
            backups = try coordinator.listBackups()
        } catch {
            errorMessage = error.localizedDescription
            showingError = true
        }
    }

    private func restoreBackup(_ backup: BackupInfo) {
        isRestoring = true
        Task {
            do {
                try await coordinator.restoreBackup(backup)
                await MainActor.run {
                    isRestoring = false
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    isRestoring = false
                    errorMessage = error.localizedDescription
                    showingError = true
                }
            }
        }
    }

    private func deleteBackup(_ backup: BackupInfo) {
        do {
            try coordinator.deleteBackup(backup)
            refreshBackups()
            if selectedBackup?.id == backup.id {
                selectedBackup = nil
            }
        } catch {
            errorMessage = error.localizedDescription
            showingError = true
        }
    }
}

// MARK: - Backup Row

private struct BackupRow: View {
    let backup: BackupInfo

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: backup.isParsedFormat ? "doc.text" : "doc.badge.gearshape")
                .font(.title2)
                .foregroundStyle(backup.isParsedFormat ? .secondary : Color.blue)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(backup.displayName)
                        .font(.headline)

                    if backup.isParsedFormat {
                        Text("Text")
                            .font(.caption2)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(.secondary.opacity(0.15))
                            .clipShape(Capsule())
                    }
                }

                Text(backup.formattedDate)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text(backup.formattedSize)
                .font(.caption)
                .foregroundStyle(.tertiary)
                .monospacedDigit()
        }
        .padding(.vertical, 4)
    }
}
