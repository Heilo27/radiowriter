import Foundation
import USBTransport
import Network

/// Monitors for connected Motorola radios via USB serial ports and network interfaces.
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

    /// Performs a single scan for devices (serial ports and network interfaces).
    public func scanForDevices() async {
        var devices: [USBDeviceInfo] = []

        // Scan for serial ports (FTDI/CH340/etc programming cables)
        let serialDevices = await findSerialPorts()
        devices.append(contentsOf: serialDevices)

        // Scan for network-connected radios (CDC ECM/RNDIS)
        let networkDevices = await findNetworkRadios()
        devices.append(contentsOf: networkDevices)

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
                displayName: "Motorola Radio (\(port))",
                connectionType: .serial(path: path)
            )
            devices.append(device)
        }

        return devices
    }

    /// Finds Motorola radios connected via network (CDC ECM/RNDIS).
    nonisolated private func findNetworkRadios() async -> [USBDeviceInfo] {
        var devices: [USBDeviceInfo] = []

        // Look for Motorola network interfaces by checking networksetup
        // Motorola radios create CDC ECM interfaces typically on 192.168.10.x
        let motorolaInterfaces = findMotorolaNetworkInterfaces()

        for (interfaceName, ipAddress) in motorolaInterfaces {
            // Verify the radio is reachable
            if await isRadioReachable(at: ipAddress) {
                let device = USBDeviceInfo(
                    id: "network-\(interfaceName)",
                    vendorID: USBDeviceInfo.motorolaVendorID,
                    productID: 0x1022,
                    serialNumber: nil,
                    portPath: ipAddress,
                    displayName: "Motorola Radio (\(ipAddress))",
                    connectionType: .network(ip: ipAddress, interface: interfaceName)
                )
                devices.append(device)
            }
        }

        return devices
    }

    /// Finds network interfaces created by Motorola radios.
    nonisolated private func findMotorolaNetworkInterfaces() -> [(String, String)] {
        var interfaces: [(String, String)] = []

        // Use process to run networksetup and parse output
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/networksetup")
        process.arguments = ["-listallhardwareports"]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
            process.waitUntilExit()

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            guard let output = String(data: data, encoding: .utf8) else {
                return interfaces
            }

            // Parse the output looking for Motorola devices
            let lines = output.components(separatedBy: "\n")
            var currentIsMotorolaDevice = false
            var currentInterface = ""

            for line in lines {
                if line.contains("Motorola") {
                    currentIsMotorolaDevice = true
                } else if line.hasPrefix("Device:") && currentIsMotorolaDevice {
                    currentInterface = line.replacingOccurrences(of: "Device: ", with: "").trimmingCharacters(in: .whitespaces)
                    // Get the IP address for this interface
                    if let ip = getIPAddress(for: currentInterface) {
                        // The radio is typically at .1 on the same subnet
                        let radioIP = deriveRadioIP(from: ip)
                        interfaces.append((currentInterface, radioIP))
                    }
                    currentIsMotorolaDevice = false
                } else if line.hasPrefix("Hardware Port:") {
                    currentIsMotorolaDevice = false
                }
            }
        } catch {
            // Silently fail - no network radios detected
        }

        return interfaces
    }

    /// Gets the IP address assigned to a network interface.
    nonisolated private func getIPAddress(for interface: String) -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/sbin/ifconfig")
        process.arguments = [interface]

        let pipe = Pipe()
        process.standardOutput = pipe

        do {
            try process.run()
            process.waitUntilExit()

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            guard let output = String(data: data, encoding: .utf8) else { return nil }

            // Look for inet line: "inet 192.168.10.2 netmask ..."
            for line in output.components(separatedBy: "\n") {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                if trimmed.hasPrefix("inet ") && !trimmed.contains("inet6") {
                    let parts = trimmed.components(separatedBy: " ")
                    if parts.count >= 2 {
                        return parts[1]
                    }
                }
            }
        } catch {
            // Silently fail
        }

        return nil
    }

    /// Derives the radio's IP address from the host IP (typically .1 on the same subnet).
    nonisolated private func deriveRadioIP(from hostIP: String) -> String {
        let parts = hostIP.split(separator: ".")
        if parts.count == 4 {
            return "\(parts[0]).\(parts[1]).\(parts[2]).1"
        }
        return "192.168.10.1" // Default Motorola radio IP
    }

    /// Checks if the radio is reachable at the given IP address.
    nonisolated private func isRadioReachable(at ip: String) async -> Bool {
        // Quick ping check using Process
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/sbin/ping")
        process.arguments = ["-c", "1", "-t", "1", ip]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus == 0
        } catch {
            return false
        }
    }

    nonisolated private func extractSerial(from portName: String) -> String? {
        // Extract serial from port name like "cu.usbserial-A12345"
        let parts = portName.split(separator: "-")
        return parts.count > 1 ? String(parts.last!) : nil
    }
}
