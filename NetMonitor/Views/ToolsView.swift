import SwiftUI

// MARK: - Tool Definition

enum NetworkTool: String, CaseIterable, Identifiable {
    case ping = "Ping"
    case traceroute = "Traceroute"
    case portScanner = "Port Scanner"
    case dnsLookup = "DNS Lookup"
    case whois = "WHOIS"
    case speedTest = "Speed Test"
    case wakeOnLan = "Wake on LAN"
    case bonjourBrowser = "Bonjour Browser"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .ping: return "waveform.path"
        case .traceroute: return "point.topleft.down.to.point.bottomright.curvepath"
        case .portScanner: return "network"
        case .dnsLookup: return "magnifyingglass"
        case .whois: return "doc.text.magnifyingglass"
        case .speedTest: return "speedometer"
        case .wakeOnLan: return "power"
        case .bonjourBrowser: return "bonjour"
        }
    }

    var description: String {
        switch self {
        case .ping: return "Test host reachability"
        case .traceroute: return "Trace network path"
        case .portScanner: return "Scan open ports"
        case .dnsLookup: return "Query DNS records"
        case .whois: return "Domain information"
        case .speedTest: return "Measure bandwidth"
        case .wakeOnLan: return "Wake devices remotely"
        case .bonjourBrowser: return "Browse local services"
        }
    }
}

// MARK: - Main View

struct ToolsView: View {
    @State private var selectedTool: NetworkTool?

    private let columns = [
        GridItem(.adaptive(minimum: 150, maximum: 200), spacing: 16)
    ]

    var body: some View {
        NavigationSplitView {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(NetworkTool.allCases) { tool in
                        ToolCard(tool: tool, isSelected: selectedTool == tool)
                            .onTapGesture {
                                selectedTool = tool
                            }
                    }
                }
                .padding()
            }
            .navigationTitle("Tools")
        } detail: {
            if let tool = selectedTool {
                ToolDetailView(tool: tool)
            } else {
                ContentUnavailableView(
                    "Select a Tool",
                    systemImage: "wrench.and.screwdriver",
                    description: Text("Choose a network tool from the sidebar")
                )
            }
        }
    }
}

// MARK: - Tool Card

struct ToolCard: View {
    let tool: NetworkTool
    let isSelected: Bool

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: tool.icon)
                .font(.system(size: 32))
                .foregroundStyle(isSelected ? .white : .cyan)

            Text(tool.rawValue)
                .font(.headline)
                .foregroundStyle(isSelected ? .white : .primary)

            Text(tool.description)
                .font(.caption)
                .foregroundStyle(isSelected ? .white.opacity(0.8) : .secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isSelected ? Color.cyan : Color.white.opacity(0.05))
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
    }
}

// MARK: - Tool Detail View

struct ToolDetailView: View {
    let tool: NetworkTool

    var body: some View {
        switch tool {
        case .ping:
            PingToolView()
        case .traceroute:
            TracerouteToolView()
        case .portScanner:
            PortScannerToolView()
        case .dnsLookup:
            DNSLookupToolView()
        case .whois:
            WHOISToolView()
        case .speedTest:
            SpeedTestToolView()
        case .wakeOnLan:
            WakeOnLANToolView()
        case .bonjourBrowser:
            BonjourBrowserToolView()
        }
    }
}

// MARK: - Ping Tool

