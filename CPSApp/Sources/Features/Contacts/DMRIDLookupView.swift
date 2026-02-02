import SwiftUI
import RadioProgrammer

/// View for looking up DMR IDs from the RadioID.net database.
struct DMRIDLookupView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppCoordinator.self) private var coordinator
    @StateObject private var dmrService = DMRIDService.shared

    @State private var searchText = ""
    @State private var searchResults: [DMRIDService.DMRRecord] = []
    @State private var selectedRecord: DMRIDService.DMRRecord?

    let onSelect: ((DMRIDService.DMRRecord) -> Void)?

    init(onSelect: ((DMRIDService.DMRRecord) -> Void)? = nil) {
        self.onSelect = onSelect
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Search bar
                searchBar

                Divider()

                // Status bar
                statusBar

                Divider()

                // Results
                if searchResults.isEmpty && !searchText.isEmpty {
                    noResultsView
                } else if searchResults.isEmpty {
                    emptyStateView
                } else {
                    resultsList
                }
            }
            .navigationTitle("DMR ID Lookup")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .primaryAction) {
                    Button("Refresh Database") {
                        Task {
                            await dmrService.downloadDatabase(forceRefresh: true)
                        }
                    }
                    .disabled(isLoading)
                }
            }
            .frame(minWidth: 500, minHeight: 400)
        }
        .onAppear {
            // Auto-download if no database
            if dmrService.recordCount == 0 {
                Task {
                    await dmrService.downloadDatabase()
                }
            }
        }
    }

    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)

            TextField("Search by callsign, name, or DMR ID", text: $searchText)
                .textFieldStyle(.plain)
                .onSubmit {
                    performSearch()
                }
                .onChange(of: searchText) { _, newValue in
                    if newValue.count >= 2 {
                        performSearch()
                    } else {
                        searchResults = []
                    }
                }

            if !searchText.isEmpty {
                Button {
                    searchText = ""
                    searchResults = []
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding()
    }

    private var statusBar: some View {
        HStack {
            switch dmrService.state {
            case .idle:
                Text("Database not loaded")
                    .foregroundStyle(.secondary)
            case .loading(let progress):
                ProgressView(value: progress)
                    .progressViewStyle(.linear)
                    .frame(width: 100)
                Text("Loading database...")
                    .foregroundStyle(.secondary)
            case .loaded(let count):
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                Text("\(count.formatted()) records")
                    .foregroundStyle(.secondary)
                if let lastUpdated = dmrService.lastUpdated {
                    Text("Updated \(lastUpdated.formatted(date: .abbreviated, time: .omitted))")
                        .foregroundStyle(.tertiary)
                }
            case .error(let message):
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.red)
                Text(message)
                    .foregroundStyle(.red)
            }

            Spacer()

            if !searchResults.isEmpty {
                Text("\(searchResults.count) results")
                    .foregroundStyle(.secondary)
            }
        }
        .font(.caption)
        .padding(.horizontal)
        .padding(.vertical, 6)
        .background(Color(nsColor: .controlBackgroundColor))
    }

    private var resultsList: some View {
        List(searchResults, selection: $selectedRecord) { record in
            DMRRecordRow(record: record)
                .tag(record)
                .onTapGesture(count: 2) {
                    selectRecord(record)
                }
                .contextMenu {
                    Button("Add to Contacts") {
                        addToContacts(record)
                    }
                    Button("Copy DMR ID") {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString("\(record.id)", forType: .string)
                    }
                    Button("Copy Callsign") {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(record.callsign, forType: .string)
                    }
                }
        }
        .listStyle(.inset)
    }

    private var noResultsView: some View {
        ContentUnavailableView {
            Label("No Results", systemImage: "magnifyingglass")
        } description: {
            Text("No records found for \"\(searchText)\"")
        }
    }

    private var emptyStateView: some View {
        ContentUnavailableView {
            Label("Search DMR IDs", systemImage: "antenna.radiowaves.left.and.right")
        } description: {
            Text("Enter a callsign, name, or DMR ID to search the RadioID.net database")
        }
    }

    private var isLoading: Bool {
        if case .loading = dmrService.state {
            return true
        }
        return false
    }

    private func performSearch() {
        searchResults = dmrService.search(searchText, limit: 50)
    }

    private func selectRecord(_ record: DMRIDService.DMRRecord) {
        if let onSelect {
            onSelect(record)
            dismiss()
        }
    }

    private func addToContacts(_ record: DMRIDService.DMRRecord) {
        guard var codeplug = coordinator.parsedCodeplug else { return }

        let newContact = ParsedContact(
            name: record.displayName,
            dmrID: record.id,
            type: .privateCall
        )

        codeplug.contacts.append(newContact)
        coordinator.updateContacts(codeplug.contacts, actionName: "Add Contact '\(record.callsign)'")
    }
}

/// Row view for displaying a DMR record.
struct DMRRecordRow: View {
    let record: DMRIDService.DMRRecord

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 8) {
                    Text(record.callsign)
                        .font(.headline)
                        .foregroundStyle(.primary)

                    Text(record.name)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Text(record.location)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }

            Spacer()

            Text("\(record.id)")
                .font(.system(.body, design: .monospaced))
                .foregroundStyle(.blue)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - DMR ID Autocomplete Field

/// A text field with DMR ID autocomplete suggestions.
struct DMRIDAutocompleteField: View {
    @Binding var dmrID: UInt32
    @Binding var contactName: String

    @StateObject private var dmrService = DMRIDService.shared
    @State private var searchText = ""
    @State private var suggestions: [DMRIDService.DMRRecord] = []
    @State private var showingSuggestions = false
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                TextField("DMR ID or Callsign", text: $searchText)
                    .textFieldStyle(.roundedBorder)
                    .focused($isFocused)
                    .onChange(of: searchText) { _, newValue in
                        updateSuggestions(newValue)
                    }
                    .onSubmit {
                        applyFirstSuggestion()
                    }

                if let record = dmrService.lookup(byID: dmrID), dmrID > 0 {
                    Text(record.callsign)
                        .font(.caption)
                        .foregroundStyle(.blue)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(4)
                }
            }

            if showingSuggestions && !suggestions.isEmpty {
                suggestionsList
            }
        }
        .onAppear {
            if dmrID > 0 {
                searchText = "\(dmrID)"
            }
        }
    }

    private var suggestionsList: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(suggestions.prefix(5)) { record in
                Button {
                    selectSuggestion(record)
                } label: {
                    HStack {
                        Text(record.callsign)
                            .fontWeight(.medium)
                        Text(record.name)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("\(record.id)")
                            .font(.caption)
                            .foregroundStyle(.blue)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                if record.id != suggestions.prefix(5).last?.id {
                    Divider()
                }
            }
        }
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(6)
        .shadow(radius: 2)
        .padding(.top, 2)
    }

    private func updateSuggestions(_ query: String) {
        if query.count >= 2 {
            suggestions = dmrService.search(query, limit: 5)
            showingSuggestions = true
        } else {
            suggestions = []
            showingSuggestions = false
        }
    }

    private func selectSuggestion(_ record: DMRIDService.DMRRecord) {
        dmrID = record.id
        contactName = record.displayName
        searchText = "\(record.id)"
        showingSuggestions = false
    }

    private func applyFirstSuggestion() {
        if let first = suggestions.first {
            selectSuggestion(first)
        } else if let id = UInt32(searchText) {
            dmrID = id
        }
        showingSuggestions = false
    }
}
