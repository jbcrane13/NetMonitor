<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-01-28 | Updated: 2026-01-28 -->

# NetMonitorTests

## Purpose

Unit test suite for the NetMonitor application using Swift Testing framework. Tests cover service layer (actors), data coordinators (@MainActor observable classes), protocol definitions, and critical business logic. All tests use structured concurrency patterns with async/await.

**Testing Framework:** Swift Testing (`import Testing`)
**Test Types:** Service unit tests, integration tests, data model tests, protocol tests
**Coverage Target:** 80%+ for service layer and critical paths

---

## Key Files

| File | Description |
|------|-------------|
| `NetMonitorTests.swift` | Root test suite setup and placeholder example test |
| `Services/` | 12 service-specific test suites (see subdirectory below) |
| `Protocol/CompanionMessageTests.swift` | Companion app message protocol encoding/decoding tests |

---

## Subdirectories

| Directory | Purpose |
|-----------|---------|
| `Services/` | 12 test files covering service actors and coordinators (13 total including root) |
| `Protocol/` | Message protocol tests for iOS companion app communication |

### Services/ (12 test files)

| Test File | Tested Component | Key Tests |
|-----------|------------------|-----------|
| `MonitoringSessionTests.swift` | MonitoringSession (@MainActor coordinator) | Session creation, start/stop lifecycle, service initialization |
| `HTTPMonitorServiceTests.swift` | HTTPMonitorService (actor) | Reachable targets, unreachable targets, timeout handling, HTTP status codes |
| `TCPMonitorServiceTests.swift` | TCPMonitorService (actor) | Port connectivity, timeout behavior, latency measurement |
| `ProcessPingServiceTests.swift` | ProcessPingService (actor) | Ping execution, streaming results, timeout, cancellation |
| `ShellCommandRunnerTests.swift` | ShellCommandRunner (actor) | Command execution, arguments, error handling, streaming, timeout, cancellation |
| `ARPScannerServiceTests.swift` | ARPScannerService (actor) | IP range calculation, subnet parsing, scanning state, edge cases |
| `BonjourDiscoveryServiceTests.swift` | BonjourDiscoveryService (actor) | Service discovery, mDNS browsing, service resolution |
| `DeviceDiscoveryCoordinatorTests.swift` | DeviceDiscoveryCoordinator (@MainActor) | Coordinator state, result merging, device deduplication, persistence |
| `DeviceDiscoveryServiceTests.swift` | DeviceDiscoveryService (protocol) | Protocol conformance tests, service interface validation |
| `CompanionServiceTests.swift` | CompanionService (actor) | Message handling, state updates, command processing |
| `MACVendorLookupServiceTests.swift` | MACVendorLookupService (actor) | Vendor lookup, OUI database queries, unknown vendors |
| `NetworkMonitorServiceTests.swift` | NetworkMonitorService (protocol) | Protocol interface, measurement types, async conformance |

### Protocol/ (1 test file)

| Test File | Tested Component | Key Tests |
|-----------|------------------|-----------|
| `CompanionMessageTests.swift` | CompanionMessage (NetMonitorShared) | Status update encoding, command encoding, device list decoding, error messages |

---

## For AI Agents

### Working In This Directory

**Before writing or modifying tests:**

1. **Understand test patterns:**
   - Service actor tests use `async throws` and `await` for actor isolation
   - Coordinator tests require `@MainActor` context and SwiftData ModelContainer
   - Use in-memory models: `ModelConfiguration(isStoredInMemoryOnly: true)`
   - Protocol tests use `@testable import NetMonitorShared`

2. **Test naming convention:**
   - Suite name: `@Suite("Component Name Tests")`
   - Test name: `@Test("Descriptive action and expected result")`
   - Async tests: Mark `async throws` in function signature
   - MainActor tests: Add `@MainActor` attribute above function

3. **File organization:**
   - One test file per service/component (e.g., `HTTPMonitorServiceTests.swift`)
   - Grouping: Services in `Services/`, protocol tests in `Protocol/`
   - No test utilities subdirectory yet (keep helper code at top of test file)

4. **Key imports:**
   ```swift
   import Testing           // @Suite, @Test, #expect, Issue
   import Foundation        // Date, String, etc.
   import SwiftData         // ModelContainer, ModelConfiguration
   @testable import NetMonitor       // Service/coordinator under test
   @testable import NetMonitorShared // Protocol tests
   ```

### Testing Requirements

**Mandatory for all service tests:**

