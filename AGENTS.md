# NETMONITOR KNOWLEDGE BASE

**Generated:** 2026-01-15 | **Commit:** 594d7a3 | **Branch:** main

## OVERVIEW

macOS 15+ network monitoring app with real-time diagnostics, device discovery, and iOS companion communication. Swift 6 with SwiftUI, SwiftData, and actor-based concurrency.

## COMMANDS

```bash
# Build
xcodebuild -project NetMonitor.xcodeproj -scheme NetMonitor -configuration Debug build

# Run all tests
xcodebuild -project NetMonitor.xcodeproj -scheme NetMonitor test

# Run single test file (Swift Testing)
xcodebuild test -project NetMonitor.xcodeproj -scheme NetMonitor \
  -only-testing:NetMonitorTests/HTTPMonitorServiceTests

# Run single test method
xcodebuild test -project NetMonitor.xcodeproj -scheme NetMonitor \
  -only-testing:NetMonitorTests/HTTPMonitorServiceTests/checkReachableTarget

# Run tests matching pattern
xcodebuild test -project NetMonitor.xcodeproj -scheme NetMonitor \
  -only-testing:NetMonitorTests -test-filter="HTTP"

# Clean build
xcodebuild -project NetMonitor.xcodeproj -scheme NetMonitor clean

# Build shared package
swift build --package-path NetMonitorShared
```

## CODE STYLE

### Imports
```swift
import Foundation          // System frameworks first
import SwiftUI             // No blank lines between imports
import SwiftData
import NetMonitorShared    // Local modules last
```

### File Organization
1. Imports (system frameworks first, local modules last)
2. Type declaration with `///` doc comment
3. MARK sections: Properties → Dependencies → Initialization → Public API → Private Methods
4. Subviews as separate structs
5. `#Preview` at end of file

### Naming Conventions
| Type | Convention | Example |
|------|------------|---------|
| Types | PascalCase | `NetworkTarget`, `HTTPMonitorService` |
| Properties/Methods | camelCase | `isMonitoring`, `startMonitoring()` |
| Protocols | Noun or -able/-ible | `NetworkMonitorService`, `Sendable` |
| Actors | Suffix with `Service` | `HTTPMonitorService`, `ARPScannerService` |
| Coordinators | Suffix with `Session`/`Coordinator` | `MonitoringSession` |

### Concurrency Patterns
```swift
// Services MUST be actors
actor HTTPMonitorService: NetworkMonitorService {
    func check(target: NetworkTarget) async throws -> TargetMeasurement
}

// UI coordinators use @MainActor + @Observable
@MainActor
@Observable
final class MonitoringSession {
    private(set) var isMonitoring: Bool = false
}

// SwiftData models are @unchecked Sendable - confine to MainActor
@Model
final class NetworkTarget: @unchecked Sendable { }
```

### Error Handling
```swift
// Use typed errors with CustomStringConvertible
enum NetworkMonitorError: Error, CustomStringConvertible {
    case invalidHost(String)
    case timeout
    
    var description: String {
        switch self {
        case .invalidHost(let host): return "Invalid host: \(host)"
        case .timeout: return "Request timed out"
        }
    }
}

// Return error state, don't throw for expected failures
return TargetMeasurement(latency: nil, isReachable: false, errorMessage: "...")
```

### SwiftUI Views
```swift
struct MyView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(MonitoringSession.self) private var session
    @Query(sort: \NetworkTarget.name) private var targets: [NetworkTarget]
    
    var body: some View {
        // Prefer computed properties for complex subviews
    }
}

#Preview {
    MyView()
        .modelContainer(PreviewContainer().container)
}
```

### Testing (Swift Testing Framework)
```swift
import Testing
@testable import NetMonitor

@Suite("HTTP Monitor Service Tests")
struct HTTPMonitorServiceTests {
    
    @Test("HTTP monitor can check reachable target")
    func checkReachableTarget() async throws {
        let service = HTTPMonitorService()
        let target = NetworkTarget(name: "Test", host: "example.com", targetProtocol: .https)
        
        let measurement = try await service.check(target: target)
        
        #expect(measurement.isReachable == true)
        #expect(measurement.latency != nil)
    }
}
```

## STRUCTURE

```
NetMonitor/
├── Services/        # Actor-based network services (see Services/AGENTS.md)
├── Views/           # SwiftUI views (Dashboard, Targets, Devices, Tools, Settings)
├── Models/          # SwiftData @Model entities (5 files)
├── MenuBar/         # NSStatusItem integration (3 files)
└── NetMonitorApp.swift
NetMonitorShared/    # Swift Package for iOS companion
NetMonitorTests/     # Unit tests (Swift Testing framework)
```

## ANTI-PATTERNS

| Don't | Do Instead |
|-------|------------|
| Class for NetworkMonitorService | Actor (protocol requires it) |
| Access @Model across actors | Confine to MainActor context |
| Raw ICMP sockets | Use `ICMPSocket` actor (wraps /sbin/ping) |
| ObservableObject + @Published | @Observable macro (Observation framework) |
| Combine for async | async/await |
| XCTest assertions | Swift Testing #expect() |

## KEY PATTERNS

### Service Protocol (Actor-constrained)
```swift
protocol NetworkMonitorService: Actor {
    func check(target: NetworkTarget) async throws -> TargetMeasurement
}
```

### ResumeTracker for Continuation Safety
Used in ARPScanner/Bonjour to prevent double-resume:
```swift
final class ResumeTracker: @unchecked Sendable {
    private let lock = NSLock()
    private var _hasResumed = false
    func tryResume() -> Bool { /* NSLock guarded */ }
}
```

## NOTES

- **UI testing mode**: Launch with `--uitesting` to skip service init
- **ModelContainer fatalError**: App crashes if SwiftData container fails
- **Companion service**: `_netmon._tcp` on port 8849, JSON protocol

## Landing the Plane (Session Completion)

**When ending a work session**, you MUST complete ALL steps below. Work is NOT complete until `git push` succeeds.

**MANDATORY WORKFLOW:**

1. **File issues for remaining work** - Create issues for anything that needs follow-up
2. **Run quality gates** (if code changed) - Tests, linters, builds
3. **Update issue status** - Close finished work, update in-progress items
4. **PUSH TO REMOTE** - This is MANDATORY:
   ```bash
   git pull --rebase
   git push
   git status  # MUST show "up to date with origin"
   ```
5. **Clean up** - Clear stashes, prune remote branches
6. **Verify** - All changes committed AND pushed
7. **Hand off** - Provide context for next session

**CRITICAL RULES:**
- Work is NOT complete until `git push` succeeds
- NEVER stop before pushing - that leaves work stranded locally
- NEVER say "ready to push when you are" - YOU must push
- If push fails, resolve and retry until it succeeds
