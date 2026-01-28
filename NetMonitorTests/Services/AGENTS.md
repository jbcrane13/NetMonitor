<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-01-28 | Updated: 2026-01-28 -->

# Services

## Purpose

This directory contains unit tests for all service layer components in NetMonitor, including:
- **Actor services** (HTTPMonitorService, TCPMonitorService, ARPScannerService, BonjourDiscoveryService, etc.)
- **Shell command execution** (ShellCommandRunner, ProcessPingService)
- **Data coordinators** (MonitoringSession, DeviceDiscoveryCoordinator) - @MainActor observable classes
- **Protocol definitions** (NetworkMonitorService, DeviceDiscoveryService)
- **Utility services** (MACVendorLookupService, CompanionService)

All tests follow Swift Testing framework patterns with async/await and proper actor isolation. Tests ensure service behavior correctness, error handling, timeout management, and streaming functionality.

**Framework:** Swift Testing (`import Testing`)
**Test Types:** Unit tests for services and coordinators
**Patterns:** Async/await, actor isolation, @MainActor context, SwiftData in-memory models

---

## Key Files

| File | Component | Tests | Status |
|------|-----------|-------|--------|
| `MonitoringSessionTests.swift` | MonitoringSession (@MainActor coordinator) | Session creation, start/stop, service initialization (DI) | COMPLETE |
| `HTTPMonitorServiceTests.swift` | HTTPMonitorService (actor) | Reachable targets, unreachable hosts, timeout handling, HTTP/HTTPS | COMPLETE |
| `TCPMonitorServiceTests.swift` | TCPMonitorService (actor) | Port connectivity, latency measurement, timeout behavior | COMPLETE |
| `ProcessPingServiceTests.swift` | ProcessPingService (actor) | Ping execution, streaming results, multi-packet, cancellation | COMPLETE |
| `ShellCommandRunnerTests.swift` | ShellCommandRunner (actor) | Command execution, arguments, error handling, streaming, timeout, cancel | COMPLETE |
| `ARPScannerServiceTests.swift` | ARPScannerService (actor) | IP range calculation, /24 subnets, /16 limits, edge cases, custom timeout | COMPLETE |
| `BonjourDiscoveryServiceTests.swift` | BonjourDiscoveryService (actor) | mDNS service discovery, browsing, service resolution | COMPLETE |
| `DeviceDiscoveryCoordinatorTests.swift` | DeviceDiscoveryCoordinator (@MainActor) | Initial state, merge results, create new devices, scan progress, offline marking | COMPLETE |
| `DeviceDiscoveryServiceTests.swift` | DeviceDiscoveryService (protocol) | Protocol conformance, service interface validation | COMPLETE |
| `CompanionServiceTests.swift` | CompanionService (actor) | Bonjour service advertising, message handling | COMPLETE |
| `MACVendorLookupServiceTests.swift` | MACVendorLookupService (actor) | Vendor lookup, OUI database, MAC format handling, case sensitivity | COMPLETE |
| `NetworkMonitorServiceTests.swift` | NetworkMonitorService (protocol) | Protocol interface, measurement types, async conformance | COMPLETE |

---

## Test Organization

### Coordinator Tests (MainActor)

These test @MainActor observable classes that coordinate multiple services:

- **MonitoringSessionTests.swift** (2 tests)
  - Session lifecycle (creation, start, stop)
  - Service initialization with dependency injection
  - Requires: ModelContainer setup, MainActor context

- **DeviceDiscoveryCoordinatorTests.swift** (6 tests)
  - Initial state validation
  - Result merging logic (update existing, create new)
  - Scan progress tracking
  - Offline device marking
  - Requires: ModelContainer setup, MainActor context, SwiftData models

### Actor Service Tests

Tests for individual service actors that handle specific responsibilities:

**Monitoring Services:**
- **HTTPMonitorServiceTests.swift** (3 tests) - HTTP/HTTPS health checks, timeouts
- **TCPMonitorServiceTests.swift** - TCP port connectivity (inherited interface)
- **ProcessPingServiceTests.swift** (6 tests) - Shell-based ICMP ping with streaming
- **ShellCommandRunnerTests.swift** (6 tests) - Generic shell command execution, streaming, timeouts

**Discovery Services:**
- **ARPScannerServiceTests.swift** (6 tests) - IP range calculation, subnet parsing, timeout configuration
- **BonjourDiscoveryServiceTests.swift** - mDNS service discovery
- **CompanionServiceTests.swift** - Bonjour service advertising

**Utility Services:**
- **MACVendorLookupServiceTests.swift** (8 tests) - OUI database lookup with format handling
- **NetworkMonitorServiceTests.swift** - Protocol interface validation

### Protocol Tests

- **DeviceDiscoveryServiceTests.swift** - Discovery protocol conformance

---

## For AI Agents

### Working In This Directory

**Before writing or modifying tests:**