1. **Async safety:** All tests call `await` on actor methods
2. **Isolation:** Use separate service instances for each test (no shared state)
3. **Timeout handling:** Test timeout path with realistic values (1-2 second timeouts)
4. **Error cases:** Include negative tests (unreachable hosts, invalid inputs, timeouts)
5. **MainActor safety:** Coordinator tests run in @MainActor context
6. **SwiftData setup:** Use in-memory ModelContainer for isolation
7. **Expectations:** Use `#expect()` macro, not `XCTAssert*`
8. **Assertions on errors:** Use `await #expect(throws: ErrorType.self) { ... }`

**Common assertion patterns:**

```swift
// Basic expectation
#expect(value == expected)
#expect(array.isEmpty)
#expect(string.contains("substring"))

// Error expectation
await #expect(throws: ToolError.self) {
    try await service.failingOperation()
}

// Optional unwrapping with expectation
if let unwrapped = optional {
    #expect(unwrapped == value)
} else {
    Issue.record("Expected non-nil value")
}

// Case matching for enums
if case .statusUpdate(let payload) = message {
    #expect(payload.isMonitoring == true)
} else {
    Issue.record("Expected statusUpdate message")
}
```

### Common Patterns

**1. Setting up an actor service test:**
```swift
@Suite("ServiceName Tests")
struct ServiceNameTests {
    @Test("Description")
    func testName() async throws {
        let service = ServiceName()  // Create fresh instance
        let result = try await service.method(param: value)
        #expect(result == expected)
    }
}
```

**2. Setting up a MainActor coordinator test:**
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
        let coordinator = CoordinatorName(modelContext: container.mainContext)
        #expect(coordinator.property == value)
    }
}
```

**3. Testing async throws with await #expect:**
```swift
@Test("Handles error condition")
func errorTest() async throws {
    let service = MyService()
    await #expect(throws: MyError.self) {
        try await service.failingOperation()
    }
}
```

**4. Testing timeout behavior:**
```swift
@Test("Respects timeout")
func timeoutTest() async throws {
    let service = MyService(timeout: 1.0)
    await #expect(throws: TimeoutError.self) {
        try await service.slowOperation()
    }
}
```

**5. Testing streaming results:**
```swift
@Test("Collects streamed output")
func streamTest() async throws {
    var results: [String] = []
    for try await line in await service.stream(command: "cmd") {
        results.append(line)
    }
    #expect(results.count > 0)
}
```

**6. Testing enum encoding/decoding:**
```swift
@Test("Encode/decode message")
func messageTest() throws {
    let message = CompanionMessage.statusUpdate(payload)
    let data = try JSONEncoder().encode(message)
    let decoded = try JSONDecoder().decode(CompanionMessage.self, from: data)

    if case .statusUpdate(let p) = decoded {
        #expect(p.isMonitoring == true)
    } else {
        Issue.record("Wrong message type")
    }
}
```

---

## Dependencies

**Test Framework:**
- `Testing` - Swift Testing framework (macOS 15.0+, standard library)

**Product Dependencies:**
- `NetMonitor` - Main app target with services and coordinators
- `NetMonitorShared` - Shared protocol definitions for companion app

**System Frameworks:**
- `SwiftData` - Data persistence (in-memory for tests)
- `Foundation` - Date, String, URL handling

**Test-Only Dependencies:**
- None (all test utilities created inline in test files)

---

## Test Execution

**Run all tests:**
```bash
xcodebuild -project NetMonitor.xcodeproj -scheme NetMonitor test
```

**Run specific test file:**
```bash
xcodebuild -project NetMonitor.xcodeproj -scheme NetMonitor test -only NetMonitorTests/HTTPMonitorServiceTests
```

**Run from Xcode:**
- Cmd+U to run all tests
- Click diamond icon on test to run single test

---

## Notes for AI Agents

- **Dependency Injection:** As of January 19, 2026, MonitoringSession and DeviceDiscoveryCoordinator use constructor dependency injection for services (see recent activity in Services/CLAUDE.md)
- **Memory Models:** Always use `isStoredInMemoryOnly: true` for ModelContainer in tests to avoid database side effects
- **Concurrency:** Tests properly isolate service actors; never reuse instances across tests
- **Flakiness:** Network-dependent tests (HTTP, TCP) may timeout; use reasonable timeouts (2-5 seconds)
- **Shell Commands:** ShellCommandRunner tests use system binaries (`/bin/echo`, `/bin/sleep`) for reliability

<!-- MANUAL: Add integration test suite when E2E testing is added -->