struct PingToolView: View {
    @State private var host = ""
    @State private var count = 5
    @State private var isRunning = false
    @State private var results: [PingResult] = []

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Input section
            HStack {
                TextField("Host or IP address", text: $host)
                    .textFieldStyle(.roundedBorder)

                Stepper("Count: \(count)", value: $count, in: 1...100)
                    .frame(width: 140)

                Button(isRunning ? "Stop" : "Ping") {
                    if isRunning {
                        isRunning = false
                    } else {
                        runPing()
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(host.isEmpty)
            }

            // Results
            if !results.isEmpty {
                ScrollView {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(results) { result in
                            HStack {
                                Text("Seq \(result.sequence):")
                                    .font(.system(.body, design: .monospaced))
                                    .foregroundStyle(.secondary)

                                if let latency = result.latency {
                                    Text(String(format: "%.2f ms", latency))
                                        .font(.system(.body, design: .monospaced))
                                        .foregroundStyle(.green)
                                } else {
                                    Text(result.error ?? "Timeout")
                                        .font(.system(.body, design: .monospaced))
                                        .foregroundStyle(.red)
                                }
                            }
                        }
                    }
                }
                .frame(maxHeight: 300)

                // Statistics
                if results.count > 1 {
                    Divider()
                    StatisticsView(results: results)
                }
            }

            Spacer()
        }
        .padding()
        .navigationTitle("Ping")
    }

    private func runPing() {
        guard !host.isEmpty else { return }
        results = []
        isRunning = true

        Task {
            for seq in 1...count {
                guard isRunning else { break }

                let result = await executePing(sequence: seq)
                await MainActor.run {
                    results.append(result)
                }

                if seq < count && isRunning {
                    try? await Task.sleep(for: .seconds(1))
                }
            }
            await MainActor.run {
                isRunning = false
            }
        }
    }

    private func executePing(sequence: Int) async -> PingResult {
        let process = Process()
        let pipe = Pipe()

        process.executableURL = URL(fileURLWithPath: "/sbin/ping")
        process.arguments = ["-c", "1", "-W", "3000", host]
        process.standardOutput = pipe
        process.standardError = pipe

        do {
            try process.run()
            process.waitUntilExit()

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""

            if process.terminationStatus == 0,
               let latency = parseLatency(from: output) {
                return PingResult(sequence: sequence, latency: latency, error: nil)
            } else {
                return PingResult(sequence: sequence, latency: nil, error: "Host unreachable")
            }
        } catch {
            return PingResult(sequence: sequence, latency: nil, error: error.localizedDescription)
        }
    }

    private func parseLatency(from output: String) -> Double? {
        let pattern = #"time[=<](\d+\.?\d*)\s*ms"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
              let match = regex.firstMatch(in: output, range: NSRange(output.startIndex..., in: output)),
              let range = Range(match.range(at: 1), in: output) else {
            return nil
        }
        return Double(output[range])
    }
}

struct PingResult: Identifiable {
    let id = UUID()
    let sequence: Int
    let latency: Double?
    let error: String?
}

struct StatisticsView: View {
    let results: [PingResult]

    private var successfulPings: [Double] {
        results.compactMap { $0.latency }
    }

    var body: some View {
        HStack(spacing: 24) {
            StatItem(label: "Sent", value: "\(results.count)")
            StatItem(label: "Received", value: "\(successfulPings.count)")
            StatItem(label: "Loss", value: String(format: "%.0f%%", lossPercentage))

            if !successfulPings.isEmpty {
                StatItem(label: "Min", value: String(format: "%.2f ms", successfulPings.min() ?? 0))
                StatItem(label: "Avg", value: String(format: "%.2f ms", average))
                StatItem(label: "Max", value: String(format: "%.2f ms", successfulPings.max() ?? 0))
            }
        }
    }

    private var lossPercentage: Double {
        guard !results.isEmpty else { return 0 }
        let lost = results.count - successfulPings.count
        return Double(lost) / Double(results.count) * 100
    }

    private var average: Double {
        guard !successfulPings.isEmpty else { return 0 }
        return successfulPings.reduce(0, +) / Double(successfulPings.count)
    }
}

struct StatItem: View {
    let label: String
    let value: String

