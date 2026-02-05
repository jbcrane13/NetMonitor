import Testing
import SwiftData
import Foundation
@testable import NetMonitor

@Suite("Monitoring Session Concurrency Tests")
struct MonitoringSessionConcurrencyTests {

    @Test("Concurrent updates to latestResults are handled safely", .timeLimit(.minutes(2)))
    @MainActor
    func concurrentResultsUpdate() async throws {
        // Setup in-memory SwiftData container
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

        // Create 15 test targets with different protocols and IDs
        var testTargets: [NetworkTarget] = []
        for i in 0..<15 {
            let target = NetworkTarget(
                name: "TestTarget\(i)",
                address: "test\(i).example.com",
                targetProtocol: i % 3 == 0 ? .http : (i % 3 == 1 ? .icmp : .tcp),
                port: 80,
                checkInterval: 5,
                isEnabled: true
            )
            testTargets.append(target)
            container.mainContext.insert(target)
        }
        try container.mainContext.save()
        
        // Track completion of all concurrent tasks
        let taskCompletionActor = TaskCompletionTracker()
        
        // Spawn concurrent tasks that simulate the race condition
        await withTaskGroup(of: Void.self) { group in
            for target in testTargets {
                group.addTask {
                    // Each task performs multiple updates to stress the system
                    for updateIndex in 0..<5 {
                        let measurement = TargetMeasurement(
                            latency: Double(updateIndex * 10 + Int.random(in: 1...50)),
                            isReachable: updateIndex % 2 == 0,
                            errorMessage: updateIndex % 3 == 0 ? "Test error \(updateIndex)" : nil
                        )
                        
                        // This should be serialized through @MainActor
                        await session.testUpdateMeasurement(measurement, for: target)
                        
                        // Small random delay to increase chance of concurrency issues
                        try? await Task.sleep(for: .milliseconds(Int.random(in: 1...10)))
                    }
                    
                    await taskCompletionActor.markTaskComplete(for: target.id)
                }
            }
        }
        
        // Verify all tasks completed
        let completedTasks = await taskCompletionActor.completedTaskCount
        #expect(completedTasks == testTargets.count)
        
        // Verify all targets have results in latestResults
        let latestResults = session.latestResults
        #expect(latestResults.count == testTargets.count)
        
        // Verify each target has a measurement
        for target in testTargets {
            let measurement = session.latestMeasurement(for: target.id)
            #expect(measurement != nil)
            
            // Verify the measurement is the latest one (from the last iteration)
            if let measurement = measurement {
                // Should be from the last update (index 4), so latency should be 40 + random(1...50)
                #expect(measurement.latency != nil)
                if let latency = measurement.latency {
                    #expect(latency >= 41 && latency <= 90) // 40 + (1...50)
                }
                // Should be reachable (4 % 2 == 0)
                #expect(measurement.isReachable == true)
            }
        }
        
        // Verify SwiftData integrity - all targets should have exactly 5 measurements
        for target in testTargets {
            #expect(target.measurements.count == 5)
        }
    }
    
    @Test("High load concurrent monitoring simulation", .timeLimit(.minutes(3)))
    @MainActor
    func highLoadConcurrentMonitoring() async throws {
        // Setup
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

        // Create 20 targets for high load test
        var testTargets: [NetworkTarget] = []
        for i in 0..<20 {
            let target = NetworkTarget(
                name: "HighLoadTarget\(i)",
                address: "load\(i).test.com",
                targetProtocol: .icmp,
                port: nil,
                checkInterval: 1, // Fast interval for stress test
                isEnabled: true
            )
            testTargets.append(target)
            container.mainContext.insert(target)
        }
        try container.mainContext.save()
        
        let updateCounter = UpdateCounter()
        
        // Simulate rapid concurrent updates
        await withTaskGroup(of: Void.self) { group in
            for target in testTargets {
                group.addTask {
                    // Rapid fire 10 updates per target
                    for i in 0..<10 {
                        let measurement = TargetMeasurement(
                            latency: Double(i * 5 + 1),
                            isReachable: true,
                            errorMessage: nil
                        )
                        
                        await session.testUpdateMeasurement(measurement, for: target)
                        await updateCounter.increment()
                    }
                }
            }
        }
        
        // Verify all 200 updates were processed (20 targets × 10 updates each)
        let totalUpdates = await updateCounter.count
        #expect(totalUpdates == 200)
        
        // Verify no data corruption - latestResults should have 20 entries
        #expect(session.latestResults.count == 20)
        
        // Verify latest measurements are correct
        for target in testTargets {
            let measurement = session.latestMeasurement(for: target.id)
            #expect(measurement != nil)
            
            if let measurement = measurement {
                // Should be from last update (index 9), so latency should be 46 (9 * 5 + 1)
                #expect(measurement.latency == 46.0)
                #expect(measurement.isReachable == true)
                #expect(measurement.errorMessage == nil)
            }
            
            // Verify SwiftData integrity
            #expect(target.measurements.count == 10)
        }
    }
    
