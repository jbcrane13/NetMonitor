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

/// Low-level ICMP socket wrapper using CFSocket
actor ICMPSocket {

    nonisolated(unsafe) private var socket: CFSocket?
    private let timeout: TimeInterval

    init(timeout: TimeInterval = 3.0) {
        self.timeout = timeout
    }

    deinit {
        if let socket = socket {
            CFSocketInvalidate(socket)
        }
    }

    /// Send ICMP echo request and wait for reply
    /// - Parameters:
    ///   - host: IP address or hostname
    ///   - identifier: Packet identifier
    ///   - sequenceNumber: Packet sequence number
    /// - Returns: Round-trip time in milliseconds
    /// - Throws: NetworkMonitorError
    func sendEchoRequest(to host: String, identifier: UInt16, sequenceNumber: UInt16) async throws -> Double {
        // This is a placeholder for the CFSocket implementation
        // The actual implementation requires C interop and is complex

        throw NetworkMonitorError.unknownError(
            NSError(domain: "ICMPSocket", code: -1, userInfo: [
                NSLocalizedDescriptionKey: "ICMP implementation requires CFSocket C interop - to be implemented"
            ])
        )
    }
}
