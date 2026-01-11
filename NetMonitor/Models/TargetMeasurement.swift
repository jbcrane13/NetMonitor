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
