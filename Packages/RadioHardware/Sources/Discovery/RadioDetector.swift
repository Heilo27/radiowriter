import Foundation
import USBTransport

/// Monitors for connected Motorola radios via USB serial ports.
/// All observable properties are isolated to MainActor for safe SwiftUI access.
@Observable
@MainActor
public final class RadioDetector: Sendable {
    public private(set) var detectedDevices: [USBDeviceInfo] = []
    public private(set) var isScanning = false
    private var scanTask: Task<Void, Never>?

    public init() {}

    /// Starts scanning for connected radio devices.
    public func startScanning() {
        guard !isScanning else { return }
        isScanning = true

        scanTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { break }
                await self.scanForDevices()
                guard !Task.isCancelled else { break }
                try? await Task.sleep(for: .seconds(2))
            }
            await MainActor.run { [weak self] in
                self?.isScanning = false
            }
        }
    }

    /// Stops scanning for devices.
    public func stopScanning() {
        scanTask?.cancel()
        scanTask = nil
        isScanning = false
    }

    /// Performs a single scan for serial devices.
    public func scanForDevices() async {
        let devices = await findSerialPorts()
        self.detectedDevices = devices
    }

    /// Finds all serial ports that match Motorola/FTDI devices.
    nonisolated private func findSerialPorts() async -> [USBDeviceInfo] {
        var devices: [USBDeviceInfo] = []

        // Scan /dev/ for USB serial devices
        let fileManager = FileManager.default
        guard let contents = try? fileManager.contentsOfDirectory(atPath: "/dev") else {
            return devices
        }

        let serialPorts = contents.filter { name in
            name.hasPrefix("cu.usbserial") || name.hasPrefix("cu.usbmodem")
        }

        for port in serialPorts {
            let path = "/dev/\(port)"
            let device = USBDeviceInfo(
                id: path,
                vendorID: USBDeviceInfo.ftdiVendorID,
                productID: 0x6001,
                serialNumber: extractSerial(from: port),
                portPath: path,
                displayName: "Motorola Radio (\(port))"
            )
            devices.append(device)
        }

        return devices
    }

    nonisolated private func extractSerial(from portName: String) -> String? {
        // Extract serial from port name like "cu.usbserial-A12345"
        let parts = portName.split(separator: "-")
        return parts.count > 1 ? String(parts.last!) : nil
    }
}
