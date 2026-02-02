import SwiftUI
import RadioProgrammer

/// View for managing DMR contacts.
struct ContactsView: View {
    @Environment(AppCoordinator.self) private var coordinator
    @State private var selectedContactIndex: Int?
    @State private var showingAddContact = false
    @State private var showingEditContact = false
    @State private var showingDeleteAlert = false

    var body: some View {
        HSplitView {
            // Left: Contact list
            contactListView
                .frame(minWidth: 250, maxWidth: 350)

            // Right: Contact detail/editor
            contactDetailView
                .frame(minWidth: 300)
        }
        .sheet(isPresented: $showingAddContact) {
            ContactEditorSheet(contact: nil) { newContact in
                addContact(newContact)
            }
        }
        .sheet(isPresented: $showingEditContact) {
            if let contact = selectedContact {
                ContactEditorSheet(contact: contact) { updatedContact in
                    updateContact(updatedContact)
                }
            }
        }
        .alert("Delete Contact?", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                deleteSelectedContact()
            }
        } message: {
            Text("This will delete '\(selectedContact?.name ?? "")'. This cannot be undone.")
        }
    }

    // MARK: - Contact List

    private var contactListView: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Text("Contacts")
                    .font(.headline)
                Spacer()
                Text("\(coordinator.parsedCodeplug?.contacts.count ?? 0)")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Button {
                    showingAddContact = true
                } label: {
                    Image(systemName: "plus")
                }
                .buttonStyle(.borderless)
                .accessibilityLabel("Add contact")
            }
            .padding(.horizontal)
            .padding(.vertical, 8)

            Divider()

            if let contacts = coordinator.parsedCodeplug?.contacts, !contacts.isEmpty {
                List(selection: $selectedContactIndex) {
                    ForEach(Array(contacts.enumerated()), id: \.offset) { index, contact in
                        ContactRow(contact: contact)
                            .tag(index)
                            .contextMenu {
                                Button {
                                    selectedContactIndex = index
                                    showingEditContact = true
                                } label: {
                                    Label("Edit", systemImage: "pencil")
                                }

                                Divider()

                                Button(role: .destructive) {
                                    selectedContactIndex = index
                                    showingDeleteAlert = true
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                    }
                }
                .listStyle(.inset)
            } else {
                VStack {
                    ContentUnavailableView {
                        Label("No Contacts", systemImage: "person.2")
                    } description: {
                        Text("Add contacts for DMR calls")
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("No contacts")
                    .accessibilityHint("Use the Add Contact button below to create a new DMR contact")

                    Button {
                        showingAddContact = true
                    } label: {
                        Label("Add Contact", systemImage: "plus")
                    }
                    .buttonStyle(.borderedProminent)
                    .padding(.bottom)
                }
            }
        }
    }

    // MARK: - Contact Detail

    private var contactDetailView: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Contact Details")
                    .font(.headline)
                Spacer()
                if selectedContact != nil {
                    Button {
                        showingEditContact = true
                    } label: {
                        Image(systemName: "pencil")
                    }
                    .buttonStyle(.borderless)
                    .accessibilityLabel("Edit contact")
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)

            Divider()

            if let contact = selectedContact {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        GroupBox("Basic Information") {
                            SettingRow("Name", value: contact.name)
                            SettingRow("Call Type", value: contact.contactType.rawValue)
                            SettingRow("DMR ID", value: "\(contact.dmrID)")
                        }

                        GroupBox("Settings") {
                            SettingRow("Call Receive Tone", value: contact.callReceiveTone ? "Enabled" : "Disabled")
                            SettingRow("Call Alert", value: contact.callAlert ? "Enabled" : "Disabled")
                        }
                    }
                    .padding()
                }
            } else {
                ContentUnavailableView {
                    Label("Select Contact", systemImage: "person.circle")
                } description: {
                    Text("Select a contact to view details")
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Select a contact")
                .accessibilityHint("Choose a contact from the left panel to view its details")
            }
        }
    }

    // MARK: - Helpers

    private var selectedContact: ParsedContact? {
        guard let contacts = coordinator.parsedCodeplug?.contacts,
              let index = selectedContactIndex,
              index >= 0 && index < contacts.count else { return nil }
        return contacts[index]
    }

    private func addContact(_ contact: ParsedContact) {
        var contacts = coordinator.parsedCodeplug?.contacts ?? []
        contacts.append(contact)
        coordinator.parsedCodeplug?.contacts = contacts
        selectedContactIndex = contacts.count - 1
    }

    private func updateContact(_ contact: ParsedContact) {
        guard var contacts = coordinator.parsedCodeplug?.contacts,
              let index = selectedContactIndex,
              index >= 0 && index < contacts.count else { return }
        contacts[index] = contact
        coordinator.parsedCodeplug?.contacts = contacts
    }

    private func deleteSelectedContact() {
        guard var contacts = coordinator.parsedCodeplug?.contacts,
              let index = selectedContactIndex,
              index >= 0 && index < contacts.count else { return }
        contacts.remove(at: index)
        coordinator.parsedCodeplug?.contacts = contacts
        if index >= contacts.count {
            selectedContactIndex = contacts.isEmpty ? nil : contacts.count - 1
        }
    }
}

