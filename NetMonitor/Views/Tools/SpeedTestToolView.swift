//
//  SpeedTestToolView.swift
//  NetMonitor
//
//  Speed test tool that measures download speed using public test files.
//

import SwiftUI

struct SpeedTestToolView: View {
    @Environment(\.appAccentColor) private var accentColor
    @State private var isRunning = false
    @State private var phase: SpeedTestPhase = .idle
    @State private var pingLatency: Double?
    @State private var downloadSpeed: Double?
    @State private var uploadSpeed: Double?
    @State private var peakDownloadSpeed: Double?
    @State private var peakUploadSpeed: Double?
    @State private var downloadSamples: [Double] = []
    @State private var uploadSamples: [Double] = []
    @State private var progress: Double = 0
    @State private var errorMessage: String?
    @State private var speedTestTask: Task<Void, Never>?
    @State private var testDuration: TimeInterval = 10 // Default 10 seconds
    @State private var timeRemaining: TimeInterval = 0

    private let uploadURL = URL(string: "https://speed.cloudflare.com/__up")! // Upload endpoint

    var body: some View {
        ToolSheetContainer(
            title: "Speed Test",
            iconName: "speedometer",
            closeAccessibilityID: "speedtest_button_close",
            minWidth: 600,
            minHeight: 500,
            inputArea: { contentArea },
            footerContent: { footer }
        )
        .onDisappear {
            speedTestTask?.cancel()
            speedTestTask = nil
        }
    }

    // MARK: - Content Area

