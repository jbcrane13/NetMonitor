import Testing
import SwiftData
@testable import NetMonitor

@Suite("DeviceDiscoveryCoordinator Tests")
struct DeviceDiscoveryCoordinatorTests {

    @Test("Coordinator initializes with not scanning state")
    @MainActor
    func initialState() throws {
        let container = try ModelContainer(
            for: LocalDevice.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let coordinator = DeviceDiscoveryCoordinator(modelContext: container.mainContext)

        #expect(coordinator.isScanning == false)
        #expect(coordinator.discoveredDevices.isEmpty)
    }

    @Test("Merge discovery results updates existing device")
    @MainActor
    func mergeUpdatesExisting() throws {
        let container = try ModelContainer(
            for: LocalDevice.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = container.mainContext

        // Create existing device
        let existing = LocalDevice(
            ipAddress: "192.168.1.100",
            macAddress: "AA:BB:CC:DD:EE:FF",
            hostname: nil,
            vendor: nil,
            deviceType: .unknown
        )
        context.insert(existing)

        let coordinator = DeviceDiscoveryCoordinator(modelContext: context)

        // Simulate discovery with new hostname
        let discovered = DiscoveredDevice(
            ipAddress: "192.168.1.100",
            macAddress: "AA:BB:CC:DD:EE:FF",
            hostname: "new-hostname.local"
        )

        coordinator.mergeDiscoveredDevices([discovered])

        // Verify hostname was updated
        let devices = try context.fetch(FetchDescriptor<LocalDevice>())
        #expect(devices.count == 1)
        #expect(devices.first?.hostname == "new-hostname.local")
    }

    @Test("Merge discovery results creates new device when not found")
    @MainActor
    func mergeCreatesNewDevice() throws {
        let container = try ModelContainer(
            for: LocalDevice.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = container.mainContext

        let coordinator = DeviceDiscoveryCoordinator(modelContext: context)

        // Simulate discovery of a new device
        let discovered = DiscoveredDevice(
            ipAddress: "192.168.1.200",
            macAddress: "11:22:33:44:55:66",
            hostname: "new-device.local"
        )

        coordinator.mergeDiscoveredDevices([discovered])

        // Verify device was created
        let devices = try context.fetch(FetchDescriptor<LocalDevice>())
        #expect(devices.count == 1)
        #expect(devices.first?.ipAddress == "192.168.1.200")
        #expect(devices.first?.macAddress == "11:22:33:44:55:66")
        #expect(devices.first?.hostname == "new-device.local")
        #expect(devices.first?.isOnline == true)
    }

    @Test("Coordinator tracks scan progress")
    @MainActor
    func scanProgress() throws {
        let container = try ModelContainer(
            for: LocalDevice.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let coordinator = DeviceDiscoveryCoordinator(modelContext: container.mainContext)

        #expect(coordinator.scanProgress == 0.0)
        #expect(coordinator.lastScanTime == nil)
    }

    @Test("Stop scan cancels ongoing scan")
    @MainActor
    func stopScanCancels() throws {
        let container = try ModelContainer(
            for: LocalDevice.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let coordinator = DeviceDiscoveryCoordinator(modelContext: container.mainContext)

        // Start and immediately stop
        coordinator.startScan()
        coordinator.stopScan()

        #expect(coordinator.isScanning == false)
    }

    @Test("Mark offline devices updates status")
    @MainActor
    func markOfflineDevices() async throws {
        let container = try ModelContainer(
            for: LocalDevice.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = container.mainContext

        // Create two devices
        let device1 = LocalDevice(
            ipAddress: "192.168.1.100",
            macAddress: "AA:BB:CC:DD:EE:FF",
            hostname: nil,
            vendor: nil,
            deviceType: .unknown,
            isOnline: true
        )
        let device2 = LocalDevice(
            ipAddress: "192.168.1.101",
            macAddress: "11:22:33:44:55:66",
            hostname: nil,
            vendor: nil,
            deviceType: .unknown,
            isOnline: true
        )
        context.insert(device1)
        context.insert(device2)
        try context.save()

        let coordinator = DeviceDiscoveryCoordinator(modelContext: context)

        // Mark device1's IP as still seen, device2 should go offline
        coordinator.markOfflineDevices(currentIPs: Set(["192.168.1.100"]))

        // Verify device2 is now offline
        let devices = try context.fetch(FetchDescriptor<LocalDevice>())
        let onlineDevice = devices.first { $0.ipAddress == "192.168.1.100" }
        let offlineDevice = devices.first { $0.ipAddress == "192.168.1.101" }

        #expect(onlineDevice?.isOnline == true)
        #expect(offlineDevice?.isOnline == false)
    }
}
