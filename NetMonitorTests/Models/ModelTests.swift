//
//  ModelTests.swift
//  NetMonitorTests
//
//  Comprehensive model validation tests for enums, value types, and model structs.
//

import Testing
import Foundation
@testable import NetMonitor
import NetMonitorShared

// MARK: - ConnectionType Enum Tests

@Suite("ConnectionType Enum Tests")
struct ConnectionTypeTests {

    @Test("ConnectionType has expected cases")
    func expectedCases() {
        let cases = ConnectionType.allCases
        #expect(cases.contains(.wifi))
        #expect(cases.contains(.ethernet))
        #expect(cases.contains(.cellular))
        #expect(cases.contains(.unknown))
        #expect(cases.count == 4)
    }

    @Test("ConnectionType raw values are display strings")
    func rawValues() {
        #expect(ConnectionType.wifi.rawValue == "WiFi")
        #expect(ConnectionType.ethernet.rawValue == "Ethernet")
        #expect(ConnectionType.cellular.rawValue == "Cellular")
        #expect(ConnectionType.unknown.rawValue == "Unknown")
    }

    @Test("ConnectionType is Codable")
    func codable() throws {
        for type_ in ConnectionType.allCases {
            let encoded = try JSONEncoder().encode(type_)
            let decoded = try JSONDecoder().decode(ConnectionType.self, from: encoded)
            #expect(decoded == type_)
        }
    }

    @Test("ConnectionType raw value round-trip")
    func rawValueRoundTrip() {
        for type_ in ConnectionType.allCases {
            let reconstructed = ConnectionType(rawValue: type_.rawValue)
            #expect(reconstructed == type_)
        }
    }
}

// MARK: - TargetProtocol Enum Tests

@Suite("TargetProtocol Enum Tests")
struct TargetProtocolEnumTests {

    @Test("TargetProtocol has expected cases")
    func expectedCases() {
        let cases = TargetProtocol.allCases
        #expect(cases.contains(.icmp))
        #expect(cases.contains(.http))
        #expect(cases.contains(.https))
        #expect(cases.contains(.tcp))
        #expect(cases.count == 4)
    }

    @Test("TargetProtocol raw values are uppercase strings")
    func rawValues() {
        #expect(TargetProtocol.icmp.rawValue == "ICMP")
        #expect(TargetProtocol.http.rawValue == "HTTP")
        #expect(TargetProtocol.https.rawValue == "HTTPS")
        #expect(TargetProtocol.tcp.rawValue == "TCP")
    }

    @Test("TargetProtocol is Codable round-trip")
    func codable() throws {
        for proto in TargetProtocol.allCases {
            let encoded = try JSONEncoder().encode(proto)
            let decoded = try JSONDecoder().decode(TargetProtocol.self, from: encoded)
            #expect(decoded == proto)
        }
    }

    @Test("TargetProtocol raw value construction")
    func rawValueConstruction() {
        #expect(TargetProtocol(rawValue: "ICMP") == .icmp)
        #expect(TargetProtocol(rawValue: "HTTP") == .http)
        #expect(TargetProtocol(rawValue: "HTTPS") == .https)
        #expect(TargetProtocol(rawValue: "TCP") == .tcp)
        #expect(TargetProtocol(rawValue: "INVALID") == nil)
    }
}

// MARK: - DeviceType Enum Tests

@Suite("DeviceType Enum Tests")
struct DeviceTypeEnumTests {

    @Test("DeviceType has expected cases")
    func expectedCases() {
        let cases = DeviceType.allCases
        #expect(cases.count == 10) // phone, laptop, tablet, tv, speaker, gaming, iot, router, printer, unknown
    }

    @Test("DeviceType raw values are display strings")
    func rawValues() {
        #expect(DeviceType.phone.rawValue == "Phone")
        #expect(DeviceType.laptop.rawValue == "Laptop")
        #expect(DeviceType.tablet.rawValue == "Tablet")
        #expect(DeviceType.tv.rawValue == "TV")
        #expect(DeviceType.speaker.rawValue == "Speaker")
        #expect(DeviceType.gaming.rawValue == "Gaming")
        #expect(DeviceType.iot.rawValue == "IoT")
        #expect(DeviceType.router.rawValue == "Router")
        #expect(DeviceType.printer.rawValue == "Printer")
        #expect(DeviceType.unknown.rawValue == "Unknown")
    }

    @Test("DeviceType is Codable")
    func codable() throws {
        for type_ in DeviceType.allCases {
            let encoded = try JSONEncoder().encode(type_)
            let decoded = try JSONDecoder().decode(DeviceType.self, from: encoded)
            #expect(decoded == type_)
        }
    }
}

// MARK: - PingResult Struct Tests

