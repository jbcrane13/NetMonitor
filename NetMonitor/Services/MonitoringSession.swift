import Foundation
import SwiftData
import os

// MARK: - Service Provider Protocol

/// Protocol for providing monitor service instances
/// Kept for backward compatibility — services are no longer used for primary monitoring
/// but remain available for ad-hoc tool checks.
protocol MonitorServiceProviding: Sendable {
    func createHTTPService() -> HTTPMonitorService
    func createTCPService() -> TCPMonitorService
    func createICMPService() -> ICMPMonitorService
}

/// Default implementation that creates standard service instances
struct DefaultMonitorServiceProvider: MonitorServiceProviding {
    func createHTTPService() -> HTTPMonitorService { HTTPMonitorService() }
    func createTCPService() -> TCPMonitorService { TCPMonitorService() }
    func createICMPService() -> ICMPMonitorService { ICMPMonitorService() }
}

/// Main-actor bound monitoring session coordinator.
///
/// Previously orchestrated periodic pinging of `NetworkTarget` records.
/// Now repurposed to drive periodic local-network device discovery via
/// `DeviceDiscoveryCoordinator`. The "Start Monitoring" / "Stop Monitoring"
/// button in the UI starts and stops recurring network scans every 60 s.
///
/// `latestResults` and the legacy target-measurement API are retained for
/// backward compatibility with concurrency tests and the companion protocol.
@MainActor
@Observable
final class MonitoringSession {

    // MARK: - Published State

    /// Whether a monitoring / scanning session is currently active
    private(set) var isMonitoring: Bool = false

    /// When the current session started
    private(set) var startTime: Date?

    /// Latest measurement results by target ID (kept for concurrency-test compat)
    private(set) var latestResults: [UUID: TargetMeasurement] = [:]

    /// Error message from last failed operation
    private(set) var errorMessage: String?

    // MARK: - Private State

    private var scanTimer: Task<Void, Never>?
    private var pruneTimer: Task<Void, Never>?
    private var currentSessionRecord: SessionRecord?

    // MARK: - Dependencies

    private let modelContext: ModelContext

    /// Device discovery coordinator used for periodic network scans.
    /// Optional to preserve backward-compatibility with unit tests that
    /// construct MonitoringSession directly without a coordinator.
    private let coordinator: DeviceDiscoveryCoordinator?

    /// Legacy services kept so the old init signatures still compile in tests.
    /// Not used for periodic scanning.
    private let httpService: HTTPMonitorService
    private let icmpService: ICMPMonitorService
    private let tcpService: TCPMonitorService

    // MARK: - Initialization

    /// Preferred initialiser — takes a discovery coordinator
    init(
        modelContext: ModelContext,
        coordinator: DeviceDiscoveryCoordinator? = nil,
        serviceProvider: MonitorServiceProviding = DefaultMonitorServiceProvider()
    ) {
        self.modelContext = modelContext
        self.coordinator = coordinator
        self.httpService = serviceProvider.createHTTPService()
        self.icmpService = serviceProvider.createICMPService()
        self.tcpService = serviceProvider.createTCPService()
    }

    /// Backward-compatible initialiser used by tests and legacy call sites.
    init(
        modelContext: ModelContext,
        coordinator: DeviceDiscoveryCoordinator? = nil,
        httpService: HTTPMonitorService,
        icmpService: ICMPMonitorService,
        tcpService: TCPMonitorService
    ) {
        self.modelContext = modelContext
        self.coordinator = coordinator
        self.httpService = httpService
        self.icmpService = icmpService
        self.tcpService = tcpService
    }

    // MARK: - Public API

