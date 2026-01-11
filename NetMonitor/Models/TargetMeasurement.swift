import Foundation
import SwiftData

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
