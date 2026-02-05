#!/usr/bin/env swift

import Foundation

// Simple test to reproduce the reachability bug

func testPing(host: String, timeout: TimeInterval) async -> (isReachable: Bool, output: String, exitCode: Int32) {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/sbin/ping")
    process.arguments = [
        "-c", "1",
        "-W", String(Int(timeout * 1000)), // macOS ping uses milliseconds for -W
        host
    ]
    
    let pipe = Pipe()
    process.standardOutput = pipe
    process.standardError = pipe
    
    try! process.run()
    process.waitUntilExit()
    
    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    let output = String(data: data, encoding: .utf8) ?? ""
    
    let isReachable = process.terminationStatus == 0 && !output.contains("100% packet loss")
    
    return (isReachable: isReachable, output: output, exitCode: process.terminationStatus)
}

// Test targets
let targets = [
    ("Cloudflare DNS", "1.1.1.1", 3.0),
    ("Google DNS", "8.8.8.8", 3.0),
    ("Google", "google.com", 3.0),
    ("Invalid Host", "invalid.host.doesnotexist", 3.0)
]

// Run tests
Task {
    print("Testing reachability with NetMonitor-style ping calls...\n")
    
    for (name, host, timeout) in targets {
        print("Testing \(name) (\(host)) with timeout \(timeout)s...")
        
        let result = await testPing(host: host, timeout: timeout)
        
        print("Result: \(result.isReachable ? "REACHABLE" : "UNREACHABLE")")
        print("Exit code: \(result.exitCode)")
        print("Output:")
        print(result.output)
        print("---")
    }
    
    exit(0)
}

RunLoop.main.run()