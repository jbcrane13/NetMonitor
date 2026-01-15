//
//  CompanionMessageHandler.swift
//  NetMonitor
//
//  Created on 2026-01-13.
//

import Foundation
import SwiftData
import NetMonitorShared
import Darwin

/// Handles incoming messages from companion apps
@MainActor
final class CompanionMessageHandler {

    private let modelContext: ModelContext
    private let monitoringSession: MonitoringSession
    private let deviceDiscovery: DeviceDiscoveryCoordinator

    init(
        modelContext: ModelContext,
        monitoringSession: MonitoringSession,
        deviceDiscovery: DeviceDiscoveryCoordinator
    ) {
        self.modelContext = modelContext
        self.monitoringSession = monitoringSession
        self.deviceDiscovery = deviceDiscovery
    }

    /// Process an incoming message and return an optional response
    func handle(_ message: CompanionMessage, from clientID: UUID) async -> CompanionMessage? {
        switch message {
        case .command(let payload):
            return await handleCommand(payload)

        case .heartbeat:
            return .heartbeat(HeartbeatPayload())

        default:
            return nil
        }
    }

    /// Generate current status update message
    func generateStatusUpdate() -> CompanionMessage {
        let results = monitoringSession.latestResults.values
        let online = results.filter { $0.isReachable }.count
        let offline = results.filter { !$0.isReachable }.count
        let latencies = results.compactMap { $0.latency }
        let avgLatency = latencies.isEmpty ? nil : latencies.reduce(0, +) / Double(latencies.count)

        return .statusUpdate(StatusUpdatePayload(
            isMonitoring: monitoringSession.isMonitoring,
            onlineTargets: online,
            offlineTargets: offline,
            averageLatency: avgLatency
        ))
    }

    /// Generate target list message
    func generateTargetList() -> CompanionMessage {
        let descriptor = FetchDescriptor<NetworkTarget>()
        let targets = (try? modelContext.fetch(descriptor)) ?? []

        let targetInfos = targets.map { target in
            let measurement = monitoringSession.latestMeasurement(for: target.id)
            return TargetInfo(
                id: target.id,
                name: target.name,
                host: target.host,
                port: target.port,
                protocol: target.targetProtocol.rawValue,
                isEnabled: target.isEnabled,
                isReachable: measurement?.isReachable,
                latency: measurement?.latency
            )
        }

        return .targetList(TargetListPayload(targets: targetInfos))
    }

    /// Generate device list message
    func generateDeviceList() -> CompanionMessage {
        let deviceInfos = deviceDiscovery.discoveredDevices.map { device in
            DeviceInfo(
                id: device.id,
                ipAddress: device.ipAddress,
                macAddress: device.macAddress,
                hostname: device.hostname,
                vendor: device.vendor,
                deviceType: device.deviceType.rawValue,
                isOnline: device.isOnline
            )
        }

        return .deviceList(DeviceListPayload(devices: deviceInfos))
    }

    // MARK: - Private Methods

    private func handleCommand(_ payload: CommandPayload) async -> CompanionMessage? {
        switch payload.action {
        case .startMonitoring:
            monitoringSession.startMonitoring()
            return generateStatusUpdate()

        case .stopMonitoring:
            monitoringSession.stopMonitoring()
            return generateStatusUpdate()

        case .scanDevices:
            deviceDiscovery.startScan()
            return .toolResult(ToolResultPayload(
                tool: "deviceScan",
                success: true,
                result: "Scan started"
            ))

        case .refreshTargets:
            return generateTargetList()

        case .refreshDevices:
            return generateDeviceList()

        case .ping:
            return await handlePingCommand(payload.parameters)

        case .wakeOnLan:
            return await handleWakeOnLan(payload.parameters)

        default:
            return .error(ErrorPayload(
                code: "UNSUPPORTED_COMMAND",
                message: "Command '\(payload.action.rawValue)' is not yet implemented"
            ))
        }
    }

