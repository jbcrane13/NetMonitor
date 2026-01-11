import Foundation
import SwiftData

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

    /// Active monitoring tasks (for cancellation)
    private var monitoringTasks: [UUID: Task<Void, Never>] = [:]

    // MARK: - Dependencies

    private let modelContext: ModelContext
    private let httpService: HTTPMonitorService
    private let icmpService: ICMPMonitorService

    // MARK: - Initialization

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        self.httpService = HTTPMonitorService()
        self.icmpService = ICMPMonitorService()
    }

    // MARK: - Public API

    /// Start monitoring all enabled targets
    func startMonitoring() {
        guard !isMonitoring else { return }

        isMonitoring = true
        startTime = Date()

        // Fetch all enabled targets
        let descriptor = FetchDescriptor<NetworkTarget>(
            predicate: #Predicate { $0.isEnabled }
        )

        guard let targets = try? modelContext.fetch(descriptor) else {
            stopMonitoring()
            return
        }

        // Start monitoring each target
        for target in targets {
            startMonitoringTarget(target)
        }
    }

    /// Stop monitoring all targets
    func stopMonitoring() {
        guard isMonitoring else { return }

        isMonitoring = false

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
                // TCP not implemented yet, use HTTP as fallback
                httpService
            }

            // Perform check
            do {
                let measurement = try await service.check(target: target)

                // Update latest results (back on main actor)
                await MainActor.run {
                    latestResults[target.id] = measurement
                }

                // Save to SwiftData (background context)
                await saveMeasurement(measurement, for: target)

            } catch {
                // Handle errors by creating failed measurement
                let failedMeasurement = TargetMeasurement(
                    latency: nil,
                    isReachable: false,
                    errorMessage: error.localizedDescription
                )

                await MainActor.run {
                    latestResults[target.id] = failedMeasurement
                }

                await saveMeasurement(failedMeasurement, for: target)
            }

            // Wait for check interval
            try? await Task.sleep(for: .seconds(target.checkInterval))
        }
    }

    private func saveMeasurement(_ measurement: TargetMeasurement, for target: NetworkTarget) async {
        // Save on main context - optimization for background context can be added later
        target.measurements.append(measurement)
        try? modelContext.save()
    }
}
