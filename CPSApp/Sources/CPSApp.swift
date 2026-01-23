import SwiftUI
import RadioCore
import RadioModelCore
import APX
import CLP
import CLP2
import CP200
import DLRx
import Dtr
import Fiji
import Nome
import RDM
import Renoir
import RMM
import Solo
import Sunb
import Vanu
import XPR

@main
struct CPSApp: App {
    @State private var appCoordinator = AppCoordinator()

    init() {
        // Register all radio models
        // APX (P25) family
        RadioModelRegistry.register(APX900.self)
        RadioModelRegistry.register(APX4000UHF.self)
        RadioModelRegistry.register(APX4000VHF.self)
        RadioModelRegistry.register(APX6000UHF.self)
        RadioModelRegistry.register(APX6000VHF.self)
        RadioModelRegistry.register(APX6000_700.self)
        RadioModelRegistry.register(APX8000.self)
        // CLP family
        RadioModelRegistry.register(CLP1010.self)
        RadioModelRegistry.register(CLP1040.self)
        // CLP2 family
        RadioModelRegistry.register(CLP1100.self)
        RadioModelRegistry.register(CLP1140.self)
        RadioModelRegistry.register(CLP1160.self)
        // CP200 family
        RadioModelRegistry.register(CP200dUHF.self)
        RadioModelRegistry.register(CP200dVHF.self)
        // DLRx family
        RadioModelRegistry.register(DLR1020.self)
        RadioModelRegistry.register(DLR1060.self)
        // DTR family
        RadioModelRegistry.register(DTR410.self)
        RadioModelRegistry.register(DTR550.self)
        RadioModelRegistry.register(DTR600.self)
        RadioModelRegistry.register(DTR620.self)
        RadioModelRegistry.register(DTR650.self)
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
        // RDM (Retail Display) family
        RadioModelRegistry.register(RDM2020.self)
        RadioModelRegistry.register(RDM2070d.self)
        // Renoir (RMU) family
        RadioModelRegistry.register(RMU2040.self)
        RadioModelRegistry.register(RMU2080.self)
        RadioModelRegistry.register(RMV2080.self)
        // RMM (Mobile) family
        RadioModelRegistry.register(RMM2050.self)
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
        // XPR (MOTOTRBO) family
        RadioModelRegistry.register(XPR3300eUHF.self)
        RadioModelRegistry.register(XPR3300eVHF.self)
        RadioModelRegistry.register(XPR3500eUHF.self)
        RadioModelRegistry.register(XPR3500eVHF.self)
        RadioModelRegistry.register(XPR7350eUHF.self)
        RadioModelRegistry.register(XPR7550eUHF.self)
        RadioModelRegistry.register(XPR7550eVHF.self)
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(appCoordinator)
        }
        .defaultSize(width: 1100, height: 700)
        .commands {
            CPSCommands()
        }
    }
}
