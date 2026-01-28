//
//  NetworkInfoService.swift
//  NetMonitor
//
//  Actor for retrieving current network connection information.
//

import Foundation
import CoreWLAN
import NetMonitorShared

/// Error types for network info operations
enum NetworkInfoError: Error, LocalizedError {
    case permissionDenied
    case noActiveInterface
    case parsingFailed(String)

    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "Permission denied to access network information"
        case .noActiveInterface:
            return "No active network interface found"
        case .parsingFailed(let detail):
            return "Failed to parse network information: \(detail)"
        }
    }
}

/// Network connection information
struct ConnectionInfo: Sendable {
    let connectionType: ConnectionType
    let ssid: String?
    let bssid: String?
    let signalStrength: Int?
    let channel: Int?
    let linkSpeed: Int?
    let interfaceName: String
}

/// Actor for retrieving network connection details
actor NetworkInfoService {
    private let shellRunner = ShellCommandRunner()

    /// Get current network connection information
    func getCurrentConnection() async throws -> ConnectionInfo {
        // Try CoreWLAN first for WiFi
        if let wifiInfo = try? await getWiFiInfoViaCoreWLAN() {
            return wifiInfo
        }

        // Fallback to networksetup command
        if let wifiInfo = try? await getWiFiInfoViaShell() {
            return wifiInfo
        }

        // Check for Ethernet connection
        if let ethernetInfo = await getEthernetInfo() {
            return ethernetInfo
        }

        // Unknown connection type
        return ConnectionInfo(
            connectionType: .unknown,
            ssid: nil,
            bssid: nil,
            signalStrength: nil,
            channel: nil,
            linkSpeed: nil,
            interfaceName: "unknown"
        )
    }

    // MARK: - WiFi Detection (CoreWLAN)

    private func getWiFiInfoViaCoreWLAN() async throws -> ConnectionInfo {
        let client = CWWiFiClient.shared()

        // Try common interface names
        let interfaceNames = ["en0", "en1"]

        for name in interfaceNames {
            if let interface = client.interface(withName: name),
               let ssid = interface.ssid() {

                return ConnectionInfo(
                    connectionType: .wifi,
                    ssid: ssid,
                    bssid: interface.bssid(),
                    signalStrength: interface.rssiValue(),
                    channel: interface.wlanChannel()?.channelNumber,
                    linkSpeed: interface.transmitRate() > 0 ? Int(interface.transmitRate()) : nil,
                    interfaceName: name
                )
            }
        }

        throw NetworkInfoError.noActiveInterface
    }

    // MARK: - WiFi Detection (Shell Fallback)

    private func getWiFiInfoViaShell() async throws -> ConnectionInfo {
        let result = try await shellRunner.run(
            "/usr/sbin/networksetup",
            arguments: ["-getairportnetwork", "en0"],
            timeout: 5
        )

        guard result.exitCode == 0 else {
            throw NetworkInfoError.parsingFailed("networksetup command failed")
        }

        // Parse output: "Current Wi-Fi Network: NetworkName"
        let output = result.stdout.trimmingCharacters(in: .whitespacesAndNewlines)

        if output.contains("You are not associated with an AirPort network") {
            throw NetworkInfoError.noActiveInterface
        }

        if let ssid = output.components(separatedBy: ": ").last,
           !ssid.isEmpty {
            return ConnectionInfo(
                connectionType: .wifi,
                ssid: ssid,
                bssid: nil,
                signalStrength: nil,
                channel: nil,
                linkSpeed: nil,
                interfaceName: "en0"
            )
        }

        throw NetworkInfoError.parsingFailed("Could not parse SSID from output")
    }

    // MARK: - Ethernet Detection

    private func getEthernetInfo() async -> ConnectionInfo? {
        // Check for active Ethernet interfaces
        let ethernetInterfaces = ["en0", "en1", "en2"]

        for interface in ethernetInterfaces {
            if let status = try? await shellRunner.run(
                "/usr/sbin/networksetup",
                arguments: ["-getinfo", interface],
                timeout: 5
            ), status.exitCode == 0 {

                // Check if interface has an IP address
                if status.stdout.contains("IP address:") &&
                   !status.stdout.contains("There is no such hardware port") {

                    // Try to determine if it's actually Ethernet (not WiFi)
                    if !status.stdout.contains("Wi-Fi") {
                        return ConnectionInfo(
                            connectionType: .ethernet,
                            ssid: nil,
                            bssid: nil,
                            signalStrength: nil,
                            channel: nil,
                            linkSpeed: nil,
                            interfaceName: interface
                        )
                    }
                }
            }
        }

        return nil
    }
}
