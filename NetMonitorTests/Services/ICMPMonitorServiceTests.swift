import Foundation
import Testing
@testable import NetMonitor

@Suite("ICMP Monitor Service Tests")
struct ICMPMonitorServiceTests {

    @Test("ICMP monitor checks reachable host")
    func checkReachableHost() async throws {
        let service = ICMPMonitorService()

        let target = NetworkTarget(
            name: "Cloudflare DNS",
            host: "1.1.1.1",
            targetProtocol: .icmp,
            timeout: 5.0
        )

        let measurement = try await service.check(target: target)

        #expect(measurement.isReachable == true)
        #expect(measurement.latency != nil)
        #expect(measurement.latency! > 0)
        #expect(measurement.errorMessage == nil)
    }

    @Test("ICMP monitor handles unreachable host")
    func checkUnreachableHost() async throws {
        let service = ICMPMonitorService()

        // Use a non-routable IP
        let target = NetworkTarget(
            name: "Unreachable",
            host: "10.255.255.254",
            targetProtocol: .icmp,
            timeout: 2.0
        )

        let measurement = try await service.check(target: target)

        #expect(measurement.isReachable == false)
        #expect(measurement.latency == nil)
        #expect(measurement.errorMessage != nil)
    }

    @Test("ICMP monitor validates target protocol")
    func checkProtocolValidation() async throws {
        let service = ICMPMonitorService()

        // Create target with wrong protocol
        let target = NetworkTarget(
            name: "Wrong Protocol",
            host: "1.1.1.1",
            targetProtocol: .http,
            timeout: 3.0
        )

        await #expect(throws: NetworkMonitorError.self) {
            _ = try await service.check(target: target)
        }
    }

    @Test("ICMP monitor respects timeout")
    func checkTimeout() async throws {
        let service = ICMPMonitorService()

        // Use a non-routable IP to force timeout
        let target = NetworkTarget(
            name: "Timeout Test",
            host: "10.255.255.1",
            targetProtocol: .icmp,
            timeout: 1.0
        )

        let startTime = Date()
        let measurement = try await service.check(target: target)
        let duration = Date().timeIntervalSince(startTime)

        #expect(measurement.isReachable == false)
        #expect(duration < 2.0)  // Should timeout within reasonable time
    }

    @Test("ICMP monitor handles localhost")
    func checkLocalhost() async throws {
        let service = ICMPMonitorService()

        let target = NetworkTarget(
            name: "Localhost",
            host: "127.0.0.1",
            targetProtocol: .icmp,
            timeout: 2.0
        )

        let measurement = try await service.check(target: target)

        #expect(measurement.isReachable == true)
        #expect(measurement.latency != nil)
        #expect(measurement.latency! >= 0)
    }

    @Test("ICMP monitor handles hostname resolution")
    func checkHostnameResolution() async throws {
        let service = ICMPMonitorService()

        let target = NetworkTarget(
            name: "Google DNS",
            host: "dns.google",
            targetProtocol: .icmp,
            timeout: 5.0
        )

        let measurement = try await service.check(target: target)

        #expect(measurement.isReachable == true)
        #expect(measurement.latency != nil)
    }
}
