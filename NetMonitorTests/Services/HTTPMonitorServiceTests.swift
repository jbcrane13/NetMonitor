import Foundation
import Testing
@testable import NetMonitor

@Suite("HTTP Monitor Service Tests")
struct HTTPMonitorServiceTests {

    @Test("HTTP monitor can check reachable target")
    func checkReachableTarget() async throws {
        let service = HTTPMonitorService()

        let request = TargetCheckRequest(
            id: UUID(),
            host: "www.google.com",
            port: nil,
            targetProtocol: .https,
            timeout: 5.0
        )

        let result = try await service.check(request: request)

        #expect(result.isReachable == true)
        #expect(result.latency != nil)
        #expect(result.latency! > 0)
        #expect(result.errorMessage == nil)
    }

    @Test("HTTP monitor handles unreachable target")
    func checkUnreachableTarget() async throws {
        let service = HTTPMonitorService()

        let request = TargetCheckRequest(
            id: UUID(),
            host: "this-domain-definitely-does-not-exist-12345.com",
            port: nil,
            targetProtocol: .https,
            timeout: 2.0
        )

        let result = try await service.check(request: request)

        #expect(result.isReachable == false)
        #expect(result.errorMessage != nil)
    }

    @Test("HTTP monitor respects timeout")
    func checkTimeout() async throws {
        let service = HTTPMonitorService()

        // Use a non-routable IP to force timeout
        let request = TargetCheckRequest(
            id: UUID(),
            host: "10.255.255.1",
            port: 80,
            targetProtocol: .http,
            timeout: 1.0
        )

        let startTime = Date()
        let result = try await service.check(request: request)
        let duration = Date().timeIntervalSince(startTime)

        #expect(result.isReachable == false)
        #expect(duration < 2.0)  // Should timeout within reasonable time
    }
}