1. **Choose test type based on component:**
   - **Actor service:** Async test function, fresh service instance, no MainActor
   - **Coordinator:** Async or sync, @MainActor attribute, ModelContainer setup
   - **Protocol:** Test file in Services/ directory (not Protocol/)

2. **Pattern: Actor service test**
   ```swift
   @Suite("ServiceName Tests")
   struct ServiceNameTests {
       @Test("Description of what is tested")
       func testName() async throws {
           let service = ServiceName()
           let result = try await service.method(param: value)
           #expect(result == expected)
       }
   }
   ```

3. **Pattern: Coordinator test with MainActor**
   ```swift
   @Suite("CoordinatorName Tests")
   struct CoordinatorNameTests {
       @Test("Description")
       @MainActor
       func testName() throws {
           let container = try ModelContainer(
               for: DataModel.self,
               configurations: ModelConfiguration(isStoredInMemoryOnly: true)
           )
           let coordinator = CoordinatorName(
               modelContext: container.mainContext,
               service1: Service1(),
               service2: Service2()
           )
           #expect(coordinator.property == value)
       }
   }
   ```

4. **Pattern: Async error testing**
   ```swift
   @Test("Handles errors")
   func errorTest() async throws {
       let service = ServiceName()
       await #expect(throws: ServiceError.self) {
           try await service.failingMethod()
       }
   }
   ```

5. **Pattern: Streaming results**
   ```swift
   @Test("Collects streamed output")
   func streamTest() async throws {
       var results: [String] = []
       for try await line in await service.stream(host: "127.0.0.1") {
           results.append(line)
       }
       #expect(results.count > 0)
   }
   ```

6. **Key imports:**
   ```swift
   import Testing           // @Suite, @Test, #expect, Issue
   import Foundation        // Date, String, etc.
   import SwiftData         // ModelContainer, ModelConfiguration (if needed)
   @testable import NetMonitor  // Service/coordinator under test
   ```

### Common Patterns

**Pattern: Testing timeout behavior**
```swift
@Test("Respects timeout")
func timeoutTest() async throws {
    let service = HTTPMonitorService()
    let target = NetworkTarget(
        name: "Slow",
        host: "10.255.255.1",
        targetProtocol: .http,
        timeout: 1.0
    )
    let startTime = Date()
    let measurement = try await service.check(target: target)
    let duration = Date().timeIntervalSince(startTime)

    #expect(measurement.isReachable == false)
    #expect(duration < 2.0)
}
```

**Pattern: Testing actor isolation**
```swift
@Test("Scanner initializes with default timeout")
func defaultTimeout() async {
    let scanner = ARPScannerService()
    let timeout = await scanner.timeout
    #expect(timeout == 1.0)  // Access via await
}
```

**Pattern: Testing result merging in coordinator**
```swift
@Test("Merge updates existing device")
@MainActor
func mergeUpdatesExisting() throws {
    let container = try ModelContainer(
        for: LocalDevice.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    let context = container.mainContext

    // Insert existing device
    let existing = LocalDevice(
        ipAddress: "192.168.1.100",
        macAddress: "AA:BB:CC:DD:EE:FF",
        hostname: nil,
        vendor: nil,
        deviceType: .unknown
    )
    context.insert(existing)

    let coordinator = DeviceDiscoveryCoordinator(
        modelContext: context,
        arpScanner: ARPScannerService(),
        bonjourScanner: BonjourDiscoveryService()
    )

    // Merge with new data
    let discovered = DiscoveredDevice(
        ipAddress: "192.168.1.100",
        macAddress: "AA:BB:CC:DD:EE:FF",
        hostname: "new-hostname.local"
    )
    coordinator.mergeDiscoveredDevices([discovered])

    // Verify update
    let devices = try context.fetch(FetchDescriptor<LocalDevice>())
    #expect(devices.first?.hostname == "new-hostname.local")
}
```

**Pattern: Testing SwiftData queries**
```swift
@Test("Marks offline devices")
@MainActor
func markOfflineDevices() throws {
    let container = try ModelContainer(
        for: LocalDevice.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    let context = container.mainContext

    // Create test data
    let device1 = LocalDevice(ipAddress: "192.168.1.100", isOnline: true)
    let device2 = LocalDevice(ipAddress: "192.168.1.101", isOnline: true)
    context.insert(device1)
    context.insert(device2)
    try context.save()

    // Perform action
    coordinator.markOfflineDevices(currentIPs: Set(["192.168.1.100"]))

    // Verify results
    let devices = try context.fetch(FetchDescriptor<LocalDevice>())
    let device2Updated = devices.first { $0.ipAddress == "192.168.1.101" }
    #expect(device2Updated?.isOnline == false)
}
```

### Testing Requirements

**Mandatory for all tests:**

1. **Async/await:** Call `await` on all actor methods
   ```swift
   let result = try await service.method()  // Not try service.method()
   ```

2. **Fresh instances:** Create new service for each test (no shared state)
   ```swift
   let service = HTTPMonitorService()  // Fresh per test
   ```

