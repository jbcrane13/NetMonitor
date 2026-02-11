import Foundation
import Testing
import SwiftData
@testable import NetMonitor

@Suite("Monitoring Session Tests", .serialized)
struct MonitoringSessionTests {

    @Test("Monitoring session can be created")
    @MainActor
    func sessionCreation() throws {
        let container = try ModelContainer(
            for: NetworkTarget.self, TargetMeasurement.self, LocalDevice.self, SessionRecord.self,
            configurations: ModelConfiguration("test-\(UUID().uuidString)", isStoredInMemoryOnly: true)
        )

        let httpService = HTTPMonitorService()
        let icmpService = ICMPMonitorService()
        let tcpService = TCPMonitorService()

        let session = MonitoringSession(
            modelContext: container.mainContext,
            httpService: httpService,
            icmpService: icmpService,
            tcpService: tcpService
        )

        #expect(session.isMonitoring == false)
        #expect(session.startTime == nil)
    }

    @Test("Monitoring session can start and stop")
    @MainActor
    func sessionStartStop() throws {
        let container = try ModelContainer(
            for: NetworkTarget.self, TargetMeasurement.self, LocalDevice.self, SessionRecord.self,
            configurations: ModelConfiguration("test-\(UUID().uuidString)", isStoredInMemoryOnly: true)
        )

        let httpService = HTTPMonitorService()
        let icmpService = ICMPMonitorService()
        let tcpService = TCPMonitorService()

        let session = MonitoringSession(
            modelContext: container.mainContext,
            httpService: httpService,
            icmpService: icmpService,
            tcpService: tcpService
        )

        // Insert a target so startMonitoring() proceeds past the empty check
        let target = NetworkTarget(name: "Test", host: "example.com", port: nil, targetProtocol: .icmp)
        container.mainContext.insert(target)
        try container.mainContext.save()

        session.startMonitoring()
        #expect(session.isMonitoring == true)
        #expect(session.startTime != nil)

        session.stopMonitoring()
        #expect(session.isMonitoring == false)
    }

    // MARK: - Measurement Pruning Tests

    @Test("Pruning preserves measurements when retention is Forever")
    @MainActor
    func pruningWithForeverRetention() throws {
        let container = try ModelContainer(
            for: NetworkTarget.self, TargetMeasurement.self, LocalDevice.self, SessionRecord.self,
            configurations: ModelConfiguration("test-\(UUID().uuidString)", isStoredInMemoryOnly: true)
        )

        let session = MonitoringSession(
            modelContext: container.mainContext,
            httpService: HTTPMonitorService(),
            icmpService: ICMPMonitorService(),
            tcpService: TCPMonitorService()
        )

        // Create target and old measurements
        let target = NetworkTarget(name: "Test", host: "example.com", port: nil, targetProtocol: .icmp)
        container.mainContext.insert(target)

        let oldDate = Calendar.current.date(byAdding: .day, value: -90, to: Date())!
        let oldMeasurement = TargetMeasurement(
            timestamp: oldDate,
            latency: 50.0,
            isReachable: true
        )
        oldMeasurement.target = target
        container.mainContext.insert(oldMeasurement)
        try container.mainContext.save()

        // Set retention to Forever
        UserDefaults.standard.set("Forever", forKey: "netmonitor.data.historyRetention")

        // Call pruning directly
        session.pruneOldMeasurements()

        // Verify measurement still exists
        let descriptor = FetchDescriptor<TargetMeasurement>()
        let measurements = try container.mainContext.fetch(descriptor)
        #expect(measurements.count == 1)

        // Cleanup
        UserDefaults.standard.removeObject(forKey: "netmonitor.data.historyRetention")
    }

    @Test("Pruning removes measurements older than 1 day")
    @MainActor
    func pruningWithOneDayRetention() throws {
        let container = try ModelContainer(
            for: NetworkTarget.self, TargetMeasurement.self, LocalDevice.self, SessionRecord.self,
            configurations: ModelConfiguration("test-\(UUID().uuidString)", isStoredInMemoryOnly: true)
        )

        let session = MonitoringSession(
            modelContext: container.mainContext,
            httpService: HTTPMonitorService(),
            icmpService: ICMPMonitorService(),
            tcpService: TCPMonitorService()
        )

        // Create target
        let target = NetworkTarget(name: "Test", host: "example.com", port: nil, targetProtocol: .icmp)
        container.mainContext.insert(target)

        // Create old measurement (2 days ago)
        let oldDate = Calendar.current.date(byAdding: .day, value: -2, to: Date())!
        let oldMeasurement = TargetMeasurement(
            timestamp: oldDate,
            latency: 50.0,
            isReachable: true
        )
        oldMeasurement.target = target
        container.mainContext.insert(oldMeasurement)

        // Create recent measurement (1 hour ago)
        let recentDate = Calendar.current.date(byAdding: .hour, value: -1, to: Date())!
        let recentMeasurement = TargetMeasurement(
            timestamp: recentDate,
            latency: 25.0,
            isReachable: true
        )
        recentMeasurement.target = target
        container.mainContext.insert(recentMeasurement)
        try container.mainContext.save()

        // Set retention to 1 day
        UserDefaults.standard.set("1 day", forKey: "netmonitor.data.historyRetention")

        // Call pruning directly
        session.pruneOldMeasurements()

        // Verify only recent measurement remains
        let descriptor = FetchDescriptor<TargetMeasurement>()
        let measurements = try container.mainContext.fetch(descriptor)
        #expect(measurements.count == 1)
        #expect(measurements.first?.timestamp == recentDate)

        // Cleanup
        UserDefaults.standard.removeObject(forKey: "netmonitor.data.historyRetention")
    }

