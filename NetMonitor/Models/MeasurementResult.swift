import Foundation

/// Sendable value type for returning measurement results across actor boundaries.
/// Converted back to TargetMeasurement @Model on the @MainActor side.
struct MeasurementResult: Sendable {
    let targetID: UUID
    let timestamp: Date
    let latency: Double?
    let isReachable: Bool
    let errorMessage: String?
}
