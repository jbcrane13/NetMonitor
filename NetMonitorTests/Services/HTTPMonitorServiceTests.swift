import Foundation
import Testing
@testable import NetMonitor

@Suite("HTTP Monitor Service Tests")
struct HTTPMonitorServiceTests {

    @Test("HTTP monitor can check reachable target")
    func checkReachableTarget() async throws {
        let service = HTTPMonitorService()

        let target = NetworkTarget(
            name: "Google",
            host: "www.google.com",
            targetProtocol: .https,
            timeout: 5.0
        )

        let measurement = try await service.check(target: target)

        #expect(measurement.isReachable == true)
        #expect(measurement.latency != nil)
        #expect(measurement.latency! > 0)
        #expect(measurement.errorMessage == nil)
    }

    @Test("HTTP monitor handles unreachable target")
    func checkUnreachableTarget() async throws {
        let service = HTTPMonitorService()

        let target = NetworkTarget(
            name: "Invalid",
            host: "this-domain-definitely-does-not-exist-12345.com",
            targetProtocol: .https,
            timeout: 2.0
        )

        let measurement = try await service.check(target: target)

        #expect(measurement.isReachable == false)
        #expect(measurement.errorMessage != nil)
    }

    @Test("HTTP monitor respects timeout")
    func checkTimeout() async throws {
        let service = HTTPMonitorService()

        // Use a non-routable IP to force timeout
        let target = NetworkTarget(
            name: "Timeout Test",
            host: "10.255.255.1",
            port: 80,
            targetProtocol: .http,
            timeout: 1.0
        )

        let startTime = Date()
        let measurement = try await service.check(target: target)
        let duration = Date().timeIntervalSince(startTime)

        #expect(measurement.isReachable == false)
        #expect(duration < 2.0)  // Should timeout within reasonable time
    }
}
