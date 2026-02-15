import SwiftUI
import RadioProgrammer
import RadioModelCore

/// Editable view for general radio settings.
struct GeneralSettingsView: View {
    @Environment(AppCoordinator.self) private var coordinator

    var body: some View {
        @Bindable var coord = coordinator

        if coord.parsedCodeplug != nil {
            Form {
                // Device Information (read-only)
                Section("Device Information") {
                    LabeledContent("Model", value: coord.parsedCodeplug?.modelNumber ?? "Unknown")
                    LabeledContent("Serial Number", value: coord.parsedCodeplug?.serialNumber ?? "Unknown")
                    LabeledContent("Firmware", value: coord.parsedCodeplug?.firmwareVersion ?? "Unknown")
                    LabeledContent("Codeplug Version", value: coord.parsedCodeplug?.codeplugVersion ?? "Unknown")
                }

                // Radio Identity (editable)
                Section("Radio Identity") {
                    HStack {
                        Text("Radio ID")
                        Spacer()
                        TextField("Radio ID", value: Binding(
                            get: { coord.parsedCodeplug?.radioID ?? 1 },
                            set: { coord.parsedCodeplug?.radioID = $0 }
                        ), format: .number)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 120)
                        .accessibilityLabel("Radio ID")
                        .accessibilityHint("Enter the unique DMR radio identifier")
                    }

                    HStack {
                        Text("Radio Alias")
                        Spacer()
                        TextField("Alias", text: Binding(
                            get: { coord.parsedCodeplug?.radioAlias ?? "" },
                            set: { coord.parsedCodeplug?.radioAlias = $0 }
                        ))
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 200)
                        .accessibilityLabel("Radio Alias")
                        .accessibilityHint("Enter a friendly name for the radio")
                    }

                    HStack {
                        Text("Intro Line 1")
                        Spacer()
                        TextField("Line 1", text: Binding(
                            get: { coord.parsedCodeplug?.introScreenLine1 ?? "" },
                            set: { coord.parsedCodeplug?.introScreenLine1 = $0 }
                        ))
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 200)
                        .accessibilityLabel("Intro Screen Line 1")
                        .accessibilityHint("First line displayed on power-up")
                    }

                    HStack {
                        Text("Intro Line 2")
                        Spacer()
                        TextField("Line 2", text: Binding(
                            get: { coord.parsedCodeplug?.introScreenLine2 ?? "" },
                            set: { coord.parsedCodeplug?.introScreenLine2 = $0 }
                        ))
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 200)
                        .accessibilityLabel("Intro Screen Line 2")
                        .accessibilityHint("Second line displayed on power-up")
                    }
                }

                // Audio Settings
                Section("Audio Settings") {
                    Toggle("VOX Enabled", isOn: Binding(
                        get: { coord.parsedCodeplug?.voxEnabled ?? false },
                        set: { coord.parsedCodeplug?.voxEnabled = $0 }
                    ))

                    if coord.parsedCodeplug?.voxEnabled == true {
                        HStack {
                            Text("VOX Sensitivity")
                            Spacer()
                            Stepper("\(coord.parsedCodeplug?.voxSensitivity ?? 3)", value: Binding(
                                get: { Int(coord.parsedCodeplug?.voxSensitivity ?? 3) },
                                set: { coord.parsedCodeplug?.voxSensitivity = UInt8($0) }
                            ), in: 1...10)
                            .accessibilityLabel("VOX Sensitivity")
                            .accessibilityValue("\(coord.parsedCodeplug?.voxSensitivity ?? 3) of 10")
                        }

                        HStack {
                            Text("VOX Delay")
                            Spacer()
                            TextField("ms", value: Binding(
                                get: { coord.parsedCodeplug?.voxDelay ?? 500 },
                                set: { coord.parsedCodeplug?.voxDelay = $0 }
                            ), format: .number)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 80)
                            .accessibilityLabel("VOX Delay in milliseconds")
                            Text("ms")
                                .foregroundStyle(.secondary)
                                .accessibilityHidden(true)
                        }
                    }

                    Toggle("Keypad Tones", isOn: Binding(
                        get: { coord.parsedCodeplug?.keypadTones ?? true },
                        set: { coord.parsedCodeplug?.keypadTones = $0 }
                    ))

                    Toggle("Call Alert Tone", isOn: Binding(
                        get: { coord.parsedCodeplug?.callAlertTone ?? true },
                        set: { coord.parsedCodeplug?.callAlertTone = $0 }
                    ))

                    Toggle("Power Up Tone", isOn: Binding(
                        get: { coord.parsedCodeplug?.powerUpTone ?? true },
                        set: { coord.parsedCodeplug?.powerUpTone = $0 }
                    ))

                    Toggle("Audio Enhancement", isOn: Binding(
                        get: { coord.parsedCodeplug?.audioEnhancement ?? false },
                        set: { coord.parsedCodeplug?.audioEnhancement = $0 }
                    ))
                }

                // Timing Settings
                Section("Timing Settings") {
                    HStack {
                        Text("TOT (Timeout Timer)")
                        Spacer()
                        TextField("sec", value: Binding(
                            get: { coord.parsedCodeplug?.totTime ?? 60 },
                            set: { coord.parsedCodeplug?.totTime = $0 }
                        ), format: .number)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 80)
                        .accessibilityLabel("Timeout Timer in seconds")
                        .accessibilityHint("0 means infinite timeout")
                        Text("sec (0 = infinite)")
                            .foregroundStyle(.secondary)
                            .font(.caption)
                            .accessibilityHidden(true)
                    }

                    HStack {
                        Text("Group Call Hang Time")
                        Spacer()
                        TextField("ms", value: Binding(
                            get: { coord.parsedCodeplug?.groupCallHangTime ?? 5000 },
                            set: { coord.parsedCodeplug?.groupCallHangTime = $0 }
                        ), format: .number)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 80)
                        .accessibilityLabel("Group Call Hang Time in milliseconds")
                        Text("ms")
                            .foregroundStyle(.secondary)
                            .accessibilityHidden(true)
                    }

                    HStack {
                        Text("Private Call Hang Time")
                        Spacer()
                        TextField("ms", value: Binding(
                            get: { coord.parsedCodeplug?.privateCallHangTime ?? 5000 },
                            set: { coord.parsedCodeplug?.privateCallHangTime = $0 }
                        ), format: .number)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 80)
                        .accessibilityLabel("Private Call Hang Time in milliseconds")
                        Text("ms")
                            .foregroundStyle(.secondary)
                            .accessibilityHidden(true)
                    }
                }

                // Display Settings
                Section("Display Settings") {
                    HStack {
                        Text("Backlight Time")
                        Spacer()
                        TextField("sec", value: Binding(
                            get: { coord.parsedCodeplug?.backlightTime ?? 5 },
                            set: { coord.parsedCodeplug?.backlightTime = $0 }
                        ), format: .number)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 80)
                        .accessibilityLabel("Backlight Time in seconds")
                        .accessibilityHint("0 means always on")
                        Text("sec (0 = always on)")
                            .foregroundStyle(.secondary)
                            .font(.caption)
                            .accessibilityHidden(true)
                    }

                    Picker("Default Power Level", selection: Binding(
                        get: { coord.parsedCodeplug?.defaultPowerLevel ?? true },
                        set: { coord.parsedCodeplug?.defaultPowerLevel = $0 }
                    )) {
                        Text("High").tag(true)
                        Text("Low").tag(false)
                    }
                }

                // Signaling Settings
                Section("Signaling") {
                    Toggle("Radio Check", isOn: Binding(
                        get: { coord.parsedCodeplug?.radioCheckEnabled ?? true },
                        set: { coord.parsedCodeplug?.radioCheckEnabled = $0 }
                    ))

                    Toggle("Remote Monitor", isOn: Binding(
                        get: { coord.parsedCodeplug?.remoteMonitorEnabled ?? false },
                        set: { coord.parsedCodeplug?.remoteMonitorEnabled = $0 }
                    ))

                    Toggle("Call Confirmation", isOn: Binding(
                        get: { coord.parsedCodeplug?.callConfirmation ?? true },
                        set: { coord.parsedCodeplug?.callConfirmation = $0 }
                    ))
                }

                // GPS Settings
                Section("GPS/GNSS") {
                    Toggle("GPS Enabled", isOn: Binding(
                        get: { coord.parsedCodeplug?.gpsEnabled ?? false },
                        set: { coord.parsedCodeplug?.gpsEnabled = $0 }
                    ))

                    Toggle("GPS Revert Channel", isOn: Binding(
                        get: { coord.parsedCodeplug?.gpsRevertChannelEnabled ?? false },
                        set: { coord.parsedCodeplug?.gpsRevertChannelEnabled = $0 }
                    ))

                    Toggle("Enhanced GNSS", isOn: Binding(
                        get: { coord.parsedCodeplug?.enhancedGNSSEnabled ?? false },
                        set: { coord.parsedCodeplug?.enhancedGNSSEnabled = $0 }
                    ))
                }

                // Lone Worker Settings
                Section("Lone Worker") {
                    Toggle("Lone Worker Enabled", isOn: Binding(
                        get: { coord.parsedCodeplug?.loneWorkerEnabled ?? false },
                        set: { coord.parsedCodeplug?.loneWorkerEnabled = $0 }
                    ))

                    if coord.parsedCodeplug?.loneWorkerEnabled == true {
                        HStack {
                            Text("Response Time")
                            Spacer()
                            TextField("sec", value: Binding(
                                get: { coord.parsedCodeplug?.loneWorkerResponseTime ?? 30 },
                                set: { coord.parsedCodeplug?.loneWorkerResponseTime = $0 }
                            ), format: .number)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 80)
                            .accessibilityLabel("Lone Worker Response Time in seconds")
                            Text("sec")
                                .foregroundStyle(.secondary)
                                .accessibilityHidden(true)
                        }

                        HStack {
                            Text("Reminder Time")
                            Spacer()
                            TextField("sec", value: Binding(
                                get: { coord.parsedCodeplug?.loneWorkerReminderTime ?? 300 },
                                set: { coord.parsedCodeplug?.loneWorkerReminderTime = $0 }
                            ), format: .number)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 80)
                            .accessibilityLabel("Lone Worker Reminder Time in seconds")
                            Text("sec")
                                .foregroundStyle(.secondary)
                                .accessibilityHidden(true)
                        }
                    }
                }

                // Man Down Settings
                Section("Man Down") {
                    Toggle("Man Down Enabled", isOn: Binding(
                        get: { coord.parsedCodeplug?.manDownEnabled ?? false },
                        set: { coord.parsedCodeplug?.manDownEnabled = $0 }
                    ))

                    if coord.parsedCodeplug?.manDownEnabled == true {
                        HStack {
                            Text("Delay")
                            Spacer()
                            TextField("sec", value: Binding(
                                get: { coord.parsedCodeplug?.manDownDelay ?? 10 },
                                set: { coord.parsedCodeplug?.manDownDelay = $0 }
                            ), format: .number)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 80)
                            .accessibilityLabel("Man Down Delay in seconds")
                            Text("sec")
                                .foregroundStyle(.secondary)
                                .accessibilityHidden(true)
                        }
                    }
                }

                // Statistics (read-only)
                Section("Codeplug Statistics") {
                    LabeledContent("Total Zones", value: "\(coord.parsedCodeplug?.zones.count ?? 0)")
                    let totalChannels = coord.parsedCodeplug?.zones.reduce(0) { $0 + $1.channels.count } ?? 0
                    LabeledContent("Total Channels", value: "\(totalChannels)")
                    LabeledContent("Total Contacts", value: "\(coord.parsedCodeplug?.contacts.count ?? 0)")
                    LabeledContent("Scan Lists", value: "\(coord.parsedCodeplug?.scanLists.count ?? 0)")
                    LabeledContent("RX Group Lists", value: "\(coord.parsedCodeplug?.rxGroupLists.count ?? 0)")
                }
            }
            .formStyle(.grouped)
        } else {
            ContentUnavailableView(
                "No Codeplug Loaded",
                systemImage: "doc.questionmark",
                description: Text("Read from a radio or open a codeplug file to edit settings.")
            )
        }
    }
}

#Preview {
    GeneralSettingsView()
        .environment(AppCoordinator())
        .frame(width: 500, height: 600)
}
