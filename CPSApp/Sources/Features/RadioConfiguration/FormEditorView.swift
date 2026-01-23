import SwiftUI
import RadioCore
import RadioModelCore

/// Form-based editor for scalar settings in a category.
struct FormEditorView: View {
    let codeplug: Codeplug
    let category: FieldCategory
    let modelIdentifier: String
    @State private var fields: [FieldDefinition] = []

    var body: some View {
        ScrollView {
            Form {
                ForEach(groupedFields, id: \.0) { group, groupFields in
                    Section(group) {
                        ForEach(groupFields, id: \.id) { field in
                            fieldRow(for: field)
                        }
                    }
                }
            }
            .formStyle(.grouped)
            .padding()
        }
        .onAppear { loadFields() }
    }

    private var groupedFields: [(String, [FieldDefinition])] {
        // Group fields by their node parent
        [("Settings", fields)]
    }

    @ViewBuilder
    private func fieldRow(for field: FieldDefinition) -> some View {
        switch field.valueType {
        case .bool:
            Toggle(field.displayName, isOn: boolBinding(for: field))
                .help(field.helpText ?? "")

        case .uint8, .int8:
            if let constraint = field.constraint, case .range(let min, let max) = constraint {
                LabeledContent(field.displayName) {
                    HStack {
                        Slider(value: numericBinding(for: field), in: Double(min)...Double(max), step: 1)
                        Text("\(codeplug.getValue(for: field).intValue ?? 0)")
                            .monospacedDigit()
                            .frame(width: 30)
                    }
                }
                .help(field.helpText ?? "")
            } else {
                LabeledContent(field.displayName) {
                    TextField("", value: intBinding(for: field), format: .number)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 80)
                }
                .help(field.helpText ?? "")
            }

        case .uint16, .uint32, .int16, .int32:
            LabeledContent(field.displayName) {
                TextField("", value: intBinding(for: field), format: .number)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 120)
            }
            .help(field.helpText ?? "")

        case .string(let maxLength, _):
            LabeledContent(field.displayName) {
                TextField("", text: stringBinding(for: field))
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: CGFloat(maxLength) * 10 + 40)
            }
            .help(field.helpText ?? "")

        case .enumeration(let options):
            Picker(field.displayName, selection: enumBinding(for: field)) {
                ForEach(options) { option in
                    Text(option.displayName).tag(option.id)
                }
            }
            .help(field.helpText ?? "")

        case .bitField, .bytes:
            LabeledContent(field.displayName) {
                Text("(Binary data)")
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Bindings

    private func boolBinding(for field: FieldDefinition) -> Binding<Bool> {
        Binding(
            get: { codeplug.getValue(for: field).boolValue ?? false },
            set: { codeplug.setValue(.bool($0), for: field) }
        )
    }

    private func numericBinding(for field: FieldDefinition) -> Binding<Double> {
        Binding(
            get: { Double(codeplug.getValue(for: field).intValue ?? 0) },
            set: { codeplug.setValue(.uint8(UInt8($0)), for: field) }
        )
    }

    private func intBinding(for field: FieldDefinition) -> Binding<Int> {
        Binding(
            get: { codeplug.getValue(for: field).intValue ?? 0 },
            set: {
                switch field.valueType {
                case .uint8: codeplug.setValue(.uint8(UInt8($0)), for: field)
                case .uint16: codeplug.setValue(.uint16(UInt16($0)), for: field)
                case .uint32: codeplug.setValue(.uint32(UInt32($0)), for: field)
                case .int8: codeplug.setValue(.int8(Int8($0)), for: field)
                case .int16: codeplug.setValue(.int16(Int16($0)), for: field)
                case .int32: codeplug.setValue(.int32(Int32($0)), for: field)
                default: break
                }
            }
        )
    }

    private func stringBinding(for field: FieldDefinition) -> Binding<String> {
        Binding(
            get: { codeplug.getValue(for: field).stringValue ?? "" },
            set: { codeplug.setValue(.string($0), for: field) }
        )
    }

    private func enumBinding(for field: FieldDefinition) -> Binding<UInt16> {
        Binding(
            get: {
                if case .enumValue(let v) = codeplug.getValue(for: field) { return v }
                return 0
            },
            set: { codeplug.setValue(.enumValue($0), for: field) }
        )
    }

    // MARK: - Loading

    private func loadFields() {
        guard let model = RadioModelRegistry.model(for: modelIdentifier) else { return }
        fields = model.allFields.filter { $0.category == category }
    }
}
