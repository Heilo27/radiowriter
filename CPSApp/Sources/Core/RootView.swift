import SwiftUI
import UniformTypeIdentifiers

/// Router view that switches between welcome and editing phases.
struct RootView: View {
    @Environment(AppCoordinator.self) private var coordinator

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
                    // TODO: Present error to user
                    print("Failed to open document: \(error)")
                }
            case .failure(let error):
                print("File import failed: \(error)")
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
                print("File export failed: \(error)")
            }
        }
    }
}
