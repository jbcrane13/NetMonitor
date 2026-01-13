import Testing
@testable import NetMonitor

@Suite("ARPScannerService Tests")
struct ARPScannerServiceTests {

    @Test("Scanner initializes with default timeout")
    func defaultTimeout() async {
        let scanner = ARPScannerService()
        let timeout = await scanner.timeout
        #expect(timeout == 30.0)
    }

    @Test("Scanner reports not scanning initially")
    func initialNotScanning() async {
        let scanner = ARPScannerService()
        let isScanning = await scanner.isScanning
        #expect(isScanning == false)
    }

    @Test("IP range calculation for /24 subnet")
    func ipRangeCalculation() {
        let range = ARPScannerService.calculateIPRange(
            baseIP: "192.168.1.0",
            subnetMask: "255.255.255.0"
        )

        #expect(range.count == 254) // .1 to .254
        #expect(range.first == "192.168.1.1")
        #expect(range.last == "192.168.1.254")
    }

    @Test("IP range calculation for /16 subnet limits to 254")
    func ipRangeLargeSubnet() {
        // For larger subnets, we should still limit to reasonable range
        let range = ARPScannerService.calculateIPRange(
            baseIP: "10.0.0.0",
            subnetMask: "255.255.0.0"
        )

        // Should limit to /24 equivalent for practical scanning
        #expect(range.count == 254)
    }

    @Test("IP range calculation handles edge cases")
    func ipRangeEdgeCases() {
        // Invalid base IP should return empty range
        let emptyRange = ARPScannerService.calculateIPRange(
            baseIP: "invalid",
            subnetMask: "255.255.255.0"
        )
        #expect(emptyRange.isEmpty)

        // Invalid subnet mask should return empty range
        let invalidMask = ARPScannerService.calculateIPRange(
            baseIP: "192.168.1.0",
            subnetMask: "invalid"
        )
        #expect(invalidMask.isEmpty)
    }

    @Test("Custom timeout can be set")
    func customTimeout() async {
        let scanner = ARPScannerService(timeout: 60.0)
        let timeout = await scanner.timeout
        #expect(timeout == 60.0)
    }
}
