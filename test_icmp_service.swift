#!/usr/bin/env swift

import Foundation

// Test to reproduce the issue using the actual NetMonitor code
// We can't import the NetMonitor module directly, so let's create a minimal version

class ProcessPingService {
    private let pingPath = "/sbin/ping"
    
    func ping(host: String, count: Int = 1, timeout: TimeInterval = 5) async throws -> PingResult {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: pingPath)
        process.arguments = [
            "-c", String(count),
            "-W", String(Int(timeout * 1000)), // macOS ping uses milliseconds for -W
            host
        ]
        
        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe
        
        let startTime = Date()
        
        try process.run()
        process.waitUntilExit()
        
        let duration = Date().timeIntervalSince(startTime)
        let stdout = String(data: stdoutPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        let stderr = String(data: stderrPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        
        print("Ping \(host) took \(duration)s, exit code: \(process.terminationStatus)")
        if !stdout.isEmpty { print("STDOUT: \(stdout)") }
        if !stderr.isEmpty { print("STDERR: \(stderr)") }
        
        let result = try parsePingOutput(stdout)
        print("Parsed result: isReachable=\(result.isReachable), avgLatency=\(String(describing: result.avgLatency))\n")
        
        return result
    }
    
    func parsePingOutput(_ output: String) throws -> PingResult {
        let lines = output.components(separatedBy: .newlines)
        
        var transmitted = 0
        var received = 0
        var packetLoss: Double = 100.0
        var avgLatency: Double = 0
        
        for line in lines {
            // Parse summary line: "1 packets transmitted, 1 received, 0.0% packet loss"
            if line.contains("packets transmitted") {
                let components = line.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
                if components.count >= 6 {
                    transmitted = Int(components[0]) ?? 0
                    received = Int(components[3]) ?? 0
                    let lossStr = components[5].replacingOccurrences(of: "%", with: "")
                    if let loss = Double(lossStr) {
                        packetLoss = loss
                    }
                }
            }
            
            // Parse statistics line: "round-trip min/avg/max/stddev = 14.1/15.2/17.8/1.4 ms"
            if line.contains("min/avg/max") {
                let parts = line.components(separatedBy: "=")
                if parts.count > 1 {
                    let stats = parts[1].trimmingCharacters(in: .whitespaces)
                    let values = stats.components(separatedBy: "/")
                    if values.count >= 2, let avg = Double(values[1]) {
                        avgLatency = avg
                    }
                }
            }
        }
        
        let isReachable = received > 0
        
        return PingResult(
            transmitted: transmitted,
            received: received,
            packetLoss: packetLoss,
            avgLatency: isReachable ? avgLatency : nil,
            isReachable: isReachable
        )
    }
}

struct PingResult {
    let transmitted: Int
    let received: Int
    let packetLoss: Double
    let avgLatency: Double?
    let isReachable: Bool
}

struct NetworkTarget {
    let name: String
    let host: String
    let timeout: Double
}

struct TargetMeasurement {
    let latency: Double?
    let isReachable: Bool
    let errorMessage: String?
}

class ICMPMonitorService {
    private let pingService = ProcessPingService()
    
    func check(target: NetworkTarget) async throws -> TargetMeasurement {
        do {
            let result = try await pingService.ping(
                host: target.host,
                count: 1,
                timeout: target.timeout
            )
            
            return TargetMeasurement(
                latency: result.isReachable ? result.avgLatency : nil,
                isReachable: result.isReachable,
                errorMessage: result.isReachable ? nil : "Host unreachable (100% packet loss)"
            )
            
        } catch {
            return TargetMeasurement(
                latency: nil,
                isReachable: false,
                errorMessage: "ICMP error: \(error.localizedDescription)"
            )
        }
    }
}

// Test main function
Task {
    print("Testing ICMPMonitorService behavior...\n")
    
    let targets = [
        NetworkTarget(name: "Cloudflare DNS", host: "1.1.1.1", timeout: 3.0),
        NetworkTarget(name: "Google DNS", host: "8.8.8.8", timeout: 3.0),
        NetworkTarget(name: "Google", host: "google.com", timeout: 3.0),
        NetworkTarget(name: "Localhost", host: "127.0.0.1", timeout: 3.0),
        NetworkTarget(name: "Invalid Host", host: "invalid.host.doesnotexist", timeout: 3.0)
    ]
    
    let service = ICMPMonitorService()
    
    for target in targets {
        print("Testing \(target.name) (\(target.host))...")
        
        do {
            let measurement = try await service.check(target: target)
            print("Result: \(measurement.isReachable ? "REACHABLE" : "UNREACHABLE")")
            if let latency = measurement.latency {
                print("Latency: \(String(format: "%.2f", latency))ms")
            }
            if let error = measurement.errorMessage {
                print("Error: \(error)")
            }
        } catch {
            print("Exception: \(error)")
        }
        
        print("---")
    }
    
    exit(0)
}

RunLoop.main.run()