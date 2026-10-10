import SwiftUI
import UniformTypeIdentifiers
import RadioProgrammer
import RadioModelCore

/// Simple document wrapper for CSV export.
struct CSVDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.commaSeparatedText, .text] }

    var content: String

    init(content: String) {
        self.content = content
    }

    init(configuration: ReadConfiguration) throws {
        if let data = configuration.file.regularFileContents,
           let string = String(data: data, encoding: .utf8) {
            content = string
        } else {
            throw CocoaError(.fileReadCorruptFile)
        }
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        guard let data = content.data(using: .utf8) else {
            throw CocoaError(.fileWriteUnknown)
        }
        return FileWrapper(regularFileWithContents: data)
    }
}

/// Router view that switches between welcome and editing phases.
struct RootView: View {
    @Environment(AppCoordinator.self) private var coordinator
    @State private var errorMessage: String?
    @State private var showingError = false
    @State private var csvExportContent: String = ""
    @State private var csvOperationInProgress = false
    @State private var csvOperationDescription = ""
    @State private var currentCSVTask: Task<Void, Never>?
    @State private var showingVerificationDetails = false

    var body: some View {
        @Bindable var coordinator = coordinator

        Group {
            switch coordinator.phase {
            case .welcome:
                WelcomeView()
            case .editing:
                ContentView()
            }
        }
        .fileImporter(
            isPresented: $coordinator.showingOpenDialog,
            allowedContentTypes: [.cpsx, .cpsLegacy],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                guard let url = urls.first else { return }
                let accessing = url.startAccessingSecurityScopedResource()
                defer { if accessing { url.stopAccessingSecurityScopedResource() } }

                // Run async open operation
                Task {
                    do {
                        try await coordinator.openDocument(url)
                    } catch {
                        errorMessage = "The file couldn't be opened. Make sure you have permission to access it."
                        showingError = true
                    }
                }
            case .failure:
                errorMessage = "The file couldn't be accessed. Make sure you have permission to read it."
                showingError = true
            }
        }
        .fileExporter(
            isPresented: $coordinator.showingSaveDialog,
            document: coordinator.currentDocument,
            contentType: .cpsx,
            defaultFilename: coordinator.currentDocument?.modelIdentifier ?? "Codeplug"
        ) { result in
            switch result {
            case .success(let url):
                coordinator.documentURL = url
            case .failure:
                errorMessage = "The file couldn't be saved. Make sure you have permission to write to this location."
                showingError = true
            }
        }
        .sheet(isPresented: $coordinator.showingProgrammingSheet) {
            ProgrammingView()
        }
        .sheet(isPresented: $coordinator.showingValidationSheet) {
            ValidationResultsView()
        }
        .alert("Error", isPresented: $showingError) {
            Button("OK") { showingError = false }
        } message: {
            Text(errorMessage ?? "An unknown error occurred")
        }
        .confirmationDialog(
            "You have unsaved changes",
            isPresented: $coordinator.showingCloseConfirmation,
            titleVisibility: .visible
        ) {
            Button("Save") {
                coordinator.saveAndCloseDocument()
            }
            Button("Don't Save", role: .destructive) {
                coordinator.forceCloseDocument()
            }
            Button("Cancel", role: .cancel) {
                coordinator.pendingCloseAction = nil
            }
        } message: {
            Text("Do you want to save your changes before closing?")
        }
        .alert("Backup Before Write?", isPresented: $coordinator.showingBackupBeforeWriteAlert) {
            Button("Backup & Write") {
                coordinator.backupAndWrite()
            }
            Button("Write Without Backup", role: .destructive) {
                coordinator.skipBackupAndWrite()
            }
            Button("Cancel", role: .cancel) {
                coordinator.pendingWriteAction = nil
            }
        } message: {
            Text("It's recommended to backup your current codeplug before writing changes to the radio. This protects against accidental data loss.")
        }
        .alert("Write Verification Warning", isPresented: $coordinator.showingVerificationFailureAlert) {
            Button("View Details") {
                showingVerificationDetails = true
            }
            Button("OK") {
                coordinator.writeVerificationResult = nil
            }
        } message: {
            if let result = coordinator.writeVerificationResult {
                let count = result.discrepancies.count
                let preview = result.discrepancies.prefix(3).map { $0.description }.joined(separator: "\n")
                let plural = count == 1 ? "y" : "ies"
                let moreText = count > 3 ? "\n...and \(count - 3) more" : ""
                Text("Write completed but verification found \(count) discrepanc\(plural):\n\n\(preview)\(moreText)")
            } else {
                Text("Write verification found discrepancies between written and read-back data.")
            }
        }
        // CSV Import dialogs
        .fileImporter(
            isPresented: $coordinator.showingImportChannelsDialog,
            allowedContentTypes: [.commaSeparatedText, .text],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                guard let url = urls.first else { return }
                let accessing = url.startAccessingSecurityScopedResource()
                csvOperationInProgress = true
                csvOperationDescription = "Reading CSV file..."
                currentCSVTask = Task {
                    defer { if accessing { url.stopAccessingSecurityScopedResource() } }
                    do {
                        let content = try await Task.detached(priority: .userInitiated) {
                            try String(contentsOf: url, encoding: .utf8)
                        }.value
                        guard !Task.isCancelled else {
                            csvOperationInProgress = false
                            return
                        }
                        csvOperationDescription = "Parsing channels..."
                        let importResult = await Task.detached(priority: .userInitiated) {
                            CSVService.importChannels(from: content)
                        }.value
                        coordinator.channelImportResult = importResult
                        coordinator.showingChannelImportSheet = true
                        csvOperationInProgress = false
                        csvOperationDescription = ""
                    } catch {
                        csvOperationInProgress = false
                        csvOperationDescription = ""
                        errorMessage = "The CSV file couldn't be read. Make sure it's a valid CSV file and try again."
                        showingError = true
                    }
                }
            case .failure:
                errorMessage = "The file couldn't be accessed. Make sure you have permission to read it."
                showingError = true
            }
        }
        .fileImporter(
            isPresented: $coordinator.showingImportContactsDialog,
            allowedContentTypes: [.commaSeparatedText, .text],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                guard let url = urls.first else { return }
                let accessing = url.startAccessingSecurityScopedResource()
                csvOperationInProgress = true
                csvOperationDescription = "Reading CSV file..."
                currentCSVTask = Task {
                    defer { if accessing { url.stopAccessingSecurityScopedResource() } }
                    do {
                        let content = try await Task.detached(priority: .userInitiated) {
                            try String(contentsOf: url, encoding: .utf8)
                        }.value
                        guard !Task.isCancelled else {
                            csvOperationInProgress = false
                            return
                        }
                        csvOperationDescription = "Parsing contacts..."
                        let importResult = await Task.detached(priority: .userInitiated) {
                            CSVService.importContacts(from: content)
                        }.value
                        coordinator.contactImportResult = importResult
                        coordinator.showingContactImportSheet = true
                        csvOperationInProgress = false
                        csvOperationDescription = ""
                    } catch {
                        csvOperationInProgress = false
                        csvOperationDescription = ""
                        errorMessage = "The CSV file couldn't be read. Make sure it's a valid CSV file and try again."
                        showingError = true
                    }
                }
            case .failure:
                errorMessage = "The file couldn't be accessed. Make sure you have permission to read it."
                showingError = true
            }
        }
        // CSV Template downloads
        .fileExporter(
            isPresented: $coordinator.showingExportChannelTemplateDialog,
            document: CSVDocument(content: CSVService.channelTemplateCSV()),
            contentType: .commaSeparatedText,
            defaultFilename: "channel-template"
        ) { result in
            if case .failure = result {
                errorMessage = "The template couldn't be saved. Make sure you have permission to write to the selected location."
                showingError = true
            }
        }
        .fileExporter(
            isPresented: $coordinator.showingExportContactTemplateDialog,
            document: CSVDocument(content: CSVService.contactTemplateCSV()),
            contentType: .commaSeparatedText,
            defaultFilename: "contact-template"
        ) { result in
            if case .failure = result {
                errorMessage = "The template couldn't be saved. Make sure you have permission to write to the selected location."
                showingError = true
            }
        }
        // CSV Export dialogs
        .fileExporter(
            isPresented: $coordinator.showingExportChannelsDialog,
            document: CSVDocument(content: coordinator.exportChannelsToCSV() ?? ""),
            contentType: .commaSeparatedText,
            defaultFilename: "channels"
        ) { result in
            if case .failure = result {
                errorMessage = "The channels couldn't be exported. Make sure you have permission to write to the selected location."
                showingError = true
            }
        }
        .fileExporter(
            isPresented: $coordinator.showingExportContactsDialog,
            document: CSVDocument(content: coordinator.exportContactsToCSV() ?? ""),
            contentType: .commaSeparatedText,
            defaultFilename: "contacts"
        ) { result in
            if case .failure = result {
                errorMessage = "The contacts couldn't be exported. Make sure you have permission to write to the selected location."
                showingError = true
            }
        }
        // CSV Import preview sheets
        .sheet(isPresented: $coordinator.showingChannelImportSheet) {
            if let result = coordinator.channelImportResult {
                ChannelImportPreviewView(importResult: result) {
                    coordinator.channelImportResult = nil
                }
            }
        }
        .sheet(isPresented: $coordinator.showingContactImportSheet) {
            if let result = coordinator.contactImportResult {
                ContactImportPreviewView(importResult: result) {
                    coordinator.contactImportResult = nil
                }
            }
        }
        // DMR ID Lookup sheet
        .sheet(isPresented: $coordinator.showingDMRIDLookup) {
            DMRIDLookupView()
        }
        .overlay {
            if csvOperationInProgress {
                ZStack {
                    Color.black.opacity(0.25)
                        .ignoresSafeArea()
                    VStack(spacing: 12) {
                        ProgressView(csvOperationDescription)
                            .controlSize(.regular)
                        Button("Cancel") {
                            currentCSVTask?.cancel()
                            csvOperationInProgress = false
                            csvOperationDescription = ""
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                    .padding(24)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                }
            }
        }
        .overlay {
            if coordinator.fileOperationInProgress {
                ZStack {
                    Color.black.opacity(0.25)
                        .ignoresSafeArea()
                    VStack(spacing: 12) {
                        ProgressView(coordinator.fileOperationStatus)
                            .controlSize(.regular)
                    }
                    .padding(24)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                }
            }
        }
        // FCC Warning Dialog
        .sheet(isPresented: $coordinator.showingFCCWarning) {
            FCCWarningDialog(
                warningManager: coordinator.regulatoryWarningManager,
                onAcknowledge: {
                    coordinator.regulatoryWarningManager.fccWarningAcknowledged = true
                }
            )
        }
        // Pre-Write Confirmation Dialog
        .sheet(isPresented: $coordinator.showingPreWriteConfirmation) {
            PreWriteConfirmationDialog(
                warningManager: coordinator.regulatoryWarningManager,
                onContinue: {
                    Task {
                        await coordinator.pendingWriteAction?()
                        coordinator.pendingWriteAction = nil
                    }
                }
            )
        }
        // Write Verification Details
        .sheet(isPresented: $showingVerificationDetails, onDismiss: {
            coordinator.writeVerificationResult = nil
        }) {
            if let result = coordinator.writeVerificationResult {
                VerificationDetailsView(result: result)
            }
        }
        // About Window
        .sheet(isPresented: $coordinator.showingAboutWindow) {
            AboutView()
        }
        // Keyboard Shortcuts reference
        .sheet(isPresented: $coordinator.showingKeyboardShortcuts) {
            KeyboardShortcutsView()
        }
        .focusedValue(\.appCoordinator, coordinator)
    }
}

/// Sheet listing every discrepancy found during write verification.
struct VerificationDetailsView: View {
    @Environment(\.dismiss) private var dismiss
    let result: WriteVerificationResult

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Write Verification Details")
                        .font(.headline)
                    Text(result.summary)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding()

            Divider()

            if result.discrepancies.isEmpty {
                ContentUnavailableView {
                    Label("No Discrepancies", systemImage: "checkmark.circle")
                } description: {
                    Text("The read-back data matched what was written.")
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(result.discrepancies) { discrepancy in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(discrepancy.category)
                                .font(.callout.bold())
                            Text(discrepancy.location)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        HStack(spacing: 16) {
                            LabeledContent("Expected", value: discrepancy.expected)
                            LabeledContent("Actual", value: discrepancy.actual)
                        }
                        .font(.caption)
                    }
                    .padding(.vertical, 4)
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel(discrepancy.description)
                }
                .listStyle(.inset)
            }

            Divider()

            HStack {
                Spacer()
                Button("Done") { dismiss() }
                    .keyboardShortcut(.defaultAction)
            }
            .padding()
        }
        .frame(minWidth: 480, minHeight: 360)
        .accessibilityIdentifier("verificationDetailsView")
    }
}
