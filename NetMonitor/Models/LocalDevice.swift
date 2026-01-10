import Foundation
import SwiftData
import NetMonitorShared

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