    @Test("Mixed protocol concurrent updates", .timeLimit(.minutes(2)))
    @MainActor 
    func mixedProtocolConcurrentUpdates() async throws {
        // Setup
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

        // Create targets with different protocols 
        var httpTargets: [NetworkTarget] = []
        var icmpTargets: [NetworkTarget] = []
        var tcpTargets: [NetworkTarget] = []
        
        for i in 0..<5 {
            let httpTarget = NetworkTarget(
                name: "HTTP\(i)",
                address: "http\(i).test.com", 
                targetProtocol: .http,
                port: 80,
                checkInterval: 5,
                isEnabled: true
            )
            httpTargets.append(httpTarget)
            container.mainContext.insert(httpTarget)
            
            let icmpTarget = NetworkTarget(
                name: "ICMP\(i)",
                address: "icmp\(i).test.com",
                targetProtocol: .icmp,
                port: nil,
                checkInterval: 5,
                isEnabled: true
            )
            icmpTargets.append(icmpTarget)
            container.mainContext.insert(icmpTarget)
            
            let tcpTarget = NetworkTarget(
                name: "TCP\(i)",
                address: "tcp\(i).test.com",
                targetProtocol: .tcp,
                port: 443,
                checkInterval: 5,
                isEnabled: true
            )
            tcpTargets.append(tcpTarget)
            container.mainContext.insert(tcpTarget)
        }
        try container.mainContext.save()
        
        let allTargets = httpTargets + icmpTargets + tcpTargets
        
        // Concurrent updates across different protocol types
        await withTaskGroup(of: Void.self) { group in
            // HTTP updates
            group.addTask {
                for target in httpTargets {
                    for i in 0..<3 {
                        let measurement = TargetMeasurement(
                            latency: Double(100 + i * 20),
                            isReachable: i != 1, // Make middle one fail
                            errorMessage: i == 1 ? "HTTP Error" : nil
                        )
                        await session.testUpdateMeasurement(measurement, for: target)
                        try? await Task.sleep(for: .milliseconds(5))
                    }
                }
            }
            
            // ICMP updates
            group.addTask {
                for target in icmpTargets {
                    for i in 0..<3 {
                        let measurement = TargetMeasurement(
                            latency: Double(50 + i * 10),
                            isReachable: true,
                            errorMessage: nil
                        )
                        await session.testUpdateMeasurement(measurement, for: target)
                        try? await Task.sleep(for: .milliseconds(3))
                    }
                }
            }
            
            // TCP updates
            group.addTask {
                for target in tcpTargets {
                    for i in 0..<3 {
                        let measurement = TargetMeasurement(
                            latency: Double(75 + i * 15),
                            isReachable: i % 2 == 0,
                            errorMessage: i % 2 != 0 ? "TCP Timeout" : nil
                        )
                        await session.testUpdateMeasurement(measurement, for: target)
                        try? await Task.sleep(for: .milliseconds(7))
                    }
                }
            }
        }
        
        // Verify all targets have final measurements
        #expect(session.latestResults.count == 15)
        
        // Verify protocol-specific final states
        for httpTarget in httpTargets {
            let measurement = session.latestMeasurement(for: httpTarget.id)
            #expect(measurement?.latency == 140.0) // 100 + 2*20
            #expect(measurement?.isReachable == true) // Last iteration (i=2)
            #expect(measurement?.errorMessage == nil)
        }
        
        for icmpTarget in icmpTargets {
            let measurement = session.latestMeasurement(for: icmpTarget.id)
            #expect(measurement?.latency == 70.0) // 50 + 2*10
            #expect(measurement?.isReachable == true)
            #expect(measurement?.errorMessage == nil)
        }
        
        for tcpTarget in tcpTargets {
            let measurement = session.latestMeasurement(for: tcpTarget.id)
            #expect(measurement?.latency == 105.0) // 75 + 2*15
            #expect(measurement?.isReachable == true) // i=2, 2%2==0
            #expect(measurement?.errorMessage == nil)
        }
    }
}

/// Helper actor to safely track task completion across concurrent operations
actor TaskCompletionTracker {
    private var completedTasks: Set<UUID> = []
    
    func markTaskComplete(for targetId: UUID) {
        completedTasks.insert(targetId)
    }
    
    var completedTaskCount: Int {
        completedTasks.count
    }
}

/// Helper actor to safely count updates across concurrent operations
actor UpdateCounter {
    private var _count: Int = 0
    
    func increment() {
        _count += 1
    }
    
    var count: Int {
        _count
    }
}

/// Test-only extension to expose updateMeasurement for testing
extension MonitoringSession {
    /// Test-only method to directly update measurements and stress the latestResults dictionary
    func testUpdateMeasurement(_ measurement: TargetMeasurement, for target: NetworkTarget) async {
        // This calls the private @MainActor updateMeasurement method to test concurrency safety
        await updateMeasurement(measurement, for: target)
    }
}