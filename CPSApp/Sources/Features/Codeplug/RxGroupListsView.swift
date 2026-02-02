import SwiftUI
import RadioProgrammer

/// View for managing RX group lists.
struct RxGroupListsView: View {
    @Environment(AppCoordinator.self) private var coordinator
    @State private var selectedListIndex: Int?
    @State private var showingAddList = false
    @State private var showingEditList = false
    @State private var showingDeleteAlert = false

    var body: some View {
        HSplitView {
            // Left: RX Group lists
            listView
                .frame(minWidth: 200, maxWidth: 250)

            // Middle: Contacts in list
            listMembersView
                .frame(minWidth: 250, maxWidth: 350)

            // Right: Available contacts
            availableContactsView
                .frame(minWidth: 250)
        }
        .sheet(isPresented: $showingAddList) {
            RxGroupListEditorSheet(rxGroupList: nil) { newList in
                addList(newList)
            }
        }
        .sheet(isPresented: $showingEditList) {
            if let list = selectedList {
                RxGroupListEditorSheet(rxGroupList: list) { updatedList in
                    updateList(updatedList)
                }
            }
        }
        .alert("Delete RX Group List?", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                deleteSelectedList()
            }
        } message: {
            Text("This will delete '\(selectedList?.name ?? "")'. This cannot be undone.")
        }
    }

    // MARK: - List View

    private var listView: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("RX Group Lists")
                    .font(.headline)
                Spacer()
                Text("\(coordinator.parsedCodeplug?.rxGroupLists.count ?? 0)")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Button {
                    showingAddList = true
                } label: {
                    Image(systemName: "plus")
                }
                .buttonStyle(.borderless)
                .accessibilityLabel("Add RX group list")
            }
            .padding(.horizontal)
            .padding(.vertical, 8)

            Divider()

            if let lists = coordinator.parsedCodeplug?.rxGroupLists, !lists.isEmpty {
                List(selection: $selectedListIndex) {
                    ForEach(Array(lists.enumerated()), id: \.offset) { index, list in
                        HStack {
                            Image(systemName: "person.2.wave.2")
                                .foregroundStyle(.secondary)
                            Text(list.name)
                            Spacer()
                            Text("\(list.contactIndices.count)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .tag(index)
                        .contextMenu {
                            Button {
                                selectedListIndex = index
                                showingEditList = true
                            } label: {
                                Label("Rename", systemImage: "pencil")
                            }

                            Divider()

                            Button(role: .destructive) {
                                selectedListIndex = index
                                showingDeleteAlert = true
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                }
                .listStyle(.sidebar)
            } else {
                VStack {
                    ContentUnavailableView {
                        Label("No RX Group Lists", systemImage: "person.2.wave.2")
                    } description: {
                        Text("Create RX group lists for digital channels")
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("No RX group lists")
                    .accessibilityHint("Use the Add RX Group button below to create a new receive group list")

                    Button {
                        showingAddList = true
                    } label: {
                        Label("Add RX Group", systemImage: "plus")
                    }
                    .buttonStyle(.borderedProminent)
                    .padding(.bottom)
                }
            }
        }
    }

    // MARK: - List Members

    private var listMembersView: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Contacts in Group")
                    .font(.headline)
                Spacer()
                if let list = selectedList {
                    Text("\(list.contactIndices.count)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)

            Divider()

            if let list = selectedList, !list.contactIndices.isEmpty {
                List {
                    ForEach(list.contactIndices, id: \.self) { contactIndex in
                        if let contact = getContact(at: contactIndex) {
                            HStack {
                                ContactRow(contact: contact)
                                Spacer()
                                Button {
                                    removeContactFromList(contactIndex)
                                } label: {
                                    Image(systemName: "minus.circle")
                                        .foregroundStyle(.red)
                                }
                                .buttonStyle(.borderless)
                            }
                        }
                    }
                    .onMove { from, to in
                        moveContactsInList(from: from, to: to)
                    }
                }
                .listStyle(.inset)
            } else if selectedList != nil {
                ContentUnavailableView {
                    Label("No Contacts", systemImage: "person.2")
                } description: {
                    Text("Add contacts from the right panel")
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("No contacts in RX group")
                .accessibilityHint("Add contacts from the Available Contacts panel on the right")
            } else {
                ContentUnavailableView {
                    Label("Select RX Group", systemImage: "person.2.wave.2")
                } description: {
                    Text("Select an RX group list to see its contacts")
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Select an RX group list")
                .accessibilityHint("Choose an RX group list from the left panel to view its contacts")
            }
        }
    }

    // MARK: - Available Contacts

    private var availableContactsView: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Available Contacts")
                    .font(.headline)
                Spacer()
            }
            .padding(.horizontal)
            .padding(.vertical, 8)

            Divider()

            if let contacts = coordinator.parsedCodeplug?.contacts, !contacts.isEmpty {
                List {
                    ForEach(Array(contacts.enumerated()), id: \.offset) { index, contact in
                        HStack {
                            ContactRow(contact: contact)
                            Spacer()
                            if selectedList != nil {
                                let isInList = isContactInSelectedList(index)
                                Button {
                                    if isInList {
                                        removeContactFromList(index)
                                    } else {
                                        addContactToList(index)
                                    }
                                } label: {
                                    Image(systemName: isInList ? "checkmark.circle.fill" : "plus.circle")
                                        .foregroundStyle(isInList ? .green : .blue)
                                }
                                .buttonStyle(.borderless)
                            }
                        }
                    }
                }
                .listStyle(.inset)
            } else {
                ContentUnavailableView {
                    Label("No Contacts", systemImage: "person.2")
                } description: {
                    Text("Add contacts first to use in RX groups")
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("No contacts available")
                .accessibilityHint("Create contacts in the Contacts view first to add them to RX groups")
            }
        }
    }

    // MARK: - Helpers

    private var selectedList: ParsedRxGroupList? {
        guard let lists = coordinator.parsedCodeplug?.rxGroupLists,
              let index = selectedListIndex,
              index >= 0 && index < lists.count else { return nil }
        return lists[index]
    }

    private func getContact(at index: Int) -> ParsedContact? {
        guard let contacts = coordinator.parsedCodeplug?.contacts,
              index >= 0 && index < contacts.count else { return nil }
        return contacts[index]
    }

    private func isContactInSelectedList(_ contactIndex: Int) -> Bool {
        selectedList?.contactIndices.contains(contactIndex) ?? false
    }

    private func addList(_ list: ParsedRxGroupList) {
        var lists = coordinator.parsedCodeplug?.rxGroupLists ?? []
        lists.append(list)
        coordinator.parsedCodeplug?.rxGroupLists = lists
        selectedListIndex = lists.count - 1
    }

    private func updateList(_ list: ParsedRxGroupList) {
        guard var lists = coordinator.parsedCodeplug?.rxGroupLists,
              let index = selectedListIndex,
              index >= 0 && index < lists.count else { return }
        lists[index] = list
        coordinator.parsedCodeplug?.rxGroupLists = lists
    }

    private func deleteSelectedList() {
        guard var lists = coordinator.parsedCodeplug?.rxGroupLists,
              let index = selectedListIndex,
              index >= 0 && index < lists.count else { return }
        lists.remove(at: index)
        coordinator.parsedCodeplug?.rxGroupLists = lists
        if index >= lists.count {
            selectedListIndex = lists.isEmpty ? nil : lists.count - 1
        }
    }

    private func addContactToList(_ contactIndex: Int) {
        guard var lists = coordinator.parsedCodeplug?.rxGroupLists,
              let index = selectedListIndex,
              index >= 0 && index < lists.count else { return }

        if !lists[index].contactIndices.contains(contactIndex) {
            lists[index].contactIndices.append(contactIndex)
            coordinator.parsedCodeplug?.rxGroupLists = lists
        }
    }

    private func removeContactFromList(_ contactIndex: Int) {
        guard var lists = coordinator.parsedCodeplug?.rxGroupLists,
              let index = selectedListIndex,
              index >= 0 && index < lists.count else { return }

        lists[index].contactIndices.removeAll { $0 == contactIndex }
        coordinator.parsedCodeplug?.rxGroupLists = lists
    }

    private func moveContactsInList(from source: IndexSet, to destination: Int) {
        guard var lists = coordinator.parsedCodeplug?.rxGroupLists,
              let index = selectedListIndex,
              index >= 0 && index < lists.count else { return }

        lists[index].contactIndices.move(fromOffsets: source, toOffset: destination)
        coordinator.parsedCodeplug?.rxGroupLists = lists
    }
}

// MARK: - RX Group List Editor Sheet

struct RxGroupListEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var name: String

    let isNew: Bool
    let onSave: (ParsedRxGroupList) -> Void

    init(rxGroupList: ParsedRxGroupList?, onSave: @escaping (ParsedRxGroupList) -> Void) {
        self.isNew = rxGroupList == nil
        self.onSave = onSave
        let list = rxGroupList ?? ParsedRxGroupList()
        _name = State(initialValue: list.name)
    }

    var body: some View {
        VStack(spacing: 20) {
            Text(isNew ? "Add RX Group List" : "Rename RX Group List")
                .font(.headline)

            TextField("RX Group Name", text: $name)
                .textFieldStyle(.roundedBorder)
                .frame(width: 250)
                .accessibilityLabel("RX Group List Name")

            HStack {
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.escape)

                Button("Save") {
                    let list = ParsedRxGroupList(name: name)
                    onSave(list)
                    dismiss()
                }
                .keyboardShortcut(.return)
                .disabled(name.isEmpty)
            }
        }
        .padding(30)
    }
}

#Preview {
    RxGroupListsView()
        .environment(AppCoordinator())
        .frame(width: 800, height: 500)
}
