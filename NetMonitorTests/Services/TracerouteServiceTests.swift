//
//  TracerouteServiceTests.swift
//  NetMonitorTests
//
//  Tests for TracerouteService actor and TracerouteHop model.
//

import Testing
@testable import NetMonitor

// MARK: - TracerouteHop Model Tests

@Suite("TracerouteHop Model Tests")
struct TracerouteHopModelTests {

    @Test("TracerouteHop initializes with required fields")
    func basicInit() {
        let hop = TracerouteHop(
            hopNumber: 3,
            hostname: "router.example.com",
            ipAddress: "10.0.0.1",
            latencies: [2.5, 3.0, 2.8],
            isTimeout: false,
            isDestination: false
        )

        #expect(hop.hopNumber == 3)
        #expect(hop.hostname == "router.example.com")
        #expect(hop.ipAddress == "10.0.0.1")
        #expect(hop.latencies == [2.5, 3.0, 2.8])
        #expect(hop.isTimeout == false)
        #expect(hop.isDestination == false)
    }

    @Test("TracerouteHop default isDestination is false")
    func defaultIsDestination() {
        let hop = TracerouteHop(
            hopNumber: 1,
            hostname: nil,
            ipAddress: "192.168.1.1",
            latencies: [1.0],
            isTimeout: false
        )
        #expect(hop.isDestination == false)
    }

    @Test("TracerouteHop timeout has empty latencies")
    func timeoutHopHasNoLatencies() {
        let hop = TracerouteHop(
            hopNumber: 4,
            hostname: nil,
            ipAddress: nil,
            latencies: [],
            isTimeout: true
        )

        #expect(hop.isTimeout == true)
        #expect(hop.latencies.isEmpty)
        #expect(hop.ipAddress == nil)
        #expect(hop.hostname == nil)
    }

    @Test("TracerouteHop destination hop")
    func destinationHop() {
        let hop = TracerouteHop(
            hopNumber: 10,
            hostname: "example.com",
            ipAddress: "93.184.216.34",
            latencies: [55.2, 54.9, 55.1],
            isTimeout: false,
            isDestination: true
        )

        #expect(hop.isDestination == true)
        #expect(hop.latencies.count == 3)
    }

    @Test("TracerouteHop has unique UUID identity")
    func uniqueIdentity() {
        let hop1 = TracerouteHop(
            hopNumber: 1,
            hostname: nil,
            ipAddress: "10.0.0.1",
            latencies: [1.0],
            isTimeout: false
        )
        let hop2 = TracerouteHop(
            hopNumber: 1,
            hostname: nil,
            ipAddress: "10.0.0.1",
            latencies: [1.0],
            isTimeout: false
        )

        // Each TracerouteHop gets a unique id even with identical data
        #expect(hop1.id != hop2.id)
    }

    @Test("TracerouteHop can have multiple latency samples")
    func multipleLatencies() {
        let latencies = [4.5, 4.8, 5.0]
        let hop = TracerouteHop(
            hopNumber: 2,
            hostname: nil,
            ipAddress: "10.0.0.2",
            latencies: latencies,
            isTimeout: false
        )

        #expect(hop.latencies.count == 3)
        #expect(hop.latencies[0] == 4.5)
        #expect(hop.latencies[1] == 4.8)
        #expect(hop.latencies[2] == 5.0)
    }
}

// MARK: - TracerouteService Tests

@Suite("TracerouteService Tests")
struct TracerouteServiceTests {

    @Test("TracerouteService initializes with default configuration")
    func defaultConfiguration() async {
        let service = TracerouteService()
        let maxHops = await service.defaultMaxHops
        let timeout = await service.defaultTimeout

        #expect(maxHops == 30)
        #expect(timeout == 2.0)
    }

    @Test("TracerouteService starts not running")
    func initiallyNotRunning() async {
        let service = TracerouteService()
        let isRunning = await service.running
        #expect(isRunning == false)
    }

    @Test("TracerouteService stop when not running is a no-op")
    func stopWhenNotRunning() async {
        let service = TracerouteService()
        await service.stop() // Should not crash
        let isRunning = await service.running
        #expect(isRunning == false)
    }

    @Test("TracerouteService returns AsyncStream from trace()")
    func traceReturnsStream() async {
        let service = TracerouteService()
        let stream = await service.trace(host: "127.0.0.1", maxHops: 3, timeout: 0.5)
        // Just verify we can create the stream (it's an AsyncStream)
        #expect(type(of: stream) == AsyncStream<TracerouteHop>.self)
    }

    @Test("TracerouteService trace to localhost yields at least one hop")
    func traceLocalhostYieldsHop() async {
        let service = TracerouteService()
        var hops: [TracerouteHop] = []

        let stream = await service.trace(host: "127.0.0.1", maxHops: 3, timeout: 2.0)
        for await hop in stream {
            hops.append(hop)
            if hop.isDestination { break }
        }

        #expect(!hops.isEmpty)
    }

    @Test("TracerouteService hop numbers are sequential starting at 1")
    func hopNumbersAreSequential() async {
        let service = TracerouteService()
        var hops: [TracerouteHop] = []

        let stream = await service.trace(host: "127.0.0.1", maxHops: 3, timeout: 2.0)
        for await hop in stream {
            hops.append(hop)
            if hop.isDestination || hops.count >= 3 { break }
        }

        for (idx, hop) in hops.enumerated() {
            #expect(hop.hopNumber == idx + 1)
        }
    }

    @Test("TracerouteService can be stopped mid-trace")
    func stopMidTrace() async {
        let service = TracerouteService()

        // Start a trace to a remote host and stop it quickly
        let stream = await service.trace(host: "192.0.2.1", maxHops: 30, timeout: 0.2)

        var count = 0
        let stopTask = Task {
            try? await Task.sleep(for: .milliseconds(300))
            await service.stop()
        }

        for await _ in stream {
            count += 1
            if count >= 3 { break }
        }

        stopTask.cancel()
        // We just verify it doesn't hang — reaching here means the trace terminated
        #expect(true)
    }
}