3. **MainActor for coordinators:** Use @MainActor attribute
   ```swift
   @Test("Coordinator test")
   @MainActor
   func coordinatorTest() throws { ... }
   ```

4. **In-memory models:** Always use in-memory ModelContainer
   ```swift
   ModelConfiguration(isStoredInMemoryOnly: true)
   ```

5. **Error assertions:** Use `await #expect(throws:)` for async errors
   ```swift
   await #expect(throws: ToolError.self) {
       try await runner.run("/nonexistent/command", arguments: [])
   }
   ```

6. **Timeout testing:** Use reasonable timeouts and verify completion
   ```swift
   let measurement = try await service.check(target: target)
   #expect(measurement.isReachable == false)
   ```

7. **Streaming:** Iterate with `for try await` and verify result count
   ```swift
   var lines: [String] = []
   for try await line in await runner.stream("/bin/echo", arguments: ["test"]) {
       lines.append(line)
   }
   #expect(lines.count > 0)
   ```

8. **Expectations:** Always use `#expect()` macro (Swift Testing)
   ```swift
   #expect(result == expected)
   #expect(array.isEmpty)
   #expect(string.contains("text"))
   ```

### Service-Specific Patterns

**HTTPMonitorService:**
- Test with real internet hosts (google.com) for connectivity
- Test unreachable with non-existent domains
- Test timeout with non-routable IPs (10.255.255.1)
- Verify HTTP status code ranges (200-399 = reachable)

**ProcessPingService:**
- Use localhost (127.0.0.1) for reliable success tests
- Test unreachable with non-routable IPs (192.0.2.1)
- Test streaming with multiple packet count
- Test cancellation by calling cancel() from separate task
- Verify latency values: minLatency ≤ avgLatency ≤ maxLatency

**ShellCommandRunner:**
- Test with system binaries (/bin/echo, /bin/sleep, /usr/bin/whoami)
- Test error with /nonexistent/command
- Test streaming with newline-delimited output
- Test timeout and cancellation
- Verify stdout/stderr/exitCode in returned output

**ARPScannerService:**
- Test IP range calculation with /24 subnets (254 IPs)
- Test /16 limits to reasonable range
- Test edge cases: invalid IP, invalid mask → empty range
- Test custom timeout via constructor

**DeviceDiscoveryCoordinator:**
- Create ModelContainer with LocalDevice model
- Test merge logic: updates existing, creates new
- Test scan progress tracking (0.0 → 1.0)
- Test offline marking with IP sets

**MACVendorLookupService:**
- Test known vendors: Apple (00:03:93), Samsung, Google, Cisco, Raspberry Pi
- Test MAC formats: colons, dashes, no separators, uppercase/lowercase
- Test unknown/invalid MACs → nil
- All tests can run without await (actor is internal state only)

---

## Dependencies

**Test Framework:**
- `Testing` - Swift Testing framework (macOS 15.0+)

**Product Dependencies:**
- `NetMonitor` - Service and coordinator implementations

**System Frameworks:**
- `SwiftData` - Persistence models (in-memory for tests)
- `Foundation` - Date, String, URL, URLSession
- `Network` - NWConnection for TCP service

**No external dependencies** - All tests use system binaries and in-memory data

---

## Running Tests

**Run all services tests:**
```bash
xcodebuild -project NetMonitor.xcodeproj -scheme NetMonitor test -only NetMonitorTests/Services
```

**Run specific test file:**
```bash
xcodebuild -project NetMonitor.xcodeproj -scheme NetMonitor test -only NetMonitorTests/HTTPMonitorServiceTests
```

**Run from Xcode:**
- Navigate to Services/ folder in test navigator
- Cmd+U to run all tests
- Click diamond icon to run single test

**Filter by test name:**
```bash
xcodebuild -project NetMonitor.xcodeproj -scheme NetMonitor test -only NetMonitorTests/ProcessPingServiceTests/pingLocalhostSucceeds
```

---

## Recent Changes

**January 19, 2026:** Dependency injection refactoring
- MonitoringSession now accepts httpService, icmpService, tcpService in constructor
- DeviceDiscoveryCoordinator now accepts arpScanner, bonjourScanner in constructor
- Tests updated to pass services explicitly (see MonitoringSessionTests, DeviceDiscoveryCoordinatorTests)
- Services are no longer created internally; they're injected at initialization

---

## Notes for AI Agents

- **Flaky tests:** Network-dependent tests may timeout; use appropriate timeouts (1-5 seconds)
- **Localhost for ping:** Always use 127.0.0.1 for reliable ping tests; it never fails
- **No database persistence:** All coordinator tests use in-memory models; no side effects
- **Fresh instances:** Never reuse service instances across tests; create new each time
- **Actor safety:** Properly await all actor method calls; Swift concurrency is enforced
- **Streaming cancellation:** Cancel from separate Task to avoid blocking the test
- **Error messages:** Optional errorMessage fields should be non-nil for error cases

<!-- MANUAL: Add integration test suite when services are combined in workflows -->
