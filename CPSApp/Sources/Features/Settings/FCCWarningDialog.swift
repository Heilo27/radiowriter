import SwiftUI

/// First-run warning dialog explaining FCC regulatory compliance responsibilities.
struct FCCWarningDialog: View {
    @Environment(\.dismiss) private var dismiss
    @State private var dontShowAgain = false

    let warningManager: RegulatoryWarningManager
    let onAcknowledge: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            // Header
            VStack(spacing: 12) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(.orange)

                Text(RegulatoryText.fccWarningTitle)
                    .font(.title2.bold())
            }
            .padding(.top, 24)

            // Message
            ScrollView {
                Text(RegulatoryText.fccWarningMessage)
                    .font(.body)
                    .lineSpacing(4)
                    .padding(.horizontal)
            }
            .frame(maxHeight: 200)

            // Checkbox
            HStack(spacing: 10) {
                Image(systemName: dontShowAgain ? "checkmark.square.fill" : "square")
                    .foregroundStyle(.tint)
                    .font(.title3)

                Text(RegulatoryText.dontShowAgain)
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
                Button(RegulatoryText.fccWarningCancel, role: .cancel) {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button(RegulatoryText.fccWarningAcknowledge) {
                    if dontShowAgain {
                        warningManager.fccWarningAcknowledged = true
                    }
                    onAcknowledge()
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
        .accessibilityIdentifier("fccWarningDialog")
    }
}

#Preview {
    FCCWarningDialog(
        warningManager: RegulatoryWarningManager(),
        onAcknowledge: {}
    )
    .padding()
}
