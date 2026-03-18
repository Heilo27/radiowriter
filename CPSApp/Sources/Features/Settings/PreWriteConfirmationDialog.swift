import SwiftUI

/// Pre-write confirmation reminder about FCC compliance responsibilities.
struct PreWriteConfirmationDialog: View {
    @Environment(\.dismiss) private var dismiss
    @State private var dontShowAgain = false

    let warningManager: RegulatoryWarningManager
    let onContinue: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            // Header
            VStack(spacing: 12) {
                Image(systemName: "radiowaves.left.and.right")
                    .font(.system(size: 44))
                    .foregroundStyle(.tint)

                Text(RegulatoryText.preWriteTitle)
                    .font(.title2.bold())
            }
            .padding(.top, 24)

            // Message
            VStack(alignment: .leading, spacing: 12) {
                Text("Compliance Checklist")
                    .font(.headline)

                Text(RegulatoryText.preWriteMessage)
                    .font(.body)
                    .lineSpacing(4)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal)

            // Checkbox for "Don't show again"
            HStack(spacing: 10) {
                Image(systemName: dontShowAgain ? "checkmark.square.fill" : "square")
                    .foregroundStyle(.tint)
                    .font(.title3)

                Text("Don't show this reminder again")
                    .font(.body)

                Spacer()
            }
            .contentShape(Rectangle())
            .onTapGesture {
                dontShowAgain.toggle()
            }
            .padding(.horizontal)

            Divider()
                .padding(.vertical, 4)

            // Buttons
            HStack(spacing: 12) {
                Button("Cancel", role: .cancel) {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button(RegulatoryText.preWriteContinue) {
                    if dontShowAgain {
                        warningManager.preWriteWarningDismissed = true
                    }
                    onContinue()
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
            }
            .padding(.horizontal)
            .padding(.bottom, 20)
        }
        .frame(minWidth: 400, maxWidth: 500)
        .fixedSize(horizontal: false, vertical: true)
        .accessibilityIdentifier("preWriteConfirmationDialog")
    }
}

#Preview {
    PreWriteConfirmationDialog(
        warningManager: RegulatoryWarningManager(),
        onContinue: {}
    )
    .padding()
}
