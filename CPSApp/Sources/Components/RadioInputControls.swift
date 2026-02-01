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
        HStack(spacing: 4) {
            if !label.isEmpty {
                Text(label)
                Spacer()
            }

            Button {
                decrementFrequency()
            } label: {
                Image(systemName: "minus")
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.bordered)
            .disabled(!canDecrement)
            .accessibilityLabel("Decrease frequency by \(step.displayName)")

            TextField("Frequency in MHz", value: Binding(
                get: { frequencyMHz },
                set: { newValue in
                    let hz = newValue * 1_000_000
                    // Validate bounds before assignment
                    if hz >= 0 && hz <= Self.maxSafeMHz * 1_000_000 {
                        let clampedHz = UInt32(min(max(hz, Double(minHz)), Double(maxHz)))
                        frequencyHz = clampedHz
                    }
                }
            ), format: .number.precision(.fractionLength(5)))
            .textFieldStyle(.roundedBorder)
            .frame(width: 110)
            .multilineTextAlignment(.trailing)
            .accessibilityLabel("Frequency")
            .accessibilityValue("\(String(format: "%.4f", frequencyMHz)) megahertz")

            Text("MHz")
                .foregroundStyle(.secondary)
                .frame(width: 35)
                .accessibilityHidden(true)

            Button {
                incrementFrequency()
            } label: {
                Image(systemName: "plus")
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.bordered)
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
            set: { newValue in
                // Clamp to valid range 0-15
                colorCode = max(0, min(15, newValue))
            }
        )) {
            ForEach(RadioConstants.colorCodes, id: \.self) { cc in
                Text("CC \(cc)")
                    .accessibilityLabel("Color Code \(cc)")
                    .tag(cc)
            }
        }
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
    }
}

// MARK: - Bandwidth Picker

/// A segmented picker for selecting channel bandwidth (12.5 kHz / 25 kHz).
struct BandwidthPicker: View {
    @Binding var wideband: Bool
    var label: String = "Bandwidth"

    var body: some View {
        LabeledContent(label) {
            Picker(label, selection: $wideband) {
                Text("12.5 kHz")
                    .accessibilityLabel("12.5 kilohertz narrowband")
                    .tag(false)
                Text("25 kHz")
                    .accessibilityLabel("25 kilohertz wideband")
                    .tag(true)
            }
            .pickerStyle(.segmented)
            .frame(width: 140)
            .labelsHidden()
            .accessibilityLabel(label)
        }
    }
}

// MARK: - Channel Mode Picker

/// A segmented picker for selecting channel mode (Analog/Digital).
struct ChannelModePicker: View {
    @Binding var isDigital: Bool
    var label: String = "Mode"

    var body: some View {
        LabeledContent(label) {
            Picker(label, selection: $isDigital) {
                Text("Analog")
                    .accessibilityLabel("Analog FM mode")
                    .tag(false)
                Text("Digital")
                    .accessibilityLabel("Digital DMR mode")
                    .tag(true)
            }
            .pickerStyle(.segmented)
            .frame(width: 140)
            .labelsHidden()
            .accessibilityLabel(label)
        }
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
            set: { newValue in
                // Clamp to valid range
                contactType = max(0, min(2, newValue))
            }
        )) {
            ForEach(RadioConstants.ContactType.allCases, id: \.rawValue) { type in
                Text(type.displayName).tag(type.rawValue)
            }
        }
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
