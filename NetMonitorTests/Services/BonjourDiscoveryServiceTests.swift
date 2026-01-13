import Testing
@testable import NetMonitor

@Suite("BonjourDiscoveryService Tests")
struct BonjourDiscoveryServiceTests {

    @Test("Service initializes with default service types")
    func defaultServiceTypes() async {
        let service = BonjourDiscoveryService()
        let types = await service.serviceTypes

        #expect(types.contains("_http._tcp"))
        #expect(types.contains("_ssh._tcp"))
        #expect(types.contains("_airplay._tcp"))
    }

    @Test("Service reports not scanning initially")
    func initialNotScanning() async {
        let service = BonjourDiscoveryService()
        let isScanning = await service.isScanning
        #expect(isScanning == false)
    }

    @Test("BonjourService struct contains required properties")
    func bonjourServiceProperties() {
        let service = BonjourService(
            name: "Test Service",
            type: "_http._tcp",
            domain: "local.",
            hostname: "test.local",
            port: 80,
            txtRecord: ["path": "/api"]
        )

        #expect(service.name == "Test Service")
        #expect(service.type == "_http._tcp")
        #expect(service.port == 80)
    }

    @Test("BonjourService has auto-generated UUID")
    func bonjourServiceAutoId() {
        let service1 = BonjourService(
            name: "Test Service",
            type: "_http._tcp"
        )
        let service2 = BonjourService(
            name: "Test Service",
            type: "_http._tcp"
        )

        #expect(service1.id != service2.id)
    }

    @Test("BonjourService is Sendable and Identifiable")
    func bonjourServiceConformance() {
        let service = BonjourService(
            name: "Test Service",
            type: "_http._tcp"
        )

        // Verify Identifiable by accessing id
        _ = service.id

        // Sendable verification happens at compile time
        let _: any Sendable = service
    }

    @Test("Service includes all required default service types")
    func allDefaultServiceTypes() async {
        let service = BonjourDiscoveryService()
        let types = await service.serviceTypes

        // Verify all required default types from spec
        let requiredTypes = [
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

        for type in requiredTypes {
            #expect(types.contains(type), "Missing service type: \(type)")
        }
    }

    @Test("Service has empty discovered services initially")
    func initialDiscoveredServices() async {
        let service = BonjourDiscoveryService()
        let services = await service.discoveredServices

        #expect(services.isEmpty)
    }

    @Test("BonjourService domain defaults to local")
    func bonjourServiceDefaultDomain() {
        let service = BonjourService(
            name: "Test",
            type: "_http._tcp"
        )

        #expect(service.domain == "local.")
    }

    @Test("BonjourService supports optional properties")
    func bonjourServiceOptionalProperties() {
        // Service with minimal properties
        let minimal = BonjourService(
            name: "Minimal",
            type: "_http._tcp"
        )

        #expect(minimal.hostname == nil)
        #expect(minimal.port == nil)
        #expect(minimal.ipAddress == nil)
        #expect(minimal.txtRecord.isEmpty)

        // Service with all properties
        let full = BonjourService(
            name: "Full",
            type: "_http._tcp",
            domain: "local.",
            hostname: "server.local",
            port: 8080,
            txtRecord: ["key": "value"],
            ipAddress: "192.168.1.100"
        )

        #expect(full.hostname == "server.local")
        #expect(full.port == 8080)
        #expect(full.ipAddress == "192.168.1.100")
        #expect(full.txtRecord["key"] == "value")
    }
}
