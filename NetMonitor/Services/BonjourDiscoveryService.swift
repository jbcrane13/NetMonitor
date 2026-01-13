import Foundation
import Network

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

/// Thread-safe resume tracker for continuation safety
private final class ResumeTracker: @unchecked Sendable {
    private let lock = NSLock()
    private var _hasResumed = false

    var hasResumed: Bool {
        lock.lock()
        defer { lock.unlock() }
        return _hasResumed
    }

    /// Attempts to mark as resumed. Returns true if this call set the flag, false if already resumed.
    func tryResume() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        if _hasResumed { return false }
        _hasResumed = true
        return true
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

        let task = Task<[DiscoveredDevice], Error> { [self] in
            // Start discovery
            var activeBrowsers: [NWBrowser] = []

            for serviceType in serviceTypes {
                let browser = createBrowser(for: serviceType)
                activeBrowsers.append(browser)
                browser.start(queue: browserQueue)
            }

            // Wait for 5 seconds to collect services
            try await Task.sleep(for: .seconds(5))

            // Stop all browsers
            for browser in activeBrowsers {
                browser.cancel()
            }

            // Convert discovered services to devices
            let currentServices = await self.discoveredServices
            return self.convertServicesToDevices(currentServices)
        }

        scanTask = task

        do {
            let result = try await task.value
            isScanning = false
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
            print("Bonjour browser failed for \(serviceType): \(error)")
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

        // Resolve the service to get more details
        Task {
            await resolveService(result, serviceType: serviceType)
        }
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

        // Create a connection to resolve the endpoint
        let parameters = NWParameters.tcp
        let connection = NWConnection(to: result.endpoint, using: parameters)

        let tracker = ResumeTracker()

        // Use continuation to get resolved endpoint info
        let resolvedInfo: (hostname: String?, port: Int?, ipAddress: String?) = await withCheckedContinuation { continuation in
            connection.stateUpdateHandler = { [tracker] state in
                switch state {
                case .ready:
                    if tracker.tryResume() {
                        // Extract resolved endpoint info
                        var hostname: String?
                        var port: Int?
                        var ipAddress: String?

                        if let endpoint = connection.currentPath?.remoteEndpoint {
                            switch endpoint {
                            case .hostPort(let host, let resolvedPort):
                                switch host {
                                case .ipv4(let addr):
                                    ipAddress = "\(addr)"
                                case .ipv6(let addr):
                                    ipAddress = "\(addr)"
                                case .name(let hostname_, _):
                                    hostname = hostname_
                                @unknown default:
                                    break
                                }
                                port = Int(resolvedPort.rawValue)
                            default:
                                break
                            }
                        }

                        connection.cancel()
                        continuation.resume(returning: (hostname, port, ipAddress))
                    }

                case .failed, .cancelled:
                    if tracker.tryResume() {
                        connection.cancel()
                        continuation.resume(returning: (nil, nil, nil))
                    }

                case .waiting:
                    // Give it a moment, but don't wait forever
                    DispatchQueue.global().asyncAfter(deadline: .now() + 2.0) { [tracker] in
                        if tracker.tryResume() {
                            connection.cancel()
                            continuation.resume(returning: (nil, nil, nil))
                        }
                    }

                default:
                    break
                }
            }

            connection.start(queue: DispatchQueue(label: "com.netmonitor.bonjour.resolve.\(name)"))

            // Timeout after 3 seconds
            DispatchQueue.global().asyncAfter(deadline: .now() + 3.0) { [tracker] in
                if tracker.tryResume() {
                    connection.cancel()
                    continuation.resume(returning: (nil, nil, nil))
                }
            }
        }

        // Update the service with resolved info
        let updatedService = BonjourService(
            name: name,
            type: type,
            domain: domain,
            hostname: resolvedInfo.hostname,
            port: resolvedInfo.port,
            txtRecord: txtRecord,
            ipAddress: resolvedInfo.ipAddress
        )

        // Replace existing service with updated one
        if let index = discoveredServices.firstIndex(where: { $0.name == name && $0.type == type }) {
            discoveredServices[index] = updatedService
        } else {
            discoveredServices.append(updatedService)
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
