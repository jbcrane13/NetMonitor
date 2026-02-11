import Foundation
import SwiftData
import os

// MARK: - Service Provider Protocol

/// Protocol for providing monitor service instances
/// Enables dependency injection and testability for MonitoringSession
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

/// Main-actor bound monitoring session coordinator
/// Manages active monitoring and publishes results to the UI
@MainActor
@Observable
final class MonitoringSession {

    // MARK: - Published State

    /// Whether monitoring is currently active
    private(set) var isMonitoring: Bool = false

    /// Current monitoring start time
    private(set) var startTime: Date?

    /// Latest measurement results by target ID
    private(set) var latestResults: [UUID: TargetMeasurement] = [:]

    /// Error message from last failed operation
    private(set) var errorMessage: String?

    /// Active monitoring tasks (for cancellation)
    private var monitoringTasks: [UUID: Task<Void, Never>] = [:]

    /// Current session record for lifecycle tracking
    private var currentSessionRecord: SessionRecord?

    /// Timer for periodic measurement pruning
    private var pruneTimer: Task<Void, Never>?

    // MARK: - Dependencies

    private let modelContext: ModelContext
    private let httpService: HTTPMonitorService
    private let icmpService: ICMPMonitorService
    private let tcpService: TCPMonitorService

    // MARK: - Initialization

    /// Initialize with a service provider (preferred)
    /// - Parameters:
    ///   - modelContext: SwiftData model context for persistence
    ///   - serviceProvider: Provider for creating monitor services
    init(
        modelContext: ModelContext,
        serviceProvider: MonitorServiceProviding = DefaultMonitorServiceProvider()
    ) {
        self.modelContext = modelContext
        self.httpService = serviceProvider.createHTTPService()
        self.icmpService = serviceProvider.createICMPService()
        self.tcpService = serviceProvider.createTCPService()
    }

    /// Initialize with explicit service instances (backwards compatible)
    /// - Parameters:
    ///   - modelContext: SwiftData model context for persistence
    ///   - httpService: HTTP/HTTPS monitoring service
    ///   - icmpService: ICMP ping monitoring service
    ///   - tcpService: TCP port monitoring service
    init(
        modelContext: ModelContext,
        httpService: HTTPMonitorService,
        icmpService: ICMPMonitorService,
        tcpService: TCPMonitorService
    ) {
        self.modelContext = modelContext
        self.httpService = httpService
        self.icmpService = icmpService
        self.tcpService = tcpService
    }

    // MARK: - Public API

    /// Start monitoring all enabled targets
    func startMonitoring() {
        guard !isMonitoring else { return }

        // Clear any previous error messages
        errorMessage = nil

        // Fetch all enabled targets
        let descriptor = FetchDescriptor<NetworkTarget>(
            predicate: #Predicate { $0.isEnabled }
        )

        let targets: [NetworkTarget]
        do {
            targets = try modelContext.fetch(descriptor)
        } catch {
            errorMessage = "Failed to fetch targets: \(error.localizedDescription)"
            return
        }

        // Validate that we have targets to monitor
        guard !targets.isEmpty else {
            errorMessage = "No enabled targets found. Add targets in the Targets section to start monitoring."
            return
        }

        // All validations passed - start monitoring
        isMonitoring = true
        startTime = Date()

        // Create session record
        let sessionRecord = SessionRecord(startedAt: Date(), isActive: true)
        currentSessionRecord = sessionRecord
        modelContext.insert(sessionRecord)
        do {
            try modelContext.save()
        } catch {
            Logger.monitoring.error("Failed to save session record: \(error)")
        }

        // Start monitoring each target
        for target in targets {
            startMonitoringTarget(target)
        }

        // Start periodic measurement pruning (hourly)
        pruneTimer = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(3600))
                await self?.pruneOldMeasurements()
            }
        }
    }

    /// Stop monitoring all targets
    func stopMonitoring() {
        guard isMonitoring else { return }

        isMonitoring = false

        // Update session record
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

        // Cancel pruning timer
        pruneTimer?.cancel()
        pruneTimer = nil

        // Cancel all monitoring tasks
        for task in monitoringTasks.values {
            task.cancel()
        }
        monitoringTasks.removeAll()
    }

    /// Get latest measurement for a target
    func latestMeasurement(for targetID: UUID) -> TargetMeasurement? {
        return latestResults[targetID]
    }

    // MARK: - Computed Statistics (extracted for testability)

    /// Number of targets currently online
    var onlineTargetCount: Int {
        latestResults.values.filter { $0.isReachable }.count
    }

    /// Number of targets currently offline
    var offlineTargetCount: Int {
        latestResults.values.filter { !$0.isReachable }.count
    }

    /// Formatted average latency string across all targets
    var averageLatencyString: String {
        let latencies = latestResults.values.compactMap { $0.latency }
        guard !latencies.isEmpty else { return "—" }
        let avg = latencies.reduce(0, +) / Double(latencies.count)
        return "\(Int(avg))ms"
    }

    // MARK: - Private Methods

    private func startMonitoringTarget(_ target: NetworkTarget) {
        // Cancel any existing task for this target
        monitoringTasks[target.id]?.cancel()

        // Create new monitoring task
        let task = Task { [weak self] in
            await self?.monitorTarget(target)
            return ()
        }

        monitoringTasks[target.id] = task
    }

    private func monitorTarget(_ target: NetworkTarget) async {
        while !Task.isCancelled && isMonitoring {
            // Select appropriate service
            let service: any NetworkMonitorService = switch target.targetProtocol {
            case .http, .https:
                httpService
            case .icmp:
                icmpService
            case .tcp:
                tcpService
            }

            // Extract Sendable DTO on @MainActor before crossing actor boundary
            let request = TargetCheckRequest(
                id: target.id,
                host: target.host,
                port: target.port,
                targetProtocol: target.targetProtocol,
                timeout: target.timeout
            )

            // Perform check across actor boundary with Sendable DTO
            do {
                let result = try await service.check(request: request)

                // Convert MeasurementResult back to TargetMeasurement on @MainActor
                let measurement = TargetMeasurement(
                    latency: result.latency,
                    isReachable: result.isReachable,
                    errorMessage: result.errorMessage
                )

                // Update latest results and save to SwiftData on main actor
                await updateMeasurement(measurement, for: target)

            } catch {
                // Handle errors by creating failed measurement (already on @MainActor)
                let failedMeasurement = TargetMeasurement(
                    latency: nil,
                    isReachable: false,
                    errorMessage: error.localizedDescription
                )

                await updateMeasurement(failedMeasurement, for: target)
            }

            // Wait for check interval
            try? await Task.sleep(for: .seconds(target.checkInterval))
        }
    }

    @MainActor
    private func updateMeasurement(_ measurement: TargetMeasurement, for target: NetworkTarget) {
        // Update latest results dictionary
        latestResults[target.id] = measurement

        // Save to SwiftData on main context
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
        guard retentionValue != "Forever" else { return } // Skip pruning when Forever is selected
        let days: Int
        switch retentionValue {
        case "1 day": days = 1
        case "30 days": days = 30
        default: days = 7 // Default 7 days
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
