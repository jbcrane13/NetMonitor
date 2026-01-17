import SwiftUI
import Network

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
    @State private var sharedHost: String = ""

    private let columns = [
        GridItem(.adaptive(minimum: 150, maximum: 200), spacing: 16)
    ]

    var body: some View {
        HStack(spacing: 0) {
            // Tool grid sidebar
            ScrollView {
                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(NetworkTool.allCases) { tool in
                        Button {
                            selectedTool = tool
                        } label: {
                            ToolCard(tool: tool, isSelected: selectedTool == tool)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding()
            }
            .frame(width: 220)
            .background(Color(nsColor: .windowBackgroundColor))

            Divider()

            // Tool detail view
            Group {
                if let tool = selectedTool {
                    ToolDetailView(tool: tool, sharedHost: $sharedHost)
                } else {
                    ContentUnavailableView(
                        "Select a Tool",
                        systemImage: "wrench.and.screwdriver",
                        description: Text("Choose a network tool from the sidebar")
                    )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .navigationTitle("Tools")
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
        .contentShape(Rectangle())
    }
}

// MARK: - Tool Detail View

struct ToolDetailView: View {
    let tool: NetworkTool
    @Binding var sharedHost: String

    var body: some View {
        switch tool {
        case .ping:
            PingToolView(sharedHost: $sharedHost)
        case .traceroute:
            TracerouteToolView(sharedHost: $sharedHost)
        case .portScanner:
            PortScannerToolView(sharedHost: $sharedHost)
        case .dnsLookup:
            DNSLookupToolView(sharedHost: $sharedHost)
        case .whois:
            WHOISToolView(sharedHost: $sharedHost)
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
    @Binding var sharedHost: String
    @State private var count = 5
    @State private var isRunning = false
    @State private var results: [PingResult] = []

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Input section
            HStack {
                TextField("Host or IP address", text: $sharedHost)
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
                .disabled(sharedHost.isEmpty)
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
        guard !sharedHost.isEmpty else { return }
        let targetHost = sharedHost
        results = []
        isRunning = true

        // Views are @MainActor - no need for MainActor.run
        Task {
            for seq in 1...count {
                guard isRunning else { break }

                let result = await executePing(host: targetHost, sequence: seq)
                results.append(result)

                if seq < count && isRunning {
                    try? await Task.sleep(for: .seconds(1))
                }
            }
            isRunning = false
        }
    }

    private func executePing(host: String, sequence: Int) async -> PingResult {
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
    @Binding var sharedHost: String
    @State private var isRunning = false
    @State private var output = ""
    @State private var currentProcess: Process?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                TextField("Host or IP address", text: $sharedHost)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit {
                        if !sharedHost.isEmpty && !isRunning {
                            runTraceroute()
                        }
                    }
                    .accessibilityIdentifier("traceroute_textfield_host")

                Button(isRunning ? "Stop" : "Trace") {
                    if isRunning {
                        stopTraceroute()
                    } else {
                        runTraceroute()
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(sharedHost.isEmpty && !isRunning)
                .accessibilityIdentifier("traceroute_button_trace")
            }

            ScrollView {
                if output.isEmpty {
                    Text("Enter a host and press Trace to begin")
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding()
                } else {
                    Text(output)
                        .font(.system(.body, design: .monospaced))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                }
            }
            .frame(minHeight: 200)
            .background(Color.black.opacity(0.2))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .padding()
        .navigationTitle("Traceroute")
    }

    private func stopTraceroute() {
        currentProcess?.terminate()
        currentProcess = nil
        isRunning = false
        output += "\n--- Traceroute stopped ---\n"
    }

    private func runTraceroute() {
        guard !sharedHost.isEmpty else { return }
        let targetHost = sharedHost
        output = "Tracing route to \(targetHost)...\n\n"
        isRunning = true

        // Run traceroute in a background task
        Task.detached { [self] in
            let process = Process()
            let pipe = Pipe()

            process.executableURL = URL(fileURLWithPath: "/usr/sbin/traceroute")
            process.arguments = ["-m", "30", "-w", "3", targetHost]
            process.standardOutput = pipe
            process.standardError = pipe

            await MainActor.run {
                self.currentProcess = process
            }

            do {
                try process.run()

                // Read output in chunks while process is running
                let fileHandle = pipe.fileHandleForReading

                while process.isRunning {
                    let data = fileHandle.availableData
                    if !data.isEmpty, let str = String(data: data, encoding: .utf8) {
                        await MainActor.run {
                            self.output += str
                        }
                    }
                    try? await Task.sleep(for: .milliseconds(100))
                }

                // Read any remaining output
                let remainingData = fileHandle.readDataToEndOfFile()
                if !remainingData.isEmpty, let str = String(data: remainingData, encoding: .utf8) {
                    await MainActor.run {
                        self.output += str
                    }
                }

                await MainActor.run {
                    self.currentProcess = nil
                    self.isRunning = false
                    if !self.output.contains("stopped") {
                        self.output += "\n--- Traceroute complete ---\n"
                    }
                }
            } catch {
                await MainActor.run {
                    self.output += "Error: \(error.localizedDescription)\n"
                    self.isRunning = false
                    self.currentProcess = nil
                }
            }
        }
    }
}

// MARK: - Port Scanner Tool

struct PortScannerToolView: View {
    @Binding var sharedHost: String
    @State private var portRange = "1-1024"
    @State private var isRunning = false
    @State private var openPorts: [Int] = []
    @State private var progress = 0.0
    @State private var currentPort = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                TextField("Host or IP address", text: $sharedHost)
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
                .disabled(sharedHost.isEmpty)
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
        guard !sharedHost.isEmpty else { return }
        let targetHost = sharedHost
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
            let ports = Array(start...end)

            // Scan in batches of 50 for parallelism and UI responsiveness
            let batchSize = 50
            var scanned = 0

            for batchStart in stride(from: 0, to: ports.count, by: batchSize) {
                guard isRunning else { break }

                let batchEnd = min(batchStart + batchSize, ports.count)
                let batch = Array(ports[batchStart..<batchEnd])

                currentPort = batch.first ?? 0

                // Scan batch in parallel
                await withTaskGroup(of: (Int, Bool).self) { group in
                    for port in batch {
                        group.addTask {
                            let isOpen = await self.isPortOpen(host: targetHost, port: port)
                            return (port, isOpen)
                        }
                    }

                    for await (port, isOpen) in group {
                        if isOpen {
                            openPorts.append(port)
                        }
                        scanned += 1
                        progress = Double(scanned) / Double(total)
                    }
                }

                // Yield to allow UI updates
                await Task.yield()
            }

            openPorts.sort()
            isRunning = false
        }
    }

    private func isPortOpen(host: String, port: Int) async -> Bool {
        await withCheckedContinuation { continuation in
            let endpoint = NWEndpoint.hostPort(
                host: NWEndpoint.Host(host),
                port: NWEndpoint.Port(integerLiteral: UInt16(port))
            )

            let connection = NWConnection(to: endpoint, using: .tcp)
            let resumed = PortScanResumeFlag()

            connection.stateUpdateHandler = { [resumed] state in
                guard resumed.tryResume() else { return }

                switch state {
                case .ready:
                    connection.cancel()
                    continuation.resume(returning: true)
                case .failed, .cancelled:
                    continuation.resume(returning: false)
                case .waiting:
                    connection.cancel()
                    continuation.resume(returning: false)
                default:
                    resumed.reset()
                }
            }

            connection.start(queue: .global(qos: .userInitiated))

            // Timeout after 500ms
            DispatchQueue.global().asyncAfter(deadline: .now() + 0.5) { [resumed] in
                guard resumed.tryResume() else { return }
                connection.cancel()
                continuation.resume(returning: false)
            }
        }
    }
}

/// Thread-safe flag for port scan continuation
private final class PortScanResumeFlag: @unchecked Sendable {
    private var _resumed = false
    private let lock = NSLock()

    func tryResume() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        if _resumed { return false }
        _resumed = true
        return true
    }

    func reset() {
        lock.lock()
        defer { lock.unlock() }
        _resumed = false
    }
}

// MARK: - DNS Lookup Tool

struct DNSLookupToolView: View {
    @Binding var sharedHost: String
    @State private var recordType = "A"
    @State private var isRunning = false
    @State private var results: [String] = []

    private let recordTypes = ["A", "AAAA", "MX", "TXT", "CNAME", "NS", "SOA"]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                TextField("Domain or host", text: $sharedHost)
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
                .disabled(sharedHost.isEmpty || isRunning)
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
        guard !sharedHost.isEmpty else { return }
        let targetDomain = sharedHost
        let targetRecordType = recordType
        results = []
        isRunning = true

        // Use regular Task - views are already @MainActor
        Task {
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

                results = output.split(separator: "\n").map(String.init)
                if results.isEmpty {
                    results = ["No records found"]
                }
                isRunning = false
            } catch {
                results = ["Error: \(error.localizedDescription)"]
                isRunning = false
            }
        }
    }
}

// MARK: - WHOIS Tool

struct WHOISToolView: View {
    @Binding var sharedHost: String
    @State private var isRunning = false
    @State private var output = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                TextField("Domain or host", text: $sharedHost)
                    .textFieldStyle(.roundedBorder)

                Button("Lookup") {
                    runWhois()
                }
                .buttonStyle(.borderedProminent)
                .disabled(sharedHost.isEmpty || isRunning)
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
        guard !sharedHost.isEmpty else { return }
        let targetDomain = sharedHost
        output = "Looking up \(targetDomain)...\n"
        isRunning = true

        // Use regular Task - views are already @MainActor
        Task {
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

                output = result
                isRunning = false
            } catch {
                output = "Error: \(error.localizedDescription)"
                isRunning = false
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
        status = "Sending..."
        Task {
            do {
                let service = WakeOnLanService()
                try await service.wake(macAddress: macAddress, targetHost: broadcastAddress)
                status = "Magic packet sent to \(macAddress)"
            } catch {
                status = "Error: \(error.localizedDescription)"
            }
        }
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
    @State private var browser = BonjourBrowserModel()

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
@Observable
final class BonjourBrowserModel {
    var services: [DiscoveredService] = []
    var isSearching = false
    var scanOutput: String = ""

    func start() {
        services = []
        isSearching = true
        scanOutput = "Scanning for services...\n"

        // Use regular Task - class is @MainActor
        Task {
            await scanUsingDnsSd()
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
                    // Capture values before MainActor call
                    let capturedOutput = output
                    let capturedServiceType = serviceType

                    await MainActor.run { [weak self] in
                        self?.parseOutput(capturedOutput, serviceType: capturedServiceType)
                    }
                }
            } catch {
                // Ignore errors, continue with next service type
            }
        }

        await MainActor.run { [weak self] in
            self?.isSearching = false
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
