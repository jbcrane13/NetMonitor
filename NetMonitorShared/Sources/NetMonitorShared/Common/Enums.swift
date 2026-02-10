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
}
