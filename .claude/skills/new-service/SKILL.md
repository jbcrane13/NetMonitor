---
name: new-service
description: "Scaffold a new network monitoring service actor following NetMonitor conventions. Creates the service file and corresponding test file."
disable-model-invocation: true
---

# New Service Scaffolder for NetMonitor

Create a new actor-based network service following established project conventions.

## Gather Requirements

Ask the user (using AskUserQuestion) for:
1. **Service name** (e.g., "DNSMonitor" -> creates `DNSMonitorService.swift`)
2. **Purpose** - what does this service monitor or do?
3. **Conforms to NetworkMonitorService?** - Does it implement the standard `check(target:)` method?

## Service File Template

Create `NetMonitor/Services/<Name>Service.swift`:

```swift
import Foundation
import Network

/// <Brief description of what the service does>
actor <Name>Service: NetworkMonitorService {

    // MARK: - Properties

    // MARK: - NetworkMonitorService

    func check(target: NetworkTarget) async throws -> TargetMeasurement {
        let startTime = CFAbsoluteTimeGetCurrent()

        // TODO: Implement monitoring logic

        let latency = (CFAbsoluteTimeGetCurrent() - startTime) * 1000 // ms

        let measurement = TargetMeasurement(
            timestamp: Date(),
            latency: latency,
            isReachable: true,
            errorMessage: nil
        )
        measurement.target = target
        return measurement
    }
}
```

If the service does NOT conform to NetworkMonitorService, omit the protocol conformance and `check` method. Use an appropriate actor structure for the service's purpose.

## Test File Template

Create `NetMonitorTests/Services/<Name>ServiceTests.swift`:

```swift
import Testing
@testable import NetMonitor

@Suite("<Name>Service Tests")
struct <Name>ServiceTests {

    let service = <Name>Service()

    @Test("Service initializes successfully")
    func initialization() async throws {
        // Verify service can be created
        let _ = service
    }

    // TODO: Add specific test cases
}
```

## Key Conventions

Follow these project patterns strictly:
- **Services are always actors** (not classes, not structs)
- **Use `import Network`** if using NWConnection, NWListener, etc.
- **Use `async throws`** for all fallible async methods
- **Use `CFAbsoluteTimeGetCurrent()`** for latency measurement
- **Tests use Swift Testing** (`import Testing`, `@Suite`, `@Test`, `#expect`)
- **Tests do NOT use XCTest** (no XCTestCase, no XCTAssert)

## After Creation

Remind the user:
1. Add both files to the Xcode project (drag into Navigator or File > Add Files)
2. Ensure the service file is in the `NetMonitor` target
3. Ensure the test file is in the `NetMonitorTests` target
4. If the service needs to be injected, add it to `NetMonitorApp.swift` and pass via `.environment()`