@Suite("PingResult Struct Tests")
struct PingResultStructTests {

    @Test("PingResult with all packets received is reachable")
    func allPacketsReachable() {
        let result = PingResult(
            transmitted: 3,
            received: 3,
            packetLoss: 0.0,
            minLatency: 1.0,
            avgLatency: 2.0,
            maxLatency: 3.0,
            stddevLatency: 0.5
        )

        #expect(result.isReachable == true)
        #expect(result.transmitted == 3)
        #expect(result.received == 3)
        #expect(result.packetLoss == 0.0)
    }

    @Test("PingResult with zero received is not reachable")
    func zeroReceivedNotReachable() {
        let result = PingResult(
            transmitted: 3,
            received: 0,
            packetLoss: 100.0,
            minLatency: 0,
            avgLatency: 0,
            maxLatency: 0,
            stddevLatency: 0
        )

        #expect(result.isReachable == false)
    }

    @Test("PingResult latency values are ordered correctly")
    func latencyOrdering() {
        let result = PingResult(
            transmitted: 5,
            received: 5,
            packetLoss: 0.0,
            minLatency: 1.5,
            avgLatency: 5.0,
            maxLatency: 10.0,
            stddevLatency: 2.5
        )

        #expect(result.minLatency <= result.avgLatency)
        #expect(result.avgLatency <= result.maxLatency)
        #expect(result.stddevLatency >= 0)
    }

    @Test("PingResult partial packet loss")
    func partialPacketLoss() {
        let result = PingResult(
            transmitted: 4,
            received: 3,
            packetLoss: 25.0,
            minLatency: 2.0,
            avgLatency: 4.0,
            maxLatency: 6.0,
            stddevLatency: 1.0
        )

        #expect(result.isReachable == true)  // Some received
        #expect(result.packetLoss == 25.0)
    }
}

// MARK: - PingLine Struct Tests

@Suite("PingLine Struct Tests")
struct PingLineStructTests {

    @Test("PingLine stores all fields")
    func allFields() {
        let line = PingLine(
            sequenceNumber: 0,
            latency: 12.5,
            ttl: 64,
            bytes: 64,
            host: "127.0.0.1"
        )

        #expect(line.sequenceNumber == 0)
        #expect(line.latency == 12.5)
        #expect(line.ttl == 64)
        #expect(line.bytes == 64)
        #expect(line.host == "127.0.0.1")
    }

    @Test("PingLine timeout has nil latency")
    func timeoutNilLatency() {
        let line = PingLine(
            sequenceNumber: 2,
            latency: nil,
            ttl: nil,
            bytes: 0,
            host: "10.0.0.1"
        )

        #expect(line.latency == nil)
        #expect(line.ttl == nil)
    }
}

// MARK: - MeasurementResult Struct Tests

@Suite("MeasurementResult Struct Tests")
struct MeasurementResultStructTests {

    @Test("MeasurementResult stores all fields")
    func allFields() {
        let id = UUID()
        let timestamp = Date()
        let result = MeasurementResult(
            targetID: id,
            timestamp: timestamp,
            latency: 42.5,
            isReachable: true,
            errorMessage: nil
        )

        #expect(result.targetID == id)
        #expect(result.isReachable == true)
        #expect(result.latency == 42.5)
        #expect(result.errorMessage == nil)
    }

    @Test("MeasurementResult error case has no latency")
    func errorCase() {
        let result = MeasurementResult(
            targetID: UUID(),
            timestamp: Date(),
            latency: nil,
            isReachable: false,
            errorMessage: "Connection refused"
        )

        #expect(result.latency == nil)
        #expect(result.isReachable == false)
        #expect(result.errorMessage == "Connection refused")
    }
}

// MARK: - TargetCheckRequest Struct Tests

@Suite("TargetCheckRequest Struct Tests")
struct TargetCheckRequestStructTests {

    @Test("TargetCheckRequest stores all fields")
    func allFields() {
        let id = UUID()
        let request = TargetCheckRequest(
            id: id,
            host: "example.com",
            port: 443,
            targetProtocol: .https,
            timeout: 5.0
        )

        #expect(request.id == id)
        #expect(request.host == "example.com")
        #expect(request.port == 443)
        #expect(request.targetProtocol == .https)
        #expect(request.timeout == 5.0)
    }

    @Test("TargetCheckRequest port can be nil")
    func portIsOptional() {
        let request = TargetCheckRequest(
            id: UUID(),
            host: "8.8.8.8",
            port: nil,
            targetProtocol: .icmp,
            timeout: 3.0
        )
        #expect(request.port == nil)
    }

