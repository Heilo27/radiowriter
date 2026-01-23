import SwiftUI
import RadioModelCore

/// Welcome screen shown at app launch.
struct WelcomeView: View {
    @Environment(AppCoordinator.self) private var coordinator
    @State private var selectedModel: String?

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            content
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: 8) {
            Image(systemName: "antenna.radiowaves.left.and.right")
                .font(.system(size: 48))
                .foregroundStyle(.tint)
            Text("Motorola CPS")
                .font(.title.bold())
            Text("Business Radio Programming Software")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 24)
    }

    // MARK: - Content

    private var content: some View {
        HStack(spacing: 0) {
            // Left: Actions
            VStack(alignment: .leading, spacing: 16) {
                Text("Get Started")
                    .font(.headline)

                Button {
                    // Scroll to model picker on the right
                } label: {
                    Label("New Profile", systemImage: "doc.badge.plus")
                }
                .buttonStyle(.link)

                Button {
                    coordinator.showingOpenDialog = true
                } label: {
                    Label("Open Existing", systemImage: "folder")
                }
                .buttonStyle(.link)

                if !coordinator.radioDetector.detectedDevices.isEmpty {
                    Divider()
                    Text("Connected Radios")
                        .font(.headline)

                    ForEach(coordinator.radioDetector.detectedDevices) { device in
                        Button {
                            // Read from this radio
                        } label: {
                            Label(device.displayName, systemImage: "cable.connector")
                        }
                        .buttonStyle(.link)
                    }
                }

                Spacer()
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)

            Divider()

            // Right: Radio Model Picker
            VStack(alignment: .leading, spacing: 12) {
                Text("Choose Radio Model")
                    .font(.headline)

                ScrollView {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 120))], spacing: 12) {
                        ForEach(coordinator.availableModels) { model in
                            RadioModelCard(model: model, isSelected: selectedModel == model.id)
                                .onTapGesture {
                                    selectedModel = model.id
                                }
                        }
                    }
                }

                Spacer()

                HStack {
                    Spacer()
                    Button("Create Profile") {
                        if let modelID = selectedModel {
                            coordinator.newDocument(modelIdentifier: modelID)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(selectedModel == nil)
                }
            }
            .padding()
            .frame(maxWidth: .infinity)
        }
    }
}

/// A card displaying a radio model in the picker grid.
struct RadioModelCard: View {
    let model: RadioModelInfo
    let isSelected: Bool

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: "radio")
                .font(.title2)
                .frame(height: 32)

            Text(model.displayName)
                .font(.caption.bold())
                .lineLimit(1)

            Text("\(model.maxChannels) CH • \(model.frequencyBand.name)")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(width: 120, height: 90)
        .background(isSelected ? Color.accentColor.opacity(0.1) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isSelected ? Color.accentColor : Color.secondary.opacity(0.3), lineWidth: isSelected ? 2 : 1)
        )
    }
}