// MARK: - Contact Row

struct ContactRow: View {
    let contact: ParsedContact

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: iconForType)
                .foregroundStyle(colorForType)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(contact.name)
                    .font(.body)
                HStack(spacing: 8) {
                    Text("ID: \(contact.dmrID)")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                    Text(contact.contactType.rawValue)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()
        }
        .padding(.vertical, 4)
    }

    private var iconForType: String {
        switch contact.contactType {
        case .privateCall: return "person"
        case .group: return "person.2"
        case .allCall: return "person.3"
        }
    }

    private var colorForType: Color {
        switch contact.contactType {
        case .privateCall: return .blue
        case .group: return .green
        case .allCall: return .orange
        }
    }
}

// MARK: - Contact Editor Sheet

struct ContactEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var contactType: ContactCallType
    @State private var dmrID: UInt32
    @State private var callReceiveTone: Bool
    @State private var callAlert: Bool

    let isNew: Bool
    let onSave: (ParsedContact) -> Void

    init(contact: ParsedContact?, onSave: @escaping (ParsedContact) -> Void) {
        self.isNew = contact == nil
        self.onSave = onSave
        let c = contact ?? ParsedContact()
        _name = State(initialValue: c.name)
        _contactType = State(initialValue: c.contactType)
        _dmrID = State(initialValue: c.dmrID)
        _callReceiveTone = State(initialValue: c.callReceiveTone)
        _callAlert = State(initialValue: c.callAlert)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Basic Information") {
                    TextField("Contact Name", text: $name)
                        .accessibilityLabel("Contact Name")

                    Picker("Call Type", selection: $contactType) {
                        ForEach(ContactCallType.allCases, id: \.self) { type in
                            Text(type.rawValue).tag(type)
                        }
                    }

                    HStack {
                        Text("DMR ID")
                        Spacer()
                        TextField("ID", value: $dmrID, format: .number)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 120)
                            .accessibilityLabel("DMR ID")
                            .accessibilityHint("Enter the contact's DMR radio identifier")
                    }
                }

                Section("Settings") {
                    Toggle("Call Receive Tone", isOn: $callReceiveTone)
                    Toggle("Call Alert", isOn: $callAlert)
                }
            }
            .formStyle(.grouped)
            .navigationTitle(isNew ? "Add Contact" : "Edit Contact")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        var contact = ParsedContact(name: name, dmrID: dmrID, type: contactType)
                        contact.callReceiveTone = callReceiveTone
                        contact.callAlert = callAlert
                        onSave(contact)
                        dismiss()
                    }
                    .disabled(name.isEmpty || dmrID == 0)
                }
            }
        }
        .frame(minWidth: 400, minHeight: 350)
    }
}

#Preview {
    ContactsView()
        .environment(AppCoordinator())
        .frame(width: 600, height: 400)
}
