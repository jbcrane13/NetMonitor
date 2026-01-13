import Testing
@testable import NetMonitor

@Suite("MACVendorLookupService Tests")
struct MACVendorLookupServiceTests {

    @Test("Lookup returns vendor for known MAC prefix")
    func knownVendor() async {
        let service = MACVendorLookupService()

        // Use a MAC prefix that exists in the database
        let vendor = await service.lookup(macAddress: "00:03:93:00:00:00")
        #expect(vendor == "Apple")
    }

    @Test("Lookup handles different MAC formats")
    func macFormats() async {
        let service = MACVendorLookupService()

        // Should handle colons, dashes, or no separators
        let v1 = await service.lookup(macAddress: "000393000000")
        let v2 = await service.lookup(macAddress: "00-03-93-00-00-00")
        let v3 = await service.lookup(macAddress: "00:03:93:00:00:00")

        #expect(v1 == v2)
        #expect(v2 == v3)
    }

    @Test("Lookup returns nil for unknown MAC")
    func unknownVendor() async {
        let service = MACVendorLookupService()

        let vendor = await service.lookup(macAddress: "FF:FF:FF:FF:FF:FF")
        #expect(vendor == nil)
    }

    @Test("Lookup handles lowercase MAC addresses")
    func lowercaseMAC() async {
        let service = MACVendorLookupService()

        let vendor = await service.lookup(macAddress: "00:03:93:aa:bb:cc")
        #expect(vendor == "Apple")
    }

    @Test("Lookup handles mixed case MAC addresses")
    func mixedCaseMAC() async {
        let service = MACVendorLookupService()

        let vendor = await service.lookup(macAddress: "00:03:93:Aa:Bb:Cc")
        #expect(vendor == "Apple")
    }

    @Test("Lookup returns nil for empty MAC address")
    func emptyMAC() async {
        let service = MACVendorLookupService()

        let vendor = await service.lookup(macAddress: "")
        #expect(vendor == nil)
    }

    @Test("Lookup returns nil for invalid MAC address")
    func invalidMAC() async {
        let service = MACVendorLookupService()

        let vendor = await service.lookup(macAddress: "XX:YY:ZZ")
        #expect(vendor == nil)
    }

    @Test("Lookup returns correct vendors for different manufacturers")
    func multipleVendors() async {
        let service = MACVendorLookupService()

        // Test various known vendors
        let samsung = await service.lookup(macAddress: "00:00:F0:11:22:33")
        #expect(samsung == "Samsung")

        let google = await service.lookup(macAddress: "00:1A:11:44:55:66")
        #expect(google == "Google")

        let cisco = await service.lookup(macAddress: "00:00:0C:77:88:99")
        #expect(cisco == "Cisco")

        let raspberryPi = await service.lookup(macAddress: "B8:27:EB:AA:BB:CC")
        #expect(raspberryPi == "Raspberry Pi")
    }
}
