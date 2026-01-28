import Foundation
import Testing
@testable import NetMonitor

@Suite("TCP Monitor Service Tests")
struct TCPMonitorServiceTests {

    @Test("TCP monitor checks reachable port")
    func checkReachablePort() async throws {
        let service = TCPMonitorService()

        // Use a commonly open port (HTTPS on Google)
        let target = NetworkTarget(
            name: "Google HTTPS",
            host: "www.google.com",
            port: 443,
            targetProtocol: .tcp,
            timeout: 5.0
        )

        let measurement = try await service.check(target: target)

        #expect(measurement.isReachable == true)
        #expect(measurement.latency != nil)
        #expect(measurement.latency! > 0)
        #expect(measurement.errorMessage == nil)
    }

    @Test("TCP monitor handles closed port")
    func checkClosedPort() async throws {
        let service = TCPMonitorService()

        // Use a commonly closed port
        let target = NetworkTarget(
            name: "Google Closed Port",
            host: "www.google.com",
            port: 12345,
            targetProtocol: .tcp,
            timeout: 3.0
        )

        let measurement = try await service.check(target: target)

        #expect(measurement.isReachable == false)
        #expect(measurement.errorMessage != nil)
    }

    @Test("TCP monitor requires port number")
    func checkRequiresPort() async throws {
        let service = TCPMonitorService()

        // Create target without port
        let target = NetworkTarget(
            name: "No Port",
            host: "www.google.com",
            targetProtocol: .tcp,
            timeout: 3.0
        )

        await #expect(throws: NetworkMonitorError.self) {
            _ = try await service.check(target: target)
        }
    }

    @Test("TCP monitor handles unreachable host")
    func checkUnreachableHost() async throws {
        let service = TCPMonitorService()

        // Use a non-existent domain
        let target = NetworkTarget(
            name: "Invalid",
            host: "this-domain-definitely-does-not-exist-12345.com",
            port: 80,
            targetProtocol: .tcp,
            timeout: 2.0
        )

        let measurement = try await service.check(target: target)

        #expect(measurement.isReachable == false)
        #expect(measurement.errorMessage != nil)
    }

    @Test("TCP monitor respects timeout")
    func checkTimeout() async throws {
        let service = TCPMonitorService()

        // Use a non-routable IP to force timeout
        let target = NetworkTarget(
            name: "Timeout Test",
            host: "10.255.255.1",
            port: 80,
            targetProtocol: .tcp,
            timeout: 1.0
        )

        let startTime = Date()
        let measurement = try await service.check(target: target)
        let duration = Date().timeIntervalSince(startTime)

        #expect(measurement.isReachable == false)
        #expect(duration < 2.0)  // Should timeout within reasonable time
        #expect(measurement.errorMessage != nil)
    }

    @Test("TCP monitor handles localhost connection")
    func checkLocalhostConnection() async throws {
        let service = TCPMonitorService()

        // Port 22 (SSH) is commonly open on macOS
        let target = NetworkTarget(
            name: "Localhost SSH",
            host: "127.0.0.1",
            port: 22,
            targetProtocol: .tcp,
            timeout: 2.0
        )

        let measurement = try await service.check(target: target)

        // May be reachable or not depending on system config
        // We just verify it returns a valid measurement
        #expect(measurement.latency == nil || measurement.latency! >= 0)
    }
}
