import SwiftUI
import RadioProgrammer
import RadioModelCore

/// View for managing DMR contacts.
struct ContactsView: View {
    @Environment(AppCoordinator.self) private var coordinator
    let searchText: String

    @State private var selectedContactIndex: Int?
    @State private var showingAddContact = false
    @State private var showingEditContact = false
    @State private var showingDeleteAlert = false

    var body: some View {
        HSplitView {
            contactListView
                .frame(minWidth: 250, maxWidth: 350)
            contactDetailView
                .frame(minWidth: 300)
        }
        .sheet(isPresented: $showingAddContact) {
            ContactEditorSheet(contact: nil) { newContact in
                addContact(newContact)
            }
        }
        .sheet(isPresented: $showingEditContact) {
            if let index = selectedContactIndex,
               let contacts = coordinator.parsedCodeplug?.contacts,
               index >= 0 && index < contacts.count {
                ContactEditorSheet(contact: contacts[index]) { updatedContact in
                    updateContact(updatedContact)
                }
            }
        }
        .alert("Delete Contact", isPresented: $showingDeleteAlert) {
            Button("Delete", role: .destructive) {
                deleteSelectedContact()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            if let contact = selectedContact {
                Text("Delete \"\(contact.name)\"? This cannot be undone.")
            }
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
                if !searchText.isEmpty && filteredContacts.isEmpty {
                    ContentUnavailableView.search(text: searchText)
                        .accessibilityLabel("No contacts match '\(searchText)'")
                } else {
                    List(selection: $selectedContactIndex) {
                        ForEach(filteredContacts, id: \.index) { item in
                            let isHighlighted = highlightMatch(item.contact.name) ||
                                highlightMatch(String(item.contact.dmrID))
                            ContactRow(contact: item.contact, isHighlighted: isHighlighted)
                                .tag(item.index)
                                .onTapGesture(count: 2) {
                                    selectedContactIndex = item.index
                                    showingEditContact = true
                                }
                                .contextMenu {
                                    Button {
                                        selectedContactIndex = item.index
                                        showingEditContact = true
                                    } label: {
                                        Label("Edit", systemImage: "pencil")
                                    }

                                    Divider()

                                    Button(role: .destructive) {
                                        selectedContactIndex = item.index
                                        showingDeleteAlert = true
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                        }
                    }
                    .listStyle(.inset)
                    .onDeleteCommand {
                        if selectedContactIndex != nil {
                            showingDeleteAlert = true
                        }
                    }
                    .onKeyPress(.return) {
                        if selectedContactIndex != nil {
                            showingEditContact = true
                            return .handled
                        }
                        return .ignored
                    }
                }
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
                            LabeledContent("Name", value: contact.name)
                            LabeledContent("Call Type", value: contact.contactType.rawValue)
                            LabeledContent("DMR ID", value: "\(contact.dmrID)")
                        }

                        GroupBox("Settings") {
                            LabeledContent("Call Receive Tone", value: contact.callReceiveTone ? "Enabled" : "Disabled")
                            LabeledContent("Call Alert", value: contact.callAlert ? "Enabled" : "Disabled")
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
        coordinator.updateContacts(contacts, actionName: "Add Contact")
        selectedContactIndex = contacts.count - 1
    }

    private func updateContact(_ contact: ParsedContact) {
        guard var contacts = coordinator.parsedCodeplug?.contacts,
              let index = selectedContactIndex,
              index >= 0 && index < contacts.count else { return }
        contacts[index] = contact
        coordinator.updateContacts(contacts, actionName: "Update Contact")
    }

    private func deleteSelectedContact() {
        guard var contacts = coordinator.parsedCodeplug?.contacts,
              let index = selectedContactIndex,
              index >= 0 && index < contacts.count else { return }
        contacts.remove(at: index)
        coordinator.updateContacts(contacts, actionName: "Delete Contact")
        if index >= contacts.count {
            selectedContactIndex = contacts.isEmpty ? nil : contacts.count - 1
        }
    }

    // MARK: - Search Filtering

    /// Filters contacts by name or DMR ID when search text is active
    private var filteredContacts: [(index: Int, contact: ParsedContact)] {
        guard let contacts = coordinator.parsedCodeplug?.contacts else { return [] }
        let indexed = contacts.enumerated().map { (index: $0.offset, contact: $0.element) }

        if searchText.isEmpty {
            return indexed
        }

        let lowercasedSearch = searchText.lowercased()
        return indexed.filter { item in
            // Match contact name
            if item.contact.name.lowercased().contains(lowercasedSearch) {
                return true
            }
            // Match DMR ID
            if String(item.contact.dmrID).contains(searchText) {
                return true
            }
            // Match contact type
            if item.contact.contactType.rawValue.lowercased().contains(lowercasedSearch) {
                return true
            }
            return false
        }
    }

    /// Checks if text contains search term (for highlighting)
    private func highlightMatch(_ text: String) -> Bool {
        guard !searchText.isEmpty else { return false }
        return text.lowercased().contains(searchText.lowercased())
    }
}

// MARK: - Contact Row

struct ContactRow: View {
    let contact: ParsedContact
    var isHighlighted: Bool = false

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: iconForType)
                .foregroundStyle(colorForType)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(contact.name)
                    .font(.body)
                    .foregroundStyle(isHighlighted ? Color.accentColor : .primary)
                HStack {
                    Text("ID: \(contact.dmrID)")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(isHighlighted ? Color.accentColor.opacity(0.8) : .secondary)
                    Text(contact.contactType.rawValue)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
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
        let contactData = contact ?? ParsedContact()
        _name = State(initialValue: contactData.name)
        _contactType = State(initialValue: contactData.contactType)
        _dmrID = State(initialValue: contactData.dmrID)
        _callReceiveTone = State(initialValue: contactData.callReceiveTone)
        _callAlert = State(initialValue: contactData.callAlert)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Basic Information") {
                    TextField("Contact Name", text: $name)
                        .accessibilityLabel("Contact name")

                    Picker("Call Type", selection: $contactType) {
                        ForEach(ContactCallType.allCases, id: \.self) { type in
                            Text(type.rawValue).tag(type)
                        }
                    }
                    .help("Private Call goes to one radio. Group Call broadcasts to a talk group. All Call reaches every radio on the channel.")

                    HStack {
                        Text("DMR ID")
                        Spacer()
                        TextField("ID", value: $dmrID, format: .number)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 120)
                            .accessibilityLabel("DMR ID number")
                            .accessibilityHint("Enter a numeric DMR ID from 1 to 16,777,215")
                    }
                    .help("DMR ID is a unique numeric identifier for a radio or talk group on DMR networks. Look up IDs at radioid.net.")
                }

                Section("Settings") {
                    Toggle("Call Receive Tone", isOn: $callReceiveTone)
                    Toggle("Call Alert", isOn: $callAlert)
                }
            }
            .navigationTitle(isNew ? "Add Contact" : "Edit Contact")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        var contact = ParsedContact()
                        contact.name = name
                        contact.dmrID = dmrID
                        contact.contactType = contactType
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
    ContactsView(searchText: "")
        .environment(AppCoordinator())
        .frame(width: 600, height: 400)
}