    private func handlePingCommand(_ parameters: [String: String]?) async -> CompanionMessage {
        guard let host = parameters?["host"] else {
            return .error(ErrorPayload(
                code: "MISSING_PARAMETER",
                message: "Ping requires 'host' parameter"
            ))
        }

        // Create temporary target for ping
        let target = NetworkTarget(
            name: "Ping \(host)",
            host: host,
            port: nil,
            targetProtocol: .icmp,
            checkInterval: 5,
            timeout: 10,
            isEnabled: true
        )

        let service = ICMPMonitorService()

        do {
            let measurement = try await service.check(target: target)
            if measurement.isReachable, let latency = measurement.latency {
                return .toolResult(ToolResultPayload(
                    tool: "ping",
                    success: true,
                    result: "Reply from \(host): time=\(Int(latency))ms"
                ))
            } else {
                return .toolResult(ToolResultPayload(
                    tool: "ping",
                    success: false,
                    result: measurement.errorMessage ?? "No response from \(host)"
                ))
            }
        } catch {
            return .toolResult(ToolResultPayload(
                tool: "ping",
                success: false,
                result: "Ping failed: \(error.localizedDescription)"
            ))
        }
    }

    private func handleWakeOnLan(_ parameters: [String: String]?) async -> CompanionMessage {
        guard let mac = parameters?["mac"] else {
            return .error(ErrorPayload(
                code: "MISSING_PARAMETER",
                message: "Wake on LAN requires 'mac' parameter"
            ))
        }

        // Parse MAC address
        guard let macBytes = parseMACAddress(mac) else {
            return .toolResult(ToolResultPayload(
                tool: "wakeOnLan",
                success: false,
                result: "Invalid MAC address format: \(mac)"
            ))
        }

        // Build magic packet: 6 bytes of 0xFF followed by MAC address repeated 16 times
        var packet = Data(repeating: 0xFF, count: 6)
        for _ in 0..<16 {
            packet.append(contentsOf: macBytes)
        }

        // Send UDP broadcast packet
        let sock = socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP)
        guard sock >= 0 else {
            return .toolResult(ToolResultPayload(
                tool: "wakeOnLan",
                success: false,
                result: "Failed to create socket"
            ))
        }
        defer { close(sock) }

        // Enable broadcast
        var broadcast: Int32 = 1
        setsockopt(sock, SOL_SOCKET, SO_BROADCAST, &broadcast, socklen_t(MemoryLayout<Int32>.size))

        // Set destination: broadcast on port 9
        var addr = sockaddr_in()
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_port = UInt16(9).bigEndian
        inet_pton(AF_INET, "255.255.255.255", &addr.sin_addr)

        // Send packet
        let sent = packet.withUnsafeBytes { ptr in
            withUnsafePointer(to: &addr) { addrPtr in
                addrPtr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockaddrPtr in
                    sendto(sock, ptr.baseAddress, packet.count, 0, sockaddrPtr, socklen_t(MemoryLayout<sockaddr_in>.size))
                }
            }
        }

        if sent > 0 {
            return .toolResult(ToolResultPayload(
                tool: "wakeOnLan",
                success: true,
                result: "Magic packet sent to \(mac)"
            ))
        } else {
            return .toolResult(ToolResultPayload(
                tool: "wakeOnLan",
                success: false,
                result: "Failed to send magic packet"
            ))
        }
    }

    private func parseMACAddress(_ mac: String) -> [UInt8]? {
        let cleaned = mac.replacingOccurrences(of: ":", with: "")
                        .replacingOccurrences(of: "-", with: "")
        guard cleaned.count == 12 else { return nil }

        var bytes: [UInt8] = []
        var index = cleaned.startIndex
        for _ in 0..<6 {
            let nextIndex = cleaned.index(index, offsetBy: 2)
            guard let byte = UInt8(cleaned[index..<nextIndex], radix: 16) else { return nil }
            bytes.append(byte)
            index = nextIndex
        }
        return bytes
    }
}
