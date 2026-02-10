import Foundation
import SwiftData

/// Coordinates device discovery from multiple sources and manages persistence
@MainActor
@Observable
final class DeviceDiscoveryCoordinator {

    private(set) var isScanning: Bool = false
    private(set) var discoveredDevices: [LocalDevice] = []
    private(set) var lastScanTime: Date?
    private(set) var scanProgress: Double = 0.0

    private let modelContext: ModelContext
    private let arpScanner: ARPScannerService
    private let bonjourScanner: BonjourDiscoveryService
    private let nameResolver: DeviceNameResolver
    private let macVendorService: MACVendorLookupService

    private var scanTask: Task<Void, Never>?

    init(
        modelContext: ModelContext,
        arpScanner: ARPScannerService,
        bonjourScanner: BonjourDiscoveryService,
        nameResolver: DeviceNameResolver = DeviceNameResolver(),
        macVendorService: MACVendorLookupService = MACVendorLookupService()
    ) {
        self.modelContext = modelContext
        self.arpScanner = arpScanner
        self.bonjourScanner = bonjourScanner
        self.nameResolver = nameResolver
        self.macVendorService = macVendorService

        loadPersistedDevices()
    }

    /// Start a full network scan
    func startScan() {
        guard !isScanning else { return }
        isScanning = true
        scanProgress = 0.0

        scanTask = Task {
            do {
                try Task.checkCancellation()

                // Phase 1: ARP Scan (60% of progress)
                scanProgress = 0.1
                let arpDevices = try await arpScanner.scanNetwork()

                try Task.checkCancellation()
                scanProgress = 0.6

                // Phase 2: Bonjour Discovery (30% of progress)
                let bonjourDevices = try await bonjourScanner.scanNetwork()

                try Task.checkCancellation()
                scanProgress = 0.9

                // Phase 3: Merge results (5% of progress)
                let allDiscovered = mergeDiscoveryResults(arp: arpDevices, bonjour: bonjourDevices)
                mergeDiscoveredDevices(allDiscovered)

                try Task.checkCancellation()
                scanProgress = 0.95

                // Phase 4: Enhanced name resolution for devices without hostnames
                await resolveDeviceNames()

                // Phase 5: Vendor lookup for devices with MAC addresses
                await resolveDeviceVendors()

                // Mark devices not seen in this scan as offline
                markOfflineDevices(currentIPs: Set(allDiscovered.map(\.ipAddress)))

                scanProgress = 1.0
                lastScanTime = Date()
            } catch is CancellationError {
                // Cancelled - exit gracefully
            } catch {
                print("Scan error: \(error)")
            }

            isScanning = false
        }
    }

    /// Stop the current scan
    func stopScan() {
        scanTask?.cancel()
        scanTask = nil
        Task {
            await arpScanner.stopScan()
            await bonjourScanner.stopDiscovery()
        }
        isScanning = false
    }

    /// Merge discovered devices into persistent storage
    func mergeDiscoveredDevices(_ devices: [DiscoveredDevice]) {
        for discovered in devices {
            // Find existing device by MAC address (primary) or IP (fallback)
            let predicate: Predicate<LocalDevice>
            if !discovered.macAddress.isEmpty {
                let macToFind = discovered.macAddress
                predicate = #Predicate<LocalDevice> { device in
                    device.macAddress == macToFind
                }
            } else {
                let ipToFind = discovered.ipAddress
                predicate = #Predicate<LocalDevice> { device in
                    device.ipAddress == ipToFind
                }
            }

            let descriptor = FetchDescriptor<LocalDevice>(predicate: predicate)
            let existing = try? modelContext.fetch(descriptor).first

