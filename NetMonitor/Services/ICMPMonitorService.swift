import Foundation

/// Actor-based ICMP ping monitoring service
///
/// Uses ProcessPingService internally to execute /sbin/ping, which works
/// within App Sandbox constraints where raw ICMP sockets are blocked.
actor ICMPMonitorService: NetworkMonitorService {

    private let pingService = ProcessPingService()

    func check(request: TargetCheckRequest) async throws -> MeasurementResult {
        // Validate target protocol
        guard request.targetProtocol == .icmp else {
            throw NetworkMonitorError.invalidHost("Target protocol must be ICMP")
        }

        do {
            let result = try await pingService.ping(
                host: request.host,
                count: 1,
                timeout: request.timeout
            )

            return MeasurementResult(
                targetID: request.id,
                timestamp: Date(),
                latency: result.isReachable ? result.avgLatency : nil,
                isReachable: result.isReachable,
                errorMessage: result.isReachable ? nil : "Host unreachable (100% packet loss)"
            )

        } catch let error as ToolError {
            return MeasurementResult(
                targetID: request.id,
                timestamp: Date(),
                latency: nil,
                isReachable: false,
                errorMessage: error.localizedDescription
            )
        } catch {
            return MeasurementResult(
                targetID: request.id,
                timestamp: Date(),
                latency: nil,
                isReachable: false,
                errorMessage: "ICMP error: \(error.localizedDescription)"
            )
        }
    }
}
