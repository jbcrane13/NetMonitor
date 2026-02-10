import Foundation
import Testing
@testable import NetMonitor

@Suite("ICMP Monitor Service Tests")
struct ICMPMonitorServiceTests {

    @Test("ICMP monitor checks reachable host")
    func checkReachableHost() async throws {
        let service = ICMPMonitorService()

        let request = TargetCheckRequest(
            id: UUID(),
            host: "1.1.1.1",
            port: nil,
            targetProtocol: .icmp,
            timeout: 5.0
        )

        let result = try await service.check(request: request)

        #expect(result.isReachable == true)
        #expect(result.latency != nil)
        #expect(result.latency! > 0)
        #expect(result.errorMessage == nil)
    }

    @Test("ICMP monitor handles unreachable host")
    func checkUnreachableHost() async throws {
        let service = ICMPMonitorService()

        // Use a non-routable IP
        let request = TargetCheckRequest(
            id: UUID(),
            host: "10.255.255.254",
            port: nil,
            targetProtocol: .icmp,
            timeout: 2.0
        )

        let result = try await service.check(request: request)

        #expect(result.isReachable == false)
        #expect(result.latency == nil)
        #expect(result.errorMessage != nil)
    }

    @Test("ICMP monitor validates target protocol")
    func checkProtocolValidation() async throws {
        let service = ICMPMonitorService()

        // Create request with wrong protocol
        let request = TargetCheckRequest(
            id: UUID(),
            host: "1.1.1.1",
            port: nil,
            targetProtocol: .http,
            timeout: 3.0
        )

        await #expect(throws: NetworkMonitorError.self) {
            _ = try await service.check(request: request)
        }
    }

    @Test("ICMP monitor respects timeout")
    func checkTimeout() async throws {
        let service = ICMPMonitorService()

        // Use a non-routable IP to force timeout
        let request = TargetCheckRequest(
            id: UUID(),
            host: "10.255.255.1",
            port: nil,
            targetProtocol: .icmp,
            timeout: 1.0
        )

        let startTime = Date()
        let result = try await service.check(request: request)
        let duration = Date().timeIntervalSince(startTime)

        #expect(result.isReachable == false)
        #expect(duration < 2.0)  // Should timeout within reasonable time
    }

    @Test("ICMP monitor handles localhost")
    func checkLocalhost() async throws {
        let service = ICMPMonitorService()

        let request = TargetCheckRequest(
            id: UUID(),
            host: "127.0.0.1",
            port: nil,
            targetProtocol: .icmp,
            timeout: 2.0
        )

        let result = try await service.check(request: request)

        #expect(result.isReachable == true)
        #expect(result.latency != nil)
        #expect(result.latency! >= 0)
    }

    @Test("ICMP monitor handles hostname resolution")
    func checkHostnameResolution() async throws {
        let service = ICMPMonitorService()

        let request = TargetCheckRequest(
            id: UUID(),
            host: "dns.google",
            port: nil,
            targetProtocol: .icmp,
            timeout: 5.0
        )

        let result = try await service.check(request: request)

        #expect(result.isReachable == true)
        #expect(result.latency != nil)
    }
}
