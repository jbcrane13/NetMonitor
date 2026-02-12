//
//  SpeedTestService.swift
//  NetMonitor
//
//  Actor-based speed test service for measuring network performance.
//  Extracted from SpeedTestToolView to separate business logic from UI.
//

import Foundation

/// A single speed measurement sample
struct SpeedSample: Sendable {
    let bytesTransferred: Int64
    let speedMbps: Double
    let elapsed: TimeInterval
    let timeRemaining: TimeInterval
    let progress: Double
    let peakSpeedMbps: Double
}

/// Actor-based speed test service for measuring network performance.
actor SpeedTestService {

    // MARK: - Properties

    private var isCancelled = false

    // swiftlint:disable:next force_unwrapping
    private let pingURL = URL(string: "https://speed.cloudflare.com")!
    // swiftlint:disable:next force_unwrapping
    private let downloadURL = URL(string: "https://speed.cloudflare.com/__down?bytes=1000000")!
    // swiftlint:disable:next force_unwrapping
    private let uploadURL = URL(string: "https://speed.cloudflare.com/__up")!

    // MARK: - Public API

    /// Measure ping latency using a HEAD request
    /// - Returns: Latency in milliseconds, or nil if the request failed
    func measurePing() async -> (latency: Double?, error: String?) {
        isCancelled = false
        let startTime = Date()

        do {
            var request = URLRequest(url: pingURL)
            request.httpMethod = "HEAD"
            request.timeoutInterval = 5

            let (_, response) = try await URLSession.shared.data(for: request)

            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                let latency = Date().timeIntervalSince(startTime) * 1000
                return (latency, nil)
            }
        } catch {
            return (nil, "Ping failed: \(error.localizedDescription)")
        }

        return (nil, nil)
    }

    /// Measure download speed by repeatedly fetching chunks
    /// - Parameter duration: How long to run the download test in seconds
    /// - Returns: AsyncStream of SpeedSample updates
    func measureDownload(duration: TimeInterval) -> AsyncStream<SpeedSample> {
        isCancelled = false
        let url = downloadURL

        return AsyncStream { continuation in
            Task { [weak self] in
                guard let self else {
                    continuation.finish()
                    return
                }

                let startTime = Date()
                var totalBytes: Int64 = 0
                var peak: Double = 0

                while Date().timeIntervalSince(startTime) < duration {
                    let cancelled = await self.isCancelled
                    guard !cancelled else { break }

                    let chunkStart = Date()
                    do {
                        var request = URLRequest(url: url)
                        request.timeoutInterval = 10

                        let (data, response) = try await URLSession.shared.data(for: request)

                        guard let httpResponse = response as? HTTPURLResponse,
                              httpResponse.statusCode == 200 else {
                            throw URLError(.badServerResponse)
                        }

                        let cancelledAfterFetch = await self.isCancelled
                        guard !cancelledAfterFetch else { break }

                        let chunkTime = Date().timeIntervalSince(chunkStart)
                        totalBytes += Int64(data.count)
                        let chunkSpeedMbps = Double(data.count * 8) / chunkTime / 1_000_000
                        peak = max(peak, chunkSpeedMbps)

                        let elapsed = Date().timeIntervalSince(startTime)
                        let currentAvg = Double(totalBytes * 8) / elapsed / 1_000_000
                        let remaining = max(0, duration - elapsed)
                        let progress = min(elapsed / duration, 1.0)

                        continuation.yield(SpeedSample(
                            bytesTransferred: totalBytes,
                            speedMbps: currentAvg,
                            elapsed: elapsed,
                            timeRemaining: remaining,
                            progress: progress,
                            peakSpeedMbps: peak
                        ))
                    } catch {
                        let cancelledOnError = await self.isCancelled
                        if !cancelledOnError {
                            // Yield a final sample to signal the error via finish
                            continuation.finish()
                            return
                        }
                        break
                    }
                }

                // Yield final sample with complete progress
                if totalBytes > 0 {
                    let totalTime = Date().timeIntervalSince(startTime)
                    let finalSpeed = Double(totalBytes * 8) / totalTime / 1_000_000

                    continuation.yield(SpeedSample(
                        bytesTransferred: totalBytes,
                        speedMbps: finalSpeed,
                        elapsed: totalTime,
                        timeRemaining: 0,
                        progress: 1.0,
                        peakSpeedMbps: peak
                    ))
                }

                continuation.finish()
            }
        }
    }

    /// Measure upload speed by repeatedly sending data chunks
    /// - Parameter duration: How long to run the upload test in seconds
    /// - Returns: AsyncStream of SpeedSample updates
    func measureUpload(duration: TimeInterval) -> AsyncStream<SpeedSample> {
        isCancelled = false
        let chunkSize = 256 * 1024 // 256KB
        let url = uploadURL

        return AsyncStream { continuation in
            Task { [weak self] in
                guard let self else {
                    continuation.finish()
                    return
                }

                let startTime = Date()
                var totalBytes: Int64 = 0
                var peak: Double = 0

                while Date().timeIntervalSince(startTime) < duration {
                    let cancelled = await self.isCancelled
                    guard !cancelled else { break }

                    let chunkStart = Date()
                    do {
                        // Generate random data payload
                        var data = Data(count: chunkSize)
                        data.withUnsafeMutableBytes { bytes in
                            guard let baseAddress = bytes.baseAddress else { return }
                            arc4random_buf(baseAddress, chunkSize)
                        }

                        var request = URLRequest(url: url)
                        request.httpMethod = "POST"
                        request.httpBody = data
                        request.setValue("application/octet-stream", forHTTPHeaderField: "Content-Type")
                        request.timeoutInterval = 10

                        let (_, response) = try await URLSession.shared.data(for: request)

                        guard let httpResponse = response as? HTTPURLResponse,
                              (200...299).contains(httpResponse.statusCode) else {
                            throw URLError(.badServerResponse)
                        }

                        let cancelledAfterFetch = await self.isCancelled
                        guard !cancelledAfterFetch else { break }

                        let chunkTime = Date().timeIntervalSince(chunkStart)
                        totalBytes += Int64(chunkSize)
                        let chunkSpeedMbps = Double(chunkSize * 8) / chunkTime / 1_000_000
                        peak = max(peak, chunkSpeedMbps)

                        let elapsed = Date().timeIntervalSince(startTime)
                        let currentAvg = Double(totalBytes * 8) / elapsed / 1_000_000
                        let remaining = max(0, duration - elapsed)
                        let progress = min(elapsed / duration, 1.0)

                        continuation.yield(SpeedSample(
                            bytesTransferred: totalBytes,
                            speedMbps: currentAvg,
                            elapsed: elapsed,
                            timeRemaining: remaining,
                            progress: progress,
                            peakSpeedMbps: peak
                        ))
                    } catch {
                        let cancelledOnError = await self.isCancelled
                        if !cancelledOnError {
                            continuation.finish()
                            return
                        }
                        break
                    }
                }

                // Yield final sample with complete progress
                if totalBytes > 0 {
                    let totalTime = Date().timeIntervalSince(startTime)
                    let finalSpeed = Double(totalBytes * 8) / totalTime / 1_000_000

                    continuation.yield(SpeedSample(
                        bytesTransferred: totalBytes,
                        speedMbps: finalSpeed,
                        elapsed: totalTime,
                        timeRemaining: 0,
                        progress: 1.0,
                        peakSpeedMbps: peak
                    ))
                }

                continuation.finish()
            }
        }
    }

    /// Cancel any ongoing speed test measurements
    func cancel() {
        isCancelled = true
    }
}
