import Foundation
import SwiftData
import NetMonitorShared

// MARK: - LocalDevice Model

@Model
final class LocalDevice {
    var id: UUID
    var ipAddress: String
    var macAddress: String
    var hostname: String?
    var vendor: String?
    var deviceType: DeviceType
    var customName: String?
    var notes: String?
    var firstSeen: Date
    var lastSeen: Date
    var isOnline: Bool

    init(
        id: UUID = UUID(),
        ipAddress: String,
        macAddress: String,
        hostname: String? = nil,
        vendor: String? = nil,
        deviceType: DeviceType = .unknown,
        customName: String? = nil,
        notes: String? = nil,
        firstSeen: Date = .now,
        lastSeen: Date = .now,
        isOnline: Bool = true
    ) {
        self.id = id
        self.ipAddress = ipAddress
        self.macAddress = macAddress
        self.hostname = hostname
        self.vendor = vendor
        self.deviceType = deviceType
        self.customName = customName
        self.notes = notes
        self.firstSeen = firstSeen
        self.lastSeen = lastSeen
        self.isOnline = isOnline
    }
}

// MARK: - Computed Properties & Filtering

extension LocalDevice {
    /// Display name for the device (prioritizes custom name, then hostname, then IP)
    var displayName: String {
        customName ?? hostname ?? ipAddress
    }

    /// Check if device matches search text (case-insensitive)
    /// - Parameter searchText: The search query
    /// - Returns: True if device matches the search criteria
    func matches(searchText: String) -> Bool {
        guard !searchText.isEmpty else { return true }

        return displayName.localizedCaseInsensitiveContains(searchText) ||
               ipAddress.contains(searchText) ||
               macAddress.localizedCaseInsensitiveContains(searchText) ||
               (vendor?.localizedCaseInsensitiveContains(searchText) ?? false)
    }

    /// Filter devices by online status and search text
    /// - Parameters:
    ///   - devices: Array of devices to filter
    ///   - onlineOnly: If true, only include online devices
    ///   - searchText: Search text to filter by
    /// - Returns: Filtered array of devices
    static func filter(
        _ devices: [LocalDevice],
        onlineOnly: Bool,
        searchText: String
    ) -> [LocalDevice] {
        var result = devices

        if onlineOnly {
            result = result.filter { $0.isOnline }
        }

        if !searchText.isEmpty {
            result = result.filter { $0.matches(searchText: searchText) }
        }

        return result
    }
}