            if let existing = existing {
                // Update existing device
                existing.ipAddress = discovered.ipAddress
                if let hostname = discovered.hostname, !hostname.isEmpty {
                    existing.hostname = hostname
                }
                existing.lastSeen = Date()
                existing.isOnline = true
            } else {
                // Create new device
                let newDevice = LocalDevice(
                    ipAddress: discovered.ipAddress,
                    macAddress: discovered.macAddress,
                    hostname: discovered.hostname,
                    vendor: nil,
                    deviceType: .unknown
                )
                modelContext.insert(newDevice)
            }
        }

        try? modelContext.save()
        loadPersistedDevices()
    }

    /// Mark devices not seen in current scan as offline
    func markOfflineDevices(currentIPs: Set<String>) {
        for device in discoveredDevices {
            if !currentIPs.contains(device.ipAddress) {
                device.isOnline = false
            }
        }
        try? modelContext.save()
    }

    // MARK: - Private Methods

    /// Enhanced name resolution for devices without hostnames
    private func resolveDeviceNames() async {
        // Find devices without hostnames
        let predicate = #Predicate<LocalDevice> { device in
            device.hostname == nil || device.hostname == ""
        }
        let descriptor = FetchDescriptor<LocalDevice>(predicate: predicate)

        guard let devicesNeedingNames = try? modelContext.fetch(descriptor) else { return }

        // Resolve names concurrently (max 10 at a time to avoid overwhelming the network)
        await withTaskGroup(of: (UUID, String?).self) { group in
            var activeCount = 0
            var deviceIterator = devicesNeedingNames.makeIterator()

            // Initial batch of 10
            while activeCount < 10, let device = deviceIterator.next() {
                let deviceId = device.id
                let ip = device.ipAddress
                group.addTask {
                    let name = await self.nameResolver.resolveName(for: ip)
                    return (deviceId, name)
                }
                activeCount += 1
            }

            // Process results and launch new tasks as previous ones complete
            for await (deviceId, name) in group {
                if let name, let device = devicesNeedingNames.first(where: { $0.id == deviceId }) {
                    device.hostname = name
                }

                // Add next device if available
                if let nextDevice = deviceIterator.next() {
                    let deviceId = nextDevice.id
                    let ip = nextDevice.ipAddress
                    group.addTask {
                        let name = await self.nameResolver.resolveName(for: ip)
                        return (deviceId, name)
                    }
                }
            }
        }

        try? modelContext.save()
    }

    /// Enhanced vendor lookup for devices with MAC addresses but no vendor
    private func resolveDeviceVendors() async {
        // Find devices with MAC addresses but no vendor
        let predicate = #Predicate<LocalDevice> { device in
            !device.macAddress.isEmpty && (device.vendor == nil || device.vendor == "")
        }
        let descriptor = FetchDescriptor<LocalDevice>(predicate: predicate)

        guard let devicesNeedingVendors = try? modelContext.fetch(descriptor) else { return }

        // Resolve vendors concurrently (max 5 at a time to respect API rate limits)
        await withTaskGroup(of: (UUID, String?).self) { group in
            var activeCount = 0
            var deviceIterator = devicesNeedingVendors.makeIterator()

            // Initial batch of 5
            while activeCount < 5, let device = deviceIterator.next() {
                let deviceId = device.id
                let mac = device.macAddress
                group.addTask {
                    let vendor = await self.macVendorService.lookupVendorEnhanced(macAddress: mac)
                    return (deviceId, vendor)
                }
                activeCount += 1
            }

            // Process results and launch new tasks as previous ones complete
            for await (deviceId, vendor) in group {
                if let vendor, let device = devicesNeedingVendors.first(where: { $0.id == deviceId }) {
                    device.vendor = vendor
                }

                // Add next device if available
                if let nextDevice = deviceIterator.next() {
                    let deviceId = nextDevice.id
                    let mac = nextDevice.macAddress
                    group.addTask {
                        let vendor = await self.macVendorService.lookupVendorEnhanced(macAddress: mac)
                        return (deviceId, vendor)
                    }
                }
            }
        }

        try? modelContext.save()
    }

    private func loadPersistedDevices() {
        let descriptor = FetchDescriptor<LocalDevice>(
            sortBy: [SortDescriptor(\.lastSeen, order: .reverse)]
        )
        discoveredDevices = (try? modelContext.fetch(descriptor)) ?? []
    }

    private func mergeDiscoveryResults(
        arp: [DiscoveredDevice],
        bonjour: [DiscoveredDevice]
    ) -> [DiscoveredDevice] {
        var merged: [String: DiscoveredDevice] = [:]

        // ARP devices are authoritative for MAC addresses
        for device in arp {
            let key = device.ipAddress
            merged[key] = device
        }

        // Bonjour devices may have hostnames
        for device in bonjour {
            let key = device.ipAddress
            if let existing = merged[key] {
                // Merge hostname from Bonjour if we don't have one
                if existing.hostname == nil && device.hostname != nil {
                    merged[key] = DiscoveredDevice(
                        ipAddress: existing.ipAddress,
                        macAddress: existing.macAddress,
                        hostname: device.hostname
                    )
                }
            } else {
                merged[key] = device
            }
        }

        return Array(merged.values)
    }
}
