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
                        errorMessage = "Failed to open file: \(error.localizedDescription)"
                        showingError = true
                    }
                }
            case .failure(let error):
                errorMessage = "Could not access file: \(error.localizedDescription)"
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
            case .failure(let error):
                errorMessage = "Failed to save file: \(error.localizedDescription)"
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
                // Could show a sheet with full discrepancy list in future
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
                defer { if accessing { url.stopAccessingSecurityScopedResource() } }
                do {
                    let content = try String(contentsOf: url, encoding: .utf8)
                    coordinator.importChannelsFromCSV(content)
                } catch {
                    errorMessage = "Failed to read CSV file: \(error.localizedDescription)"
                    showingError = true
                }
            case .failure(let error):
                errorMessage = "Could not access file: \(error.localizedDescription)"
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
                defer { if accessing { url.stopAccessingSecurityScopedResource() } }
                do {
                    let content = try String(contentsOf: url, encoding: .utf8)
                    coordinator.importContactsFromCSV(content)
                } catch {
                    errorMessage = "Failed to read CSV file: \(error.localizedDescription)"
                    showingError = true
                }
            case .failure(let error):
                errorMessage = "Could not access file: \(error.localizedDescription)"
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
            if case .failure(let error) = result {
                errorMessage = "Failed to export CSV: \(error.localizedDescription)"
                showingError = true
            }
        }
        .fileExporter(
            isPresented: $coordinator.showingExportContactsDialog,
            document: CSVDocument(content: coordinator.exportContactsToCSV() ?? ""),
            contentType: .commaSeparatedText,
            defaultFilename: "contacts"
        ) { result in
            if case .failure(let error) = result {
                errorMessage = "Failed to export CSV: \(error.localizedDescription)"
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
        .focusedValue(\.appCoordinator, coordinator)
    }
}
