//
//  PortScanService.swift
//  NetMonitor
//
//  Actor-based port scanning service using Network.framework NWConnection.
//

import Foundation
import Network

/// Actor-based service for TCP port scanning using Network.framework.
actor PortScanService {

    /// Result of scanning a single port.
    struct PortScanResult: Sendable {
        let port: UInt16
        let isOpen: Bool
        let latency: TimeInterval
        let serviceName: String
    }

    private var isCancelled = false

    /// Scan a list of ports on the given host, yielding results as they complete.
    ///
    /// Ports are scanned in concurrent batches for performance.
    /// - Parameters:
    ///   - host: Target hostname or IP address
    ///   - ports: Array of port numbers to scan
    ///   - batchSize: Number of concurrent connections per batch (default 50)
    /// - Returns: AsyncStream of PortScanResult values
    func scanPorts(host: String, ports: [UInt16], batchSize: Int = 50) -> AsyncStream<PortScanResult> {
        isCancelled = false

        let service = self
        return AsyncStream { continuation in
            Task {
                for batch in stride(from: 0, to: ports.count, by: batchSize) {
                    guard await !service.isCancelled else { break }

                    let end = min(batch + batchSize, ports.count)
                    let batchPorts = Array(ports[batch..<end])

                    await withTaskGroup(of: PortScanResult.self) { group in
                        for port in batchPorts {
                            group.addTask {
                                await Self.checkPort(host: host, port: port)
                            }
                        }

                        for await result in group {
                            if await service.isCancelled { break }
                            continuation.yield(result)
                        }
                    }
                }
                continuation.finish()
            }
        }
    }

    /// Cancel any in-progress scan.
    func cancel() {
        isCancelled = true
    }

    /// Look up the common service name for a well-known port.
    static func serviceName(for port: UInt16) -> String {
        switch port {
        case 21: return "FTP"
        case 22: return "SSH"
        case 23: return "Telnet"
        case 25: return "SMTP"
        case 53: return "DNS"
        case 80: return "HTTP"
        case 110: return "POP3"
        case 143: return "IMAP"
        case 443: return "HTTPS"
        case 445: return "SMB"
        case 465: return "SMTPS"
        case 548: return "AFP"
        case 587: return "Submission"
        case 993: return "IMAPS"
        case 995: return "POP3S"
        case 3000: return "Dev Server"
        case 3001: return "Dev Server"
        case 3306: return "MySQL"
        case 3389: return "RDP"
        case 4000: return "Dev Server"
        case 5000: return "Dev Server"
        case 5432: return "PostgreSQL"
        case 5900: return "VNC"
        case 6379: return "Redis"
        case 8000: return "HTTP Alt"
        case 8080: return "HTTP Alt"
        case 8443: return "HTTPS Alt"
        case 9000: return "Dev Server"
        case 27017: return "MongoDB"
        default: return "Unknown"
        }
    }

    // MARK: - Private

    /// Check a single port using NWConnection with a 2-second timeout.
    private static func checkPort(host: String, port: UInt16) async -> PortScanResult {
        let startTime = Date()

        guard let nwPort = NWEndpoint.Port(rawValue: port) else {
            return PortScanResult(port: port, isOpen: false, latency: 0, serviceName: serviceName(for: port))
        }

        let endpoint = NWEndpoint.hostPort(
            host: NWEndpoint.Host(host),
            port: nwPort
        )

        let connection = NWConnection(to: endpoint, using: .tcp)

        let isOpen: Bool = await withCheckedContinuation { continuation in
            let tracker = ContinuationTracker()

            connection.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    connection.cancel()
                    if tracker.tryResume() {
                        continuation.resume(returning: true)
                    }

                case .failed, .cancelled:
                    if tracker.tryResume() {
                        continuation.resume(returning: false)
                    }

                default:
                    break
                }
            }

            connection.start(queue: .global())

            // Timeout after 2 seconds
            DispatchQueue.global().asyncAfter(deadline: .now() + 2) {
                if tracker.tryResume() {
                    connection.cancel()
                    continuation.resume(returning: false)
                }
            }
        }

        let latency = Date().timeIntervalSince(startTime)

        return PortScanResult(
            port: port,
            isOpen: isOpen,
            latency: isOpen ? latency : 0,
            serviceName: serviceName(for: port)
        )
    }
}
