import Testing
import SwiftData
@testable import NetMonitor

@Suite("Monitoring Session Tests")
struct MonitoringSessionTests {

    @Test("Monitoring session can be created")
    @MainActor
    func sessionCreation() throws {
        let container = try ModelContainer(
            for: NetworkTarget.self, TargetMeasurement.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
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
            for: NetworkTarget.self, TargetMeasurement.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
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

        session.startMonitoring()
        #expect(session.isMonitoring == true)
        #expect(session.startTime != nil)

        session.stopMonitoring()
        #expect(session.isMonitoring == false)
    }
}