    @Test("TargetCheckRequest is Sendable (can be used across actors)")
    func isSendable() {
        let request = TargetCheckRequest(
            id: UUID(),
            host: "test.host",
            port: 80,
            targetProtocol: .http,
            timeout: 2.0
        )
        // Sendable conformance is compile-time; this just verifies construction
        #expect(request.host == "test.host")
    }
}

// MARK: - NavigationSection Tests

@Suite("NavigationSection Tests")
struct NavigationSectionModelTests {

    @Test("NavigationSection has all expected cases")
    func expectedCases() {
        let cases = NavigationSection.allCases
        #expect(cases.contains(.dashboard))
        #expect(cases.contains(.targets))
        #expect(cases.contains(.devices))
        #expect(cases.contains(.tools))
        #expect(cases.contains(.settings))
        #expect(cases.count == 5)
    }

    @Test("NavigationSection IDs match rawValues")
    func idsMatchRawValues() {
        for section in NavigationSection.allCases {
            #expect(section.id == section.rawValue)
        }
    }

    @Test("NavigationSection icons are non-empty")
    func iconsNonEmpty() {
        for section in NavigationSection.allCases {
            #expect(!section.iconName.isEmpty)
        }
    }
}

// MARK: - StatisticsWindow Tests

@Suite("StatisticsWindow Tests")
struct StatisticsWindowTests {

    @Test("StatisticsWindow has expected cases")
    func expectedCases() {
        let cases = StatisticsWindow.allCases
        #expect(cases.contains(.twoMinutes))
        #expect(cases.contains(.tenMinutes))
        #expect(cases.contains(.allTime))
    }

    @Test("StatisticsWindow time intervals are correct")
    func timeIntervals() {
        #expect(StatisticsWindow.twoMinutes.timeInterval == 120)
        #expect(StatisticsWindow.tenMinutes.timeInterval == 600)
        #expect(StatisticsWindow.allTime.timeInterval == nil)
    }

    @Test("StatisticsWindow display names are non-empty")
    func displayNamesNonEmpty() {
        for window in StatisticsWindow.allCases {
            #expect(!window.displayName.isEmpty)
        }
    }

    @Test("StatisticsWindow raw values are non-empty strings")
    func rawValuesNonEmpty() {
        for window in StatisticsWindow.allCases {
            #expect(!window.rawValue.isEmpty)
        }
    }
}

// MARK: - NetMonitorError Tests

@Suite("NetMonitorError Tests")
struct NetMonitorErrorTests {

    @Test("NetMonitorError error descriptions are non-empty")
    func errorDescriptionsNonEmpty() {
        let errors: [NetMonitorError] = [
            .networkUnavailable,
            .permissionDenied("test"),
            .timeout(5.0),
            .commandFailed("error"),
            .invalidInput("bad input")
        ]

        for error in errors {
            #expect(error.errorDescription != nil)
            #expect(!error.errorDescription!.isEmpty)
        }
    }

    @Test("NetMonitorError timeout includes duration in description")
    func timeoutIncludesDuration() {
        let error = NetMonitorError.timeout(10.0)
        #expect(error.errorDescription?.contains("10") == true)
    }

    @Test("NetMonitorError commandFailed includes message")
    func commandFailedIncludesMessage() {
        let error = NetMonitorError.commandFailed("ping failed")
        #expect(error.errorDescription?.contains("ping failed") == true)
    }

    @Test("NetMonitorError invalidInput includes input in description")
    func invalidInputIncludesInput() {
        let error = NetMonitorError.invalidInput("bad-host")
        #expect(error.errorDescription?.contains("bad-host") == true)
    }
}

// MARK: - DNSRecordType Tests

@Suite("DNSRecordType Tests")
struct DNSRecordTypeTests {

    @Test("DNSRecordType has all expected cases")
    func expectedCases() {
        let cases = DNSRecordType.allCases
        #expect(cases.contains(.a))
        #expect(cases.contains(.aaaa))
        #expect(cases.contains(.mx))
        #expect(cases.contains(.txt))
        #expect(cases.contains(.cname))
        #expect(cases.contains(.ns))
        #expect(cases.contains(.soa))
        #expect(cases.contains(.ptr))
        #expect(cases.count == 8)
    }

    @Test("DNSRecordType raw values are uppercase DNS type strings")
    func rawValues() {
        #expect(DNSRecordType.a.rawValue == "A")
        #expect(DNSRecordType.aaaa.rawValue == "AAAA")
        #expect(DNSRecordType.mx.rawValue == "MX")
        #expect(DNSRecordType.txt.rawValue == "TXT")
        #expect(DNSRecordType.cname.rawValue == "CNAME")
        #expect(DNSRecordType.ns.rawValue == "NS")
        #expect(DNSRecordType.soa.rawValue == "SOA")
        #expect(DNSRecordType.ptr.rawValue == "PTR")
    }
}
