import Foundation
import USBTransport
import Network
import IOKit
import IOKit.usb

/// Monitors for connected Motorola radios via USB serial ports, USB devices, and network interfaces.
/// All observable properties are isolated to MainActor for safe SwiftUI access.
@Observable
@MainActor
public final class RadioDetector {
    public private(set) var detectedDevices: [USBDeviceInfo] = []
    public private(set) var isScanning = false

    /// Diagnostic log of the last scan (for debugging)
    public private(set) var lastScanLog: String = ""

    /// mDNS browser for OTAP service discovery (like CPS uses)
    private var mdnsBrowser: NWBrowser?
    private var mdnsDiscoveredIPs: Set<String> = []

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

    /// Performs a single scan for devices (USB, serial ports, and network interfaces).
    public func scanForDevices() async {
        var devices: [USBDeviceInfo] = []
        var log = "=== Radio Scan @ \(Date()) ===\n"

        // Method 1: Look for Motorola USB devices by VID/PID first
        // MOTOTRBO radios use VID 0x0CAD with PIDs 0x1020-0x102D
        log += "\n[Motorola USB Devices]\n"
        let motorolaUSBDevices = await findMotorolaUSBDevices(log: &log)

        // Method 2: If we found Motorola USB devices, find their network interfaces
        // On macOS, these appear as CDC-ECM adapters
        if !motorolaUSBDevices.isEmpty {
            log += "\n[Finding Network Interface for Motorola USB]\n"
            let usbNetworkDevices = await findUSBNetworkInterface(for: motorolaUSBDevices, log: &log)
            devices.append(contentsOf: usbNetworkDevices)
        }

        // Method 3: mDNS discovery for _otap._tcp.local (like CPS 2.0 uses)
        // This discovers radios advertising via Bonjour/mDNS
        if devices.isEmpty {
            log += "\n[mDNS Discovery (_otap._tcp.local)]\n"
            let mdnsDevices = await findRadiosViaMDNS(log: &log)
            devices.append(contentsOf: mdnsDevices)
        }

        // Method 4: Scan for network-connected radios (CDC ECM - XPR series)
        // This catches radios whose USB device might not be detected by IOKit
        if devices.isEmpty {
            log += "\n[Network Interfaces - IP Scan]\n"
            let networkDevices = await findNetworkRadios(log: &log)
            devices.append(contentsOf: networkDevices)
        }

        // Method 5: Scan for serial ports (FTDI/CH340/etc programming cables)
        log += "\n[Serial Ports]\n"
        let serialDevices = await findSerialPorts(log: &log)
        devices.append(contentsOf: serialDevices)

        // Log all USB devices for debugging
        log += "\n[All USB Devices (debug)]\n"
        var usbLog = ""
        _ = await findUSBDevices(log: &usbLog)
        log += usbLog

        // Add routing table info for debugging
        log += "\n[Routing Table (private networks)]\n"
        log += getRoutingTableInfo()

        log += "\n[Result: \(devices.count) devices found]\n"

        if devices.isEmpty {
            log += "\n" + String(repeating: "=", count: 50) + "\n"
            log += "TROUBLESHOOTING CHECKLIST\n"
            log += String(repeating: "=", count: 50) + "\n\n"

            // Different guidance based on what we found
            if motorolaUSBDevices.isEmpty {
                log += "[USB LEVEL - Radio NOT on USB bus]\n"
                log += "The radio is not appearing as a USB device at all.\n"
                log += "This is a hardware/connection issue, not a software issue.\n\n"
                log += "Check these in order:\n"
                log += "1. Is the radio FULLY powered ON? (Power button, not just plugged in)\n"
                log += "   - Charging indicator alone is NOT enough\n"
                log += "   - Radio display should be lit and responsive\n\n"
                log += "2. Is this a USB DATA cable?\n"
                log += "   - Some cables are charge-only (2 wires instead of 4)\n"
                log += "   - Try a cable that you KNOW transfers data\n\n"
                log += "3. Try a different USB port\n"
                log += "   - USB-C ports may work better than USB-A hubs\n"
                log += "   - Avoid USB hubs if possible\n\n"
                log += "4. Check for VM USB passthrough\n"
                log += "   - Parallels/VMware/UTM may be capturing the USB device\n"
                log += "   - Check VM > Devices > USB menu\n\n"
                log += "5. Power cycle the radio completely\n"
                log += "   - Turn OFF the radio\n"
                log += "   - Unplug USB\n"
                log += "   - Wait 10 seconds\n"
                log += "   - Plug in USB\n"
                log += "   - Turn ON the radio\n\n"
                log += "6. Check System Information\n"
                log += "   - Apple menu > About This Mac > System Report > USB\n"
                log += "   - Look for 'Motorola' or vendor ID 0x0CAD (3245)\n\n"
            } else {
                log += "[NETWORK LEVEL - USB found but no network]\n"
                log += "Radio appeared on USB but network interface isn't ready.\n\n"
                log += "This usually resolves in 5-10 seconds. If not:\n"
                log += "1. Wait 10-15 seconds for CDC-ECM driver to initialize\n"
                log += "2. Check System Settings > Network for new interface\n"
                log += "3. Try unplugging and replugging USB\n\n"
            }

            log += "DIAGNOSTIC COMMANDS:\n"
            log += "  ioreg -p IOUSB -l | grep -i motorola\n"
            log += "  system_profiler SPUSBDataType | grep -A 10 -i motorola\n"
            log += "  ifconfig | grep -A 5 192.168.10\n"
            log += "  nc -z -v -G 1 192.168.10.1 8002\n"
        }

        self.detectedDevices = devices
        self.lastScanLog = log
    }

