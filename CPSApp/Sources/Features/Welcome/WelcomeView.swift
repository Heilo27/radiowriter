import SwiftUI
import RadioModelCore

/// Welcome screen shown at app launch.
struct WelcomeView: View {
    @Environment(AppCoordinator.self) private var coordinator
    @State private var selectedModel: String?
    @State private var showModelPickerForRead = false

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            content
        }
        .onAppear {
            // Sync local selection with coordinator's selected model
            if let modelId = coordinator.selectedModelIdentifier {
                selectedModel = modelId
            }
        }
        .onChange(of: coordinator.selectedModelIdentifier) { _, newValue in
            // Keep local selection in sync when coordinator changes it (e.g., auto-detection)
            if let newValue, selectedModel != newValue {
                selectedModel = newValue
            }
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
                .accessibilityIdentifier("welcome.newProfile")

                Button {
                    coordinator.showingOpenDialog = true
                } label: {
                    Label("Open Existing", systemImage: "folder")
                }
                .buttonStyle(.link)
                .accessibilityIdentifier("welcome.openExisting")

                // Show detected radio section
                if !coordinator.detectedDevices.isEmpty {
                    Divider()

                    // Identified radio info
                    if let identified = coordinator.identifiedRadio {
                        detectedRadioInfo(identified)
                    } else {
                        Text("Radio Detected")
                            .font(.headline)

                        ForEach(coordinator.detectedDevices) { device in
                            Label(device.displayName, systemImage: "cable.connector")
                                .foregroundStyle(.secondary)
                        }
                    }

                    // Read from Radio button
                    Button {
                        Task {
                            await coordinator.readFromRadio()
                        }
                    } label: {
                        Label("Read from Radio", systemImage: "arrow.down.to.line")
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(selectedModel == nil)
                    .accessibilityIdentifier("welcome.readRadio")
                    .padding(.top, 8)

                    if selectedModel == nil {
                        Text("Select a radio model to continue")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)

            Divider()

            // Right: Radio Model Picker
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Choose Radio Model")
                        .font(.headline)

                    if coordinator.identifiedRadio != nil {
                        Text("(Auto-selected)")
                            .font(.caption)
                            .foregroundStyle(.green)
                    }
                }

                ScrollView {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 120))], spacing: 12) {
                        ForEach(coordinator.availableModels) { model in
                            RadioModelCard(
                                model: model,
                                isSelected: selectedModel == model.id,
                                isRecommended: model.id == coordinator.identifiedRadio?.suggestedModelIdentifier
                            )
                            .onTapGesture {
                                selectedModel = model.id
                                coordinator.selectedModelIdentifier = model.id
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
                    .accessibilityIdentifier("welcome.createProfile")
                }
            }
            .padding()
            .frame(maxWidth: .infinity)
        }
    }

    // MARK: - Detected Radio Info

    @ViewBuilder
    private func detectedRadioInfo(_ radio: IdentifiedRadio) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                Text("Radio Detected")
                    .font(.headline)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Model:")
                        .foregroundStyle(.secondary)
                    Text(radio.modelNumber)
                        .fontWeight(.medium)
                }
                .font(.caption)

                if let serial = radio.serialNumber {
                    HStack {
                        Text("Serial:")
                            .foregroundStyle(.secondary)
                        Text(serial)
                    }
                    .font(.caption)
                }

                if let firmware = radio.firmwareVersion {
                    HStack {
                        Text("Firmware:")
                            .foregroundStyle(.secondary)
                        Text(firmware)
                    }
                    .font(.caption)
                }
            }
            .padding(.leading, 24)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Radio detected: \(radio.modelNumber), serial \(radio.serialNumber ?? "unknown")")
    }
}

/// A card displaying a radio model in the picker grid.
struct RadioModelCard: View {
    let model: RadioModelInfo
    let isSelected: Bool
    var isRecommended: Bool = false

    var body: some View {
        VStack(spacing: 6) {
            ZStack(alignment: .topTrailing) {
                Image(systemName: "radio")
                    .font(.title2)
                    .frame(height: 32)

                if isRecommended {
                    Image(systemName: "star.fill")
                        .font(.caption2)
                        .foregroundStyle(.yellow)
                        .offset(x: 8, y: -4)
                }
            }

            Text(model.displayName)
                .font(.caption.bold())
                .lineLimit(1)

            Text("\(model.maxChannels) CH • \(model.frequencyBand.name)")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(width: 120, height: 90)
        .background(isSelected ? Color.accentColor.opacity(0.1) : (isRecommended ? Color.yellow.opacity(0.05) : Color.clear))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isSelected ? Color.accentColor : (isRecommended ? Color.yellow.opacity(0.5) : Color.secondary.opacity(0.3)), lineWidth: isSelected ? 2 : 1)
        )
        .accessibilityIdentifier("radioModel.\(model.id)")
        .accessibilityLabel("\(model.displayName), \(model.maxChannels) channels, \(model.frequencyBand.name)\(isRecommended ? ", recommended for detected radio" : "")")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
