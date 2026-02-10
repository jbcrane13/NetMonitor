import Foundation
import Network
import CoreFoundation
import os

/// Represents a discovered Bonjour/mDNS service on the local network
struct BonjourService: Sendable, Identifiable {
    let id: UUID
    let name: String
    let type: String
    let domain: String
    let hostname: String?
    let port: Int?
    let txtRecord: [String: String]
    let ipAddress: String?

    init(
        id: UUID = UUID(),
        name: String,
        type: String,
        domain: String = "local.",
        hostname: String? = nil,
        port: Int? = nil,
        txtRecord: [String: String] = [:],
        ipAddress: String? = nil
    ) {
        self.id = id
        self.name = name
        self.type = type
        self.domain = domain
        self.hostname = hostname
        self.port = port
        self.txtRecord = txtRecord
        self.ipAddress = ipAddress
    }
}

/// Actor-based Bonjour/mDNS discovery service for finding advertised services on the local network
actor BonjourDiscoveryService: DeviceDiscoveryService {

    // MARK: - Properties

    /// Service types to browse for during discovery
    let serviceTypes: [String]

    /// Whether a scan/discovery is currently in progress
    private(set) var isScanning: Bool = false

    /// Currently discovered services
    private(set) var discoveredServices: [BonjourService] = []

    /// Active NWBrowser instances for each service type
    private var browsers: [NWBrowser] = []

    /// Task for the current scan operation
    private var scanTask: Task<[DiscoveredDevice], Error>?

    /// Tasks for ongoing service resolutions
    private var resolutionTasks: [Task<Void, Never>] = []

    /// Queue for browser callbacks
    private let browserQueue = DispatchQueue(label: "com.netmonitor.bonjour.browser")

    // MARK: - Default Service Types

    /// Default service types to browse for
    static let defaultServiceTypes: [String] = [
        "_http._tcp",
        "_https._tcp",
        "_ssh._tcp",
        "_sftp._tcp",
        "_smb._tcp",
        "_afp._tcp",
        "_airplay._tcp",
        "_raop._tcp",
        "_printer._tcp",
        "_ipp._tcp",
        "_scanner._tcp",
        "_homekit._tcp",
        "_hap._tcp",
        "_companion-link._tcp",
        "_sleep-proxy._udp"
    ]

    // MARK: - Initialization

    init(serviceTypes: [String] = defaultServiceTypes) {
        self.serviceTypes = serviceTypes
    }

    // MARK: - Discovery Methods

    /// Start discovering Bonjour services
    func startDiscovery() async {
        guard !isScanning else { return }

        isScanning = true
        discoveredServices = []

        // Create browsers for each service type
        for serviceType in serviceTypes {
            let browser = createBrowser(for: serviceType)
            browsers.append(browser)
            browser.start(queue: browserQueue)
        }
    }

    /// Stop all active discovery
    func stopDiscovery() {
        for browser in browsers {
            browser.cancel()
        }
        browsers.removeAll()

        // Cancel all pending resolution tasks
        for task in resolutionTasks {
            task.cancel()
        }
        resolutionTasks.removeAll()

        isScanning = false
    }

    // MARK: - DeviceDiscoveryService Conformance

    /// Scan the network for devices via Bonjour discovery
    /// Waits 5 seconds to collect discovered services, then converts them to DiscoveredDevice
    func scanNetwork() async throws -> [DiscoveredDevice] {
        guard !isScanning else {
            throw DeviceDiscoveryError.networkUnavailable
        }

        isScanning = true
        discoveredServices = []

        // Start discovery - store browsers in self.browsers so stopScan() can cancel them
        for serviceType in serviceTypes {
            let browser = createBrowser(for: serviceType)
            browsers.append(browser)
            browser.start(queue: browserQueue)
        }

        let task = Task<[DiscoveredDevice], Error> { [self] in
            // Wait for 5 seconds to collect services
            try await Task.sleep(for: .seconds(5))

            // Stop all browsers
            for browser in self.browsers {
                browser.cancel()
            }
            self.clearBrowsers()

            // Convert discovered services to devices
            let currentServices = self.discoveredServices
            return self.convertServicesToDevices(currentServices)
        }

        scanTask = task

        do {
            let result = try await task.value
            isScanning = false
            scanTask = nil
            return result
        } catch {
            isScanning = false
            scanTask = nil
            throw error
        }
    }

    /// Stop any ongoing scan
    func stopScan() {
        scanTask?.cancel()
        scanTask = nil
        stopDiscovery()
        isScanning = false
    }

    /// Clear browsers array (helper for actor isolation)
    private func clearBrowsers() {
        browsers.removeAll()
    }

    // MARK: - Private Methods

    /// Create an NWBrowser for a specific service type
    private func createBrowser(for serviceType: String) -> NWBrowser {
        let descriptor = NWBrowser.Descriptor.bonjour(type: serviceType, domain: "local.")
        let parameters = NWParameters()
        parameters.includePeerToPeer = true

        let browser = NWBrowser(for: descriptor, using: parameters)

        browser.stateUpdateHandler = { [weak self] state in
            Task { [weak self] in
                await self?.handleBrowserState(state, serviceType: serviceType)
            }
        }

        browser.browseResultsChangedHandler = { [weak self] results, changes in
            Task { [weak self] in
                await self?.handleBrowseResults(results, changes: changes, serviceType: serviceType)
            }
        }

        return browser
    }

    /// Handle browser state changes
    private func handleBrowserState(_ state: NWBrowser.State, serviceType: String) {
        switch state {
        case .ready:
            // Browser is ready to receive results
            break
        case .failed(let error):
            // Log error but continue - other browsers may succeed
            Logger.discovery.error("Bonjour browser failed for \(serviceType, privacy: .public): \(error, privacy: .public)")
        case .cancelled:
            // Browser was cancelled
            break
        default:
            break
        }
    }

    /// Handle browse result changes
    private func handleBrowseResults(
        _ results: Set<NWBrowser.Result>,
        changes: Set<NWBrowser.Result.Change>,
        serviceType: String
    ) {
        for change in changes {
            switch change {
            case .added(let result):
                handleServiceAdded(result, serviceType: serviceType)
            case .removed(let result):
                handleServiceRemoved(result)
            case .changed(_, let newResult, _):
                handleServiceChanged(newResult, serviceType: serviceType)
            case .identical:
                break
            @unknown default:
                break
            }
        }
    }

    /// Handle a newly discovered service
    private func handleServiceAdded(_ result: NWBrowser.Result, serviceType: String) {
        guard case .service(let name, let type, let domain, _) = result.endpoint else {
            return
        }

        // Check if service already exists
        if discoveredServices.contains(where: { $0.name == name && $0.type == type }) {
            return
        }

        // Create basic service entry
        let service = BonjourService(
            name: name,
            type: type,
            domain: domain
        )

        discoveredServices.append(service)

        // Resolve the service to get more details - track the task for cancellation
        let resolutionTask = Task {
            await resolveService(result, serviceType: serviceType)
        }
        resolutionTasks.append(resolutionTask)
    }

    /// Handle a removed service
    private func handleServiceRemoved(_ result: NWBrowser.Result) {
        guard case .service(let name, let type, _, _) = result.endpoint else {
            return
        }

        discoveredServices.removeAll { $0.name == name && $0.type == type }
    }

    /// Handle a changed service
    private func handleServiceChanged(_ result: NWBrowser.Result, serviceType: String) {
        // Remove old entry and add updated one
        handleServiceRemoved(result)
        handleServiceAdded(result, serviceType: serviceType)
    }

    /// Resolve a service to get IP address and other details
    private func resolveService(_ result: NWBrowser.Result, serviceType: String) async {
        guard case .service(let name, let type, let domain, _) = result.endpoint else {
            return
        }

        // Get TXT record if available
        var txtRecord: [String: String] = [:]
        if case .bonjour(let txtData) = result.metadata {
            txtRecord = parseTXTRecord(txtData)
        }

        // Extract basic info from result endpoint
        var hostname: String?
        var port: Int?
        var ipAddress: String?

        // First try to extract info directly from the result endpoint
        switch result.endpoint {
        case .service(_, _, _, let interface):
            // For Bonjour services, we can extract port from metadata
            if case .bonjour(let txtData) = result.metadata {
                // Check if port is in TXT record metadata
                if let portValue = txtData.dictionary["port"] {
                    port = Int(portValue)
                }
            }
            
        case .hostPort(let host, let resultPort):
            port = Int(resultPort.rawValue)
            switch host {
            case .ipv4(let addr):
                ipAddress = "\(addr)"
            case .ipv6(let addr):
                ipAddress = "\(addr)"
            case .name(let hostName, _):
                hostname = hostName
            @unknown default:
                break
            }
            
        default:
            break
        }

        // If we couldn't get IP directly, try a lightweight resolution
        if ipAddress == nil && hostname != nil {
            // Use DNS resolution instead of creating a full connection
            ipAddress = await resolveHostnameToIP(hostname!)
        }

        // Create a minimal test connection only if we need to verify connectivity
        // This is much lighter than the previous approach
        if ipAddress == nil {
            ipAddress = await attemptLightweightResolution(result.endpoint)
        }

        // Update the service with resolved info
        let updatedService = BonjourService(
            name: name,
            type: type,
            domain: domain,
            hostname: hostname ?? name, // Use service name as fallback
            port: port,
            txtRecord: txtRecord,
            ipAddress: ipAddress
        )

        // Replace existing service with updated one
        if let index = discoveredServices.firstIndex(where: { $0.name == name && $0.type == type }) {
            discoveredServices[index] = updatedService
        } else {
            discoveredServices.append(updatedService)
        }
    }
    
    /// Resolve hostname to IP using basic DNS lookup (simplified approach)
    private func resolveHostnameToIP(_ hostname: String) async -> String? {
        // Use a simpler approach with URLSession for DNS resolution
        guard let url = URL(string: "http://\(hostname)") else { return nil }

        return await withCheckedContinuation { continuation in
            let tracker = ContinuationTracker()

            let task = URLSession.shared.dataTask(with: url) { _, response, _ in
                if tracker.tryResume() {
                    if let httpResponse = response as? HTTPURLResponse,
                       let resolvedHost = httpResponse.url?.host {
                        // Try to extract IP if it's available in the resolved URL
                        continuation.resume(returning: resolvedHost)
                    } else {
                        continuation.resume(returning: nil)
                    }
                }
            }

            task.resume()

            // Timeout after 2 seconds
            DispatchQueue.global().asyncAfter(deadline: .now() + 2.0) { [tracker] in
                if tracker.tryResume() {
                    task.cancel()
                    continuation.resume(returning: nil)
                }
            }
        }
    }
    
    /// Convert sockaddr data to string representation
    private func sockaddrToString(_ data: Data) -> String? {
        return data.withUnsafeBytes { bytes in
            let sockaddr = bytes.bindMemory(to: sockaddr.self).first!
            
            switch Int32(sockaddr.sa_family) {
            case AF_INET:
                let sin = bytes.bindMemory(to: sockaddr_in.self).first!
                return String(cString: inet_ntoa(sin.sin_addr))
                
            case AF_INET6:
                var buffer = [CChar](repeating: 0, count: Int(INET6_ADDRSTRLEN))
                let sin6 = bytes.bindMemory(to: sockaddr_in6.self).first!
                var addr = sin6.sin6_addr
                inet_ntop(AF_INET6, &addr, &buffer, socklen_t(INET6_ADDRSTRLEN))
                return String(cString: buffer)
                
            default:
                return nil
            }
        }
    }

    /// Lightweight resolution attempt using minimal NWConnection approach
    private func attemptLightweightResolution(_ endpoint: NWEndpoint) async -> String? {
        let tracker = ContinuationTracker()
        
        return await withCheckedContinuation { continuation in
            let parameters = NWParameters()
            parameters.requiredInterface = nil  // Use any interface
            let connection = NWConnection(to: endpoint, using: parameters)
            
            connection.stateUpdateHandler = { [tracker] state in
                switch state {
                case .ready:
                    if tracker.tryResume() {
                        var resolvedIP: String?
                        if let remoteEndpoint = connection.currentPath?.remoteEndpoint {
                            switch remoteEndpoint {
                            case .hostPort(let host, _):
                                switch host {
                                case .ipv4(let addr):
                                    resolvedIP = "\(addr)"
                                case .ipv6(let addr):
                                    resolvedIP = "\(addr)"
                                default:
                                    break
                                }
                            default:
                                break
                            }
                        }
                        connection.cancel()
                        continuation.resume(returning: resolvedIP)
                    }
                    
                case .failed, .cancelled:
                    if tracker.tryResume() {
                        connection.cancel()
                        continuation.resume(returning: nil)
                    }
                    
                default:
                    break
                }
            }
            
            connection.start(queue: .global())
            
            // Quick timeout - this is just for IP resolution, not actual connection
            DispatchQueue.global().asyncAfter(deadline: .now() + 1.0) { [tracker] in
                if tracker.tryResume() {
                    connection.cancel()
                    continuation.resume(returning: nil)
                }
            }
        }
    }

    /// Parse TXT record data into key-value pairs
    private func parseTXTRecord(_ txtData: NWTXTRecord) -> [String: String] {
        var result: [String: String] = [:]

        // NWTXTRecord provides dictionary property that returns non-optional [String: String]
        let dictionary = txtData.dictionary
        for (key, value) in dictionary {
            result[key] = value
        }

        return result
    }

    /// Convert discovered Bonjour services to DiscoveredDevice instances
    private func convertServicesToDevices(_ services: [BonjourService]) -> [DiscoveredDevice] {
        // Group services by IP address to create unique devices
        var devicesByIP: [String: DiscoveredDevice] = [:]

        for service in services {
            guard let ipAddress = service.ipAddress else { continue }

            // Use hostname as device name if available
            let hostname = service.hostname ?? service.name

            // Create or update device
            if devicesByIP[ipAddress] == nil {
                devicesByIP[ipAddress] = DiscoveredDevice(
                    ipAddress: ipAddress,
                    macAddress: "", // Bonjour doesn't provide MAC directly
                    hostname: hostname
                )
            }
        }

        return Array(devicesByIP.values)
    }
}
