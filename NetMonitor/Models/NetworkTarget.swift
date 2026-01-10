import Foundation
import SwiftData
import NetMonitorShared

@Model
final class NetworkTarget {
    var id: UUID
    var name: String
    var host: String
    var port: Int?
    var targetProtocol: TargetProtocol
    var checkInterval: TimeInterval
    var timeout: TimeInterval
    var isEnabled: Bool
    var createdAt: Date

    @Relationship(deleteRule: .cascade, inverse: \TargetMeasurement.target)
    var measurements: [TargetMeasurement] = []

    init(
        id: UUID = UUID(),
        name: String,
        host: String,
        port: Int? = nil,
        targetProtocol: TargetProtocol,
        checkInterval: TimeInterval = 5.0,
        timeout: TimeInterval = 3.0,
        isEnabled: Bool = true,
        createdAt: Date = .now
    ) {
        self.id = id
        self.name = name
        self.host = host
        self.port = port
        self.targetProtocol = targetProtocol
        self.checkInterval = checkInterval
        self.timeout = timeout
        self.isEnabled = isEnabled
        self.createdAt = createdAt
    }
}
