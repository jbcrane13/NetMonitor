#!/usr/bin/env swift

import Foundation

// Simplified test to reproduce MonitoringSession behavior

struct NetworkTarget {
    let id: String
    let name: String
    let host: String
    let timeout: Double
    let checkInterval: Double
    let targetProtocol: String
    
    init(id: String = UUID().uuidString, name: String, host: String, timeout: Double = 3.0, checkInterval: Double = 5.0, targetProtocol: String = "icmp") {
        self.id = id
        self.name = name
        self.host = host
        self.timeout = timeout
        self.checkInterval = checkInterval
        self.targetProtocol = targetProtocol
    }
}

struct TargetMeasurement {
    let latency: Double?
    let isReachable: Bool
    let errorMessage: String?
}

class ICMPMonitorService {
    func check(target: NetworkTarget) async throws -> TargetMeasurement {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/sbin/ping")
        process.arguments = [
            "-c", "1",
            "-W", String(Int(target.timeout * 1000)),
            target.host
        ]
        
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        
        try process.run()
        process.waitUntilExit()
        
        let output = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        let isReachable = process.terminationStatus == 0 && !output.contains("100% packet loss")
        
        // Extract latency from output if available
        var latency: Double? = nil
        if isReachable {
            let lines = output.components(separatedBy: .newlines)
            for line in lines {
                if line.contains("time=") {
                    let parts = line.components(separatedBy: "time=")
                    if parts.count > 1 {
                        let timeStr = parts[1].components(separatedBy: " ")[0]
                        latency = Double(timeStr)
                        break
                    }
                }
            }
        }
        
        return TargetMeasurement(
            latency: latency,
            isReachable: isReachable,
            errorMessage: isReachable ? nil : "Host unreachable"
        )
    }
}

class TestMonitoringSession {
    var isMonitoring: Bool = false
    var latestResults: [String: TargetMeasurement] = [:]
    private var monitoringTasks: [String: Task<Void, Never>] = [:]
    
    let icmpService = ICMPMonitorService()
    
    func startMonitoring(targets: [NetworkTarget]) {
        guard !isMonitoring else { return }
        
        isMonitoring = true
        print("Started monitoring \(targets.count) targets")
        
        for target in targets {
            startMonitoringTarget(target)
        }
    }
    
    func stopMonitoring() {
        guard isMonitoring else { return }
        
        isMonitoring = false
        print("Stopped monitoring")
        
        for task in monitoringTasks.values {
            task.cancel()
        }
        monitoringTasks.removeAll()
    }
    
    func latestMeasurement(for targetID: String) -> TargetMeasurement? {
        return latestResults[targetID]
    }
    
    private func startMonitoringTarget(_ target: NetworkTarget) {
        // Cancel any existing task for this target
        monitoringTasks[target.id]?.cancel()
        
        let task = Task { [weak self] in
            await self?.monitorTarget(target)
            return ()
        }
        
        monitoringTasks[target.id] = task
    }
    
    private func monitorTarget(_ target: NetworkTarget) async {
        print("Started monitoring \(target.name) (\(target.host))")
        
        while !Task.isCancelled && isMonitoring {
            print("Checking \(target.name)...")
            
            do {
                let measurement = try await icmpService.check(target: target)
                
                print("  Result: \(measurement.isReachable ? "REACHABLE" : "UNREACHABLE")")
                if let latency = measurement.latency {
                    print("  Latency: \(String(format: "%.1f", latency))ms")
                }
                if let error = measurement.errorMessage {
                    print("  Error: \(error)")
                }
                
                latestResults[target.id] = measurement
                
            } catch {
                print("  Exception: \(error)")
                let failedMeasurement = TargetMeasurement(
                    latency: nil,
                    isReachable: false,
                    errorMessage: error.localizedDescription
                )
                latestResults[target.id] = failedMeasurement
            }
            
            // Wait for check interval
            print("  Waiting \(target.checkInterval)s until next check...")
            try? await Task.sleep(nanoseconds: UInt64(target.checkInterval * 1_000_000_000))
        }
        
        print("Stopped monitoring \(target.name)")
    }
}

// Test main function
Task {
    print("Testing MonitoringSession behavior with short intervals...\n")
    
    let targets = [
        NetworkTarget(name: "Cloudflare DNS", host: "1.1.1.1", checkInterval: 2.0),
        NetworkTarget(name: "Google DNS", host: "8.8.8.8", checkInterval: 2.0),
        NetworkTarget(name: "Invalid Host", host: "invalid.host.doesnotexist", checkInterval: 2.0)
    ]
    
    let session = TestMonitoringSession()
    
    session.startMonitoring(targets: targets)
    
    // Let it run for a while to see if there are any issues
    print("Running monitoring for 10 seconds...")
    try await Task.sleep(nanoseconds: 10_000_000_000)
    
    print("\nLatest results:")
    for target in targets {
        if let measurement = session.latestMeasurement(for: target.id) {
            print("  \(target.name): \(measurement.isReachable ? "REACHABLE" : "UNREACHABLE")")
            if let latency = measurement.latency {
                print("    Latency: \(String(format: "%.1f", latency))ms")
            }
            if let error = measurement.errorMessage {
                print("    Error: \(error)")
            }
        } else {
            print("  \(target.name): NO MEASUREMENT")
        }
    }
    
    session.stopMonitoring()
    
    try await Task.sleep(nanoseconds: 1_000_000_000)
    exit(0)
}

RunLoop.main.run()