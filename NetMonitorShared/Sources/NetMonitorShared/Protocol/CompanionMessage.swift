//
//  CompanionMessage.swift
//  NetMonitorShared
//
//  Created on 2026-01-13.
//

import Foundation

// MARK: - Message Types

/// Root message type for companion app communication
public enum CompanionMessage: Codable, Sendable {
    case statusUpdate(StatusUpdatePayload)
    case targetList(TargetListPayload)
    case deviceList(DeviceListPayload)
    case command(CommandPayload)
    case toolResult(ToolResultPayload)
    case error(ErrorPayload)
    case heartbeat(HeartbeatPayload)

    enum CodingKeys: String, CodingKey {
        case type
        case payload
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)

        switch type {
        case "statusUpdate":
            let payload = try container.decode(StatusUpdatePayload.self, forKey: .payload)
            self = .statusUpdate(payload)
        case "targetList":
            let payload = try container.decode(TargetListPayload.self, forKey: .payload)
            self = .targetList(payload)
        case "deviceList":
            let payload = try container.decode(DeviceListPayload.self, forKey: .payload)
            self = .deviceList(payload)
        case "command":
            let payload = try container.decode(CommandPayload.self, forKey: .payload)
            self = .command(payload)
        case "toolResult":
            let payload = try container.decode(ToolResultPayload.self, forKey: .payload)
            self = .toolResult(payload)
        case "error":
            let payload = try container.decode(ErrorPayload.self, forKey: .payload)
            self = .error(payload)
        case "heartbeat":
            let payload = try container.decode(HeartbeatPayload.self, forKey: .payload)
            self = .heartbeat(payload)
        default:
            throw DecodingError.dataCorruptedError(
                forKey: .type,
                in: container,
                debugDescription: "Unknown message type: \(type)"
            )
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        switch self {
        case .statusUpdate(let payload):
            try container.encode("statusUpdate", forKey: .type)
            try container.encode(payload, forKey: .payload)
        case .targetList(let payload):
            try container.encode("targetList", forKey: .type)
            try container.encode(payload, forKey: .payload)
        case .deviceList(let payload):
            try container.encode("deviceList", forKey: .type)
            try container.encode(payload, forKey: .payload)
        case .command(let payload):
            try container.encode("command", forKey: .type)
            try container.encode(payload, forKey: .payload)
        case .toolResult(let payload):
            try container.encode("toolResult", forKey: .type)
            try container.encode(payload, forKey: .payload)
        case .error(let payload):
            try container.encode("error", forKey: .type)
            try container.encode(payload, forKey: .payload)
        case .heartbeat(let payload):
            try container.encode("heartbeat", forKey: .type)
            try container.encode(payload, forKey: .payload)
        }
    }
}

// MARK: - Payload Types

public struct StatusUpdatePayload: Codable, Sendable {
    public let isMonitoring: Bool
    public let onlineTargets: Int
    public let offlineTargets: Int
    public let averageLatency: Double?
    public let timestamp: Date

    public init(
        isMonitoring: Bool,
        onlineTargets: Int,
        offlineTargets: Int,
        averageLatency: Double?,
        timestamp: Date = Date()
    ) {
        self.isMonitoring = isMonitoring
        self.onlineTargets = onlineTargets
        self.offlineTargets = offlineTargets
        self.averageLatency = averageLatency
        self.timestamp = timestamp
    }
}

public struct TargetListPayload: Codable, Sendable {
    public let targets: [TargetInfo]

    public init(targets: [TargetInfo]) {
        self.targets = targets
    }
}

public struct TargetInfo: Codable, Sendable, Identifiable {
    public let id: UUID
    public let name: String
    public let host: String
    public let port: Int?
    public let `protocol`: String
    public let isEnabled: Bool
    public let isReachable: Bool?
    public let latency: Double?

    public init(
        id: UUID,
        name: String,
        host: String,
        port: Int?,
        protocol: String,
        isEnabled: Bool,
        isReachable: Bool?,
        latency: Double?
    ) {
        self.id = id
        self.name = name
        self.host = host
        self.port = port
        self.protocol = `protocol`
        self.isEnabled = isEnabled
        self.isReachable = isReachable
        self.latency = latency
    }
}

public struct DeviceListPayload: Codable, Sendable {
    public let devices: [DeviceInfo]

    public init(devices: [DeviceInfo]) {
        self.devices = devices
    }
}

public struct DeviceInfo: Codable, Sendable, Identifiable {
    public let id: UUID
    public let ipAddress: String
    public let macAddress: String
    public let hostname: String?
    public let vendor: String?
    public let deviceType: String
    public let isOnline: Bool

    public init(
        id: UUID = UUID(),
        ipAddress: String,
        macAddress: String,
        hostname: String?,
        vendor: String? = nil,
        deviceType: String = "unknown",
        isOnline: Bool
    ) {
        self.id = id
        self.ipAddress = ipAddress
        self.macAddress = macAddress
        self.hostname = hostname
        self.vendor = vendor
        self.deviceType = deviceType
        self.isOnline = isOnline
    }
}

public struct CommandPayload: Codable, Sendable {
    public let action: CommandAction
    public let parameters: [String: String]?

    public init(action: CommandAction, parameters: [String: String]?) {
        self.action = action
        self.parameters = parameters
    }
}

public enum CommandAction: String, Codable, Sendable {
    case startMonitoring
    case stopMonitoring
    case scanDevices
    case ping
    case traceroute
    case portScan
    case dnsLookup
    case wakeOnLan
    case refreshTargets
    case refreshDevices
}

public struct ToolResultPayload: Codable, Sendable {
    public let tool: String
    public let success: Bool
    public let result: String
    public let timestamp: Date

    public init(tool: String, success: Bool, result: String, timestamp: Date = Date()) {
        self.tool = tool
        self.success = success
        self.result = result
        self.timestamp = timestamp
    }
}

public struct ErrorPayload: Codable, Sendable {
    public let code: String
    public let message: String
    public let timestamp: Date

    public init(code: String, message: String, timestamp: Date = Date()) {
        self.code = code
        self.message = message
        self.timestamp = timestamp
    }
}

public struct HeartbeatPayload: Codable, Sendable {
    public let timestamp: Date
    public let version: String

    public init(timestamp: Date = Date(), version: String = "1.0") {
        self.timestamp = timestamp
        self.version = version
    }
}
