import SwiftUI
import RadioCore
import RadioModelCore
import CLP
import CLP2
import DLRx
import Dtr
import Fiji
import Nome
import Renoir
import Solo
import Sunb
import Vanu

@main
struct CPSApp: App {
    @State private var appCoordinator = AppCoordinator()

    init() {
        // Register all radio models
        // CLP family
        RadioModelRegistry.register(CLP1010.self)
        RadioModelRegistry.register(CLP1040.self)
        // CLP2 family
        RadioModelRegistry.register(CLP1100.self)
        RadioModelRegistry.register(CLP1140.self)
        RadioModelRegistry.register(CLP1160.self)
        // DLRx family
        RadioModelRegistry.register(DLR1020.self)
        RadioModelRegistry.register(DLR1060.self)
        // DTR family
        RadioModelRegistry.register(DTR410.self)
        RadioModelRegistry.register(DTR620.self)
        RadioModelRegistry.register(DTR700.self)
        // Fiji (CLS) family
        RadioModelRegistry.register(CLS1110.self)
        RadioModelRegistry.register(CLS1410.self)
        RadioModelRegistry.register(VLR150.self)
        // Nome (RM) family
        RadioModelRegistry.register(RM110.self)
        RadioModelRegistry.register(RM160.self)
        RadioModelRegistry.register(RM410.self)
        RadioModelRegistry.register(RM460.self)
        // Renoir (RMU) family
        RadioModelRegistry.register(RMU2040.self)
        RadioModelRegistry.register(RMU2080.self)
        RadioModelRegistry.register(RMV2080.self)
        // Solo (RDU) family
        RadioModelRegistry.register(RDU2020.self)
        RadioModelRegistry.register(RDU2080.self)
        RadioModelRegistry.register(RDU4100.self)
        RadioModelRegistry.register(RDU4160.self)
        // Sunb (CLS) family
        RadioModelRegistry.register(CLS1450CB.self)
        RadioModelRegistry.register(CLS1450CH.self)
        // Vanu (VL/RDU4100d) family
        RadioModelRegistry.register(VL50.self)
        RadioModelRegistry.register(RDU4100d.self)
    }

    var body: some Scene {
        DocumentGroup(newDocument: CodeplugDocument()) { file in
            ContentView(document: file.$document)
                .environment(appCoordinator)
        }
        .defaultSize(width: 1100, height: 700)
        .commands {
            CPSCommands()
        }

        Window("Welcome to Motorola CPS", id: "welcome") {
            WelcomeView()
                .environment(appCoordinator)
        }
        .defaultSize(width: 600, height: 450)
        .windowResizability(.contentSize)
    }
}
