import SwiftUI
import SwiftData
import AppKit

struct DevicesView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \LocalDevice.lastSeen, order: .reverse) private var devices: [LocalDevice]

    @State private var coordinator: DeviceDiscoveryCoordinator?
    @State private var selectedDevice: LocalDevice?
    @State private var searchText: String = ""
    @State private var filterOnlineOnly: Bool = false

    // Action sheets
    @State private var showingPingSheet = false
    @State private var showingPortScanSheet = false
    @State private var showingWOLSheet = false
    @State private var actionTargetDevice: LocalDevice?

    var filteredDevices: [LocalDevice] {
        // Use extracted filter logic from LocalDevice model for testability
        LocalDevice.filter(devices, onlineOnly: filterOnlineOnly, searchText: searchText)
    }

    var body: some View {
        HStack(spacing: 0) {
            // Device list
            deviceList
                .frame(width: 350)

            Divider()

            // Detail pane
            Group {
                if let device = selectedDevice {
                    DeviceDetailView(device: device)
                } else {
                    ContentUnavailableView(
                        "Select a Device",
                        systemImage: "desktopcomputer",
                        description: Text("Choose a device from the list to view details")
                    )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .navigationTitle("Devices")
        .searchable(text: $searchText, prompt: "Search devices...")
        .toolbar {
            toolbarContent
        }
        .onAppear {
            if coordinator == nil {
                coordinator = DeviceDiscoveryCoordinator(modelContext: modelContext)
            }
        }
        .sheet(isPresented: $showingPingSheet) {
            if let device = actionTargetDevice {
                DevicePingSheet(ipAddress: device.ipAddress)
            }
        }
        .sheet(isPresented: $showingPortScanSheet) {
            if let device = actionTargetDevice {
                DevicePortScanSheet(ipAddress: device.ipAddress)
            }
        }
        .sheet(isPresented: $showingWOLSheet) {
            if let device = actionTargetDevice {
                DeviceWOLSheet(macAddress: device.macAddress, deviceName: device.displayName)
            }
        }
    }

    // MARK: - Device List

    private var deviceList: some View {
        Group {
            if devices.isEmpty && coordinator?.isScanning != true {
                ContentUnavailableView(
                    "No Devices Found",
                    systemImage: "network",
                    description: Text("Tap Scan to discover devices on your network")
                )
            } else {
                List(filteredDevices, selection: $selectedDevice) { device in
                    DeviceRowView(device: device)
                        .tag(device)
                        .contextMenu {
                            deviceContextMenu(for: device)
                        }
                }
                .listStyle(.inset)
            }
        }
        .frame(minWidth: 300)
        .overlay {
            if coordinator?.isScanning == true {
                scanningOverlay
            }
        }
    }

    // MARK: - Scanning Overlay

    private var scanningOverlay: some View {
        VStack(spacing: 16) {
            ProgressView(value: coordinator?.scanProgress ?? 0)
                .progressViewStyle(.linear)
                .frame(width: 200)

            Text("Scanning network...")
                .font(.headline)

            Text("\(Int((coordinator?.scanProgress ?? 0) * 100))% complete")
                .font(.caption)
                .foregroundStyle(.secondary)

            Button("Stop") {
                coordinator?.stopScan()
            }
            .buttonStyle(.bordered)
        }
        .padding(24)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            Button {
                coordinator?.startScan()
            } label: {
                Label("Scan", systemImage: "antenna.radiowaves.left.and.right")
            }
            .disabled(coordinator?.isScanning == true)
        }

        ToolbarItem(placement: .automatic) {
            Toggle(isOn: $filterOnlineOnly) {
                Label("Online Only", systemImage: "circle.fill")
            }
            .toggleStyle(.button)
        }

        ToolbarItem(placement: .status) {
            HStack(spacing: 4) {
                Text("\(filteredDevices.count)")
                    .fontWeight(.semibold)
                Text("devices")
                    .foregroundStyle(.secondary)

                if let lastScan = coordinator?.lastScanTime {
                    Text("- Last scan: \(lastScan, style: .relative)")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
            .font(.caption)
        }
    }

    // MARK: - Context Menu

    @ViewBuilder
    private func deviceContextMenu(for device: LocalDevice) -> some View {
        Button {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(device.ipAddress, forType: .string)
        } label: {
            Label("Copy IP Address", systemImage: "doc.on.doc")
        }

        if !device.macAddress.isEmpty {
            Button {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(device.macAddress, forType: .string)
            } label: {
                Label("Copy MAC Address", systemImage: "doc.on.doc")
            }
        }

        Divider()

        Button {
            actionTargetDevice = device
            showingPingSheet = true
        } label: {
            Label("Ping Device", systemImage: "waveform.path")
        }

        Button {
            actionTargetDevice = device
            showingPortScanSheet = true
        } label: {
            Label("Scan Ports", systemImage: "network")
        }

        if !device.macAddress.isEmpty {
            Button {
                actionTargetDevice = device
                showingWOLSheet = true
            } label: {
                Label("Wake on LAN", systemImage: "power")
            }
        }

        Divider()

        Button(role: .destructive) {
            modelContext.delete(device)
        } label: {
            Label("Remove Device", systemImage: "trash")
        }
    }
}

// MARK: - Device Ping Sheet

struct DevicePingSheet: View {
    let ipAddress: String
    @Environment(\.dismiss) private var dismiss

    @State private var isRunning = false
    @State private var results: [DevicePingResult] = []

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Ping \(ipAddress)")
                    .font(.headline)
                Spacer()
                Button("Done") { dismiss() }
                    .keyboardShortcut(.cancelAction)
            }

            Divider()

            // Results area - always show placeholder when empty
            ScrollView {
                VStack(alignment: .leading, spacing: 4) {
                    if results.isEmpty && !isRunning {
                        Text("Click 'Start Ping' to begin")
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.vertical, 40)
                    } else {
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
                        if isRunning {
                            ProgressView()
                                .padding(.top, 8)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 4)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(nsColor: .textBackgroundColor).opacity(0.5))
            .clipShape(RoundedRectangle(cornerRadius: 8))

            Divider()

            HStack {
                Spacer()
                Button(isRunning ? "Stop" : "Start Ping") {
                    if isRunning {
                        isRunning = false
                    } else {
                        runPing()
                    }
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(20)
        .frame(minWidth: 400, minHeight: 350)
    }

    private func runPing() {
        results = []
        isRunning = true

        // Views are @MainActor - no need for MainActor.run
        Task {
            for seq in 1...10 {
                guard isRunning else { break }

                let result = await executePing(sequence: seq)
                results.append(result)

                if seq < 10 && isRunning {
                    try? await Task.sleep(for: .seconds(1))
                }
            }
            isRunning = false
        }
    }

    private func executePing(sequence: Int) async -> DevicePingResult {
        let process = Process()
        let pipe = Pipe()

        process.executableURL = URL(fileURLWithPath: "/sbin/ping")
        process.arguments = ["-c", "1", "-W", "3000", ipAddress]
        process.standardOutput = pipe
        process.standardError = pipe

        do {
            try process.run()
            process.waitUntilExit()

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""

            if process.terminationStatus == 0,
               let latency = parseLatency(from: output) {
                return DevicePingResult(sequence: sequence, latency: latency, error: nil)
            } else {
                return DevicePingResult(sequence: sequence, latency: nil, error: "Host unreachable")
            }
        } catch {
            return DevicePingResult(sequence: sequence, latency: nil, error: error.localizedDescription)
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

struct DevicePingResult: Identifiable {
    let id = UUID()
    let sequence: Int
    let latency: Double?
    let error: String?
}

// MARK: - Device Port Scan Sheet

struct DevicePortScanSheet: View {
    let ipAddress: String
    @Environment(\.dismiss) private var dismiss

    @State private var portRange = "1-1024"
    @State private var isRunning = false
    @State private var openPorts: [Int] = []
    @State private var progress = 0.0
    @State private var currentPort = 0

    private let commonPorts: [Int: String] = [
        21: "FTP", 22: "SSH", 23: "Telnet", 25: "SMTP", 53: "DNS",
        80: "HTTP", 110: "POP3", 143: "IMAP", 443: "HTTPS", 993: "IMAPS",
        995: "POP3S", 3306: "MySQL", 5432: "PostgreSQL", 6379: "Redis",
        8080: "HTTP-Alt", 27017: "MongoDB"
    ]

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Port Scan: \(ipAddress)")
                    .font(.headline)
                Spacer()
                Button("Done") { dismiss() }
            }

            HStack {
                TextField("Port range", text: $portRange)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 120)

                Button(isRunning ? "Stop" : "Scan") {
                    if isRunning {
                        isRunning = false
                    } else {
                        runScan()
                    }
                }
                .buttonStyle(.borderedProminent)
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
                    .frame(maxWidth: .infinity, alignment: .leading)

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
        .padding(20)
        .frame(minWidth: 450, minHeight: 400)
    }

    private func runScan() {
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

        // Views are @MainActor - no need for MainActor.run
        Task {
            let total = end - start + 1
            var scanned = 0

            for port in start...end {
                guard isRunning else { break }

                currentPort = port

                if await isPortOpen(port: port) {
                    openPorts.append(port)
                }

                scanned += 1
                progress = Double(scanned) / Double(total)
            }

            isRunning = false
        }
    }

    private func isPortOpen(port: Int) async -> Bool {
        await withCheckedContinuation { continuation in
            var hints = addrinfo()
            hints.ai_family = AF_INET
            hints.ai_socktype = SOCK_STREAM

            var result: UnsafeMutablePointer<addrinfo>?
            guard getaddrinfo(ipAddress, String(port), &hints, &result) == 0,
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

            let flags = fcntl(sock, F_GETFL, 0)
            _ = fcntl(sock, F_SETFL, flags | O_NONBLOCK)

            let connectResult = connect(sock, info.pointee.ai_addr, info.pointee.ai_addrlen)
            if connectResult == 0 {
                continuation.resume(returning: true)
                return
            }

            if errno == EINPROGRESS {
                var pfd = pollfd(fd: sock, events: Int16(POLLOUT), revents: 0)
                let pollResult = poll(&pfd, 1, 100)

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

// MARK: - Device WOL Sheet

struct DeviceWOLSheet: View {
    let macAddress: String
    let deviceName: String
    @Environment(\.dismiss) private var dismiss

    @State private var status = ""
    @State private var broadcastAddress = "255.255.255.255"

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Wake on LAN")
                    .font(.headline)
                Spacer()
                Button("Done") { dismiss() }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Device: \(deviceName)")
                Text("MAC: \(macAddress)")
                    .font(.system(.body, design: .monospaced))
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            HStack {
                Text("Broadcast:")
                TextField("Address", text: $broadcastAddress)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 150)
            }

            Button("Send Wake Packet") {
                sendWakePacket()
            }
            .buttonStyle(.borderedProminent)

            if !status.isEmpty {
                Text(status)
                    .foregroundStyle(status.contains("Error") ? .red : .green)
            }

            Spacer()
        }
        .padding(20)
        .frame(minWidth: 380, minHeight: 280)
    }

    private func sendWakePacket() {
        guard let macBytes = parseMACAddress(macAddress) else {
            status = "Error: Invalid MAC address"
            return
        }

        var packet = Data(repeating: 0xFF, count: 6)
        for _ in 0..<16 {
            packet.append(contentsOf: macBytes)
        }

        let sock = socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP)
        guard sock >= 0 else {
            status = "Error: Failed to create socket"
            return
        }
        defer { close(sock) }

        var broadcast: Int32 = 1
        setsockopt(sock, SOL_SOCKET, SO_BROADCAST, &broadcast, socklen_t(MemoryLayout<Int32>.size))

        var addr = sockaddr_in()
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_port = UInt16(9).bigEndian
        inet_pton(AF_INET, broadcastAddress, &addr.sin_addr)

        let sent = packet.withUnsafeBytes { ptr in
            withUnsafePointer(to: &addr) { addrPtr in
                addrPtr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockaddrPtr in
                    sendto(sock, ptr.baseAddress, packet.count, 0, sockaddrPtr, socklen_t(MemoryLayout<sockaddr_in>.size))
                }
            }
        }

        if sent > 0 {
            status = "Magic packet sent!"
        } else {
            status = "Error: Failed to send packet"
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

#Preview {
    DevicesView()
        .modelContainer(PreviewContainer().container)
}