    var body: some View {
        VStack {
            Text(value)
                .font(.headline)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Traceroute Tool

struct TracerouteToolView: View {
    @State private var host = ""
    @State private var isRunning = false
    @State private var output = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                TextField("Host or IP address", text: $host)
                    .textFieldStyle(.roundedBorder)

                Button(isRunning ? "Stop" : "Trace") {
                    if isRunning {
                        isRunning = false
                    } else {
                        runTraceroute()
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(host.isEmpty)
            }

            if !output.isEmpty {
                ScrollView {
                    Text(output)
                        .font(.system(.body, design: .monospaced))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }

            Spacer()
        }
        .padding()
        .navigationTitle("Traceroute")
    }

    private func runTraceroute() {
        guard !host.isEmpty else { return }
        let targetHost = host
        output = "Tracing route to \(targetHost)...\n"
        isRunning = true

        Task.detached {
            let process = Process()
            let pipe = Pipe()

            process.executableURL = URL(fileURLWithPath: "/usr/sbin/traceroute")
            process.arguments = ["-m", "30", targetHost]
            process.standardOutput = pipe
            process.standardError = pipe

            do {
                try process.run()

                // Read output incrementally
                let handle = pipe.fileHandleForReading
                for try await line in handle.bytes.lines {
                    await MainActor.run {
                        output += line + "\n"
                    }
                }

                process.waitUntilExit()
            } catch {
                await MainActor.run {
                    output += "Error: \(error.localizedDescription)\n"
                }
            }

            await MainActor.run {
                isRunning = false
            }
        }
    }
}

// MARK: - Port Scanner Tool

struct PortScannerToolView: View {
    @State private var host = ""
    @State private var portRange = "1-1024"
    @State private var isRunning = false
    @State private var openPorts: [Int] = []
    @State private var progress = 0.0
    @State private var currentPort = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                TextField("Host or IP address", text: $host)
                    .textFieldStyle(.roundedBorder)

                TextField("Port range (e.g., 1-1024)", text: $portRange)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 150)

                Button(isRunning ? "Stop" : "Scan") {
                    if isRunning {
                        isRunning = false
                    } else {
                        runScan()
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(host.isEmpty)
            }

            if isRunning {
                VStack(alignment: .leading) {
                    ProgressView(value: progress)
                    Text("Scanning port \(currentPort)...")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if !openPorts.isEmpty {
                Text("Open Ports:")
                    .font(.headline)

                ScrollView {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 100))], spacing: 8) {
                        ForEach(openPorts, id: \.self) { port in
                            HStack {
                                Text("\(port)")
                                    .font(.system(.body, design: .monospaced))
                                if let service = commonPorts[port] {
                                    Text("(\(service))")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.green.opacity(0.2))
                            .cornerRadius(4)
                        }
                    }
                }
            }

            Spacer()
        }
        .padding()
        .navigationTitle("Port Scanner")
    }

    private let commonPorts: [Int: String] = [
        21: "FTP", 22: "SSH", 23: "Telnet", 25: "SMTP", 53: "DNS",
        80: "HTTP", 110: "POP3", 143: "IMAP", 443: "HTTPS", 993: "IMAPS",
        995: "POP3S", 3306: "MySQL", 5432: "PostgreSQL", 6379: "Redis",
        8080: "HTTP-Alt", 27017: "MongoDB"
    ]

    private func runScan() {
        guard !host.isEmpty else { return }

        let parts = portRange.split(separator: "-")
        guard parts.count == 2,
              let start = Int(parts[0]),
              let end = Int(parts[1]),
              start > 0, end <= 65535, start <= end else {
            return
        }

        openPorts = []
        isRunning = true
        progress = 0

        Task {
            let total = end - start + 1
            var scanned = 0

            for port in start...end {
                guard isRunning else { break }

                await MainActor.run {
                    currentPort = port
                }

                if await isPortOpen(host: host, port: port) {
                    await MainActor.run {
                        openPorts.append(port)
                    }
                }

                scanned += 1
                await MainActor.run {
                    progress = Double(scanned) / Double(total)
                }
            }

            await MainActor.run {
                isRunning = false
            }
        }
    }

