import Foundation

/// Network connection type
public enum ConnectionType: String, Codable, Sendable, CaseIterable {
    case wifi = "WiFi"
    case ethernet = "Ethernet"
    case cellular = "Cellular"
    case unknown = "Unknown"
}

/// Monitoring protocol type
public enum TargetProtocol: String, Codable, Sendable, CaseIterable {
    case icmp = "ICMP"
    case http = "HTTP"
    case https = "HTTPS"
    case tcp = "TCP"
}

/// Local device type
public enum DeviceType: String, Codable, Sendable, CaseIterable {
    case phone = "Phone"
    case laptop = "Laptop"
    case tablet = "Tablet"
    case tv = "TV"
    case speaker = "Speaker"
    case gaming = "Gaming"
    case iot = "IoT"
    case router = "Router"
    case printer = "Printer"
    case unknown = "Unknown"

    public var iconName: String {
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