    @Test("Pruning removes measurements older than 7 days (default)")
    @MainActor
    func pruningWithDefaultRetention() throws {
        let container = try ModelContainer(
            for: NetworkTarget.self, TargetMeasurement.self, LocalDevice.self, SessionRecord.self,
            configurations: ModelConfiguration("test-\(UUID().uuidString)", isStoredInMemoryOnly: true)
        )

        let session = MonitoringSession(
            modelContext: container.mainContext,
            httpService: HTTPMonitorService(),
            icmpService: ICMPMonitorService(),
            tcpService: TCPMonitorService()
        )

        // Create target
        let target = NetworkTarget(name: "Test", host: "example.com", port: nil, targetProtocol: .icmp)
        container.mainContext.insert(target)

        // Create old measurement (10 days ago)
        let oldDate = Calendar.current.date(byAdding: .day, value: -10, to: Date())!
        let oldMeasurement = TargetMeasurement(
            timestamp: oldDate,
            latency: 50.0,
            isReachable: true
        )
        oldMeasurement.target = target
        container.mainContext.insert(oldMeasurement)

        // Create recent measurement (3 days ago)
        let recentDate = Calendar.current.date(byAdding: .day, value: -3, to: Date())!
        let recentMeasurement = TargetMeasurement(
            timestamp: recentDate,
            latency: 25.0,
            isReachable: true
        )
        recentMeasurement.target = target
        container.mainContext.insert(recentMeasurement)
        try container.mainContext.save()

        // Don't set retention (should default to 7 days)
        UserDefaults.standard.removeObject(forKey: "netmonitor.data.historyRetention")

        // Call pruning directly
        session.pruneOldMeasurements()

        // Verify only recent measurement remains (within 7 days)
        let descriptor = FetchDescriptor<TargetMeasurement>()
        let measurements = try container.mainContext.fetch(descriptor)
        #expect(measurements.count == 1)
        #expect(measurements.first?.timestamp == recentDate)
    }

    @Test("Pruning removes measurements older than 30 days")
    @MainActor
    func pruningWithThirtyDayRetention() throws {
        let container = try ModelContainer(
            for: NetworkTarget.self, TargetMeasurement.self, LocalDevice.self, SessionRecord.self,
            configurations: ModelConfiguration("test-\(UUID().uuidString)", isStoredInMemoryOnly: true)
        )

        let session = MonitoringSession(
            modelContext: container.mainContext,
            httpService: HTTPMonitorService(),
            icmpService: ICMPMonitorService(),
            tcpService: TCPMonitorService()
        )

        // Create target
        let target = NetworkTarget(name: "Test", host: "example.com", port: nil, targetProtocol: .icmp)
        container.mainContext.insert(target)

        // Create old measurement (45 days ago)
        let oldDate = Calendar.current.date(byAdding: .day, value: -45, to: Date())!
        let oldMeasurement = TargetMeasurement(
            timestamp: oldDate,
            latency: 50.0,
            isReachable: true
        )
        oldMeasurement.target = target
        container.mainContext.insert(oldMeasurement)

        // Create recent measurement (15 days ago)
        let recentDate = Calendar.current.date(byAdding: .day, value: -15, to: Date())!
        let recentMeasurement = TargetMeasurement(
            timestamp: recentDate,
            latency: 25.0,
            isReachable: true
        )
        recentMeasurement.target = target
        container.mainContext.insert(recentMeasurement)
        try container.mainContext.save()

        // Set retention to 30 days
        UserDefaults.standard.set("30 days", forKey: "netmonitor.data.historyRetention")

        // Call pruning directly
        session.pruneOldMeasurements()

        // Verify only recent measurement remains (within 30 days)
        let descriptor = FetchDescriptor<TargetMeasurement>()
        let measurements = try container.mainContext.fetch(descriptor)
        #expect(measurements.count == 1)
        #expect(measurements.first?.timestamp == recentDate)

        // Cleanup
        UserDefaults.standard.removeObject(forKey: "netmonitor.data.historyRetention")
    }

    @Test("Pruning handles unknown retention value as 7 days default")
    @MainActor
    func pruningWithUnknownRetention() throws {
        let container = try ModelContainer(
            for: NetworkTarget.self, TargetMeasurement.self, LocalDevice.self, SessionRecord.self,
            configurations: ModelConfiguration("test-\(UUID().uuidString)", isStoredInMemoryOnly: true)
        )

        let session = MonitoringSession(
            modelContext: container.mainContext,
            httpService: HTTPMonitorService(),
            icmpService: ICMPMonitorService(),
            tcpService: TCPMonitorService()
        )

        // Create target
        let target = NetworkTarget(name: "Test", host: "example.com", port: nil, targetProtocol: .icmp)
        container.mainContext.insert(target)

        // Create old measurement (10 days ago)
        let oldDate = Calendar.current.date(byAdding: .day, value: -10, to: Date())!
        let oldMeasurement = TargetMeasurement(
            timestamp: oldDate,
            latency: 50.0,
            isReachable: true
        )
        oldMeasurement.target = target
        container.mainContext.insert(oldMeasurement)
        try container.mainContext.save()

        // Set unknown retention value
        UserDefaults.standard.set("invalid value", forKey: "netmonitor.data.historyRetention")

        // Call pruning directly
        session.pruneOldMeasurements()

        // Verify old measurement was pruned (defaults to 7 days)
        let descriptor = FetchDescriptor<TargetMeasurement>()
        let measurements = try container.mainContext.fetch(descriptor)
        #expect(measurements.count == 0)

        // Cleanup
        UserDefaults.standard.removeObject(forKey: "netmonitor.data.historyRetention")
    }
}
