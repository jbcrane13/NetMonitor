import Foundation
import Testing
@testable import NetMonitor

@Suite("Network Monitor Service Protocol Tests")
struct NetworkMonitorServiceTests {

    @Test("Mock service can be created")
    func mockServiceCreation() async throws {
        let mock = MockNetworkMonitorService()

        // Verify the actor was created successfully by accessing a property
        let latency = await mock.mockLatency
        #expect(latency == 10.0)
    }
}

// Mock implementation for testing
actor MockNetworkMonitorService: NetworkMonitorService {
    var mockLatency: Double = 10.0
    var shouldFail: Bool = false

    func check(request: TargetCheckRequest) async throws -> MeasurementResult {
        if shouldFail {
            throw NetworkMonitorError.timeout
        }

        return MeasurementResult(
            targetID: request.id,
            timestamp: Date(),
            latency: mockLatency,
            isReachable: true,
            errorMessage: nil
        )
    }
}