    private func isPortOpen(host: String, port: Int) async -> Bool {
        await withCheckedContinuation { continuation in
            var hints = addrinfo()
            hints.ai_family = AF_INET
            hints.ai_socktype = SOCK_STREAM

            var result: UnsafeMutablePointer<addrinfo>?
            guard getaddrinfo(host, String(port), &hints, &result) == 0,
                  let info = result else {
                continuation.resume(returning: false)
                return
            }
            defer { freeaddrinfo(result) }

            let sock = socket(info.pointee.ai_family, info.pointee.ai_socktype, info.pointee.ai_protocol)
            guard sock >= 0 else {
                continuation.resume(returning: false)
                return
            }
            defer { close(sock) }

            // Set non-blocking
            let flags = fcntl(sock, F_GETFL, 0)
            _ = fcntl(sock, F_SETFL, flags | O_NONBLOCK)

            let connectResult = connect(sock, info.pointee.ai_addr, info.pointee.ai_addrlen)
            if connectResult == 0 {
                continuation.resume(returning: true)
                return
            }

            if errno == EINPROGRESS {
                // Use poll instead of select for simplicity
                var pfd = pollfd(fd: sock, events: Int16(POLLOUT), revents: 0)
                let pollResult = poll(&pfd, 1, 100) // 100ms timeout

                if pollResult > 0 && (pfd.revents & Int16(POLLOUT)) != 0 {
                    var error: Int32 = 0
                    var len = socklen_t(MemoryLayout<Int32>.size)
                    getsockopt(sock, SOL_SOCKET, SO_ERROR, &error, &len)
                    continuation.resume(returning: error == 0)
                    return
                }
            }

            continuation.resume(returning: false)
        }
    }
}

// MARK: - DNS Lookup Tool

struct DNSLookupToolView: View {
    @State private var domain = ""
    @State private var recordType = "A"
    @State private var isRunning = false
    @State private var results: [String] = []

    private let recordTypes = ["A", "AAAA", "MX", "TXT", "CNAME", "NS", "SOA"]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                TextField("Domain name", text: $domain)
                    .textFieldStyle(.roundedBorder)

                Picker("Type", selection: $recordType) {
                    ForEach(recordTypes, id: \.self) { type in
                        Text(type).tag(type)
                    }
                }
                .frame(width: 100)

                Button("Lookup") {
                    runLookup()
                }
                .buttonStyle(.borderedProminent)
                .disabled(domain.isEmpty || isRunning)
            }

            if !results.isEmpty {
                ScrollView {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(results, id: \.self) { result in
                            Text(result)
                                .font(.system(.body, design: .monospaced))
                                .textSelection(.enabled)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }

            Spacer()
        }
        .padding()
        .navigationTitle("DNS Lookup")
    }

    private func runLookup() {
        guard !domain.isEmpty else { return }
        let targetDomain = domain
        let targetRecordType = recordType
        results = []
        isRunning = true

        Task.detached {
            let process = Process()
            let pipe = Pipe()

            process.executableURL = URL(fileURLWithPath: "/usr/bin/dig")
            process.arguments = ["+short", targetDomain, targetRecordType]
            process.standardOutput = pipe
            process.standardError = pipe

            do {
                try process.run()
                process.waitUntilExit()

                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                let output = String(data: data, encoding: .utf8) ?? ""

                await MainActor.run {
                    results = output.split(separator: "\n").map(String.init)
                    if results.isEmpty {
                        results = ["No records found"]
                    }
                    isRunning = false
                }
            } catch {
                await MainActor.run {
                    results = ["Error: \(error.localizedDescription)"]
                    isRunning = false
                }
            }
        }
    }
}

// MARK: - WHOIS Tool

struct WHOISToolView: View {
    @State private var domain = ""
    @State private var isRunning = false
    @State private var output = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                TextField("Domain name", text: $domain)
                    .textFieldStyle(.roundedBorder)

                Button("Lookup") {
                    runWhois()
                }
                .buttonStyle(.borderedProminent)
                .disabled(domain.isEmpty || isRunning)
            }

            if !output.isEmpty {
                ScrollView {
                    Text(output)
                        .font(.system(.body, design: .monospaced))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }

            Spacer()
        }
        .padding()
        .navigationTitle("WHOIS")
    }

    private func runWhois() {
        guard !domain.isEmpty else { return }
        let targetDomain = domain
        output = "Looking up \(targetDomain)...\n"
        isRunning = true

        Task.detached {
            let process = Process()
            let pipe = Pipe()

            process.executableURL = URL(fileURLWithPath: "/usr/bin/whois")
            process.arguments = [targetDomain]
            process.standardOutput = pipe
            process.standardError = pipe

            do {
                try process.run()
                process.waitUntilExit()

                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                let result = String(data: data, encoding: .utf8) ?? "No output"

                await MainActor.run {
                    output = result
                    isRunning = false
                }
            } catch {
                await MainActor.run {
                    output = "Error: \(error.localizedDescription)"
                    isRunning = false
                }
            }
        }
    }
}

