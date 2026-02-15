import SwiftUI

/// View displaying codeplug validation results before writing to radio.
struct ValidationResultsView: View {
    @Environment(AppCoordinator.self) private var coordinator
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Header summary
                validationHeader

                Divider()

                // Issue list
                if let result = coordinator.validationResult {
                    if result.issues.isEmpty {
                        successView
                    } else {
                        issuesList(result)
                    }
                } else {
                    ProgressView("Validating...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .navigationTitle("Pre-Write Validation")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Proceed to Write") {
                        coordinator.proceedFromValidation()
                    }
                    .disabled(coordinator.validationResult?.hasErrors ?? true)
                    .keyboardShortcut(.return)
                }
            }
        }
        .frame(minWidth: 500, idealWidth: 600, minHeight: 400, idealHeight: 500)
    }

    // MARK: - Header

    private var validationHeader: some View {
        HStack(spacing: 16) {
            if let result = coordinator.validationResult {
                // Status icon
                let iconName = result.hasErrors ? "xmark.circle.fill"
                    : (result.warnings.isEmpty ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                let iconColor = result.hasErrors ? Color.red : (result.warnings.isEmpty ? .green : .orange)

                Image(systemName: iconName)
                    .font(.system(size: 40))
                    .foregroundStyle(iconColor)

                VStack(alignment: .leading, spacing: 4) {
                    Text(result.hasErrors ? "Validation Failed" : (result.warnings.isEmpty ? "Validation Passed" : "Validation Warnings"))
                        .font(.headline)

                    Text(result.summary)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    if result.hasErrors {
                        Text("Fix errors before writing to radio")
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }

                Spacer()

                // Counts
                VStack(alignment: .trailing, spacing: 2) {
                    if !result.errors.isEmpty {
                        Label("\(result.errors.count)", systemImage: "xmark.circle.fill")
                            .foregroundStyle(.red)
                            .font(.callout)
                    }
                    if !result.warnings.isEmpty {
                        Label("\(result.warnings.count)", systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                            .font(.callout)
                    }
                    if !result.infos.isEmpty {
                        Label("\(result.infos.count)", systemImage: "info.circle.fill")
                            .foregroundStyle(.blue)
                            .font(.callout)
                    }
                }
            }
        }
        .padding()
        .background(Color(.windowBackgroundColor))
    }

    // MARK: - Success View

    private var successView: some View {
        ContentUnavailableView {
            Label("No Issues Found", systemImage: "checkmark.circle")
        } description: {
            Text("Your codeplug is ready to write to the radio.")
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Issues List

    private func issuesList(_ result: ValidationResult) -> some View {
        List {
            if !result.errors.isEmpty {
                Section {
                    ForEach(result.errors) { issue in
                        IssueRow(issue: issue)
                    }
                } header: {
                    Label("Errors", systemImage: "xmark.circle.fill")
                        .foregroundStyle(.red)
                }
            }

            if !result.warnings.isEmpty {
                Section {
                    ForEach(result.warnings) { issue in
                        IssueRow(issue: issue)
                    }
                } header: {
                    Label("Warnings", systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                }
            }

            if !result.infos.isEmpty {
                Section {
                    ForEach(result.infos) { issue in
                        IssueRow(issue: issue)
                    }
                } header: {
                    Label("Information", systemImage: "info.circle.fill")
                        .foregroundStyle(.blue)
                }
            }
        }
        .listStyle(.inset)
    }
}

// MARK: - Issue Row

struct IssueRow: View {
    let issue: ValidationIssue

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: issue.severity.icon)
                    .foregroundStyle(colorForSeverity)
                    .frame(width: 16)

                VStack(alignment: .leading, spacing: 2) {
                    Text(issue.message)
                        .font(.body)

                    if let location = issue.location {
                        Text(location)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            if let suggestion = issue.suggestion {
                HStack(spacing: 4) {
                    Image(systemName: "lightbulb")
                        .font(.caption)
                        .foregroundStyle(.yellow)
                    Text(suggestion)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.leading, 24)
            }
        }
        .padding(.vertical, 4)
    }

    private var colorForSeverity: Color {
        switch issue.severity {
        case .error: return .red
        case .warning: return .orange
        case .info: return .blue
        }
    }
}

#Preview {
    ValidationResultsView()
        .environment(AppCoordinator())
}
