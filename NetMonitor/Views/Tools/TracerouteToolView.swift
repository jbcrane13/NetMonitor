//
//  TracerouteToolView.swift
//  NetMonitor
//
//  Traceroute tool using /usr/sbin/traceroute.
//

import SwiftUI

struct TracerouteToolView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var host = ""
    @State private var maxHops = 30
    @State private var isRunning = false
    @State private var hops: [TracerouteHop] = []
    @State private var errorMessage: String?

    private let runner = ShellCommandRunner()

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            inputArea
            Divider()
            outputArea
            Divider()
            footer
        }
        .frame(minWidth: 500, minHeight: 400)
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Label("Traceroute", systemImage: "point.topleft.down.to.point.bottomright.curvepath")
                .font(.headline)

            Spacer()

            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("traceroute_button_close")
        }
        .padding()
    }

    // MARK: - Input Area

    private var inputArea: some View {
        HStack(spacing: 12) {
            TextField("Hostname or IP address", text: $host)
                .textFieldStyle(.roundedBorder)
                .onSubmit { runTraceroute() }
                .disabled(isRunning)
                .accessibilityIdentifier("traceroute_textfield_host")

            Picker("Max Hops", selection: $maxHops) {
                Text("15").tag(15)
                Text("30").tag(30)
                Text("64").tag(64)
            }
            .frame(width: 100)
            .disabled(isRunning)
            .accessibilityIdentifier("traceroute_picker_hops")

            Button(isRunning ? "Stop" : "Trace") {
                if isRunning {
                    stopTraceroute()
                } else {
                    runTraceroute()
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(host.isEmpty && !isRunning)
            .accessibilityIdentifier("traceroute_button_run")
        }
        .padding()
    }

    // MARK: - Output Area

    private var outputArea: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 4) {
                    if hops.isEmpty && errorMessage == nil && !isRunning {
                        Text("Enter a hostname to trace the network path")
                            .foregroundStyle(.tertiary)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.top, 40)
                    } else {
                        ForEach(hops) { hop in
                            hopRow(hop)
                                .id(hop.id)
                        }

                        if let error = errorMessage {
                            Text(error)
                                .font(.system(.body, design: .monospaced))
                                .foregroundStyle(.red)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
            }
            .background(Color.black.opacity(0.2))
            .onChange(of: hops.count) { _, _ in
                if let lastHop = hops.last {
                    proxy.scrollTo(lastHop.id, anchor: .bottom)
                }
            }
        }
    }

    private func hopRow(_ hop: TracerouteHop) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text(String(format: "%2d", hop.hopNumber))
                .font(.system(.body, design: .monospaced))
                .foregroundStyle(.secondary)
                .frame(width: 25, alignment: .trailing)

            if hop.isTimeout {
                Text("* * *")
                    .font(.system(.body, design: .monospaced))
                    .foregroundStyle(.orange)
            } else {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 8) {
                        Text(hop.hostname ?? hop.ipAddress ?? "unknown")
                            .font(.system(.body, design: .monospaced))

                        if let ip = hop.ipAddress, hop.hostname != nil {
                            Text("(\(ip))")
                                .font(.system(.caption, design: .monospaced))
                                .foregroundStyle(.secondary)
                        }
                    }

                    if !hop.latencies.isEmpty {
                        Text(hop.latencies.map { String(format: "%.2f ms", $0) }.joined(separator: "  "))
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(.cyan)
                    }
                }
            }
        }
        .padding(.vertical, 2)
    }

    // MARK: - Footer

    private var footer: some View {
        HStack {
            if isRunning {
                ProgressView()
                    .scaleEffect(0.7)
                Text("Tracing route to \(host)...")
                    .foregroundStyle(.secondary)
            } else if !hops.isEmpty {
                let successfulHops = hops.filter { !$0.isTimeout }.count
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                Text("\(successfulHops)/\(hops.count) hops completed")
                    .foregroundStyle(.secondary)
            } else if errorMessage != nil {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                Text("Trace failed")
                    .foregroundStyle(.secondary)
            } else {
                Text("Trace the path to any host")
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if !hops.isEmpty && !isRunning {
                Button("Clear") {
                    hops.removeAll()
                    errorMessage = nil
                }
                .accessibilityIdentifier("traceroute_button_clear")
            }
        }
        .padding()
    }

    // MARK: - Actions

    private func runTraceroute() {
        guard !host.isEmpty else { return }

        isRunning = true
        hops.removeAll()
        errorMessage = nil

        Task {
            // Try standard traceroute first, fall back to ping-based if it fails
            let success = await tryStandardTraceroute()
            if !success {
                await runPingBasedTraceroute()
            }

            await MainActor.run {
                isRunning = false
            }
        }
    }

    private func tryStandardTraceroute() async -> Bool {
        do {
            for try await line in await runner.stream(
                "/usr/sbin/traceroute",
                arguments: ["-m", String(maxHops), host]
            ) {
                if let hop = parseTracerouteLine(line) {
                    await MainActor.run {
                        hops.append(hop)
                    }
                }
            }
            return true
        } catch {
            // Check if it's a permission error - if so, fall back to ping-based
            let message = error.localizedDescription
            if message.contains("not permitted") || message.contains("Operation not permitted") {
                return false
            }

            // For other errors, if we got some results, consider it a success
            if !hops.isEmpty {
                return true
            }

            // Otherwise, show the error and don't fall back
            await MainActor.run {
                errorMessage = message
            }
            return true // Don't fall back for non-permission errors
        }
    }

    private func runPingBasedTraceroute() async {
        await MainActor.run {
            hops.removeAll()
        }

        let target = host.trimmingCharacters(in: .whitespacesAndNewlines)
        var destinationReached = false

        for ttl in 1...maxHops {
            guard isRunning else { break }
            guard !destinationReached else { break }

            do {
                // Use ping with specific TTL: -c 1 (one packet), -t TTL, -W 2000 (2 sec timeout)
                let result = try await runner.run(
                    "/sbin/ping",
                    arguments: ["-c", "1", "-t", "\(ttl)", "-W", "2000", target],
                    timeout: 5
                )

                let output = result.stdout + result.stderr
                var hop = TracerouteHop(hopNumber: ttl, isTimeout: true)

                // Parse response - check for "Time to live exceeded" (intermediate hop) or normal response (destination)
                if output.contains("Time to live exceeded") || output.contains("from") {
                    // Extract source IP from "Time to live exceeded from X" or "bytes from X"
                    if let fromRange = output.range(of: "from ") {
                        let afterFrom = String(output[fromRange.upperBound...])

                        // Extract hostname/IP part before colon
                        if let colonRange = afterFrom.range(of: ":") {
                            let hostPart = String(afterFrom[..<colonRange.lowerBound]).trimmingCharacters(in: .whitespaces)

                            // Check for format "hostname (ip)" or just "ip"
                            if let parenStart = hostPart.range(of: "("),
                               let parenEnd = hostPart.range(of: ")") {
                                hop.hostname = String(hostPart[..<parenStart.lowerBound]).trimmingCharacters(in: .whitespaces)
                                hop.ipAddress = String(hostPart[parenStart.upperBound..<parenEnd.lowerBound])
                            } else {
                                hop.ipAddress = hostPart
                                hop.hostname = hostPart
                            }
                            hop.isTimeout = false
                        }
                    }

                    // Extract latency from "time=X.XX ms" if present
                    if let timeRange = output.range(of: "time=") {
                        let afterTime = String(output[timeRange.upperBound...])
                        if let msRange = afterTime.range(of: " ms") {
                            let latencyStr = String(afterTime[..<msRange.lowerBound])
                            if let latency = Double(latencyStr) {
                                hop.latencies = [latency]
                            }
                        }
                    }
                }

                await MainActor.run {
                    hops.append(hop)
                }

                // Check if we reached the destination (exit code 0 and received response)
                if result.exitCode == 0 && output.contains("1 packets received") {
                    destinationReached = true
                }

            } catch {
                // Timeout or error for this hop
                await MainActor.run {
                    hops.append(TracerouteHop(hopNumber: ttl, isTimeout: true))
                }
            }
        }
    }

    private func stopTraceroute() {
        Task {
            await runner.cancel()
            await MainActor.run {
                isRunning = false
            }
        }
    }

    // MARK: - Parsing

    private func parseTracerouteLine(_ line: String) -> TracerouteHop? {
        // Skip header line
        if line.hasPrefix("traceroute to") { return nil }

        // Pattern: " 1  router.local (192.168.1.1)  1.234 ms  1.456 ms  1.789 ms"
        // Or timeout: " 2  * * *"
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return nil }

        // Extract hop number
        let components = trimmed.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
        guard let hopNumber = Int(components.first ?? "") else { return nil }

        // Check for timeout
        if components.contains("*") && components.filter({ $0 == "*" }).count >= 3 {
            return TracerouteHop(hopNumber: hopNumber, isTimeout: true)
        }

        // Parse hostname, IP, and latencies
        var hostname: String?
        var ipAddress: String?
        var latencies: [Double] = []

        for (index, component) in components.enumerated() {
            if index == 0 { continue } // Skip hop number

            if component.hasPrefix("(") && component.hasSuffix(")") {
                // IP address in parentheses
                ipAddress = String(component.dropFirst().dropLast())
            } else if component == "ms" {
                // Previous component was a latency
                if index > 1, let latency = Double(components[index - 1]) {
                    latencies.append(latency)
                }
            } else if hostname == nil && Double(component) == nil && component != "*" && !component.hasPrefix("(") {
                // First non-numeric component is hostname - look for domain names or host identifiers
                if component.contains(".") || component.contains("-") || component.count > 3 {
                    hostname = component
                }
            }
        }

        // If no hostname but we have IP, use IP as hostname
        if hostname == nil && ipAddress != nil {
            hostname = ipAddress
            ipAddress = nil
        }

        return TracerouteHop(
            hopNumber: hopNumber,
            hostname: hostname,
            ipAddress: ipAddress,
            latencies: latencies,
            isTimeout: false
        )
    }
}

// MARK: - Models

struct TracerouteHop: Identifiable {
    let id = UUID()
    let hopNumber: Int
    var hostname: String?
    var ipAddress: String?
    var latencies: [Double] = []
    var isTimeout: Bool
}

#Preview {
    TracerouteToolView()
}
