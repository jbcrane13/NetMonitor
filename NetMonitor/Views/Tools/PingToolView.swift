//
//  PingToolView.swift
//  NetMonitor
//
//  Ping tool for testing host reachability with streaming output.
//

import SwiftUI

struct PingToolView: View {
    @State private var host = ""
    @State private var count = 5
    @State private var isRunning = false
    @State private var output: [String] = []
    @State private var summary: PingResult?
    @State private var errorMessage: String?
    @State private var pingTask: Task<Void, Never>?
    @State private var pingService = ProcessPingService()

    var body: some View {
        ToolSheetContainer(
            title: "Ping",
            iconName: "waveform.path",
            closeAccessibilityID: "ping_button_close",
            inputArea: { inputArea },
            outputArea: { outputArea },
            footerContent: { footer }
        )
        .onDisappear {
            pingTask?.cancel()
            pingTask = nil
        }
    }

    // MARK: - Input Area

    private var inputArea: some View {
        HStack(spacing: 12) {
            TextField("Hostname or IP address", text: $host)
                .textFieldStyle(.roundedBorder)
                .onSubmit { runPing() }
                .disabled(isRunning)
                .accessibilityIdentifier("ping_textfield_host")

            Picker("Count", selection: $count) {
                Text("1").tag(1)
                Text("5").tag(5)
                Text("10").tag(10)
                Text("20").tag(20)
            }
            .frame(width: 80)
            .disabled(isRunning)
            .accessibilityIdentifier("ping_picker_count")

            Button(isRunning ? "Stop" : "Run") {
                if isRunning {
                    stopPing()
                } else {
                    runPing()
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(host.isEmpty && !isRunning)
            .accessibilityIdentifier("ping_button_run")
        }
        .padding()
    }

    // MARK: - Output Area

    private var outputArea: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 2) {
                    ForEach(Array(output.enumerated()), id: \.offset) { index, line in
                        Text(line)
                            .font(.system(.body, design: .monospaced))
                            .textSelection(.enabled)
                            .id(index)
                    }

                    if let error = errorMessage {
                        Text(error)
                            .font(.system(.body, design: .monospaced))
                            .foregroundStyle(.red)
                    }

                    if let result = summary {
                        summaryView(result)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
            }
            .background(Color.black.opacity(0.2))
            .onChange(of: output.count) { _, _ in
                if let lastIndex = output.indices.last {
                    proxy.scrollTo(lastIndex, anchor: .bottom)
                }
            }
        }
    }

    private func summaryView(_ result: PingResult) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Divider()
                .padding(.vertical, 8)

            Text("--- Summary ---")
                .font(.system(.body, design: .monospaced))
                .fontWeight(.bold)

            Text("\(result.transmitted) packets transmitted, \(result.received) received, \(String(format: "%.1f", result.packetLoss))% packet loss")
                .font(.system(.body, design: .monospaced))

            if result.received > 0 {
                Text("round-trip min/avg/max = \(String(format: "%.2f", result.minLatency))/\(String(format: "%.2f", result.avgLatency))/\(String(format: "%.2f", result.maxLatency)) ms")
                    .font(.system(.body, design: .monospaced))
            }
        }
    }

    // MARK: - Footer

    private var footer: some View {
        HStack {
            if isRunning {
                ProgressView()
                    .scaleEffect(0.7)
                Text("Pinging \(host)...")
                    .foregroundStyle(.secondary)
            } else if let summary = summary {
                Image(systemName: summary.isReachable ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundStyle(summary.isReachable ? .green : .red)
                Text(summary.isReachable ? "Host is reachable" : "Host unreachable")
                    .foregroundStyle(.secondary)
            } else {
                Text("Enter a hostname or IP address")
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if !output.isEmpty && !isRunning {
                Button("Clear") {
                    output.removeAll()
                    summary = nil
                    errorMessage = nil
                }
                .accessibilityIdentifier("ping_button_clear")
            }
        }
        .padding()
    }

    // MARK: - Actions

    private func runPing() {
        guard !host.isEmpty else { return }

        isRunning = true
        output.removeAll()
        summary = nil
        errorMessage = nil

        output.append("PING \(host) (\(count) packets)...")

        pingTask = Task {
            do {
                var latencies: [Double] = []
                var received = 0

                for try await line in await pingService.pingStream(host: host, count: count) {
                    await MainActor.run {
                        if let latency = line.latency {
                            output.append("\(line.bytes) bytes from \(line.host): icmp_seq=\(line.sequenceNumber) ttl=\(line.ttl ?? 0) time=\(String(format: "%.2f", latency)) ms")
                            latencies.append(latency)
                            received += 1
                        } else {
                            output.append("Request timeout for icmp_seq \(line.sequenceNumber)")
                        }
                    }
                }

                await MainActor.run {
                    // Calculate summary from actual stream data
                    let packetLoss = Double(count - received) / Double(count) * 100
                    let minLatency = latencies.min() ?? 0.0
                    let maxLatency = latencies.max() ?? 0.0
                    let avgLatency = latencies.isEmpty ? 0.0 : latencies.reduce(0, +) / Double(latencies.count)
                    let stddevLatency = latencies.isEmpty ? 0.0 : calculateStddev(latencies, mean: avgLatency)
                    
                    summary = PingResult(
                        transmitted: count,
                        received: received,
                        packetLoss: packetLoss,
                        minLatency: minLatency,
                        avgLatency: avgLatency,
                        maxLatency: maxLatency,
                        stddevLatency: stddevLatency
                    )
                    isRunning = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isRunning = false
                }
            }
        }
    }
    
    private func calculateStddev(_ values: [Double], mean: Double) -> Double {
        guard values.count > 1 else { return 0.0 }
        let variance = values.reduce(0) { sum, value in
            sum + pow(value - mean, 2)
        } / Double(values.count - 1)
        return sqrt(variance)
    }

    private func stopPing() {
        Task {
            await pingService.cancel()
            await MainActor.run {
                isRunning = false
                output.append("--- Ping cancelled ---")
            }
        }
    }
}

#Preview {
    PingToolView()
}
