//
//  ProcessPingService.swift
//  NetMonitor
//
//  Shell-based ping service using /sbin/ping for ICMP monitoring.
//  Works within App Sandbox constraints where raw ICMP sockets are blocked.
//

import Foundation

/// Result of a completed ping operation with aggregate statistics
struct PingResult: Sendable {
    let transmitted: Int
    let received: Int
    let packetLoss: Double      // percentage 0-100
    let minLatency: Double      // milliseconds
    let avgLatency: Double      // milliseconds
    let maxLatency: Double      // milliseconds
    let stddevLatency: Double   // milliseconds

    var isReachable: Bool {
        received > 0
    }
}

/// A single ping response line
struct PingLine: Sendable {
    let sequenceNumber: Int
    let latency: Double?        // nil if timeout
    let ttl: Int?
    let bytes: Int
    let host: String
}

/// Actor-based service for executing ping commands via /sbin/ping
actor ProcessPingService {
    private let pingPath = "/sbin/ping"
    private let runner = ShellCommandRunner()

    /// Execute a ping and return aggregate results
    /// - Parameters:
    ///   - host: Target hostname or IP address
    ///   - count: Number of ping packets to send (default 1)
    ///   - timeout: Timeout per packet in seconds (default 5)
    /// - Returns: PingResult with statistics
    func ping(host: String, count: Int = 1, timeout: TimeInterval = 5) async throws -> PingResult {
        let arguments = [
            "-c", String(count),
            "-W", String(Int(timeout * 1000)), // macOS ping uses milliseconds for -W
            host
        ]

        let output = try await runner.run(pingPath, arguments: arguments, timeout: timeout * Double(count) + 5)

        // Parse the output even if exit code is non-zero (partial results)
        return try PingOutputParser.parseResult(output.stdout)
    }

    /// Stream ping output line-by-line for real-time display
    /// - Parameters:
    ///   - host: Target hostname or IP address
    ///   - count: Number of ping packets to send
    /// - Returns: AsyncThrowingStream of PingLine results
    func pingStream(host: String, count: Int) -> AsyncThrowingStream<PingLine, Error> {
        let arguments = ["-c", String(count), host]

        return AsyncThrowingStream { continuation in
            Task {
                do {
                    for try await line in await runner.stream(pingPath, arguments: arguments) {
                        if let pingLine = PingOutputParser.parseResponseLine(line) {
                            continuation.yield(pingLine)
                        }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    /// Cancel any running ping operation
    func cancel() async {
        await runner.cancel()
    }
}

/// Parser for /sbin/ping output on macOS
enum PingOutputParser {
    // Response line pattern: "64 bytes from 8.8.8.8: icmp_seq=1 ttl=117 time=14.2 ms"
    private static let responsePattern = try! NSRegularExpression(
        pattern: #"(\d+) bytes from ([^:]+): icmp_seq=(\d+) ttl=(\d+) time=([0-9.]+) ms"#,
        options: []
    )

    // Summary line pattern: "5 packets transmitted, 5 received, 0.0% packet loss"
    // Also handles: "5 packets transmitted, 5 packets received, 0.0% packet loss"
    private static let summaryPattern = try! NSRegularExpression(
        pattern: #"(\d+) packets transmitted, (\d+) (?:packets )?received, ([0-9.]+)% packet loss"#,
        options: []
    )

    // Statistics line pattern: "round-trip min/avg/max/stddev = 14.1/15.2/17.8/1.4 ms"
    private static let statsPattern = try! NSRegularExpression(
        pattern: #"min/avg/max/stddev = ([0-9.]+)/([0-9.]+)/([0-9.]+)/([0-9.]+) ms"#,
        options: []
    )

    // Timeout line pattern: "Request timeout for icmp_seq 1"
    private static let timeoutPattern = try! NSRegularExpression(
        pattern: #"Request timeout for icmp_seq (\d+)"#,
        options: []
    )

    /// Parse a single response line
    static func parseResponseLine(_ line: String) -> PingLine? {
        let range = NSRange(line.startIndex..., in: line)

        // Check for timeout
        if let match = timeoutPattern.firstMatch(in: line, options: [], range: range) {
            if let seqRange = Range(match.range(at: 1), in: line),
               let seq = Int(line[seqRange]) {
                return PingLine(
                    sequenceNumber: seq,
                    latency: nil,
                    ttl: nil,
                    bytes: 0,
                    host: ""
                )
            }
        }

        // Check for successful response
        if let match = responsePattern.firstMatch(in: line, options: [], range: range) {
            guard match.numberOfRanges == 6,
                  let bytesRange = Range(match.range(at: 1), in: line),
                  let hostRange = Range(match.range(at: 2), in: line),
                  let seqRange = Range(match.range(at: 3), in: line),
                  let ttlRange = Range(match.range(at: 4), in: line),
                  let timeRange = Range(match.range(at: 5), in: line),
                  let bytes = Int(line[bytesRange]),
                  let seq = Int(line[seqRange]),
                  let ttl = Int(line[ttlRange]),
                  let time = Double(line[timeRange]) else {
                return nil
            }

            return PingLine(
                sequenceNumber: seq,
                latency: time,
                ttl: ttl,
                bytes: bytes,
                host: String(line[hostRange])
            )
        }

        return nil
    }

    /// Parse complete ping output into PingResult
    static func parseResult(_ output: String) throws -> PingResult {
        let lines = output.components(separatedBy: .newlines)

        var transmitted = 0
        var received = 0
        var packetLoss: Double = 100.0
        var minLatency: Double = 0
        var avgLatency: Double = 0
        var maxLatency: Double = 0
        var stddevLatency: Double = 0

        for line in lines {
            let range = NSRange(line.startIndex..., in: line)

            // Parse summary line
            if let match = summaryPattern.firstMatch(in: line, options: [], range: range) {
                if let txRange = Range(match.range(at: 1), in: line),
                   let rxRange = Range(match.range(at: 2), in: line),
                   let lossRange = Range(match.range(at: 3), in: line) {
                    transmitted = Int(line[txRange]) ?? 0
                    received = Int(line[rxRange]) ?? 0
                    packetLoss = Double(line[lossRange]) ?? 100.0
                }
            }

            // Parse statistics line
            if let match = statsPattern.firstMatch(in: line, options: [], range: range) {
                if let minRange = Range(match.range(at: 1), in: line),
                   let avgRange = Range(match.range(at: 2), in: line),
                   let maxRange = Range(match.range(at: 3), in: line),
                   let stddevRange = Range(match.range(at: 4), in: line) {
                    minLatency = Double(line[minRange]) ?? 0
                    avgLatency = Double(line[avgRange]) ?? 0
                    maxLatency = Double(line[maxRange]) ?? 0
                    stddevLatency = Double(line[stddevRange]) ?? 0
                }
            }
        }

        // If we couldn't parse summary, try to determine from response lines
        if transmitted == 0 {
            var responseCount = 0
            var totalLatency: Double = 0

            for line in lines {
                if let pingLine = parseResponseLine(line) {
                    transmitted = max(transmitted, pingLine.sequenceNumber)
                    if let latency = pingLine.latency {
                        responseCount += 1
                        totalLatency += latency
                        minLatency = minLatency == 0 ? latency : min(minLatency, latency)
                        maxLatency = max(maxLatency, latency)
                    }
                }
            }

            received = responseCount
            if responseCount > 0 {
                avgLatency = totalLatency / Double(responseCount)
                packetLoss = transmitted > 0 ? Double(transmitted - received) / Double(transmitted) * 100 : 100
            }
        }

        return PingResult(
            transmitted: transmitted,
            received: received,
            packetLoss: packetLoss,
            minLatency: minLatency,
            avgLatency: avgLatency,
            maxLatency: maxLatency,
            stddevLatency: stddevLatency
        )
    }
}
