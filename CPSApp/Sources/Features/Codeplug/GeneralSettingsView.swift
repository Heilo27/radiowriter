import SwiftUI
import RadioProgrammer
import RadioModelCore

/// Editable view for general radio settings.
struct GeneralSettingsView: View {
    @Environment(AppCoordinator.self) private var coordinator

    @State private var showingSignalingHelp = false
    @State private var showingTimingHelp = false
    @State private var showingGPSHelp = false

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
                            set: { newValue in coord.updateGeneralSettings({ $0.radioID = newValue }, actionName: "Edit Radio ID") }
                        ), format: .number)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 120)
                        .accessibilityLabel("Radio ID")
                        .accessibilityHint("Enter the unique DMR radio identifier")
                    }
                    .help("Radio ID is your unique DMR subscriber number. On licensed amateur networks like BrandMeister, use your callsign's registered ID from radioid.net. On private DMR networks, it's assigned by the system administrator. Each radio must have a unique ID on the network.")

                    HStack {
                        Text("Radio Alias")
                        Spacer()
                        TextField("Alias", text: Binding(
                            get: { coord.parsedCodeplug?.radioAlias ?? "" },
                            set: { newValue in coord.updateGeneralSettings({ $0.radioAlias = newValue }, actionName: "Edit Radio Alias") }
                        ))
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 200)
                        .accessibilityLabel("Radio Alias")
                        .accessibilityHint("Enter a friendly name for the radio")
                    }
                    .help("Radio Alias is the name displayed on other DMR radios when you transmit. Keep it short — most radio displays show only 8–16 characters. Commonly used for callsigns, names, or department identifiers.")

                    HStack {
                        Text("Intro Line 1")
                        Spacer()
                        TextField("Line 1", text: Binding(
                            get: { coord.parsedCodeplug?.introScreenLine1 ?? "" },
                            set: { newValue in coord.updateGeneralSettings({ $0.introScreenLine1 = newValue }, actionName: "Edit Intro Line 1") }
                        ))
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 200)
                        .accessibilityLabel("Intro Screen Line 1")
                        .accessibilityHint("First line displayed on power-up")
                    }
                    .help("Text shown on the radio's display when it powers on. Useful for identifying the owner, department, or callsign. Length is limited by the radio's display — typically 8–16 characters.")

                    HStack {
                        Text("Intro Line 2")
                        Spacer()
                        TextField("Line 2", text: Binding(
                            get: { coord.parsedCodeplug?.introScreenLine2 ?? "" },
                            set: { newValue in coord.updateGeneralSettings({ $0.introScreenLine2 = newValue }, actionName: "Edit Intro Line 2") }
                        ))
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 200)
                        .accessibilityLabel("Intro Screen Line 2")
                        .accessibilityHint("Second line displayed on power-up")
                    }
                    .help("Second line of text shown on power-up. Pair with Intro Line 1 for multi-line messages such as callsign on line 1 and department on line 2.")
                }

                // Audio Settings
                Section("Audio Settings") {
                    Toggle("VOX Enabled", isOn: Binding(
                        get: { coord.parsedCodeplug?.voxEnabled ?? false },
                        set: { newValue in coord.updateGeneralSettings({ $0.voxEnabled = newValue }, actionName: "Edit VOX Enabled") }
                    ))
                    .help("VOX (Voice Operated Exchange) keys the transmitter automatically when it detects your voice, so you don't need to press PTT. Adjust sensitivity and delay to avoid false triggers from background noise.")

                    if coord.parsedCodeplug?.voxEnabled == true {
                        HStack {
                            Text("VOX Sensitivity")
                            Spacer()
                            Stepper("\(coord.parsedCodeplug?.voxSensitivity ?? 3)", value: Binding(
                                get: { Int(coord.parsedCodeplug?.voxSensitivity ?? 3) },
                                set: { newValue in coord.updateGeneralSettings({ $0.voxSensitivity = UInt8(newValue) }, actionName: "Edit VOX Sensitivity") }
                            ), in: 1...10)
                            .accessibilityLabel("VOX Sensitivity")
                            .accessibilityValue("\(coord.parsedCodeplug?.voxSensitivity ?? 3) of 10")
                        }
                        .help("Higher sensitivity triggers transmission with quieter sounds. Lower sensitivity requires louder speech. If VOX triggers from background noise or breathing, reduce this value. Start at 3–5 and adjust.")

                        HStack {
                            Text("VOX Delay")
                            Spacer()
                            TextField("ms", value: Binding(
                                get: { coord.parsedCodeplug?.voxDelay ?? 500 },
                                set: { newValue in coord.updateGeneralSettings({ $0.voxDelay = newValue }, actionName: "Edit VOX Delay") }
                            ), format: .number)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 80)
                            .accessibilityLabel("VOX Delay in milliseconds")
                            Text("ms")
                                .foregroundStyle(.secondary)
                                .accessibilityHidden(true)
                        }
                        .help("How long (in milliseconds) the transmitter stays keyed after your voice stops. Longer delays prevent words from being cut off, but keep the channel occupied longer. Typical values: 500–1500 ms.")
                    }

                    Toggle("Keypad Tones", isOn: Binding(
                        get: { coord.parsedCodeplug?.keypadTones ?? true },
                        set: { newValue in coord.updateGeneralSettings({ $0.keypadTones = newValue }, actionName: "Edit Keypad Tones") }
                    ))
                    .help("Plays audible beep tones when pressing keys on the radio's keypad to confirm each press. Disable in quiet environments where the beeps would be disruptive.")

                    Toggle("Call Alert Tone", isOn: Binding(
                        get: { coord.parsedCodeplug?.callAlertTone ?? true },
                        set: { newValue in coord.updateGeneralSettings({ $0.callAlertTone = newValue }, actionName: "Edit Call Alert Tone") }
                    ))
                    .help("Plays an audible tone when an incoming call is received. Useful for noticing calls when radio volume is low or in noisy environments. Disable for silent operation.")

                    Toggle("Power Up Tone", isOn: Binding(
                        get: { coord.parsedCodeplug?.powerUpTone ?? true },
                        set: { newValue in coord.updateGeneralSettings({ $0.powerUpTone = newValue }, actionName: "Edit Power Up Tone") }
                    ))
                    .help("Plays a tone when the radio powers on to confirm it has started successfully. Disable for silent startup — useful in meetings, surveillance, or noise-sensitive situations.")

                    Toggle("Audio Enhancement", isOn: Binding(
                        get: { coord.parsedCodeplug?.audioEnhancement ?? false },
                        set: { newValue in coord.updateGeneralSettings({ $0.audioEnhancement = newValue }, actionName: "Edit Audio Enhancement") }
                    ))
                    .help("Enables digital signal processing to improve received audio clarity, reducing background noise and improving speech intelligibility in challenging acoustic environments. May slightly increase battery drain.")
                }

                // Timing Settings
                Section {
                    HStack {
                        Text("TOT (Timeout Timer)")
                        Spacer()
                        TextField("sec", value: Binding(
                            get: { coord.parsedCodeplug?.totTime ?? 60 },
                            set: { newValue in coord.updateGeneralSettings({ $0.totTime = newValue }, actionName: "Edit TOT") }
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
                    .help("TOT (Timeout Timer) limits how long the radio can transmit continuously. When the timer expires, transmission stops automatically to prevent accidental channel blockage. Set to 0 to disable. Typical values: 60–180 seconds.")

                    HStack {
                        Text("Group Call Hang Time")
                        Spacer()
                        TextField("ms", value: Binding(
                            get: { coord.parsedCodeplug?.groupCallHangTime ?? 5000 },
                            set: { newValue in coord.updateGeneralSettings({ $0.groupCallHangTime = newValue }, actionName: "Edit Group Call Hang Time") }
                        ), format: .number)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 80)
                        .accessibilityLabel("Group Call Hang Time in milliseconds")
                        Text("ms")
                            .foregroundStyle(.secondary)
                            .accessibilityHidden(true)
                    }
                    .help("How long (in milliseconds) the channel stays assigned to a group call after the last transmission ends. During hang time, the radio monitors that talkgroup for replies. Longer hang times improve conversation flow but delay other traffic. Typical: 3000–6000 ms.")

                    HStack {
                        Text("Private Call Hang Time")
                        Spacer()
                        TextField("ms", value: Binding(
                            get: { coord.parsedCodeplug?.privateCallHangTime ?? 5000 },
                            set: { newValue in coord.updateGeneralSettings({ $0.privateCallHangTime = newValue }, actionName: "Edit Private Call Hang Time") }
                        ), format: .number)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 80)
                        .accessibilityLabel("Private Call Hang Time in milliseconds")
                        Text("ms")
                            .foregroundStyle(.secondary)
                            .accessibilityHidden(true)
                    }
                    .help("How long (in milliseconds) the channel stays in private call mode after transmission ends. Allows back-and-forth conversation without re-establishing the call each time. Typical: 3000–6000 ms.")
                } header: {
                    HStack {
                        Text("Timing Settings")
                        Spacer()
                        Button {
                            showingTimingHelp = true
                        } label: {
                            Image(systemName: "questionmark.circle")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Timing Settings help")
                        .popover(isPresented: $showingTimingHelp, arrowEdge: .trailing) {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("Timing Settings")
                                    .font(.headline)
                                Text("These settings control how long the radio holds the channel after a transmission. They affect channel efficiency and conversation flow on DMR systems.")
                                    .font(.callout)
                                Divider()
                                Label("TOT prevents accidental long transmissions", systemImage: "timer")
                                    .font(.caption)
                                Label("Hang Time lets conversations flow naturally", systemImage: "arrow.left.arrow.right")
                                    .font(.caption)
                                Label("Longer hang times = slower channel recovery", systemImage: "exclamationmark.triangle")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .padding()
                            .frame(maxWidth: 280)
                        }
                    }
                }

                // Display Settings
                Section("Display Settings") {
                    HStack {
                        Text("Backlight Time")
                        Spacer()
                        TextField("sec", value: Binding(
                            get: { coord.parsedCodeplug?.backlightTime ?? 5 },
                            set: { newValue in coord.updateGeneralSettings({ $0.backlightTime = newValue }, actionName: "Edit Backlight Time") }
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
                    .help("How long the display backlight stays lit after a keypress (in seconds). Set to 0 to keep the backlight always on — useful in dark environments but increases battery drain.")

                    Picker("Default Power Level", selection: Binding(
                        get: { coord.parsedCodeplug?.defaultPowerLevel ?? true },
                        set: { newValue in coord.updateGeneralSettings({ $0.defaultPowerLevel = newValue }, actionName: "Edit Default Power Level") }
                    )) {
                        Text("High").tag(true)
                        Text("Low").tag(false)
                    }
                    .help("Default power level used when a channel doesn't specify its own. High power extends range but drains the battery faster. Low power is usually sufficient indoors or over short distances.")
                }

                // Signaling Settings
                Section {
                    Toggle("Radio Check", isOn: Binding(
                        get: { coord.parsedCodeplug?.radioCheckEnabled ?? true },
                        set: { newValue in coord.updateGeneralSettings({ $0.radioCheckEnabled = newValue }, actionName: "Edit Radio Check") }
                    ))
                    .help("Radio Check lets dispatchers or other radios silently verify that your radio is active and reachable, without requiring a voice response. Your radio automatically responds with a status message. Used for fleet presence checking.")

                    Toggle("Remote Monitor", isOn: Binding(
                        get: { coord.parsedCodeplug?.remoteMonitorEnabled ?? false },
                        set: { newValue in coord.updateGeneralSettings({ $0.remoteMonitorEnabled = newValue }, actionName: "Edit Remote Monitor") }
                    ))
                    .help("Remote Monitor allows a controller to remotely activate this radio's microphone without user interaction — enabling audio monitoring of the radio's surroundings. Only enable in controlled fleet deployments where users are informed.")

                    Toggle("Call Confirmation", isOn: Binding(
                        get: { coord.parsedCodeplug?.callConfirmation ?? true },
                        set: { newValue in coord.updateGeneralSettings({ $0.callConfirmation = newValue }, actionName: "Edit Call Confirmation") }
                    ))
                    .help("When enabled, the radio sends an acknowledgement to confirm each call was received. Improves end-to-end reliability and lets the caller know the message got through, but adds slight overhead to each transmission.")
                } header: {
                    HStack {
                        Text("Signaling")
                        Spacer()
                        Button {
                            showingSignalingHelp = true
                        } label: {
                            Image(systemName: "questionmark.circle")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Signaling help")
                        .popover(isPresented: $showingSignalingHelp, arrowEdge: .trailing) {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("Signaling Features")
                                    .font(.headline)
                                Text("These features control how your radio communicates its status and responds to remote commands from dispatchers or other radios.")
                                    .font(.callout)
                                Divider()
                                Label("Radio Check — silent status polling", systemImage: "antenna.radiowaves.left.and.right")
                                    .font(.caption)
                                Label("Remote Monitor — remote mic activation", systemImage: "mic.fill")
                                    .font(.caption)
                                Label("Call Confirmation — delivery receipts", systemImage: "checkmark.circle")
                                    .font(.caption)
                            }
                            .padding()
                            .frame(maxWidth: 280)
                        }
                    }
                }

                // GPS Settings
                Section {
                    Toggle("GPS Enabled", isOn: Binding(
                        get: { coord.parsedCodeplug?.gpsEnabled ?? false },
                        set: { newValue in coord.updateGeneralSettings({ $0.gpsEnabled = newValue }, actionName: "Edit GPS Enabled") }
                    ))
                    .help("Enables the radio's internal GPS receiver so it can report its location. Required for GPS-based dispatch, man-down alerts, and location-aware repeaters. GPS significantly increases battery drain — enable only when needed.")

                    Toggle("GPS Revert Channel", isOn: Binding(
                        get: { coord.parsedCodeplug?.gpsRevertChannelEnabled ?? false },
                        set: { newValue in coord.updateGeneralSettings({ $0.gpsRevertChannelEnabled = newValue }, actionName: "Edit GPS Revert Channel") }
                    ))
                    .help("When enabled, the radio temporarily switches to a designated GPS data channel to transmit location reports, then returns to the current channel. Required by some GPS-aware repeater systems and dispatch platforms.")

                    Toggle("Enhanced GNSS", isOn: Binding(
                        get: { coord.parsedCodeplug?.enhancedGNSSEnabled ?? false },
                        set: { newValue in coord.updateGeneralSettings({ $0.enhancedGNSSEnabled = newValue }, actionName: "Edit Enhanced GNSS") }
                    ))
                    .help("Enhanced GNSS uses multiple satellite systems (GPS, GLONASS, Galileo, BeiDou) simultaneously for faster position fixes and improved accuracy in urban canyons or areas with limited sky view. Increases battery drain compared to GPS-only mode.")
                } header: {
                    HStack {
                        Text("GPS/GNSS")
                        Spacer()
                        Button {
                            showingGPSHelp = true
                        } label: {
                            Image(systemName: "questionmark.circle")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("GPS help")
                        .popover(isPresented: $showingGPSHelp, arrowEdge: .trailing) {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("GPS/GNSS Location")
                                    .font(.headline)
                                Text("GPS lets your radio report its location to dispatch systems, enabling tracking, geo-fencing, and location-triggered alerts.")
                                    .font(.callout)
                                Divider()
                                Label("GNSS = GPS + GLONASS + Galileo + BeiDou", systemImage: "globe")
                                    .font(.caption)
                                Label("GPS increases battery drain significantly", systemImage: "battery.25")
                                    .font(.caption)
                                Label("Revert Channel required by some repeater systems", systemImage: "arrow.left.arrow.right")
                                    .font(.caption)
                            }
                            .padding()
                            .frame(maxWidth: 280)
                        }
                    }
                }

                // Lone Worker Settings
                Section("Lone Worker") {
                    Toggle("Lone Worker Enabled", isOn: Binding(
                        get: { coord.parsedCodeplug?.loneWorkerEnabled ?? false },
                        set: { newValue in coord.updateGeneralSettings({ $0.loneWorkerEnabled = newValue }, actionName: "Edit Lone Worker Enabled") }
                    ))
                    .help("Lone Worker periodically prompts the radio user to confirm they are safe. If the user doesn't respond within the configured time, the radio sounds an alert and may transmit an emergency call. Used for workers in isolated or hazardous environments.")

                    if coord.parsedCodeplug?.loneWorkerEnabled == true {
                        HStack {
                            Text("Response Time")
                            Spacer()
                            TextField("sec", value: Binding(
                                get: { coord.parsedCodeplug?.loneWorkerResponseTime ?? 30 },
                                set: { newValue in coord.updateGeneralSettings({ $0.loneWorkerResponseTime = newValue }, actionName: "Edit Lone Worker Response Time") }
                            ), format: .number)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 80)
                            .accessibilityLabel("Lone Worker Response Time in seconds")
                            Text("sec")
                                .foregroundStyle(.secondary)
                                .accessibilityHidden(true)
                        }
                        .help("How long (in seconds) the user has to respond to the Lone Worker check-in prompt before an alert is raised. Set long enough to be practical but short enough to detect an emergency. Typical: 20–60 seconds.")

                        HStack {
                            Text("Reminder Time")
                            Spacer()
                            TextField("sec", value: Binding(
                                get: { coord.parsedCodeplug?.loneWorkerReminderTime ?? 300 },
                                set: { newValue in coord.updateGeneralSettings({ $0.loneWorkerReminderTime = newValue }, actionName: "Edit Lone Worker Reminder Time") }
                            ), format: .number)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 80)
                            .accessibilityLabel("Lone Worker Reminder Time in seconds")
                            Text("sec")
                                .foregroundStyle(.secondary)
                                .accessibilityHidden(true)
                        }
                        .help("How often (in seconds) the radio prompts for a Lone Worker check-in. Set based on your safety policy — more frequent checks reduce the time before an emergency is detected. Typical: 180–600 seconds.")
                    }
                }

                // Man Down Settings
                Section("Man Down") {
                    Toggle("Man Down Enabled", isOn: Binding(
                        get: { coord.parsedCodeplug?.manDownEnabled ?? false },
                        set: { newValue in coord.updateGeneralSettings({ $0.manDownEnabled = newValue }, actionName: "Edit Man Down Enabled") }
                    ))
                    .help("Man Down uses the radio's motion sensor to detect if the radio has become horizontal (e.g., the user has fallen). After the configured delay, the radio sounds an alert and transmits an emergency if the user doesn't cancel it.")

                    if coord.parsedCodeplug?.manDownEnabled == true {
                        HStack {
                            Text("Delay")
                            Spacer()
                            TextField("sec", value: Binding(
                                get: { coord.parsedCodeplug?.manDownDelay ?? 10 },
                                set: { newValue in coord.updateGeneralSettings({ $0.manDownDelay = newValue }, actionName: "Edit Man Down Delay") }
                            ), format: .number)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 80)
                            .accessibilityLabel("Man Down Delay in seconds")
                            Text("sec")
                                .foregroundStyle(.secondary)
                                .accessibilityHidden(true)
                        }
                        .help("How long (in seconds) the radio waits in the horizontal position before triggering the Man Down alert. A short delay reduces false alarms from normal radio movement. Typical: 5–15 seconds.")
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
