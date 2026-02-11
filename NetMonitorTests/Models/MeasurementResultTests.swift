import Testing
import Foundation
@testable import NetMonitor

@Suite("MeasurementResult Tests")
struct MeasurementResultTests {

    @Test("MeasurementResult conforms to Sendable")
    func sendableConformance() {
        let result = MeasurementResult(
            targetID: UUID(),
            timestamp: Date(),
            latency: 42.5,
            isReachable: true,
            errorMessage: nil
        )

        // This test verifies the struct can be passed across actor boundaries
        let sendable: any Sendable = result
        #expect(sendable is MeasurementResult)
    }

    @Test("creates result with successful measurement")
    func successfulMeasurement() {
        let targetID = UUID()
        let timestamp = Date()
        let latency = 25.3

        let result = MeasurementResult(
            targetID: targetID,
            timestamp: timestamp,
            latency: latency,
            isReachable: true,
            errorMessage: nil
        )

        #expect(result.targetID == targetID)
        #expect(result.timestamp == timestamp)
        #expect(result.latency == latency)
        #expect(result.isReachable == true)
        #expect(result.errorMessage == nil)
    }

    @Test("creates result with failed measurement")
    func failedMeasurement() {
        let targetID = UUID()
        let timestamp = Date()
        let errorMessage = "Connection timeout"

        let result = MeasurementResult(
            targetID: targetID,
            timestamp: timestamp,
            latency: nil,
            isReachable: false,
            errorMessage: errorMessage
        )

        #expect(result.targetID == targetID)
        #expect(result.timestamp == timestamp)
        #expect(result.latency == nil)
        #expect(result.isReachable == false)
        #expect(result.errorMessage == errorMessage)
    }

    @Test("creates result with reachable target but no latency")
    func reachableWithoutLatency() {
        let result = MeasurementResult(
            targetID: UUID(),
            timestamp: Date(),
            latency: nil,
            isReachable: true,
            errorMessage: nil
        )

        #expect(result.isReachable == true)
        #expect(result.latency == nil)
        #expect(result.errorMessage == nil)
    }

    @Test("creates result with zero latency")
    func zeroLatency() {
        let result = MeasurementResult(
            targetID: UUID(),
            timestamp: Date(),
            latency: 0.0,
            isReachable: true,
            errorMessage: nil
        )

        #expect(result.latency == 0.0)
        #expect(result.isReachable == true)
    }

    @Test("creates result with high latency value")
    func highLatency() {
        let result = MeasurementResult(
            targetID: UUID(),
            timestamp: Date(),
            latency: 9999.99,
            isReachable: true,
            errorMessage: nil
        )

        #expect(result.latency == 9999.99)
        #expect(result.isReachable == true)
    }

    @Test("creates result with failure and error message")
    func unreachableWithError() {
        let errorMessage = "Host unreachable"

        let result = MeasurementResult(
            targetID: UUID(),
            timestamp: Date(),
            latency: nil,
            isReachable: false,
            errorMessage: errorMessage
        )

        #expect(result.isReachable == false)
        #expect(result.errorMessage == errorMessage)
    }

    @Test("different UUIDs create distinct results")
    func distinctTargetIDs() {
        let id1 = UUID()
        let id2 = UUID()
        let timestamp = Date()

        let result1 = MeasurementResult(
            targetID: id1,
            timestamp: timestamp,
            latency: 10.0,
            isReachable: true,
            errorMessage: nil
        )

        let result2 = MeasurementResult(
            targetID: id2,
            timestamp: timestamp,
            latency: 10.0,
            isReachable: true,
            errorMessage: nil
        )

        #expect(result1.targetID != result2.targetID)
    }

    @Test("preserves timestamp precision")
    func timestampPrecision() {
        let timestamp = Date(timeIntervalSince1970: 1704067200.123456)

        let result = MeasurementResult(
            targetID: UUID(),
            timestamp: timestamp,
            latency: 15.0,
            isReachable: true,
            errorMessage: nil
        )

        #expect(result.timestamp.timeIntervalSince1970 == timestamp.timeIntervalSince1970)
    }

    @Test("handles empty error message string")
    func emptyErrorMessage() {
        let result = MeasurementResult(
            targetID: UUID(),
            timestamp: Date(),
            latency: nil,
            isReachable: false,
            errorMessage: ""
        )

        #expect(result.errorMessage == "")
        #expect(result.isReachable == false)
    }
}
