import SwiftUI
import RadioCore
import RadioModelCore

/// Sheet view for radio read/write operations with progress tracking.
/// Uses bindings from AppCoordinator to display real progress.
struct ProgrammingView: View {
    @Environment(AppCoordinator.self) private var coordinator
    @Environment(\.dismiss) private var dismiss

    /// Estimated total time for operation in seconds.
    private let estimatedTotalSeconds: Double = 15.0

    var body: some View {
        VStack(spacing: 20) {
            // Icon
            Image(systemName: coordinator.programmingOperation.icon)
                .font(.system(size: 40))
                .foregroundStyle(coordinator.programmingComplete ? Color.green : Color.accentColor)
                .symbolEffect(.bounce, value: coordinator.programmingComplete)

            // Title
            Text(coordinator.programmingOperation.title)
                .font(.title2.bold())

            // Progress
            VStack(spacing: 8) {
                ProgressView(value: coordinator.programmingProgress)
                    .progressViewStyle(.linear)

                Text(coordinator.programmingStatus)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                // Time estimate
                if !coordinator.programmingComplete && coordinator.programmingError == nil {
                    Text(timeRemainingText)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
            .frame(width: 300)

            // Error
            if let error = coordinator.programmingError {
                errorSection(message: error)
            }

            // Actions
            HStack(spacing: 12) {
                if coordinator.programmingComplete {
                    Button("Done") {
                        coordinator.finishProgrammingAndTransition()
                    }
                    .buttonStyle(.borderedProminent)
                } else if coordinator.programmingError != nil {
                    Button("Retry") {
                        Task {
                            switch coordinator.programmingOperation {
                            case .read:
                                await coordinator.readFromRadio()
                            case .write:
                                await coordinator.writeToRadio()
                            case .clone:
                                break // Not implemented yet
                            }
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    Button("Cancel") {
                        coordinator.cancelProgramming()
                    }
                } else {
                    Button("Cancel") {
                        coordinator.cancelProgramming()
                    }
                }
            }
        }
        .padding(40)
        .frame(width: 400)
        .interactiveDismissDisabled(!coordinator.programmingComplete && coordinator.programmingError == nil)
    }

    @ViewBuilder
    private func errorSection(message: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(message, systemImage: "exclamationmark.triangle.fill")
                .foregroundStyle(.red)
                .font(.callout.weight(.medium))

            if let suggestion = coordinator.programmingRecoverySuggestion {
                Text(suggestion)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if let details = coordinator.programmingErrorDetails {
                DisclosureGroup("Show Technical Details") {
                    Text(details)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .fontDesign(.monospaced)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 2)
                }
                .font(.caption)
            }
        }
        .padding(12)
        .background(Color.red.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .frame(maxWidth: 360, alignment: .leading)
    }

    private var timeRemainingText: String {
        let progress = coordinator.programmingProgress
        if progress < 0.05 {
            return "Estimating time..."
        }
        let elapsed = progress * estimatedTotalSeconds
        let remaining = max(0, estimatedTotalSeconds - elapsed)
        if remaining < 1 {
            return "Almost done..."
        }
        return "About \(Int(remaining)) seconds remaining"
    }
}

/// Types of programming operations.
enum ProgrammingOperation {
    case read
    case write
    case clone

    var title: String {
        switch self {
        case .read: return "Reading Radio"
        case .write: return "Writing Radio"
        case .clone: return "Cloning Radio"
        }
    }

    var icon: String {
        switch self {
        case .read: return "arrow.down.to.line"
        case .write: return "arrow.up.to.line"
        case .clone: return "doc.on.doc"
        }
    }
}
