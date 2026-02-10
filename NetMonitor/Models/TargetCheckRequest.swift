import Foundation
import NetMonitorShared

/// Sendable value type for passing target info across actor boundaries.
/// Extracted from NetworkTarget @Model to avoid sending SwiftData objects across actors.
struct TargetCheckRequest: Sendable {
    let id: UUID
    let host: String
    let port: Int?
    let targetProtocol: TargetProtocol
    let timeout: TimeInterval
}
