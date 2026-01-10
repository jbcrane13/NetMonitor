import Foundation
import SwiftData

@Model
final class MonitoringSession {
    var id: UUID
    var startedAt: Date
    var pausedAt: Date?
    var stoppedAt: Date?
    var isActive: Bool

    init(
        id: UUID = UUID(),
        startedAt: Date = .now,
        pausedAt: Date? = nil,
        stoppedAt: Date? = nil,
        isActive: Bool = true
    ) {
        self.id = id
        self.startedAt = startedAt
        self.pausedAt = pausedAt
        self.stoppedAt = stoppedAt
        self.isActive = isActive
    }
}
