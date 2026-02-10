import Foundation
import NetMonitorShared

// MARK: - SF Symbol Icon Names for Shared Enums
// These extensions provide SF Symbol icon names for UI display.
// Kept in the main app target since the shared package should not
// reference platform-specific SF Symbol names.

extension TargetProtocol {
    /// SF Symbol name for this protocol type
    var iconName: String {
        switch self {
        case .http, .https:
            return "network"
        case .icmp:
            return "waveform.path.ecg"
        case .tcp:
            return "arrow.left.arrow.right"
        }
    }
}

extension DeviceType {
    /// SF Symbol name for this device type
    var iconName: String {
        switch self {
        case .phone: return "iphone"
        case .laptop: return "laptopcomputer"
        case .tablet: return "ipad"
        case .tv: return "tv"
        case .speaker: return "homepod"
        case .gaming: return "gamecontroller"
        case .iot: return "sensor"
        case .router: return "wifi.router"
        case .printer: return "printer"
        case .unknown: return "questionmark.circle"
        }
    }
}