    /// Gets routing table info for debugging.
    nonisolated private func getRoutingTableInfo() -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/netstat")
        process.arguments = ["-rn"]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
            process.waitUntilExit()

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            guard let output = String(data: data, encoding: .utf8) else {
                return "  Could not read routing table\n"
            }

            // Filter for private network routes
            let lines = output.components(separatedBy: "\n")
            var result = ""
            for line in lines {
                if line.contains("192.168") || line.contains("10.") || line.contains("169.254") || line.contains("172.") {
                    if !line.contains("192.168.50") { // Skip main network
                        result += "  \(line)\n"
                    }
                }
            }

            return result.isEmpty ? "  No radio-specific routes found\n" : result
        } catch {
            return "  Error reading routing table: \(error)\n"
        }
    }

    // MARK: - Motorola USB Device Detection

    /// MOTOTRBO USB Vendor ID
    nonisolated private static let motorolaVID: Int = 0x0CAD  // 3245 decimal

    /// MOTOTRBO USB Product IDs (from mototrbo.inf driver)
    nonisolated private static let mototrboProductIDs: Set<Int> = [
        0x1020, 0x1021, 0x1022, 0x1023, 0x1024, 0x1025, 0x1026,
        0x1027, 0x1028, 0x1029, 0x102A, 0x102B, 0x102C, 0x102D
    ]

    /// Finds Motorola MOTOTRBO USB devices by their specific VID/PID.
    nonisolated private func findMotorolaUSBDevices(log: inout String) async -> [(vendorID: Int, productID: Int, serial: String?)] {
        var found: [(vendorID: Int, productID: Int, serial: String?)] = []

        guard let matchingDict = IOServiceMatching(kIOUSBDeviceClassName) else {
            log += "  Failed to create matching dictionary\n"
            return found
        }

        var iterator: io_iterator_t = 0
        let result = IOServiceGetMatchingServices(kIOMainPortDefault, matchingDict, &iterator)

        guard result == KERN_SUCCESS else {
            log += "  Failed to get USB devices: \(result)\n"
            return found
        }

        defer { IOObjectRelease(iterator) }

        var service = IOIteratorNext(iterator)
        while service != 0 {
            defer {
                IOObjectRelease(service)
                service = IOIteratorNext(iterator)
            }

            var vendorID: Int = 0
            var productID: Int = 0
            var serialNumber: String?

            if let vendorRef = IORegistryEntryCreateCFProperty(service, "idVendor" as CFString, kCFAllocatorDefault, 0) {
                vendorID = (vendorRef.takeRetainedValue() as? Int) ?? 0
            }
            if let productRef = IORegistryEntryCreateCFProperty(service, "idProduct" as CFString, kCFAllocatorDefault, 0) {
                productID = (productRef.takeRetainedValue() as? Int) ?? 0
            }
            if let serialRef = IORegistryEntryCreateCFProperty(service, "USB Serial Number" as CFString, kCFAllocatorDefault, 0) {
                serialNumber = serialRef.takeRetainedValue() as? String
            }

            // Check if this is a Motorola MOTOTRBO device
            if vendorID == Self.motorolaVID && Self.mototrboProductIDs.contains(productID) {
                let vidHex = String(format: "0x%04X", vendorID)
                let pidHex = String(format: "0x%04X", productID)
                log += "  FOUND MOTOTRBO: VID=\(vidHex) PID=\(pidHex) Serial=\(serialNumber ?? "none")\n"
                found.append((vendorID, productID, serialNumber))
            }
        }

        if found.isEmpty {
            log += "  No Motorola MOTOTRBO devices found (VID 0x0CAD)\n"
            log += "  Tip: Make sure radio is powered ON (not just charging)\n"
        }

        return found
    }

    // MARK: - mDNS Discovery

    /// Discovers radios via mDNS/Bonjour using _otap._tcp.local service.
    /// This is how CPS 2.0 discovers radios (from DNSConfig.xml).
    nonisolated private func findRadiosViaMDNS(log: inout String) async -> [USBDeviceInfo] {
        var devices: [USBDeviceInfo] = []

        // CPS uses _otap._tcp.local for OTAP (Over-The-Air Programming) discovery
        // This is configured in MOTOTRBO/Metadata/DNS/DNSConfig.xml
        let serviceType = "_otap._tcp"

        log += "  Looking for \(serviceType).local services...\n"

        // Perform mDNS browse with async/await wrapper
        let (discoveredEndpoints, browseLog) = await browseMDNSServices(serviceType: serviceType)
        log += browseLog

        if discoveredEndpoints.isEmpty {
            log += "  No OTAP services found via mDNS\n"
            log += "  (This is normal if radio doesn't advertise mDNS)\n"
        }

        // Resolve discovered services to get IP addresses
        for (endpoint, name) in discoveredEndpoints {
            if let ip = await resolveEndpointToIP(endpoint) {
                log += "  Resolved \(name) -> \(ip)\n"

                // Verify XNL port is open
                if await isXNLPortOpen(at: ip) {
                    log += "  XNL port OPEN at \(ip) - Radio found!\n"
                    let device = USBDeviceInfo(
                        id: "mdns-\(name)-\(ip)",
                        vendorID: USBDeviceInfo.motorolaVendorID,
                        productID: 0x1022,
                        serialNumber: nil,
                        portPath: ip,
                        displayName: "Radio via mDNS (\(name))",
                        connectionType: .network(ip: ip, interface: "mdns")
                    )
                    devices.append(device)
                }
            }
        }

        return devices
    }

    /// Browses for mDNS services and returns discovered endpoints with log.
    nonisolated private func browseMDNSServices(serviceType: String) async -> ([(NWEndpoint, String)], String) {
        return await withCheckedContinuation { continuation in
            let browser = NWBrowser(for: .bonjour(type: serviceType, domain: "local"), using: .tcp)
            let queue = DispatchQueue(label: "com.radiowriter.mdns")

            // Use a class to hold mutable state safely across concurrent contexts
            final class BrowseState: @unchecked Sendable {
                var hasResumed = false
                var discoveredEndpoints: [(NWEndpoint, String)] = []
                var logMessages = ""
                let resumeLock = NSLock()
                let lock = NSLock()
            }
            let state = BrowseState()

            let safeResume: @Sendable () -> Void = {
                state.resumeLock.lock()
                defer { state.resumeLock.unlock() }
                guard !state.hasResumed else { return }
                state.hasResumed = true
                browser.cancel()
                // Acquire data lock before reading shared state to prevent races
                state.lock.lock()
                let endpoints = state.discoveredEndpoints
                let logs = state.logMessages
                state.lock.unlock()
                continuation.resume(returning: (endpoints, logs))
            }

            browser.stateUpdateHandler = { browserState in
                state.lock.lock()
                defer { state.lock.unlock() }
                switch browserState {
                case .ready:
                    state.logMessages += "  mDNS browser ready\n"
                case .failed(let error):
                    state.logMessages += "  mDNS browser failed: \(error)\n"
                    safeResume()
                case .cancelled:
                    safeResume()
                default:
                    break
                }
            }

            browser.browseResultsChangedHandler = { results, _ in
                state.lock.lock()
                defer { state.lock.unlock() }
                for result in results {
                    if case let .service(name, type, domain, _) = result.endpoint {
                        state.logMessages += "  Found service: \(name).\(type).\(domain)\n"
                        if !state.discoveredEndpoints.contains(where: { $0.1 == name }) {
                            state.discoveredEndpoints.append((result.endpoint, name))
                        }
                    }
                }
            }

            browser.start(queue: queue)

            // Timeout after 2 seconds
            queue.asyncAfter(deadline: .now() + 2.0) {
                safeResume()
            }
        }
    }

    /// Resolves an NWEndpoint to an IP address string.
    nonisolated private func resolveEndpointToIP(_ endpoint: NWEndpoint) async -> String? {
        // Try to connect briefly to resolve the endpoint
        let connection = NWConnection(to: endpoint, using: .tcp)
        let queue = DispatchQueue(label: "com.radiowriter.resolve")

        return await withCheckedContinuation { continuation in
            var hasResumed = false
            let lock = NSLock()

            func safeResume(_ value: String?) {
                lock.lock()
                defer { lock.unlock() }
                guard !hasResumed else { return }
                hasResumed = true
                connection.cancel()
                continuation.resume(returning: value)
            }

            // Timeout after 2 seconds
            queue.asyncAfter(deadline: .now() + 2.0) {
                safeResume(nil)
            }

            connection.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    // Get the remote endpoint's resolved address
                    if let path = connection.currentPath,
                       let remoteEndpoint = path.remoteEndpoint,
                       case let .hostPort(host, _) = remoteEndpoint {
                        switch host {
                        case .ipv4(let addr):
                            let ip = addr.debugDescription
                            safeResume(ip)
                        case .ipv6(let addr):
                            let ip = addr.debugDescription
                            safeResume(ip)
                        default:
                            safeResume(nil)
                        }
                    } else {
                        safeResume(nil)
                    }
                case .failed, .cancelled:
                    safeResume(nil)
                default:
                    break
                }
            }

            connection.start(queue: queue)
        }
    }

    /// Finds the network interface created by macOS for a Motorola CDC-ECM USB device.
    nonisolated private func findUSBNetworkInterface(
        for usbDevices: [(vendorID: Int, productID: Int, serial: String?)],
        log: inout String
    ) async -> [USBDeviceInfo] {
        var devices: [USBDeviceInfo] = []

        // When a MOTOTRBO radio is connected via USB, macOS creates a CDC-ECM
        // network interface. We need to find it and get its IP configuration.

        // Get all network interfaces
        let interfaces = findAllNetworkInterfaces(log: &log)

        for (iface, ip) in interfaces {
            // CDC-ECM interfaces from USB radios typically:
            // 1. Have names like en7, en17, etc. (higher numbered)
            // 2. Get IPs in the 192.168.10.x range (radio DHCP)

            // Check if this interface is in a radio-typical subnet
            if ip.hasPrefix("192.168.10.") || ip.hasPrefix("192.168.") {
                // Try to connect to XNL port to confirm it's a radio
                let radioIP = deriveRadioIP(from: ip)
                log += "  Trying \(iface) -> \(radioIP)...\n"

                if await isXNLPortOpen(at: radioIP) {
                    log += "    XNL port OPEN - Radio found!\n"
                    let device = USBDeviceInfo(
                        id: "usb-cdc-\(iface)-\(radioIP)",
                        vendorID: UInt16(usbDevices.first?.vendorID ?? Self.motorolaVID),
                        productID: UInt16(usbDevices.first?.productID ?? 0x1022),
                        serialNumber: usbDevices.first?.serial,
                        portPath: radioIP,
                        displayName: "MOTOTRBO Radio (\(radioIP))",
                        connectionType: .network(ip: radioIP, interface: iface)
                    )
                    devices.append(device)
                    return devices  // Found it, no need to continue
                }
            }
        }

        // If we have USB devices but couldn't find the interface, it might still be initializing
        if !usbDevices.isEmpty && devices.isEmpty {
            log += "  Motorola USB device detected but network interface not ready\n"
            log += "  Tip: Wait 5-10 seconds for interface to initialize\n"
        }

        return devices
    }

    /// Gets all network interfaces with their IP addresses.
    nonisolated private func findAllNetworkInterfaces(log: inout String) -> [(String, String)] {
        var interfaces: [(String, String)] = []

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/sbin/ifconfig")
        process.arguments = ["-a"]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
            process.waitUntilExit()

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            guard let output = String(data: data, encoding: .utf8) else { return interfaces }

            var currentInterface = ""
            var currentIP = ""

            for line in output.components(separatedBy: "\n") {
                if !line.hasPrefix("\t") && !line.hasPrefix(" ") && line.contains(":") {
                    // Save previous interface
                    if !currentInterface.isEmpty && !currentIP.isEmpty && currentIP != "127.0.0.1" {
                        interfaces.append((currentInterface, currentIP))
                    }
                    currentInterface = String(line.split(separator: ":").first ?? "")
                    currentIP = ""
                }

                let trimmed = line.trimmingCharacters(in: .whitespaces)
                if trimmed.hasPrefix("inet ") && !trimmed.contains("inet6") {
                    let parts = trimmed.components(separatedBy: " ")
                    if parts.count >= 2 {
                        currentIP = parts[1]
                    }
                }
            }

            // Don't forget the last one
            if !currentInterface.isEmpty && !currentIP.isEmpty && currentIP != "127.0.0.1" {
                interfaces.append((currentInterface, currentIP))
            }
        } catch {
            log += "  Error running ifconfig: \(error)\n"
        }

        return interfaces
    }

    // MARK: - USB Device Scanning (IOKit)

    /// Finds USB devices that could be Motorola radios.
    nonisolated private func findUSBDevices(log: inout String) async -> [USBDeviceInfo] {
        // Known Motorola Solutions vendor IDs (defined locally to avoid actor isolation issues)
        let motorolaVendorIDs: Set<Int> = [
            0x0CAD,  // Motorola Solutions MOTOTRBO (primary!)
            0x0451,  // Texas Instruments (some legacy Motorola)
            0x22B8,  // Motorola (phones)
            0x2B4C,  // Motorola Solutions (modern radios)
            0x2EF4,  // Motorola Solutions (XPR series)
        ]

        var devices: [USBDeviceInfo] = []

        // Get the USB device matching dictionary
        guard let matchingDict = IOServiceMatching(kIOUSBDeviceClassName) else {
            log += "  Failed to create matching dictionary\n"
            return devices
        }

        var iterator: io_iterator_t = 0
        let result = IOServiceGetMatchingServices(kIOMainPortDefault, matchingDict, &iterator)

        guard result == KERN_SUCCESS else {
            log += "  Failed to get USB devices: \(result)\n"
            return devices
        }

        defer { IOObjectRelease(iterator) }

        var service = IOIteratorNext(iterator)
        while service != 0 {
            defer {
                IOObjectRelease(service)
                service = IOIteratorNext(iterator)
            }

            // Get vendor and product IDs
            var vendorID: Int = 0
            var productID: Int = 0
            var productName = ""
            var vendorName = ""
            var serialNumber: String?

            if let vendorRef = IORegistryEntryCreateCFProperty(service, "idVendor" as CFString, kCFAllocatorDefault, 0) {
                vendorID = (vendorRef.takeRetainedValue() as? Int) ?? 0
            }
            if let productRef = IORegistryEntryCreateCFProperty(service, "idProduct" as CFString, kCFAllocatorDefault, 0) {
                productID = (productRef.takeRetainedValue() as? Int) ?? 0
            }
            if let nameRef = IORegistryEntryCreateCFProperty(service, "USB Product Name" as CFString, kCFAllocatorDefault, 0) {
                productName = (nameRef.takeRetainedValue() as? String) ?? ""
            }
            if let vendorRef = IORegistryEntryCreateCFProperty(service, "USB Vendor Name" as CFString, kCFAllocatorDefault, 0) {
                vendorName = (vendorRef.takeRetainedValue() as? String) ?? ""
            }
            if let serialRef = IORegistryEntryCreateCFProperty(service, "USB Serial Number" as CFString, kCFAllocatorDefault, 0) {
                serialNumber = serialRef.takeRetainedValue() as? String
            }

            // Log all USB devices for debugging
            if vendorID != 0 {
                let vendorHex = String(format: "0x%04X", vendorID)
                let productHex = String(format: "0x%04X", productID)
                log += "  \(vendorName) \(productName) [\(vendorHex):\(productHex)]\n"

                // Check if this could be a Motorola radio
                let isMotorola = motorolaVendorIDs.contains(vendorID) ||
                                 vendorName.lowercased().contains("motorola") ||
                                 productName.lowercased().contains("moto") ||
                                 productName.lowercased().contains("xpr") ||
                                 productName.lowercased().contains("radio")

                if isMotorola {
                    log += "    ^ MOTOROLA DETECTED!\n"
                    let device = USBDeviceInfo(
                        id: "usb-\(vendorID)-\(productID)",
                        vendorID: UInt16(vendorID),
                        productID: UInt16(productID),
                        serialNumber: serialNumber,
                        portPath: "USB",
                        displayName: productName.isEmpty ? "Motorola Radio" : productName,
                        connectionType: .serial(path: "USB-\(vendorID)-\(productID)")
                    )
                    devices.append(device)
                }
            }
        }

        if devices.isEmpty {
            log += "  No Motorola USB devices found\n"
        }

        return devices
    }

    /// Finds all serial ports that match Motorola/FTDI devices.
    nonisolated private func findSerialPorts(log: inout String) async -> [USBDeviceInfo] {
        var devices: [USBDeviceInfo] = []

        // Scan /dev/ for USB serial devices
        let fileManager = FileManager.default
        guard let contents = try? fileManager.contentsOfDirectory(atPath: "/dev") else {
            log += "  Cannot read /dev directory\n"
            return devices
        }

        let serialPorts = contents.filter { name in
            name.hasPrefix("cu.usbserial") ||
            name.hasPrefix("cu.usbmodem") ||
            name.hasPrefix("cu.SLAB") ||     // Silicon Labs
            name.hasPrefix("cu.wchusbserial") // CH340
        }

        if serialPorts.isEmpty {
            log += "  No USB serial ports found\n"
        }

        for port in serialPorts {
            let path = "/dev/\(port)"
            log += "  Found: \(port)\n"
            let device = USBDeviceInfo(
                id: path,
                vendorID: USBDeviceInfo.ftdiVendorID,
                productID: 0x6001,
                serialNumber: extractSerial(from: port),
                portPath: path,
                displayName: "Radio (\(port))",
                connectionType: .serial(path: path)
            )
            devices.append(device)
        }

        return devices
    }

    /// Finds radios connected via network (CDC ECM/RNDIS).
    nonisolated private func findNetworkRadios(log: inout String) async -> [USBDeviceInfo] {
        var devices: [USBDeviceInfo] = []
        var checkedIPs: Set<String> = []

        // Method 1: Look for ALL network interfaces and try to find radios
        let allInterfaces = findCDCNetworkInterfaces(log: &log)

        for (interfaceName, hostIP) in allInterfaces {
            // Try the gateway (.1) and a few other common radio offsets
            let ipBase = hostIP.split(separator: ".").prefix(3).joined(separator: ".")
            let possibleRadioIPs = [
                "\(ipBase).1",   // Most common - radio at .1
                "\(ipBase).10",  // Some radios use .10
                "\(ipBase).100", // Some use .100
                hostIP          // Maybe the host IP IS the radio
            ]

            for radioIP in possibleRadioIPs {
                guard !checkedIPs.contains(radioIP) else { continue }
                checkedIPs.insert(radioIP)

                log += "  Trying \(radioIP) (via \(interfaceName))...\n"

                // First check if XNL port is open (faster than ping for radios)
                if await isXNLPortOpen(at: radioIP) {
                    log += "    XNL port 8002 OPEN - Radio found!\n"
                    let device = USBDeviceInfo(
                        id: "network-\(interfaceName)-\(radioIP)",
                        vendorID: USBDeviceInfo.motorolaVendorID,
                        productID: 0x1022,
                        serialNumber: nil,
                        portPath: radioIP,
                        displayName: "Radio (\(radioIP))",
                        connectionType: .network(ip: radioIP, interface: interfaceName)
                    )
                    devices.append(device)
                } else {
                    log += "    XNL port closed\n"
                }
            }
        }

        // Method 2: Check common radio IP ranges directly (even if no interface found)
        // Build comprehensive list of IPs to check
        var commonRadioIPs: [String] = []

        // 192.168.10.x range (most common for MOTOTRBO)
        for i in 1...20 {
            commonRadioIPs.append("192.168.10.\(i)")
        }

        // 192.168.1.x range
        for i in 1...20 {
            commonRadioIPs.append("192.168.1.\(i)")
        }

        // 192.168.2.x range
        for i in 1...20 {
            commonRadioIPs.append("192.168.2.\(i)")
        }

        // 192.168.0.x range
        for i in 1...20 {
            commonRadioIPs.append("192.168.0.\(i)")
        }

        // 172.16.x.x range (some USB adapters use this)
        for i in 1...10 {
            commonRadioIPs.append("172.16.0.\(i)")
            commonRadioIPs.append("172.16.1.\(i)")
        }

        // Other common ranges
        commonRadioIPs.append(contentsOf: [
            "10.0.0.1", "10.0.0.10", "10.0.1.1", "10.1.0.1",
            "169.254.1.1", "169.254.10.1", "169.254.100.1",  // Link-local
        ])

        // Filter out already-checked IPs
        let ipsToCheck = commonRadioIPs.filter { !checkedIPs.contains($0) }
        checkedIPs.formUnion(ipsToCheck)

        log += "\n  Scanning \(ipsToCheck.count) IPs in parallel...\n"

        // Scan IPs in parallel batches for speed
        let batchSize = 20
        for batchStart in stride(from: 0, to: ipsToCheck.count, by: batchSize) {
            let batchEnd = min(batchStart + batchSize, ipsToCheck.count)
            let batch = Array(ipsToCheck[batchStart..<batchEnd])

            let results = await withTaskGroup(of: (String, Bool).self) { group in
                for ip in batch {
                    group.addTask {
                        let isOpen = await self.isXNLPortOpen(at: ip)
                        return (ip, isOpen)
                    }
                }

                var batchResults: [(String, Bool)] = []
                for await result in group {
                    batchResults.append(result)
                }
                return batchResults
            }

            for (radioIP, isOpen) in results {
                if isOpen {
                    log += "  \(radioIP) - XNL port OPEN! Radio found!\n"
                    let device = USBDeviceInfo(
                        id: "network-\(radioIP)",
                        vendorID: USBDeviceInfo.motorolaVendorID,
                        productID: 0x1022,
                        serialNumber: nil,
                        portPath: radioIP,
                        displayName: "Radio (\(radioIP))",
                        connectionType: .network(ip: radioIP, interface: "direct")
                    )
                    devices.append(device)
                }
            }

            // If we found devices, we can stop scanning
            if !devices.isEmpty {
                log += "  (stopping scan - radio found)\n"
                break
            }
        }

        if devices.isEmpty {
            log += "\n  No radios found on network.\n"
            log += "  Tip: Make sure the radio is powered ON and connected via USB.\n"
        }

        return devices
    }

    /// Finds ALL network interfaces by scanning ifconfig output.
    /// More permissive - includes all interfaces with private IPs.
    nonisolated private func findCDCNetworkInterfaces(log: inout String) -> [(String, String)] {
        var interfaces: [(String, String)] = []

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/sbin/ifconfig")
        process.arguments = ["-a"]

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

            var currentInterface = ""
            var currentIP = ""
            var currentStatus = "unknown"

            for line in output.components(separatedBy: "\n") {
                // New interface starts with name followed by colon
                if !line.hasPrefix("\t") && !line.hasPrefix(" ") && line.contains(":") {
                    // Save previous interface if it had a valid IP
                    if !currentInterface.isEmpty && !currentIP.isEmpty {
                        let isPrivate = isPrivateIP(currentIP)
                        log += "  \(currentInterface): \(currentIP) [\(currentStatus)] \(isPrivate ? "" : "(public, skipped)")\n"
                        if isPrivate {
                            interfaces.append((currentInterface, currentIP))
                        }
                    }
                    currentInterface = String(line.split(separator: ":").first ?? "")
                    currentIP = ""
                    currentStatus = "unknown"
                }

                // Check status
                if line.contains("status: active") {
                    currentStatus = "active"
                } else if line.contains("status: inactive") {
                    currentStatus = "inactive"
                }

                // Look for inet address
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                if trimmed.hasPrefix("inet ") && !trimmed.contains("inet6") {
                    let parts = trimmed.components(separatedBy: " ")
                    if parts.count >= 2 {
                        currentIP = parts[1]
                    }
                }
            }

            // Don't forget the last interface
            if !currentInterface.isEmpty && !currentIP.isEmpty {
                let isPrivate = isPrivateIP(currentIP)
                log += "  \(currentInterface): \(currentIP) [\(currentStatus)] \(isPrivate ? "" : "(public, skipped)")\n"
                if isPrivate {
                    interfaces.append((currentInterface, currentIP))
                }
            }
        } catch {
            log += "  Error running ifconfig: \(error)\n"
        }

        if interfaces.isEmpty {
            log += "  No interfaces with private IPs found\n"
        }

        return interfaces
    }

    /// Checks if an IP is a private/local address (not public internet).
    nonisolated private func isPrivateIP(_ ip: String) -> Bool {
        // Exclude loopback
        if ip.hasPrefix("127.") { return false }

        // Private ranges: 10.x.x.x, 172.16-31.x.x, 192.168.x.x, 169.254.x.x (link-local)
        if ip.hasPrefix("10.") { return true }
        if ip.hasPrefix("192.168.") { return true }
        if ip.hasPrefix("169.254.") { return true }

        // 172.16.0.0 - 172.31.255.255
        if ip.hasPrefix("172.") {
            let parts = ip.split(separator: ".")
            if parts.count >= 2, let second = Int(parts[1]) {
                if second >= 16 && second <= 31 {
                    return true
                }
            }
        }

        return false
    }

    /// Derives the radio's IP address from the host IP (typically .1 on the same subnet).
    nonisolated private func deriveRadioIP(from hostIP: String) -> String {
        let parts = hostIP.split(separator: ".")
        if parts.count == 4 {
            return "\(parts[0]).\(parts[1]).\(parts[2]).1"
        }
        return "192.168.10.1"
    }

    /// Checks if the radio is reachable at the given IP address.
    nonisolated private func isRadioReachable(at ip: String) async -> Bool {
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

    /// Checks if the XNL/CPS port (8002) is open on the target IP.
    nonisolated private func isXNLPortOpen(at ip: String) async -> Bool {
        final class ResumeGuard: @unchecked Sendable {
            private var hasResumed = false
            private let lock = NSLock()

            func tryResume() -> Bool {
                lock.lock()
                defer { lock.unlock() }
                if hasResumed { return false }
                hasResumed = true
                return true
            }
        }

        return await withCheckedContinuation { continuation in
            let host = NWEndpoint.Host(ip)
            guard let port = NWEndpoint.Port(rawValue: 8002) else {
                continuation.resume(returning: false)
                return
            }

            let connection = NWConnection(host: host, port: port, using: .tcp)
            let queue = DispatchQueue(label: "com.radiowriter.portcheck")
            let guard_ = ResumeGuard()

            let timeoutWork = DispatchWorkItem {
                if guard_.tryResume() {
                    connection.cancel()
                    continuation.resume(returning: false)
                }
            }
            // Short timeout - radios respond quickly if present
            queue.asyncAfter(deadline: .now() + 0.3, execute: timeoutWork)

            connection.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    timeoutWork.cancel()
                    if guard_.tryResume() {
                        connection.cancel()
                        continuation.resume(returning: true)
                    }
                case .failed, .cancelled:
                    timeoutWork.cancel()
                    if guard_.tryResume() {
                        continuation.resume(returning: false)
                    }
                default:
                    break
                }
            }

            connection.start(queue: queue)
        }
    }

    nonisolated private func extractSerial(from portName: String) -> String? {
        let parts = portName.split(separator: "-")
        return parts.count > 1 ? String(parts.last!) : nil
    }
}
