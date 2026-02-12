//
//  WakeOnLanService.swift
//  NetMonitor
//
//  Created on 2026-01-15.
//

import Foundation
import Network

/// Error types for Wake on LAN operations
enum WakeOnLanError: Error, LocalizedError {
    case invalidMACAddress(String)
    case networkError(String)
    case timeout

    var errorDescription: String? {
        switch self {
        case .invalidMACAddress(let mac):
            return "Invalid MAC address format: \(mac)"
        case .networkError(let message):
            return "Network error: \(message)"
        case .timeout:
            return "Wake on LAN packet send timed out"
        }
    }
}

/// Actor-based service for sending Wake on LAN magic packets
actor WakeOnLanService {

    /// The standard WOL port
    private let wolPort: UInt16 = 9

    /// Send a Wake on LAN magic packet to the specified MAC address
    /// - Parameters:
    ///   - macAddress: Target MAC address (supports formats: AA:BB:CC:DD:EE:FF, AA-BB-CC-DD-EE-FF, AABBCCDDEEFF)
    ///   - broadcastAddress: Broadcast address for the magic packet (default: "255.255.255.255")
    /// - Returns: True if the packet was sent successfully
    func wake(macAddress: String, broadcastAddress: String = "255.255.255.255") async throws {
        let macBytes = try parseMACAddress(macAddress)
        let magicPacket = buildMagicPacket(macBytes: macBytes)
        try await sendPacket(magicPacket, to: broadcastAddress)
    }

    /// Parse a MAC address string into bytes
    /// - Parameter macAddress: MAC address in any common format
    /// - Returns: Array of 6 bytes representing the MAC address
    private func parseMACAddress(_ macAddress: String) throws -> [UInt8] {
        // Remove common separators and convert to uppercase
        let cleaned = macAddress
            .replacingOccurrences(of: ":", with: "")
            .replacingOccurrences(of: "-", with: "")
            .replacingOccurrences(of: " ", with: "")
            .uppercased()

        guard cleaned.count == 12 else {
            throw WakeOnLanError.invalidMACAddress(macAddress)
        }

        // Validate hex characters only
        guard cleaned.allSatisfy({ $0.isHexDigit }) else {
            throw WakeOnLanError.invalidMACAddress(macAddress)
        }

        // Convert to bytes
        var bytes: [UInt8] = []
        var index = cleaned.startIndex

        for _ in 0..<6 {
            let nextIndex = cleaned.index(index, offsetBy: 2)
            let byteString = String(cleaned[index..<nextIndex])
            guard let byte = UInt8(byteString, radix: 16) else {
                throw WakeOnLanError.invalidMACAddress(macAddress)
            }
            bytes.append(byte)
            index = nextIndex
        }

        return bytes
    }

    /// Build a Wake on LAN magic packet
    /// - Parameter macBytes: The 6-byte MAC address
    /// - Returns: The 102-byte magic packet
    private func buildMagicPacket(macBytes: [UInt8]) -> Data {
        // Magic packet format:
        // - 6 bytes of 0xFF (synchronization stream)
        // - Target MAC address repeated 16 times

        var packet = Data()

        // Add synchronization stream (6 bytes of 0xFF)
        packet.append(contentsOf: [UInt8](repeating: 0xFF, count: 6))

        // Add MAC address 16 times
        for _ in 0..<16 {
            packet.append(contentsOf: macBytes)
        }

        return packet
    }

    /// Send the magic packet via UDP broadcast
    /// - Parameters:
    ///   - packet: The magic packet data
    ///   - broadcastAddress: Broadcast address to send to
    private func sendPacket(_ packet: Data, to broadcastAddress: String) async throws {
        let tracker = ContinuationTracker()

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            let host = NWEndpoint.Host(broadcastAddress)
            guard let port = NWEndpoint.Port(rawValue: wolPort) else {
                continuation.resume(throwing: WakeOnLanError.networkError("Invalid WOL port"))
                return
            }

            // Create UDP connection with broadcast enabled
            let parameters = NWParameters.udp
            parameters.allowLocalEndpointReuse = true

            let connection = NWConnection(host: host, port: port, using: parameters)

            connection.stateUpdateHandler = { [tracker] state in
                switch state {
                case .ready:
                    // Send the magic packet
                    connection.send(content: packet, completion: .contentProcessed { error in
                        connection.cancel()
                        if tracker.tryResume() {
                            if let error = error {
                                continuation.resume(throwing: WakeOnLanError.networkError(error.localizedDescription))
                            } else {
                                continuation.resume()
                            }
                        }
                    })

                case .failed(let error):
                    connection.cancel()
                    if tracker.tryResume() {
                        continuation.resume(throwing: WakeOnLanError.networkError(error.localizedDescription))
                    }

                case .cancelled:
                    if tracker.tryResume() {
                        continuation.resume(throwing: WakeOnLanError.networkError("Connection cancelled"))
                    }

                default:
                    break
                }
            }

            connection.start(queue: .global())

            // Set timeout
            DispatchQueue.global().asyncAfter(deadline: .now() + 5) { [tracker] in
                if tracker.tryResume() {
                    connection.cancel()
                    continuation.resume(throwing: WakeOnLanError.timeout)
                }
            }
        }
    }
}