// MARK: - Speed Test Tool

struct SpeedTestToolView: View {
    @State private var isRunning = false
    @State private var downloadSpeed: Double?
    @State private var status = "Ready to test"

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            VStack(spacing: 8) {
                if let speed = downloadSpeed {
                    Text(String(format: "%.1f", speed))
                        .font(.system(size: 64, weight: .bold, design: .rounded))
                    Text("Mbps Download")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                } else {
                    Image(systemName: "speedometer")
                        .font(.system(size: 64))
                        .foregroundStyle(.cyan)
                }
            }

            Text(status)
                .foregroundStyle(.secondary)

            Button(isRunning ? "Testing..." : "Start Test") {
                runSpeedTest()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(isRunning)

            Spacer()

            Text("Uses Cloudflare's speed test endpoint")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .navigationTitle("Speed Test")
    }

    private func runSpeedTest() {
        isRunning = true
        downloadSpeed = nil
        status = "Connecting..."

        Task {
            // Test download speed using Cloudflare's speed test
            let testURL = URL(string: "https://speed.cloudflare.com/__down?bytes=10000000")!
            let startTime = Date()

            do {
                status = "Downloading..."
                let (data, _) = try await URLSession.shared.data(from: testURL)
                let elapsed = Date().timeIntervalSince(startTime)

                // Calculate speed in Mbps
                let bytesPerSecond = Double(data.count) / elapsed
                let mbps = (bytesPerSecond * 8) / 1_000_000

                await MainActor.run {
                    downloadSpeed = mbps
                    status = "Test complete"
                    isRunning = false
                }
            } catch {
                await MainActor.run {
                    status = "Error: \(error.localizedDescription)"
                    isRunning = false
                }
            }
        }
    }
}

// MARK: - Wake on LAN Tool

struct WakeOnLANToolView: View {
    @State private var macAddress = ""
    @State private var broadcastAddress = "255.255.255.255"
    @State private var status = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                TextField("MAC Address (e.g., AA:BB:CC:DD:EE:FF)", text: $macAddress)
                    .textFieldStyle(.roundedBorder)

