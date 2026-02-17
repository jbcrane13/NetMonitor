import Foundation
import Network

/// Service for performing real ICMP traceroute using non-privileged BSD sockets.
///
/// Uses `SOCK_DGRAM/IPPROTO_ICMP` with incrementing TTL values. When a router
/// decrements TTL to zero, it returns an ICMP Time Exceeded message revealing
/// its IP address. When the destination is reached, it returns an Echo Reply.
///
/// Falls back to a single TCP probe if ICMP socket creation fails.
actor TracerouteService {

    // MARK: - Configuration

    let defaultMaxHops: Int = 30
    let defaultTimeout: TimeInterval = 2.0
    /// Number of probes sent per hop (standard traceroute uses 3).
    private let probesPerHop: Int = 3

    // MARK: - State

    private var isRunning = false

    // MARK: - Initialization

    init() {}

    // MARK: - Public API

    /// Performs a traceroute to the specified host.
    func trace(
        host: String,
        maxHops: Int? = nil,
        timeout: TimeInterval? = nil
    ) -> AsyncStream<TracerouteHop> {
        let effectiveMaxHops = maxHops ?? defaultMaxHops
        let effectiveTimeout = timeout ?? defaultTimeout

        return AsyncStream { continuation in
            Task {
                await self.performTrace(
                    host: host,
                    maxHops: effectiveMaxHops,
                    timeout: effectiveTimeout,
                    continuation: continuation
                )
            }
        }
    }

    /// Stops the current traceroute operation.
    func stop() async {
        isRunning = false
    }

    /// Returns whether a traceroute is currently running.
    var running: Bool {
        isRunning
    }

    // MARK: - Private Implementation

    private func performTrace(
        host: String,
        maxHops: Int,
        timeout: TimeInterval,
        continuation: AsyncStream<TracerouteHop>.Continuation
    ) async {
        isRunning = true
        defer {
            isRunning = false
            continuation.finish()
        }

        // Resolve hostname to IP
        let resolvedIP = resolveHostname(host)
        guard let targetIP = resolvedIP else {
            continuation.yield(TracerouteHop(
                hopNumber: 1,
                hostname: host,
                ipAddress: nil,
                latencies: [],
                isTimeout: true
            ))
            return
        }

        // Try ICMP traceroute first; fall back to TCP probe if unavailable
        if let socket = try? ICMPSocket() {
            await performICMPTrace(
                socket: socket,
                host: host,
                targetIP: targetIP,
                maxHops: maxHops,
                timeout: timeout,
                continuation: continuation
            )
        } else {
            await performTCPFallback(
                host: host,
                targetIP: targetIP,
                timeout: timeout,
                continuation: continuation
            )
        }
    }

    // MARK: - Real ICMP Traceroute

    private func performICMPTrace(
        socket: ICMPSocket,
        host: String,
        targetIP: String,
        maxHops: Int,
        timeout: TimeInterval,
        continuation: AsyncStream<TracerouteHop>.Continuation
    ) async {
        for ttl in 1...maxHops {
            guard isRunning else { break }

            var probeTimes: [Double] = []
            var hopIP: String?
            var destinationReached = false

            for _ in 0..<probesPerHop {
                guard isRunning else { break }

                let response = await socket.sendProbe(
                    to: targetIP,
                    ttl: Int32(ttl),
                    timeout: timeout
                )

                switch response.kind {
                case .echoReply:
                    probeTimes.append(response.rtt)
                    hopIP = response.sourceIP ?? targetIP
                    destinationReached = true

                case .timeExceeded(let routerIP, _):
                    probeTimes.append(response.rtt)
                    if hopIP == nil {
                        hopIP = routerIP
                    }

                case .timeout:
                    break

                case .error:
                    break
                }
            }

            let allTimeout = probeTimes.isEmpty

            // Reverse DNS lookup for the hop IP
            var hostname: String?
            if let ip = hopIP {
                hostname = await reverseDNS(ip)
                if hostname == host { hostname = nil }
            }

            continuation.yield(TracerouteHop(
                hopNumber: ttl,
                hostname: hostname,
                ipAddress: hopIP,
                latencies: probeTimes,
                isTimeout: allTimeout,
                isDestination: destinationReached
            ))

            if destinationReached { break }
        }
    }

    // MARK: - TCP Fallback

    private nonisolated func performTCPFallback(
        host: String,
        targetIP: String,
        timeout: TimeInterval,
        continuation: AsyncStream<TracerouteHop>.Continuation
    ) async {
        let result = tcpProbe(host: targetIP, port: 443, timeout: timeout)

        switch result {
        case .connected(let rtt), .refused(let rtt):
            continuation.yield(TracerouteHop(
                hopNumber: 1,
                hostname: host == targetIP ? nil : host,
                ipAddress: targetIP,
                latencies: [rtt],
                isTimeout: false,
                isDestination: true
            ))
        case .timeout, .error:
            continuation.yield(TracerouteHop(
                hopNumber: 1,
                hostname: host == targetIP ? nil : host,
                ipAddress: targetIP,
                latencies: [],
                isTimeout: true
            ))
        }
    }

    // MARK: - TCP Probe

    private enum ProbeResult: Sendable {
        case connected(Double)
        case refused(Double)
        case timeout
        case error
    }

    private nonisolated func tcpProbe(
        host: String,
        port: UInt16,
        timeout: TimeInterval
    ) -> ProbeResult {
        let startTime = ContinuousClock.now

        let fd = socket(AF_INET, SOCK_STREAM, IPPROTO_TCP)
        guard fd >= 0 else { return .error }

        let flags = fcntl(fd, F_GETFL, 0)
        _ = fcntl(fd, F_SETFL, flags | O_NONBLOCK)

        var addr = sockaddr_in()
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_port = port.bigEndian
        guard inet_pton(AF_INET, host, &addr.sin_addr) == 1 else {
            close(fd)
            return .error
        }

        let connectResult = withUnsafePointer(to: &addr) { ptr in
            ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockaddrPtr in
                connect(fd, sockaddrPtr, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }

        if connectResult == 0 {
            let elapsed = ContinuousClock.now - startTime
            let rtt = Double(elapsed.components.seconds) * 1000.0 + Double(elapsed.components.attoseconds) / 1e15
            close(fd)
            return .connected(rtt)
        }

        guard errno == EINPROGRESS else {
            close(fd)
            return .error
        }

        let timeoutMs = Int32(timeout * 1000)
        var pollFd = pollfd(fd: fd, events: Int16(POLLOUT), revents: 0)
        let pollResult = poll(&pollFd, 1, timeoutMs)

        let elapsed = ContinuousClock.now - startTime
        let rtt = Double(elapsed.components.seconds) * 1000.0 + Double(elapsed.components.attoseconds) / 1e15

        if pollResult <= 0 {
            close(fd)
            return .timeout
        }

        var connectError: Int32 = 0
        var errorLen = socklen_t(MemoryLayout<Int32>.size)
        getsockopt(fd, SOL_SOCKET, SO_ERROR, &connectError, &errorLen)
        close(fd)

        if connectError == 0 {
            return .connected(rtt)
        } else if connectError == ECONNREFUSED {
            return .refused(rtt)
        } else {
            return .timeout
        }
    }

    // MARK: - DNS Resolution

    private nonisolated func resolveHostname(_ hostname: String) -> String? {
        var testAddr = in_addr()
        if inet_pton(AF_INET, hostname, &testAddr) == 1 {
            return hostname
        }

        var hints = addrinfo()
        hints.ai_family = AF_INET
        hints.ai_socktype = SOCK_STREAM

        var result: UnsafeMutablePointer<addrinfo>?
        let status = getaddrinfo(hostname, nil, &hints, &result)

        guard status == 0, let info = result else {
            return nil
        }
        defer { freeaddrinfo(result) }

        if let addr = info.pointee.ai_addr {
            let sockAddr = addr.withMemoryRebound(to: sockaddr_in.self, capacity: 1) { $0.pointee }
            var ipBuffer = [CChar](repeating: 0, count: Int(INET_ADDRSTRLEN))
            var sinAddr = sockAddr.sin_addr
            inet_ntop(AF_INET, &sinAddr, &ipBuffer, socklen_t(INET_ADDRSTRLEN))
            return String(cString: ipBuffer)
        }

        return nil
    }

    /// Reverse DNS lookup for a hop IP address.
    private func reverseDNS(_ ipAddress: String) async -> String? {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .utility).async {
                var addr = sockaddr_in()
                addr.sin_family = sa_family_t(AF_INET)
                inet_pton(AF_INET, ipAddress, &addr.sin_addr)

                var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))

                let result = withUnsafePointer(to: &addr) { ptr in
                    ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockaddrPtr in
                        getnameinfo(
                            sockaddrPtr,
                            socklen_t(MemoryLayout<sockaddr_in>.size),
                            &hostname,
                            socklen_t(hostname.count),
                            nil, 0, 0
                        )
                    }
                }

                if result == 0 {
                    let name = String(cString: hostname)
                    if name != ipAddress {
                        continuation.resume(returning: name)
                    } else {
                        continuation.resume(returning: nil)
                    }
                } else {
                    continuation.resume(returning: nil)
                }
            }
        }
    }
}
