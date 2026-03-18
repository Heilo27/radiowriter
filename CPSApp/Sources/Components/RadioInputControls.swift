import SwiftUI
import RadioCore

// MARK: - Frequency Input

/// A frequency input field with increment/decrement buttons.
/// Displays in MHz but stores in Hz internally.
struct FrequencyInput: View {
    @Binding var frequencyHz: UInt32
    var step: RadioConstants.FrequencyStep = .step12_5kHz
    var label: String = ""
    var minHz: UInt32 = 100_000_000   // 100 MHz default minimum
    var maxHz: UInt32 = 600_000_000   // 600 MHz default maximum

    private var frequencyMHz: Double {
        Double(frequencyHz) / 1_000_000.0
    }

    /// Maximum safe frequency in MHz to prevent UInt32 overflow
    private static let maxSafeMHz: Double = Double(UInt32.max) / 1_000_000.0

    private var canIncrement: Bool {
        UInt64(frequencyHz) + UInt64(step.hertz) <= UInt64(maxHz)
    }

    private var canDecrement: Bool {
        frequencyHz >= step.hertz && frequencyHz - UInt32(step.hertz) >= minHz
    }

    var body: some View {
        HStack(spacing: 8) {
            if !label.isEmpty {
                Text(label)
                Spacer()
            }

            Button {
                decrementFrequency()
            } label: {
                Image(systemName: "minus")
                    .font(.body)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .disabled(!canDecrement)
            .accessibilityLabel("Decrease frequency by \(step.displayName)")

            TextField("", value: Binding(
                get: { frequencyMHz },
                set: { newValue in
                    let hz = newValue * 1_000_000
                    if hz >= 0 && hz <= Self.maxSafeMHz * 1_000_000 {
                        let clampedHz = UInt32(min(max(hz, Double(minHz)), Double(maxHz)))
                        frequencyHz = clampedHz
                    }
                }
            ), format: .number.precision(.fractionLength(5)))
            .textFieldStyle(.roundedBorder)
            .frame(minWidth: 110)
            .multilineTextAlignment(.trailing)
            .accessibilityLabel(label.isEmpty ? "Frequency in MHz" : "\(label) in MHz")
            .accessibilityValue(String(format: "%.5f megahertz", frequencyMHz))

            Text("MHz")
                .foregroundStyle(.secondary)
                .font(.caption)
                .accessibilityHidden(true)

            Button {
                incrementFrequency()
            } label: {
                Image(systemName: "plus")
                    .font(.body)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .disabled(!canIncrement)
            .accessibilityLabel("Increase frequency by \(step.displayName)")
        }
    }

    private func incrementFrequency() {
        let newValue = UInt64(frequencyHz) + UInt64(step.hertz)
        if newValue <= UInt64(maxHz) {
            frequencyHz = UInt32(newValue)
        }
    }

    private func decrementFrequency() {
        if frequencyHz >= step.hertz {
            let newValue = frequencyHz - UInt32(step.hertz)
            if newValue >= minHz {
                frequencyHz = newValue
            }
        }
    }
}

// MARK: - CTCSS Picker

/// A picker for selecting CTCSS (PL) tones from the standard list.
struct CTCSSPicker: View {
    @Binding var toneHz: Double
    var label: String = "CTCSS"

    var body: some View {
        Picker(label, selection: Binding(
            get: { toneHz },
            set: { newValue in
                // Validate that selected tone is in the standard list
                if RadioConstants.isValidCTCSS(newValue) {
                    toneHz = newValue
                } else {
                    // Snap to closest valid tone
                    toneHz = RadioConstants.closestCTCSSTone(to: newValue)
                }
            }
        )) {
            Text("None").tag(0.0)
            ForEach(RadioConstants.ctcssTones.dropFirst(), id: \.self) { tone in
                Text(String(format: "%.1f Hz", tone)).tag(tone)
            }
        }
        .help("CTCSS (Continuous Tone-Coded Squelch System) is a subaudible tone transmitted with your voice that opens the squelch on receiving radios programmed to the same tone. Also called PL tone or Private Line.")
    }
}

// MARK: - DCS Picker

/// A picker for selecting DCS codes with polarity (Normal/Inverted).
struct DCSPicker: View {
    @Binding var code: UInt16
    @Binding var inverted: Bool
    var label: String = "DCS"

    var body: some View {
        HStack {
            Picker(label, selection: Binding(
                get: { code },
                set: { newValue in
                    // Validate DCS code
                    if RadioConstants.isValidDCS(Int(newValue)) {
                        code = newValue
                    }
                }
            )) {
                Text("None").tag(UInt16(0))
                ForEach(RadioConstants.dcsCodes.dropFirst(), id: \.self) { dcsCode in
                    Text(String(format: "D%03o", dcsCode)).tag(UInt16(dcsCode))
                }
            }
            .help("DCS (Digital-Coded Squelch) uses a digital data stream transmitted below the voice to selectively open squelch. Polarity N (Normal) or I (Inverted) must match the repeater or other radio. Also called DPL (Digital Private Line).")

            if code > 0 {
                Picker("Polarity", selection: $inverted) {
                    Text("N")
                        .accessibilityLabel("Normal polarity")
                        .tag(false)
                    Text("I")
                        .accessibilityLabel("Inverted polarity")
                        .tag(true)
                }
                .pickerStyle(.segmented)
                .frame(width: 70)
                .labelsHidden()
                .accessibilityLabel("DCS Polarity")
            }
        }
    }
}

// MARK: - Color Code Picker

/// A picker for selecting DMR Color Codes (0-15).
struct ColorCodePicker: View {
    @Binding var colorCode: Int
    var label: String = "Color Code"

    var body: some View {
        Picker(label, selection: Binding(
            get: { colorCode },
            set: { colorCode = max(0, min(15, $0)) }
        )) {
            ForEach(0...15, id: \.self) { code in
                Text("\(code)").tag(code)
            }
        }
        .help("Color Code is a DMR network identifier (0–15) that separates radios on the same frequency. All radios in the same system must use the same Color Code. Think of it as a digital CTCSS tone — without a match, your radio won't hear or join calls on that system.")
    }
}

// MARK: - Timeslot Picker

/// A segmented picker for selecting DMR Timeslot (1 or 2).
struct TimeslotPicker: View {
    @Binding var timeslot: Int
    var label: String = "Timeslot"

    var body: some View {
        LabeledContent(label) {
            Picker(label, selection: Binding(
                get: { timeslot },
                set: { newValue in
                    // Clamp to valid range 1-2
                    timeslot = max(1, min(2, newValue))
                }
            )) {
                Text("TS1")
                    .accessibilityLabel("Timeslot 1")
                    .tag(1)
                Text("TS2")
                    .accessibilityLabel("Timeslot 2")
                    .tag(2)
            }
            .pickerStyle(.segmented)
            .frame(width: 100)
            .labelsHidden()
            .accessibilityLabel(label)
        }
        .help("Time Slot (TS1 or TS2) is one of two logical channels DMR creates on a single frequency by alternating in time. This doubles capacity. A repeater may dedicate each slot to different purposes — check your repeater's plan before choosing.")
    }
}

// MARK: - Power Picker

/// A segmented picker for selecting TX power level (Low/High).
struct PowerPicker: View {
    @Binding var highPower: Bool
    var label: String = "TX Power"

    var body: some View {
        LabeledContent(label) {
            Picker(label, selection: $highPower) {
                Text("Low")
                    .accessibilityLabel("Low power")
                    .tag(false)
                Text("High")
                    .accessibilityLabel("High power")
                    .tag(true)
            }
            .pickerStyle(.segmented)
            .frame(width: 100)
            .labelsHidden()
            .accessibilityLabel(label)
        }
        .help("TX Power controls transmit strength. High increases range but drains the battery faster and may cause interference to nearby radios. Low power is sufficient for short-range or indoor use and extends battery life significantly.")
    }
}

// MARK: - Bandwidth Picker

/// A segmented picker for selecting channel bandwidth (12.5 kHz / 25 kHz).
struct BandwidthPicker: View {
    @Binding var wideband: Bool
    var label: String = "Bandwidth"

    var body: some View {
        LabeledContent(label) {
            Picker(label, selection: Binding(
                get: { wideband },
                set: { wideband = $0 }
            )) {
                Text("12.5 kHz").tag(false)
                Text("25 kHz").tag(true)
            }
            .pickerStyle(.segmented)
            .frame(width: 140)
            .labelsHidden()
            .accessibilityLabel(label)
        }
        .help("Bandwidth sets the channel spacing. 12.5 kHz (Narrow) has been FCC-mandated for Part 90 land mobile radios since 2013, and is correct for most systems. Only use 25 kHz (Wide) if your repeater or system explicitly requires it.")
    }
}

// MARK: - Channel Mode Picker

/// A segmented picker for selecting channel mode (Analog/Digital).
struct ChannelModePicker: View {
    @Binding var isDigital: Bool
    var label: String = "Mode"

    var body: some View {
        LabeledContent(label) {
            Picker(label, selection: Binding(
                get: { isDigital },
                set: { isDigital = $0 }
            )) {
                Text("Analog").tag(false)
                Text("Digital").tag(true)
            }
            .pickerStyle(.segmented)
            .frame(width: 140)
            .labelsHidden()
            .accessibilityLabel(label)
        }
        .help("Mode selects between Analog FM (conventional) and Digital DMR. Use Analog for traditional FM repeaters and simplex channels. Use Digital for DMR repeaters on networks like BrandMeister or DMR-MARC.")
    }
}

// MARK: - Squelch Type Picker

/// A picker for selecting squelch type.
struct SquelchTypePicker: View {
    @Binding var squelchType: Int
    var label: String = "RX Squelch"

    var body: some View {
        Picker(label, selection: Binding(
            get: { squelchType },
            set: { newValue in
                // Clamp to valid range
                squelchType = max(0, min(2, newValue))
            }
        )) {
            ForEach(RadioConstants.SquelchType.allCases, id: \.rawValue) { type in
                Text(type.displayName).tag(type.rawValue)
            }
        }
        .help("Squelch suppresses background noise when no signal is present. Carrier (CSQ) opens on any signal. CTCSS opens only when the correct subaudible tone is received. DCS opens on a digital code. Tone squelch lets you share a frequency without hearing every other user.")
    }
}

// MARK: - Privacy Type Picker

/// A picker for selecting encryption/privacy type.
struct PrivacyTypePicker: View {
    @Binding var privacyType: Int
    var label: String = "Privacy"

    var body: some View {
        Picker(label, selection: Binding(
            get: { privacyType },
            set: { newValue in
                // Clamp to valid range
                privacyType = max(0, min(3, newValue))
            }
        )) {
            ForEach(RadioConstants.PrivacyType.allCases, id: \.rawValue) { type in
                Text(type.displayName).tag(type.rawValue)
            }
        }
        .help("Privacy scrambles transmissions so radios without the same key cannot decode them. Basic Privacy is obfuscation only — not true encryption. Enhanced Privacy (AES) provides stronger protection. Confirm your repeater and all radios support the same privacy type.")
    }
}

// MARK: - Contact Type Picker

/// A picker for selecting DMR contact type.
struct ContactTypePicker: View {
    @Binding var contactType: Int
    var label: String = "Contact Type"

    var body: some View {
        Picker(label, selection: Binding(
            get: { contactType },
            set: { contactType = max(0, min(2, $0)) }
        )) {
            Text("Private Call").tag(0)
            Text("Group Call").tag(1)
            Text("All Call").tag(2)
        }
        .help("Call type determines how a transmission is addressed. Private Call goes to one specific radio by DMR ID. Group Call broadcasts to all radios in a talkgroup. All Call reaches every radio on the channel — use sparingly as it interrupts all users.")
    }
}

// MARK: - Timing Leader Picker

/// A picker for selecting DMR timing leader preference.
struct TimingLeaderPicker: View {
    @Binding var preference: Int
    var label: String = "Timing Leader"

    var body: some View {
        Picker(label, selection: Binding(
            get: { preference },
            set: { newValue in
                // Clamp to valid range
                preference = max(0, min(2, newValue))
            }
        )) {
            ForEach(RadioConstants.TimingLeader.allCases, id: \.rawValue) { type in
                Text(type.displayName).tag(type.rawValue)
            }
        }
        .help("Timing Leader controls which radio establishes the timing reference in a direct (simplex) DMR call. Set to Leader if this radio should drive timing, or Follower if it should sync to another radio. Used in DCDM and ERDM configurations.")
    }
}

// MARK: - Previews

#Preview("Frequency Input") {
    @Previewable @State var freq: UInt32 = 461_462_500
    Form {
        FrequencyInput(frequencyHz: $freq, step: .step12_5kHz, label: "RX Frequency")
        FrequencyInput(frequencyHz: $freq, step: .step25kHz, label: "TX Frequency")
    }
    .frame(width: 450)
    .padding()
}

#Preview("Tone Pickers") {
    @Previewable @State var ctcss: Double = 100.0
    @Previewable @State var dcs: UInt16 = 023  // Octal literal = D023 DCS code
    @Previewable @State var inverted = false

    Form {
        CTCSSPicker(toneHz: $ctcss, label: "TX CTCSS")
        DCSPicker(code: $dcs, inverted: $inverted, label: "TX DCS")
    }
    .frame(width: 400)
    .padding()
}

#Preview("DMR Controls") {
    @Previewable @State var colorCode = 1
    @Previewable @State var timeslot = 1
    @Previewable @State var contactType = 1

    Form {
        ColorCodePicker(colorCode: $colorCode)
        TimeslotPicker(timeslot: $timeslot)
        ContactTypePicker(contactType: $contactType)
    }
    .frame(width: 400)
    .padding()
}

#Preview("Power & Bandwidth") {
    @Previewable @State var highPower = true
    @Previewable @State var wideband = false
    @Previewable @State var isDigital = true

    Form {
        PowerPicker(highPower: $highPower)
        BandwidthPicker(wideband: $wideband)
        ChannelModePicker(isDigital: $isDigital)
    }
    .frame(width: 400)
    .padding()
}
