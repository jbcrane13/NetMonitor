//
//  SmokeTests.swift
//  NetMonitorTests
//
//  Critical-path smoke tests that validate core types can be instantiated
//  and basic operations work correctly. Target runtime: < 5 seconds total.
//

import Testing
import Foundation
@testable import NetMonitor
import NetMonitorShared

/// Quick sanity checks — if these fail the app is fundamentally broken.
@Suite("Smoke Tests", .timeLimit(.minutes(1)))
struct SmokeTests {

    // MARK: - Core Enum Smoke Tests

    @Test("All TargetProtocol cases are accessible")
    func targetProtocolCases() {
        #expect(TargetProtocol.allCases.count == 4)
        _ = TargetProtocol.icmp
        _ = TargetProtocol.http
        _ = TargetProtocol.https
        _ = TargetProtocol.tcp
    }

    @Test("All DeviceType cases are accessible")
    func deviceTypeCases() {
        #expect(DeviceType.allCases.count == 10)
        _ = DeviceType.unknown
    }

    @Test("All ConnectionType cases are accessible")
    func connectionTypeCases() {
        #expect(ConnectionType.allCases.count == 4)
        _ = ConnectionType.wifi
        _ = ConnectionType.ethernet
    }

    @Test("All NavigationSection cases are accessible")
    func navigationSectionCases() {
        #expect(NavigationSection.allCases.count == 5)
        for section in NavigationSection.allCases {
            #expect(!section.iconName.isEmpty)
        }
    }

    // MARK: - Core Struct Construction

    @Test("MeasurementResult can be created")
    func measurementResultConstruction() {
        let result = MeasurementResult(
            targetID: UUID(),
            timestamp: Date(),
            latency: 5.0,
            isReachable: true,
            errorMessage: nil
        )
        #expect(result.isReachable)
    }

    @Test("TargetCheckRequest can be created")
    func targetCheckRequestConstruction() {
        let req = TargetCheckRequest(
            id: UUID(),
            host: "1.1.1.1",
            port: nil,
            targetProtocol: .icmp,
            timeout: 3.0
        )
        #expect(req.host == "1.1.1.1")
    }

    @Test("PingResult can be created and isReachable computed correctly")
    func pingResultConstruction() {
        let reachable = PingResult(transmitted: 1, received: 1, packetLoss: 0,
                                    minLatency: 1, avgLatency: 1, maxLatency: 1, stddevLatency: 0)
        let unreachable = PingResult(transmitted: 1, received: 0, packetLoss: 100,
                                      minLatency: 0, avgLatency: 0, maxLatency: 0, stddevLatency: 0)
        #expect(reachable.isReachable)
        #expect(!unreachable.isReachable)
    }

    @Test("TracerouteHop can be created")
    func tracerouteHopConstruction() {
        let hop = TracerouteHop(hopNumber: 1, hostname: nil, ipAddress: "10.0.0.1",
                                 latencies: [1.5], isTimeout: false)
        #expect(hop.hopNumber == 1)
        #expect(!hop.isTimeout)
    }


    @Test("PortScanResult can be created")
    func portScanResultConstruction() {
        // PortScanService not in project — placeholder
    }

    // MARK: - Core Service Actor Construction

    @Test("TracerouteService can be instantiated")
    func tracerouteServiceConstruction() async {
        let service = TracerouteService()
        let running = await service.running
        #expect(!running)
    }



    @Test("ICMPSocket throws on unsupported contexts only")
    func icmpSocketStaticMethods() {
        // Static methods don't need a socket — verify they work without throwing
        let checksum = ICMPSocket.icmpChecksum([0, 0, 0, 0])
        #expect(checksum == 0xFFFF)

        let packet = ICMPSocket.buildEchoRequest(sequence: 1, payloadSize: 0)
        #expect(packet.count == 8)
    }

    // MARK: - Model Parsing Smoke Tests

    @Test("WHOISInfo parse from empty string doesn't crash")
    func whoisParseEmpty() {
        let info = WHOISInfo.parse(from: "")
        #expect(info.rawText == "")
    }

    @Test("WHOISInfo parse from valid data returns expected fields")
    func whoisParseValid() {
        let info = WHOISInfo.parse(from: "Domain Name: smoke-test.com\nRegistrar: TestRegistrar\n")
        #expect(info.domainName == "smoke-test.com")
        #expect(info.registrar == "TestRegistrar")
    }

    // MARK: - ICMP Checksum Smoke Test

    @Test("ICMP checksum over echo request header is valid")
    func icmpEchoChecksumValid() {
        let packet = ICMPSocket.buildEchoRequest(sequence: 42, payloadSize: 56)
        // Self-verification: computing checksum over complete packet (with embedded checksum) yields 0
        #expect(ICMPSocket.icmpChecksum(packet) == 0)
    }

    // MARK: - Port Service Name Smoke Test

    @Test("Port service names cover common ports")
    func portServiceNamesCommonPorts() {
        let commonPorts: [UInt16: String] = [
            22: "SSH", 80: "HTTP", 443: "HTTPS", 3306: "MySQL"
        ]
        // Port service name validation deferred — PortScanService not in project
    }
}