    /// Start monitoring — triggers an immediate network scan and schedules
    /// recurring scans every 60 seconds.
    func startMonitoring() {
        guard !isMonitoring else { return }

        errorMessage = nil
        isMonitoring = true
        startTime = Date()

        // Persist session record
        let sessionRecord = SessionRecord(startedAt: Date(), isActive: true)
        currentSessionRecord = sessionRecord
        modelContext.insert(sessionRecord)
        do {
            try modelContext.save()
        } catch {
            Logger.monitoring.error("Failed to save session record: \(error)")
        }

        // Trigger an immediate scan
        coordinator?.startScan()

        // Schedule recurring scans every 60 seconds
        scanTimer = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(60))
                guard !Task.isCancelled else { break }
                await self?.triggerScan()
            }
        }

        // Schedule periodic measurement pruning (hourly)
        pruneTimer = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(3600))
                await self?.pruneOldMeasurements()
            }
        }
    }

    /// Stop monitoring and cancel all pending scans.
    func stopMonitoring() {
        guard isMonitoring else { return }

        isMonitoring = false

        // Persist session stop
        if let session = currentSessionRecord {
            session.stoppedAt = Date()
            session.isActive = false
            do {
                try modelContext.save()
            } catch {
                Logger.monitoring.error("Failed to save session stop: \(error)")
            }
            currentSessionRecord = nil
        }

        // Cancel timers
        scanTimer?.cancel()
        scanTimer = nil
        pruneTimer?.cancel()
        pruneTimer = nil

        // Stop any in-progress scan
        coordinator?.stopScan()
    }

    /// Get latest measurement for a target ID (kept for backward compatibility).
    func latestMeasurement(for targetID: UUID) -> TargetMeasurement? {
        return latestResults[targetID]
    }

    // MARK: - Computed Statistics

    /// Number of devices currently online (from coordinator; falls back to
    /// latestResults for test environments where coordinator is nil).
    var onlineTargetCount: Int {
        guard let coordinator else {
            return latestResults.values.filter { $0.isReachable }.count
        }
        return coordinator.discoveredDevices.filter { $0.isOnline }.count
    }

    /// Number of devices currently offline.
    var offlineTargetCount: Int {
        guard let coordinator else {
            return latestResults.values.filter { !$0.isReachable }.count
        }
        return coordinator.discoveredDevices.filter { !$0.isOnline }.count
    }

    /// Total discovered device count.
    var deviceCount: Int {
        coordinator?.discoveredDevices.count ?? 0
    }

    /// Time of the most recent completed scan.
    var lastScanTime: Date? {
        coordinator?.lastScanTime
    }

    /// Whether a scan is currently in progress.
    var isScanning: Bool {
        coordinator?.isScanning ?? false
    }

    /// Average latency string across legacy target measurements.
    /// Returns "—" in normal scanning mode (no per-device latency data).
    var averageLatencyString: String {
        let latencies = latestResults.values.compactMap { $0.latency }
        guard !latencies.isEmpty else { return "—" }
        let avg = latencies.reduce(0, +) / Double(latencies.count)
        return "\(Int(avg))ms"
    }

    // MARK: - Private Helpers

    @MainActor
    private func triggerScan() {
        coordinator?.startScan()
    }

    // MARK: - Internal Update (used by concurrency tests via testUpdateMeasurement)

    @MainActor
    func updateMeasurement(_ measurement: TargetMeasurement, for target: NetworkTarget) {
        latestResults[target.id] = measurement
        target.measurements.append(measurement)
        do {
            try modelContext.save()
        } catch {
            Logger.monitoring.error("Failed to save measurement: \(error)")
        }
    }

    // MARK: - Measurement Pruning

    @MainActor
    func pruneOldMeasurements() {
        let retentionValue = UserDefaults.standard.string(forKey: "netmonitor.data.historyRetention") ?? "7 days"
        guard retentionValue != "Forever" else { return }
        let days: Int
        switch retentionValue {
        case "1 day": days = 1
        case "30 days": days = 30
        default: days = 7
        }
        let cutoffDate = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()

        let descriptor = FetchDescriptor<TargetMeasurement>(
            predicate: #Predicate { $0.timestamp < cutoffDate }
        )

        do {
            let oldMeasurements = try modelContext.fetch(descriptor)
            for measurement in oldMeasurements {
                modelContext.delete(measurement)
            }
            if !oldMeasurements.isEmpty {
                try modelContext.save()
                Logger.data.info("Pruned \(oldMeasurements.count) measurements older than \(days) days")
            }
        } catch {
            Logger.data.error("Failed to prune measurements: \(error)")
        }
    }
}
