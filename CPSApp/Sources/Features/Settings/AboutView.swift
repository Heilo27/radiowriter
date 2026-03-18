import SwiftUI

/// App About screen with version information, links, and regulatory disclaimers.
struct AboutView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            // Header with close button
            HStack {
                Text("About RadioWriter")
                    .font(.headline)
                Spacer()
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Close About window")
            }
            .padding()
            .background(Color(nsColor: .controlBackgroundColor))
            .border(Color.separator, width: 1)

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // App info
                    VStack(alignment: .center, spacing: 12) {
                        Image(systemName: "antenna.radiowaves.left.and.right")
                            .font(.system(size: 48))
                            .foregroundStyle(.tint)

                        VStack(spacing: 4) {
                            Text("RadioWriter")
                                .font(.title2.bold())

                            if let version = Bundle.main.appVersion {
                                Text("Version \(version)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)

                    Divider()

                    // Description
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Read, edit, and write codeplugs for Motorola digital radios.")
                            .font(.body)
                            .lineSpacing(2)

                        Text("RadioWriter enables users to configure frequency, power, contacts, and other settings on compatible Motorola radio models including MOTOTRBO, APX, and CLS series radios.")
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .lineSpacing(2)
                    }

                    Divider()

                    // Links
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Resources")
                            .font(.headline)

                        linkButton("Documentation", "book.circle", action: {
                            NSWorkspace.shared.open(URL(string: "https://github.com/radiowriter/docs")!)
                        })

                        linkButton("GitHub Repository", "square.and.arrow.up.right", action: {
                            NSWorkspace.shared.open(URL(string: "https://github.com/radiowriter")!)
                        })

                        linkButton("Issue Tracker", "ladybug.circle", action: {
                            NSWorkspace.shared.open(URL(string: "https://github.com/radiowriter/issues")!)
                        })

                        linkButton("Discuss with Community", "bubble.right.circle", action: {
                            NSWorkspace.shared.open(URL(string: "https://github.com/radiowriter/discussions")!)
                        })
                    }

                    Divider()

                    // Regulatory Section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("FCC Regulatory Compliance")
                            .font(.headline)
                            .foregroundStyle(.orange)

                        Text(RegulatoryText.aboutRegulatorySection)
                            .font(.body)
                            .lineSpacing(3)
                    }
                    .padding()
                    .background(Color.orange.opacity(0.05))
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                    Divider()

                    // Legal
                    VStack(alignment: .leading, spacing: 8) {
                        Text("License & Legal")
                            .font(.headline)

                        linkButton("License Agreement", "doc.circle", action: {
                            // Open license file or web link
                        })

                        linkButton("Privacy Policy", "hand.raised.circle", action: {
                            // Open privacy policy
                        })

                        linkButton("Terms of Service", "list.clipboard.circle", action: {
                            // Open terms of service
                        })
                    }

                    Divider()

                    // Credits
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Credits")
                            .font(.headline)

                        Text("RadioWriter is built with Swift and SwiftUI, powered by reverse engineering and protocol analysis of Motorola radio systems.")
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .lineSpacing(2)
                    }
                }
                .padding(24)
            }
        }
        .frame(minWidth: 500, maxWidth: 600, maxHeight: 700)
        .accessibilityIdentifier("aboutView")
    }

    @ViewBuilder
    private func linkButton(_ label: String, _ icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                    .font(.body)
                Text(label)
                    .font(.body)
                Spacer()
                Image(systemName: "arrow.up.right")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(.tint)
        .padding(.vertical, 4)
    }
}

extension Bundle {
    var appVersion: String? {
        infoDictionary?["CFBundleShortVersionString"] as? String
    }
}

#Preview {
    AboutView()
}
