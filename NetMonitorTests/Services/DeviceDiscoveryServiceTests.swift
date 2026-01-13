import Testing
@testable import NetMonitor

@Suite("DeviceDiscoveryService Protocol Tests")
struct DeviceDiscoveryServiceTests {

    @Test("DiscoveredDevice contains required properties")
    func discoveredDeviceProperties() {
        let device = DiscoveredDevice(
            ipAddress: "192.168.1.100",
            macAddress: "AA:BB:CC:DD:EE:FF",
            hostname: "test-device.local"
        )

        #expect(device.ipAddress == "192.168.1.100")
        #expect(device.macAddress == "AA:BB:CC:DD:EE:FF")
        #expect(device.hostname == "test-device.local")
    }

    @Test("DiscoveredDevice MAC address is normalized")
    func macAddressNormalized() {
        let device = DiscoveredDevice(
            ipAddress: "192.168.1.100",
            macAddress: "aa:bb:cc:dd:ee:ff",
            hostname: nil
        )

        #expect(device.macAddress == "AA:BB:CC:DD:EE:FF")
    }
}
