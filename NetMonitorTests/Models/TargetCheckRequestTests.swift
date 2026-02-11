import Testing
import Foundation
@testable import NetMonitor
import NetMonitorShared

@Suite("TargetCheckRequest Tests")
struct TargetCheckRequestTests {

    @Test("TargetCheckRequest conforms to Sendable")
    func sendableConformance() {
        let request = TargetCheckRequest(
            id: UUID(),
            host: "example.com",
            port: 80,
            targetProtocol: .http,
            timeout: 5.0
        )

        // This test verifies the struct can be passed across actor boundaries
        let sendable: any Sendable = request
        #expect(sendable is TargetCheckRequest)
    }

    @Test("creates HTTP request with port")
    func httpRequestWithPort() {
        let id = UUID()
        let host = "api.example.com"
        let port = 8080
        let timeout: TimeInterval = 10.0

        let request = TargetCheckRequest(
            id: id,
            host: host,
            port: port,
            targetProtocol: .http,
            timeout: timeout
        )

        #expect(request.id == id)
        #expect(request.host == host)
        #expect(request.port == port)
        #expect(request.targetProtocol == .http)
        #expect(request.timeout == timeout)
    }

    @Test("creates HTTPS request without port")
    func httpsRequestWithoutPort() {
        let request = TargetCheckRequest(
            id: UUID(),
            host: "secure.example.com",
            port: nil,
            targetProtocol: .https,
            timeout: 30.0
        )

        #expect(request.port == nil)
        #expect(request.targetProtocol == .https)
    }

    @Test("creates ICMP request")
    func icmpRequest() {
        let request = TargetCheckRequest(
            id: UUID(),
            host: "8.8.8.8",
            port: nil,
            targetProtocol: .icmp,
            timeout: 5.0
        )

        #expect(request.targetProtocol == .icmp)
        #expect(request.port == nil)
    }

    @Test("creates TCP request with custom port")
    func tcpRequestWithCustomPort() {
        let port = 22

        let request = TargetCheckRequest(
            id: UUID(),
            host: "192.168.1.1",
            port: port,
            targetProtocol: .tcp,
            timeout: 3.0
        )

        #expect(request.targetProtocol == .tcp)
        #expect(request.port == port)
    }

    @Test("handles IPv4 address as host")
    func ipv4Host() {
        let host = "192.168.1.100"

        let request = TargetCheckRequest(
            id: UUID(),
            host: host,
            port: 443,
            targetProtocol: .https,
            timeout: 5.0
        )

        #expect(request.host == host)
    }

    @Test("handles IPv6 address as host")
    func ipv6Host() {
        let host = "2001:4860:4860::8888"

        let request = TargetCheckRequest(
            id: UUID(),
            host: host,
            port: 53,
            targetProtocol: .tcp,
            timeout: 5.0
        )

        #expect(request.host == host)
    }

    @Test("handles localhost as host")
    func localhostHost() {
        let request = TargetCheckRequest(
            id: UUID(),
            host: "localhost",
            port: 3000,
            targetProtocol: .http,
            timeout: 1.0
        )

        #expect(request.host == "localhost")
    }

    @Test("handles very short timeout")
    func shortTimeout() {
        let timeout: TimeInterval = 0.5

        let request = TargetCheckRequest(
            id: UUID(),
            host: "example.com",
            port: nil,
            targetProtocol: .icmp,
            timeout: timeout
        )

        #expect(request.timeout == timeout)
    }

    @Test("handles long timeout")
    func longTimeout() {
        let timeout: TimeInterval = 120.0

        let request = TargetCheckRequest(
            id: UUID(),
            host: "slow-server.example.com",
            port: 80,
            targetProtocol: .http,
            timeout: timeout
        )

        #expect(request.timeout == timeout)
    }

    @Test("handles standard HTTP port")
    func standardHttpPort() {
        let request = TargetCheckRequest(
            id: UUID(),
            host: "example.com",
            port: 80,
            targetProtocol: .http,
            timeout: 5.0
        )

        #expect(request.port == 80)
    }

    @Test("handles standard HTTPS port")
    func standardHttpsPort() {
        let request = TargetCheckRequest(
            id: UUID(),
            host: "example.com",
            port: 443,
            targetProtocol: .https,
            timeout: 5.0
        )

        #expect(request.port == 443)
    }

    @Test("handles high port number")
    func highPortNumber() {
        let port = 65535

        let request = TargetCheckRequest(
            id: UUID(),
            host: "example.com",
            port: port,
            targetProtocol: .tcp,
            timeout: 5.0
        )

        #expect(request.port == port)
    }

    @Test("different UUIDs create distinct requests")
    func distinctRequestIDs() {
        let id1 = UUID()
        let id2 = UUID()

        let request1 = TargetCheckRequest(
            id: id1,
            host: "example.com",
            port: 80,
            targetProtocol: .http,
            timeout: 5.0
        )

        let request2 = TargetCheckRequest(
            id: id2,
            host: "example.com",
            port: 80,
            targetProtocol: .http,
            timeout: 5.0
        )

        #expect(request1.id != request2.id)
    }

    @Test("preserves all protocol types")
    func allProtocolTypes() {
        let protocols: [TargetProtocol] = [.http, .https, .icmp, .tcp]

        for proto in protocols {
            let request = TargetCheckRequest(
                id: UUID(),
                host: "example.com",
                port: 80,
                targetProtocol: proto,
                timeout: 5.0
            )

            #expect(request.targetProtocol == proto)
        }
    }
}
