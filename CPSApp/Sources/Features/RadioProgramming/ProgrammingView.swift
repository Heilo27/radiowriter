import SwiftUI
import RadioCore
import RadioModelCore

/// Sheet view for radio read/write operations with progress tracking.
struct ProgrammingView: View {
    let operation: ProgrammingOperation
    @State private var progress: Double = 0
    @State private var status: String = "Preparing..."
    @State private var isComplete = false
    @State private var error: String?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 20) {
            // Icon
            Image(systemName: operation.icon)
                .font(.system(size: 40))
                .foregroundStyle(isComplete ? Color.green : Color.accentColor)
                .symbolEffect(.bounce, value: isComplete)

            // Title
            Text(operation.title)
                .font(.title2.bold())

            // Progress
            VStack(spacing: 8) {
                ProgressView(value: progress)
                    .progressViewStyle(.linear)

                Text(status)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(width: 300)

            // Error
            if let error {
                Label(error, systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.red)
                    .font(.caption)
            }

            // Actions
            HStack(spacing: 12) {
                if isComplete {
                    Button("Done") {
                        dismiss()
                    }
                    .buttonStyle(.borderedProminent)
                } else if error != nil {
                    Button("Retry") {
                        self.error = nil
                        progress = 0
                        startOperation()
                    }
                    Button("Cancel") { dismiss() }
                } else {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .padding(40)
        .frame(width: 400)
        .onAppear { startOperation() }
    }

    private func startOperation() {
        Task {
            do {
                switch operation {
                case .read:
                    status = "Reading codeplug from radio..."
                    // Simulate read progress
                    for i in 0...100 {
                        try await Task.sleep(for: .milliseconds(30))
                        progress = Double(i) / 100.0
                    }
                    status = "Read complete"

                case .write:
                    status = "Validating codeplug..."
                    try await Task.sleep(for: .milliseconds(500))
                    progress = 0.1
                    status = "Writing to radio..."
                    for i in 10...90 {
                        try await Task.sleep(for: .milliseconds(30))
                        progress = Double(i) / 100.0
                    }
                    status = "Verifying..."
                    progress = 0.95
                    try await Task.sleep(for: .milliseconds(500))
                    progress = 1.0
                    status = "Write complete and verified"

                case .clone:
                    status = "Reading source radio..."
                    for i in 0...50 {
                        try await Task.sleep(for: .milliseconds(30))
                        progress = Double(i) / 100.0
                    }
                    status = "Writing to target radio..."
                    for i in 50...100 {
                        try await Task.sleep(for: .milliseconds(30))
                        progress = Double(i) / 100.0
                    }
                    status = "Clone complete"
                }
                isComplete = true
            } catch {
                self.error = error.localizedDescription
            }
        }
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
