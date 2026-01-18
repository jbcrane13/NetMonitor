//
//  ProcessPingServiceTests.swift
//  NetMonitorTests
//
//  Tests for ProcessPingService actor.
//

import Testing
@testable import NetMonitor

@Suite("ProcessPingService Tests")
struct ProcessPingServiceTests {

    @Test("Ping localhost succeeds")
    func pingLocalhostSucceeds() async throws {
        let service = ProcessPingService()
        let result = try await service.ping(host: "127.0.0.1", count: 1, timeout: 5)

        #expect(result.transmitted == 1)
        #expect(result.received == 1)
        #expect(result.packetLoss == 0)
        #expect(result.avgLatency >= 0)
        #expect(result.isReachable)
    }

    @Test("Ping invalid host returns failure")
    func pingInvalidHostReturnsFailure() async throws {
        let service = ProcessPingService()

        // Use an invalid IP that won't respond
        let result = try await service.ping(host: "192.0.2.1", count: 1, timeout: 2)

        #expect(!result.isReachable || result.packetLoss == 100)
    }

    @Test("Ping with multiple packets tracks all")
    func pingWithMultiplePackets() async throws {
        let service = ProcessPingService()
        let result = try await service.ping(host: "127.0.0.1", count: 3, timeout: 10)

        #expect(result.transmitted == 3)
    }

    @Test("Ping stream emits individual responses")
    func pingStreamEmitsIndividualResponses() async throws {
        let service = ProcessPingService()
        var responses: [PingLine] = []

        for try await response in await service.pingStream(host: "127.0.0.1", count: 3) {
            responses.append(response)
        }

        #expect(responses.count == 3)
        for (index, response) in responses.enumerated() {
            // Sequence numbers from ping are 0-based
            #expect(response.sequenceNumber == index)
        }
    }

    @Test("Cancel stops ping stream")
    func cancelStopsPingStream() async throws {
        let service = ProcessPingService()
        var responseCount = 0

        Task {
            try? await Task.sleep(for: .milliseconds(500))
            await service.cancel()
        }

        do {
            for try await _ in await service.pingStream(host: "127.0.0.1", count: 100) {
                responseCount += 1
                if responseCount >= 5 {
                    // Give time for cancel to take effect
                    try? await Task.sleep(for: .milliseconds(100))
                }
            }
        } catch {
            // Expected - stream was cancelled
        }

        // Should have received some responses but not all 100
        #expect(responseCount < 100)
    }

    @Test("Ping result latency values are valid")
    func pingResultLatencyValuesAreValid() async throws {
        let service = ProcessPingService()
        let result = try await service.ping(host: "127.0.0.1", count: 3, timeout: 10)

        if result.received > 0 {
            #expect(result.minLatency >= 0)
            #expect(result.avgLatency >= result.minLatency)
            #expect(result.maxLatency >= result.avgLatency)
        }
    }
}
