import Foundation
import Testing
@testable import NetMonitor

@Suite("TCP Monitor Service Tests")
struct TCPMonitorServiceTests {

    @Test("TCP monitor checks reachable port")
    func checkReachablePort() async throws {
        let service = TCPMonitorService()

        // Use a commonly open port (HTTPS on Google)
        let request = TargetCheckRequest(
            id: UUID(),
            host: "www.google.com",
            port: 443,
            targetProtocol: .tcp,
            timeout: 5.0
        )

        let result = try await service.check(request: request)

        #expect(result.isReachable == true)
        #expect(result.latency != nil)
        #expect(result.latency! > 0)
        #expect(result.errorMessage == nil)
    }

    @Test("TCP monitor handles closed port")
    func checkClosedPort() async throws {
        let service = TCPMonitorService()

        // Use a commonly closed port
        let request = TargetCheckRequest(
            id: UUID(),
            host: "www.google.com",
            port: 12345,
            targetProtocol: .tcp,
            timeout: 3.0
        )

        let result = try await service.check(request: request)

        #expect(result.isReachable == false)
        #expect(result.errorMessage != nil)
    }

    @Test("TCP monitor requires port number")
    func checkRequiresPort() async throws {
        let service = TCPMonitorService()

        // Create request without port
        let request = TargetCheckRequest(
            id: UUID(),
            host: "www.google.com",
            port: nil,
            targetProtocol: .tcp,
            timeout: 3.0
        )

        await #expect(throws: NetworkMonitorError.self) {
            _ = try await service.check(request: request)
        }
    }

    @Test("TCP monitor handles unreachable host")
    func checkUnreachableHost() async throws {
        let service = TCPMonitorService()

        // Use a non-existent domain
        let request = TargetCheckRequest(
            id: UUID(),
            host: "this-domain-definitely-does-not-exist-12345.com",
            port: 80,
            targetProtocol: .tcp,
            timeout: 2.0
        )

        let result = try await service.check(request: request)

        #expect(result.isReachable == false)
        #expect(result.errorMessage != nil)
    }

    @Test("TCP monitor respects timeout")
    func checkTimeout() async throws {
        let service = TCPMonitorService()

        // Use a non-routable IP to force timeout
        let request = TargetCheckRequest(
            id: UUID(),
            host: "10.255.255.1",
            port: 80,
            targetProtocol: .tcp,
            timeout: 1.0
        )

        let startTime = Date()
        let result = try await service.check(request: request)
        let duration = Date().timeIntervalSince(startTime)

        #expect(result.isReachable == false)
        #expect(duration < 2.0)  // Should timeout within reasonable time
        #expect(result.errorMessage != nil)
    }

    @Test("TCP monitor handles localhost connection")
    func checkLocalhostConnection() async throws {
        let service = TCPMonitorService()

        // Port 22 (SSH) is commonly open on macOS
        let request = TargetCheckRequest(
            id: UUID(),
            host: "127.0.0.1",
            port: 22,
            targetProtocol: .tcp,
            timeout: 2.0
        )

        let result = try await service.check(request: request)

        // May be reachable or not depending on system config
        // We just verify it returns a valid measurement
        #expect(result.latency == nil || result.latency! >= 0)
    }
}
