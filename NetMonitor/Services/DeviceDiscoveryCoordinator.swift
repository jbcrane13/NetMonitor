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

    private var scanTask: Task<Void, Never>?

    init(
        modelContext: ModelContext,
        arpScanner: ARPScannerService = ARPScannerService(),
        bonjourScanner: BonjourDiscoveryService = BonjourDiscoveryService()
    ) {
        self.modelContext = modelContext
        self.arpScanner = arpScanner
        self.bonjourScanner = bonjourScanner

        loadPersistedDevices()
    }

    /// Start a full network scan
    func startScan() {
        guard !isScanning else { return }
        isScanning = true
        scanProgress = 0.0

        scanTask = Task {
            do {
                // Phase 1: ARP Scan (60% of progress)
                scanProgress = 0.1
                let arpDevices = try await arpScanner.scanNetwork()
                scanProgress = 0.6

                // Phase 2: Bonjour Discovery (30% of progress)
                let bonjourDevices = try await bonjourScanner.scanNetwork()
                scanProgress = 0.9

                // Merge results
                let allDiscovered = mergeDiscoveryResults(arp: arpDevices, bonjour: bonjourDevices)
                await mergeDiscoveredDevices(allDiscovered)

                scanProgress = 1.0
                lastScanTime = Date()
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
    func mergeDiscoveredDevices(_ devices: [DiscoveredDevice]) async {
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
