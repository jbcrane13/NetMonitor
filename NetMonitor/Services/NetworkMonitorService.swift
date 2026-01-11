import Foundation

/// Protocol for network monitoring services
/// Implementations must be actors for thread safety
protocol NetworkMonitorService: Actor {
    /// Check a network target and return measurement result
    /// - Parameter target: The target to check
    /// - Returns: Measurement result with latency and reachability
    /// - Throws: NetworkMonitorError for unrecoverable failures
    func check(target: NetworkTarget) async throws -> TargetMeasurement
}

/// Errors that can occur during network monitoring
enum NetworkMonitorError: Error, CustomStringConvertible {
    case invalidHost(String)
    case timeout
    case permissionDenied
    case networkUnreachable
    case unknownError(Error)

    var description: String {
        switch self {
        case .invalidHost(let host):
            return "Invalid host: \(host)"
        case .timeout:
            return "Request timed out"
        case .permissionDenied:
            return "Network permission denied"
        case .networkUnreachable:
            return "Network unreachable"
        case .unknownError(let error):
            return "Unknown error: \(error.localizedDescription)"
        }
    }
}
