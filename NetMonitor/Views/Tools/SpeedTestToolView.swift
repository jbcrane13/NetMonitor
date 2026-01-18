//
//  SpeedTestToolView.swift
//  NetMonitor
//
//  Speed test tool that measures download speed using public test files.
//

import SwiftUI

struct SpeedTestToolView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var isRunning = false
    @State private var phase: SpeedTestPhase = .idle
    @State private var pingLatency: Double?
    @State private var downloadSpeed: Double?
    @State private var progress: Double = 0
    @State private var errorMessage: String?

    private let testFileURL = URL(string: "https://speed.cloudflare.com/__down?bytes=25000000")! // 25MB test file

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            contentArea
            Divider()
            footer
        }
        .frame(minWidth: 600, minHeight: 500)
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Label("Speed Test", systemImage: "speedometer")
                .font(.headline)

            Spacer()

            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("speedtest_button_close")
        }
        .padding()
    }

    // MARK: - Content Area

    private var contentArea: some View {
        VStack(spacing: 32) {
            Spacer()

            // Speedometer display
            speedometerView

            // Results
            resultsView

            Spacer()

            // Start button
            if !isRunning {
                Button {
                    runSpeedTest()
                } label: {
                    Label("Start Test", systemImage: "play.fill")
                        .font(.headline)
                        .frame(width: 200)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .accessibilityIdentifier("speedtest_button_start")
            } else {
                Button {
                    stopSpeedTest()
                } label: {
                    Label("Stop", systemImage: "stop.fill")
                        .font(.headline)
                        .frame(width: 200)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .accessibilityIdentifier("speedtest_button_stop")
            }

            Spacer()
        }
        .padding()
        .background(Color.black.opacity(0.2))
    }

    private var speedometerView: some View {
        ZStack {
            // Background arc
            Circle()
                .trim(from: 0.15, to: 0.85)
                .stroke(Color.gray.opacity(0.3), lineWidth: 20)
                .rotationEffect(.degrees(90))
                .frame(width: 200, height: 200)

            // Progress arc
            Circle()
                .trim(from: 0.15, to: 0.15 + (0.7 * min(progress, 1.0)))
                .stroke(
                    LinearGradient(
                        colors: [.cyan, .green],
                        startPoint: .leading,
                        endPoint: .trailing
                    ),
                    style: StrokeStyle(lineWidth: 20, lineCap: .round)
                )
                .rotationEffect(.degrees(90))
                .frame(width: 200, height: 200)
                .animation(.easeInOut(duration: 0.3), value: progress)

            // Center display
            VStack(spacing: 4) {
                if isRunning {
                    Text(phase.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if let speed = downloadSpeed {
                    Text(formatSpeed(speed))
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                    Text("Mbps")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else if isRunning {
                    ProgressView()
                        .scaleEffect(1.5)
                } else {
                    Text("--")
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundStyle(.secondary)
                    Text("Mbps")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
        }
    }

    private var resultsView: some View {
        HStack(spacing: 48) {
            // Ping
            VStack(spacing: 4) {
                Image(systemName: "waveform.path")
                    .font(.title2)
                    .foregroundStyle(.cyan)

                if let ping = pingLatency {
                    Text(String(format: "%.0f", ping))
                        .font(.title2.bold())
                    Text("ms ping")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text("--")
                        .font(.title2.bold())
                        .foregroundStyle(.secondary)
                    Text("ms ping")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }

            // Download
            VStack(spacing: 4) {
                Image(systemName: "arrow.down.circle")
                    .font(.title2)
                    .foregroundStyle(.green)

                if let speed = downloadSpeed {
                    Text(formatSpeed(speed))
                        .font(.title2.bold())
                    Text("Mbps down")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text("--")
                        .font(.title2.bold())
                        .foregroundStyle(.secondary)
                    Text("Mbps down")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }

            // Server
            VStack(spacing: 4) {
                Image(systemName: "server.rack")
                    .font(.title2)
                    .foregroundStyle(.orange)

                Text("Cloudflare")
                    .font(.title3.bold())
                Text("Server")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Footer

    private var footer: some View {
        HStack {
            if let error = errorMessage {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                Text(error)
                    .foregroundStyle(.secondary)
            } else if isRunning {
                Text(phase.description)
                    .foregroundStyle(.secondary)
            } else if downloadSpeed != nil {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                Text("Test completed")
                    .foregroundStyle(.secondary)
            } else {
                Text("Test your internet connection speed")
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if downloadSpeed != nil && !isRunning {
                Button("Reset") {
                    resetTest()
                }
                .accessibilityIdentifier("speedtest_button_reset")
            }
        }
        .padding()
    }

    // MARK: - Actions

    private func runSpeedTest() {
        isRunning = true
        errorMessage = nil
        pingLatency = nil
        downloadSpeed = nil
        progress = 0

        Task {
            // Phase 1: Ping test
            await MainActor.run { phase = .ping }
            pingLatency = await measurePing()

            guard isRunning else { return }

            // Phase 2: Download test
            await MainActor.run { phase = .download }
            downloadSpeed = await measureDownload()

            await MainActor.run {
                phase = .complete
                isRunning = false
            }
        }
    }

    private func stopSpeedTest() {
        isRunning = false
        phase = .idle
    }

    private func resetTest() {
        pingLatency = nil
        downloadSpeed = nil
        progress = 0
        phase = .idle
        errorMessage = nil
    }

    // MARK: - Measurements

    private func measurePing() async -> Double? {
        // Simple ping using HEAD request
        let startTime = Date()

        do {
            var request = URLRequest(url: URL(string: "https://speed.cloudflare.com")!)
            request.httpMethod = "HEAD"
            request.timeoutInterval = 5

            let (_, response) = try await URLSession.shared.data(for: request)

            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                return Date().timeIntervalSince(startTime) * 1000 // Convert to ms
            }
        } catch {
            await MainActor.run {
                errorMessage = "Ping failed: \(error.localizedDescription)"
            }
        }

        return nil
    }

    private func measureDownload() async -> Double? {
        let startTime = Date()
        var totalBytes: Int64 = 0

        do {
            let (asyncBytes, response) = try await URLSession.shared.bytes(from: testFileURL)

            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                throw URLError(.badServerResponse)
            }

            let expectedLength = response.expectedContentLength

            for try await byte in asyncBytes {
                guard isRunning else { break }

                totalBytes += 1

                // Update progress every 100KB
                if totalBytes % 102400 == 0 {
                    let currentProgress = expectedLength > 0 ? Double(totalBytes) / Double(expectedLength) : 0
                    await MainActor.run {
                        progress = currentProgress

                        // Calculate current speed
                        let elapsed = Date().timeIntervalSince(startTime)
                        if elapsed > 0 {
                            let bitsPerSecond = Double(totalBytes * 8) / elapsed
                            downloadSpeed = bitsPerSecond / 1_000_000 // Convert to Mbps
                        }
                    }
                }

                // Yield to prevent blocking
                if totalBytes % 1048576 == 0 { // Every 1MB
                    try? await Task.sleep(for: .milliseconds(1))
                }
            }

            let elapsed = Date().timeIntervalSince(startTime)
            let bitsPerSecond = Double(totalBytes * 8) / elapsed
            let speedMbps = bitsPerSecond / 1_000_000

            await MainActor.run {
                progress = 1.0
            }

            return speedMbps

        } catch {
            await MainActor.run {
                errorMessage = "Download failed: \(error.localizedDescription)"
            }
            return nil
        }
    }

    // MARK: - Helpers

    private func formatSpeed(_ speed: Double) -> String {
        if speed >= 100 {
            return String(format: "%.0f", speed)
        } else if speed >= 10 {
            return String(format: "%.1f", speed)
        } else {
            return String(format: "%.2f", speed)
        }
    }
}

// MARK: - Models

enum SpeedTestPhase {
    case idle
    case ping
    case download
    case complete

    var description: String {
        switch self {
        case .idle: return "Ready"
        case .ping: return "Testing latency..."
        case .download: return "Testing download..."
        case .complete: return "Complete"
        }
    }
}

#Preview {
    SpeedTestToolView()
}
