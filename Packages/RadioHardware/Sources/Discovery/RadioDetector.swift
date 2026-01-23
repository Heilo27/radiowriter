import Foundation
import USBTransport

/// Monitors for connected Motorola radios via USB serial ports.
@Observable
public final class RadioDetector: @unchecked Sendable {
    public private(set) var detectedDevices: [USBDeviceInfo] = []
    public private(set) var isScanning = false
    private var scanTask: Task<Void, Never>?

    public init() {}

    /// Starts scanning for connected radio devices.
    public func startScanning() {
        guard !isScanning else { return }
        isScanning = true

        scanTask = Task {
            while !Task.isCancelled {
                await scanForDevices()
                try? await Task.sleep(for: .seconds(2))
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
        await MainActor.run {
            self.detectedDevices = devices
        }
    }

    /// Finds all serial ports that match Motorola/FTDI devices.
    private func findSerialPorts() async -> [USBDeviceInfo] {
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

    private func extractSerial(from portName: String) -> String? {
        // Extract serial from port name like "cu.usbserial-A12345"
        let parts = portName.split(separator: "-")
        return parts.count > 1 ? String(parts.last!) : nil
    }
}
