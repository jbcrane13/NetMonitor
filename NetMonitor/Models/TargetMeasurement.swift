import Foundation
import SwiftData

/// Measurement result from a network target check
///
/// @unchecked Sendable: SwiftData @Model classes cannot safely conform to Sendable
/// due to mutable state. Access should be confined to MainActor or properly isolated
/// actor contexts.
@Model
final class TargetMeasurement: @unchecked Sendable {
    var id: UUID
    var timestamp: Date
    var latency: Double?
    var isReachable: Bool
    var errorMessage: String?

    var target: NetworkTarget?

    init(
        id: UUID = UUID(),
        timestamp: Date = .now,
        latency: Double? = nil,
        isReachable: Bool,
        errorMessage: String? = nil
    ) {
        self.id = id
        self.timestamp = timestamp
        self.latency = latency
        self.isReachable = isReachable
        self.errorMessage = errorMessage
    }
}

// MARK: - Measurement Statistics

/// Aggregated statistics from a collection of measurements
struct MeasurementStatistics {
    let averageLatency: Double?
    let minLatency: Double?
    let maxLatency: Double?
    let uptimePercentage: Double?

    /// Formatted average latency string
    var averageLatencyFormatted: String {
        guard let avg = averageLatency else { return "—" }
        return String(format: "%.0f", avg)
    }

    /// Formatted minimum latency string
    var minLatencyFormatted: String {
        guard let min = minLatency else { return "—" }
        return String(format: "%.0f", min)
    }

    /// Formatted maximum latency string
    var maxLatencyFormatted: String {
        guard let max = maxLatency else { return "—" }
        return String(format: "%.0f", max)
    }

    /// Formatted uptime percentage string
    var uptimeFormatted: String {
        guard let uptime = uptimePercentage else { return "—" }
        return String(format: "%.1f", uptime)
    }
}

extension TargetMeasurement {
    /// Calculate statistics from an array of measurements
    /// - Parameter measurements: Array of measurements to analyze
    /// - Returns: Aggregated statistics
    static func calculateStatistics(from measurements: [TargetMeasurement]) -> MeasurementStatistics {
        guard !measurements.isEmpty else {
            return MeasurementStatistics(
                averageLatency: nil,
                minLatency: nil,
                maxLatency: nil,
                uptimePercentage: nil
            )
        }

        let latencies = measurements.compactMap { $0.latency }

        let avgLatency: Double? = latencies.isEmpty ? nil : latencies.reduce(0, +) / Double(latencies.count)
        let minLat: Double? = latencies.min()
        let maxLat: Double? = latencies.max()

        let reachableCount = measurements.filter { $0.isReachable }.count
        let uptime = (Double(reachableCount) / Double(measurements.count)) * 100

        return MeasurementStatistics(
            averageLatency: avgLatency,
            minLatency: minLat,
            maxLatency: maxLat,
            uptimePercentage: uptime
        )
    }
}
