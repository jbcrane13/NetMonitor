import Foundation
import Darwin

/// ICMP Echo Request/Reply packet structure
struct ICMPPacket {
    static let headerSize = 8
    static let echoRequestType: UInt8 = 8
    static let echoReplyType: UInt8 = 0

    var type: UInt8
    var code: UInt8
    var checksum: UInt16
    var identifier: UInt16
    var sequenceNumber: UInt16
    var data: Data

    /// Calculate ICMP checksum
    static func calculateChecksum(data: Data) -> UInt16 {
        var sum: UInt32 = 0
        var count = data.count
        var index = 0

        // Sum all 16-bit words
        while count > 1 {
            let value = UInt16(data[index]) << 8 | UInt16(data[index + 1])
            sum += UInt32(value)
            index += 2
            count -= 2
        }

        // Add leftover byte if odd length
        if count > 0 {
            sum += UInt32(data[index]) << 8
        }

        // Fold 32-bit sum to 16 bits
        while (sum >> 16) != 0 {
            sum = (sum & 0xFFFF) + (sum >> 16)
        }

        return ~UInt16(sum & 0xFFFF)
    }

    /// Create echo request packet
    static func createEchoRequest(identifier: UInt16, sequenceNumber: UInt16) -> Data {
        var packet = Data(count: headerSize)

        packet[0] = echoRequestType
        packet[1] = 0  // code
        // checksum bytes 2-3 will be filled later
        packet[4] = UInt8(identifier >> 8)
        packet[5] = UInt8(identifier & 0xFF)
        packet[6] = UInt8(sequenceNumber >> 8)
        packet[7] = UInt8(sequenceNumber & 0xFF)

        // Calculate and set checksum
        let checksum = calculateChecksum(data: packet)
        packet[2] = UInt8(checksum >> 8)
        packet[3] = UInt8(checksum & 0xFF)

        return packet
    }
}

/// ICMP ping implementation using system ping utility
actor ICMPSocket {

    private let timeout: TimeInterval

    init(timeout: TimeInterval = 3.0) {
        self.timeout = timeout
    }

    /// Send ICMP echo request using system ping utility
    /// - Parameters:
    ///   - host: IP address or hostname
    ///   - identifier: Packet identifier (unused, kept for API compatibility)
    ///   - sequenceNumber: Packet sequence number (unused, kept for API compatibility)
    /// - Returns: Round-trip time in milliseconds
    /// - Throws: NetworkMonitorError
    func sendEchoRequest(to host: String, identifier: UInt16, sequenceNumber: UInt16) async throws -> Double {
        try await withCheckedThrowingContinuation { continuation in
            Task.detached {
                let result = await self.executePing(host: host)
                continuation.resume(with: result)
            }
        }
    }

    /// Execute ping command and parse result
    private func executePing(host: String) async -> Result<Double, Error> {
        let process = Process()
        let pipe = Pipe()

        process.executableURL = URL(fileURLWithPath: "/sbin/ping")
        // -c 1: send 1 packet, -W: timeout in ms
        process.arguments = ["-c", "1", "-W", String(Int(timeout * 1000)), host]
        process.standardOutput = pipe
        process.standardError = pipe

        do {
            try process.run()
            process.waitUntilExit()

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            guard let output = String(data: data, encoding: .utf8) else {
                return .failure(NetworkMonitorError.unknownError(
                    NSError(domain: "ICMPSocket", code: -1, userInfo: [
                        NSLocalizedDescriptionKey: "Failed to read ping output"
                    ])
                ))
            }

            // Check exit status
            if process.terminationStatus != 0 {
                // Host unreachable or timeout
                if output.contains("Request timeout") || output.contains("100.0% packet loss") {
                    return .failure(NetworkMonitorError.timeout)
                }
                if output.contains("Unknown host") || output.contains("cannot resolve") {
                    return .failure(NetworkMonitorError.invalidHost("Cannot resolve hostname: \(host)"))
                }
                return .failure(NetworkMonitorError.networkUnreachable)
            }

            // Parse latency from output
            // Example: "64 bytes from 1.1.1.1: icmp_seq=0 ttl=57 time=12.345 ms"
            if let latency = self.parseLatency(from: output) {
                return .success(latency)
            }

            return .failure(NetworkMonitorError.unknownError(
                NSError(domain: "ICMPSocket", code: -1, userInfo: [
                    NSLocalizedDescriptionKey: "Failed to parse ping latency from output"
                ])
            ))

        } catch {
            return .failure(NetworkMonitorError.unknownError(error))
        }
    }

    /// Parse latency value from ping output
    private func parseLatency(from output: String) -> Double? {
        // Match patterns like "time=12.345 ms" or "time=12 ms"
        let pattern = #"time[=<](\d+\.?\d*)\s*ms"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else {
            return nil
        }

        let range = NSRange(output.startIndex..., in: output)
        guard let match = regex.firstMatch(in: output, options: [], range: range) else {
            return nil
        }

        guard let latencyRange = Range(match.range(at: 1), in: output) else {
            return nil
        }

        return Double(output[latencyRange])
    }
}
