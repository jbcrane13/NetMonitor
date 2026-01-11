import Foundation

/// Actor-based ICMP ping monitoring service
actor ICMPMonitorService: NetworkMonitorService {

    private let socket: ICMPSocket
    private var sequenceNumber: UInt16 = 0
    private let identifier: UInt16

    init() {
        self.identifier = UInt16.random(in: 1...65535)
        self.socket = ICMPSocket()
    }

    func check(target: NetworkTarget) async throws -> TargetMeasurement {
        // Validate target protocol
        guard target.targetProtocol == .icmp else {
            throw NetworkMonitorError.invalidHost("Target protocol must be ICMP")
        }

        // Increment sequence number
        sequenceNumber = sequenceNumber &+ 1

        do {
            // Send ICMP echo request
            let latency = try await socket.sendEchoRequest(
                to: target.host,
                identifier: identifier,
                sequenceNumber: sequenceNumber
            )

            return TargetMeasurement(
                latency: latency,
                isReachable: true
            )

        } catch let error as NetworkMonitorError {
            return TargetMeasurement(
                latency: nil,
                isReachable: false,
                errorMessage: error.description
            )
        } catch {
            return TargetMeasurement(
                latency: nil,
                isReachable: false,
                errorMessage: "ICMP error: \(error.localizedDescription)"
            )
        }
    }
}