    private var contentArea: some View {
        VStack(spacing: 32) {
            // Duration picker
            VStack(spacing: 8) {
                Text("Test Duration")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Picker("Duration", selection: $testDuration) {
                    Text("5 seconds").tag(TimeInterval(5))
                    Text("10 seconds").tag(TimeInterval(10))
                    Text("30 seconds").tag(TimeInterval(30))
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 300)
                .disabled(isRunning)
                .accessibilityIdentifier("speedtest_picker_duration")
            }

            Spacer()

            // Speedometer display
            speedometerView

            // Time remaining during test
            if isRunning && (phase == .download || phase == .upload) && timeRemaining > 0 {
                Text("Time remaining: \(Int(timeRemaining))s")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

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
                        colors: [accentColor, .green],
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

                if phase == .download, let speed = downloadSpeed {
                    Text(formatSpeed(speed))
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                    Text("Mbps")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else if phase == .upload, let speed = uploadSpeed {
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
                    .foregroundStyle(accentColor)

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
                    Text("Mbps avg down")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if let peak = peakDownloadSpeed {
                        Text("Peak: \(formatSpeed(peak)) Mbps")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Text("--")
                        .font(.title2.bold())
                        .foregroundStyle(.secondary)
                    Text("Mbps down")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }

            // Upload
            VStack(spacing: 4) {
                Image(systemName: "arrow.up.circle")
                    .font(.title2)
                    .foregroundStyle(.blue)

                if let speed = uploadSpeed {
                    Text(formatSpeed(speed))
                        .font(.title2.bold())
                    Text("Mbps avg up")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if let peak = peakUploadSpeed {
                        Text("Peak: \(formatSpeed(peak)) Mbps")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Text("--")
                        .font(.title2.bold())
                        .foregroundStyle(.secondary)
                    Text("Mbps up")
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
            } else if downloadSpeed != nil || uploadSpeed != nil {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                Text("Test completed")
                    .foregroundStyle(.secondary)
            } else {
                Text("Test your internet connection speed")
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if (downloadSpeed != nil || uploadSpeed != nil) && !isRunning {
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
        uploadSpeed = nil
        peakDownloadSpeed = nil
        peakUploadSpeed = nil
        downloadSamples = []
        uploadSamples = []
        progress = 0
        timeRemaining = 0

        speedTestTask = Task {
            // Phase 1: Ping test
            await MainActor.run { phase = .ping }
            pingLatency = await measurePing()

            guard isRunning else { return }

            // Phase 2: Download test
            await MainActor.run { phase = .download }
            downloadSpeed = await measureDownload()

            guard isRunning else { return }

            // Phase 3: Upload test
            await MainActor.run { phase = .upload }
            uploadSpeed = await measureUpload()

            await MainActor.run {
                phase = .complete
                isRunning = false
            }
        }
    }

    private func stopSpeedTest() {
        speedTestTask?.cancel()
        speedTestTask = nil
        isRunning = false
        phase = .idle
    }

    private func resetTest() {
        pingLatency = nil
        downloadSpeed = nil
        uploadSpeed = nil
        peakDownloadSpeed = nil
        peakUploadSpeed = nil
        downloadSamples = []
        uploadSamples = []
        progress = 0
        phase = .idle
        errorMessage = nil
        timeRemaining = 0
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
        let chunkURL = URL(string: "https://speed.cloudflare.com/__down?bytes=1000000")! // 1MB chunks
        let startTime = Date()
        var totalBytes: Int64 = 0
        var samples: [Double] = []
        var peak: Double = 0

        while Date().timeIntervalSince(startTime) < testDuration && isRunning {
            let chunkStart = Date()
            do {
                var request = URLRequest(url: chunkURL)
                request.timeoutInterval = 10

                let (data, response) = try await URLSession.shared.data(for: request)

                guard let httpResponse = response as? HTTPURLResponse,
                      httpResponse.statusCode == 200 else {
                    throw URLError(.badServerResponse)
                }

                guard isRunning else { return nil }

                let chunkTime = Date().timeIntervalSince(chunkStart)
                totalBytes += Int64(data.count)
                let chunkSpeedMbps = Double(data.count * 8) / chunkTime / 1_000_000
                samples.append(chunkSpeedMbps)
                peak = max(peak, chunkSpeedMbps)

                let elapsed = Date().timeIntervalSince(startTime)
                let currentAvg = Double(totalBytes * 8) / elapsed / 1_000_000
                let remaining = max(0, testDuration - elapsed)

                await MainActor.run {
                    downloadSpeed = currentAvg
                    peakDownloadSpeed = peak
                    downloadSamples = samples
                    progress = min(elapsed / testDuration, 1.0)
                    timeRemaining = remaining
                }
            } catch {
                if isRunning {
                    await MainActor.run {
                        errorMessage = "Download failed: \(error.localizedDescription)"
                    }
                }
                break
            }
        }

        let totalTime = Date().timeIntervalSince(startTime)
        let finalSpeed = totalBytes > 0 ? Double(totalBytes * 8) / totalTime / 1_000_000 : nil

        await MainActor.run {
            downloadSpeed = finalSpeed
            peakDownloadSpeed = peak
            downloadSamples = samples
            progress = 1.0
            timeRemaining = 0
        }

        return finalSpeed
    }

    private func measureUpload() async -> Double? {
        let chunkSize: Int = 256 * 1024 // 256KB chunks
        let startTime = Date()
        var totalBytes: Int64 = 0
        var samples: [Double] = []
        var peak: Double = 0

        while Date().timeIntervalSince(startTime) < testDuration && isRunning {
            let chunkStart = Date()
            do {
                // Generate random data payload
                var data = Data(count: chunkSize)
                data.withUnsafeMutableBytes { bytes in
                    guard let baseAddress = bytes.baseAddress else { return }
                    arc4random_buf(baseAddress, chunkSize)
                }

                var request = URLRequest(url: uploadURL)
                request.httpMethod = "POST"
                request.httpBody = data
                request.setValue("application/octet-stream", forHTTPHeaderField: "Content-Type")
                request.timeoutInterval = 10

                let (_, response) = try await URLSession.shared.data(for: request)

                guard let httpResponse = response as? HTTPURLResponse,
                      (200...299).contains(httpResponse.statusCode) else {
                    throw URLError(.badServerResponse)
                }

                guard isRunning else { return nil }

                let chunkTime = Date().timeIntervalSince(chunkStart)
                totalBytes += Int64(chunkSize)
                let chunkSpeedMbps = Double(chunkSize * 8) / chunkTime / 1_000_000
                samples.append(chunkSpeedMbps)
                peak = max(peak, chunkSpeedMbps)

                let elapsed = Date().timeIntervalSince(startTime)
                let currentAvg = Double(totalBytes * 8) / elapsed / 1_000_000
                let remaining = max(0, testDuration - elapsed)

                await MainActor.run {
                    uploadSpeed = currentAvg
                    peakUploadSpeed = peak
                    uploadSamples = samples
                    progress = min(elapsed / testDuration, 1.0)
                    timeRemaining = remaining
                }
            } catch {
                if isRunning {
                    await MainActor.run {
                        errorMessage = "Upload failed: \(error.localizedDescription)"
                    }
                }
                break
            }
        }

        let totalTime = Date().timeIntervalSince(startTime)
        let finalSpeed = totalBytes > 0 ? Double(totalBytes * 8) / totalTime / 1_000_000 : nil

        await MainActor.run {
            uploadSpeed = finalSpeed
            peakUploadSpeed = peak
            uploadSamples = samples
            progress = 1.0
            timeRemaining = 0
        }

        return finalSpeed
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
    case upload
    case complete

    var description: String {
        switch self {
        case .idle: return "Ready"
        case .ping: return "Testing latency..."
        case .download: return "Testing download..."
        case .upload: return "Testing upload..."
        case .complete: return "Complete"
        }
    }
}

#Preview {
    SpeedTestToolView()
}
