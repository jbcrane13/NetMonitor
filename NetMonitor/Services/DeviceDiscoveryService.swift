import Foundation

/// Represents a device discovered on the local network
struct DiscoveredDevice: Sendable, Equatable {
    let ipAddress: String
    let macAddress: String
    let hostname: String?

    init(ipAddress: String, macAddress: String, hostname: String?) {
        self.ipAddress = ipAddress
        self.macAddress = macAddress.uppercased()
        self.hostname = hostname
    }
}

/// Errors that can occur during device discovery
enum DeviceDiscoveryError: Error, Sendable {
    case networkUnavailable
    case permissionDenied
    case scanTimeout
    case invalidSubnet
}

/// Protocol for device discovery services
protocol DeviceDiscoveryService: Actor {
    /// Scan the local network for devices
    func scanNetwork() async throws -> [DiscoveredDevice]

    /// Stop any ongoing scan
    func stopScan()

    /// Check if a scan is currently in progress
    var isScanning: Bool { get }
}
