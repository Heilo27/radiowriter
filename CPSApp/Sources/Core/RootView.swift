import SwiftUI
import UniformTypeIdentifiers

/// Router view that switches between welcome and editing phases.
struct RootView: View {
    @Environment(AppCoordinator.self) private var coordinator
    @State private var errorMessage: String?
    @State private var showingError = false

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
                do {
                    try coordinator.openDocument(url)
                } catch {
                    errorMessage = "Failed to open file: \(error.localizedDescription)"
                    showingError = true
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
        .focusedValue(\.appCoordinator, coordinator)
    }
}