                TextField("Broadcast", text: $broadcastAddress)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 150)

                Button("Wake") {
                    sendWakePacket()
                }
                .buttonStyle(.borderedProminent)
                .disabled(macAddress.isEmpty)
            }

            if !status.isEmpty {
                Text(status)
                    .foregroundStyle(status.contains("Error") ? .red : .green)
            }

            Spacer()

            Text("Sends a magic packet to wake devices on the local network")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .navigationTitle("Wake on LAN")
    }

    private func sendWakePacket() {
        guard let macBytes = parseMACAddress(macAddress) else {
            status = "Error: Invalid MAC address format"
            return
        }

        // Build magic packet: 6 bytes of 0xFF followed by MAC address repeated 16 times
        var packet = Data(repeating: 0xFF, count: 6)
        for _ in 0..<16 {
            packet.append(contentsOf: macBytes)
        }

        // Send UDP packet
        Task {
            do {
                let sock = socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP)
                guard sock >= 0 else {
                    throw NSError(domain: "WOL", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to create socket"])
                }
                defer { close(sock) }

                // Enable broadcast
                var broadcast: Int32 = 1
                setsockopt(sock, SOL_SOCKET, SO_BROADCAST, &broadcast, socklen_t(MemoryLayout<Int32>.size))

                // Set destination
                var addr = sockaddr_in()
                addr.sin_family = sa_family_t(AF_INET)
                addr.sin_port = UInt16(9).bigEndian
                inet_pton(AF_INET, broadcastAddress, &addr.sin_addr)

                // Send packet
                let sent = packet.withUnsafeBytes { ptr in
                    withUnsafePointer(to: &addr) { addrPtr in
                        addrPtr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockaddrPtr in
                            sendto(sock, ptr.baseAddress, packet.count, 0, sockaddrPtr, socklen_t(MemoryLayout<sockaddr_in>.size))
                        }
                    }
                }

                if sent > 0 {
                    status = "Magic packet sent to \(macAddress)"
                } else {
                    status = "Error: Failed to send packet"
                }
            } catch {
                status = "Error: \(error.localizedDescription)"
            }
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

// MARK: - Bonjour Browser Tool

struct DiscoveredService: Identifiable {
    let id = UUID()
    let name: String
    let type: String
    var hostName: String?
    var port: Int?
}

struct BonjourBrowserToolView: View {
    @StateObject private var browser = BonjourBrowserModel()

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Discovered Services")
                    .font(.headline)

                Spacer()

                Button(browser.isSearching ? "Stop" : "Scan") {
                    if browser.isSearching {
                        browser.stop()
                    } else {
                        browser.start()
                    }
                }
                .buttonStyle(.borderedProminent)
            }

            if browser.services.isEmpty && !browser.isSearching {
                ContentUnavailableView(
                    "No Services Found",
                    systemImage: "bonjour",
                    description: Text("Click Scan to search for Bonjour services")
                )
            } else {
                List(browser.services) { service in
                    VStack(alignment: .leading) {
                        Text(service.name)
                            .font(.headline)
                        Text(service.type)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        if let host = service.hostName {
                            HStack {
                                Text(host)
                                if let port = service.port {
                                    Text(":\(port)")
                                }
                            }
                            .font(.caption)
                            .foregroundStyle(.cyan)
                        }
                    }
                }
            }
        }
        .padding()
        .navigationTitle("Bonjour Browser")
    }
}

@MainActor
class BonjourBrowserModel: ObservableObject {
    @Published var services: [DiscoveredService] = []
    @Published var isSearching = false
    @Published var scanOutput: String = ""

    func start() {
        services = []
        isSearching = true
        scanOutput = "Scanning for services...\n"

        // Use dns-sd command to browse for services
        Task.detached {
            await self.scanUsingDnsSd()
        }
    }

    func stop() {
        isSearching = false
    }

    private nonisolated func scanUsingDnsSd() async {
        let serviceTypes = ["_http._tcp", "_ssh._tcp", "_smb._tcp", "_afpovertcp._tcp",
                            "_printer._tcp", "_ipp._tcp", "_airplay._tcp", "_raop._tcp"]

        for serviceType in serviceTypes {
            let process = Process()
            let pipe = Pipe()

            process.executableURL = URL(fileURLWithPath: "/usr/bin/dns-sd")
            process.arguments = ["-B", serviceType, "local."]
            process.standardOutput = pipe
            process.standardError = pipe

            do {
                try process.run()

                // Read for 2 seconds then terminate
                try await Task.sleep(for: .seconds(2))
                process.terminate()

                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                if let output = String(data: data, encoding: .utf8) {
                    await self.parseOutput(output, serviceType: serviceType)
                }
            } catch {
                // Ignore errors, continue with next service type
            }
        }

        await MainActor.run {
            self.isSearching = false
        }
    }

    private func parseOutput(_ output: String, serviceType: String) {
        // Parse dns-sd output format:
        // Timestamp  A/R Flags if Domain  Service Type  Instance Name
        let lines = output.split(separator: "\n")
        for line in lines {
            let parts = line.split(separator: " ", omittingEmptySubsequences: true)
            // Skip header lines and look for service entries (have "Add" in them)
            if parts.count >= 7 && parts[1] == "Add" {
                let instanceName = parts[6...].joined(separator: " ")
                if !services.contains(where: { $0.name == instanceName && $0.type == serviceType }) {
                    services.append(DiscoveredService(name: instanceName, type: serviceType))
                }
            }
        }
    }
}

#Preview {
    ToolsView()
}
