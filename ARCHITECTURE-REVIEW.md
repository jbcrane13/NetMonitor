# NetMonitor 2.0 Architectural Review

**Date:** February 13, 2026  
**Review Scope:** Complete codebase analysis for 2.0 refactoring  
**Target:** macOS 15.0+, Swift 6 readiness

---

## Executive Summary

NetMonitor is a well-structured macOS network monitoring application built with SwiftUI, SwiftData, and modern concurrency patterns. The codebase demonstrates good architectural separation with a clear 3-tier structure (Models, Services, Views). However, there are significant opportunities for improvement in Swift 6 compliance, dependency injection, service layer architecture, and code reusability.

**Overall Grade:** B+ (Solid foundation with room for architectural improvements)

**Key Strengths:**
- ✅ Clear separation of concerns (Models/Services/Views)
- ✅ Actor-based service isolation for thread safety
- ✅ SwiftData integration with versioned schemas
- ✅ Comprehensive feature set (monitoring, discovery, tools)
- ✅ Companion app protocol infrastructure

**Critical Areas for Improvement:**
- ⚠️ Swift 6 concurrency compliance (`@unchecked Sendable` usage)
- ⚠️ Lack of centralized dependency injection
- ⚠️ God objects in coordinator classes
- ⚠️ View complexity and duplication
- ⚠️ Companion protocol versioning and error recovery
- ⚠️ Testing infrastructure and coverage

---

## 1. Architecture Overview

### 1.1 High-Level Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                      NetMonitorApp                          │
│  - Entry point                                              │
│  - Service initialization (manual DI)                       │
│  - Environment injection                                    │
└──────────────────┬──────────────────────────────────────────┘
                   │
         ┌─────────┴─────────┐
         │                   │
┌────────▼────────┐   ┌─────▼──────────┐
│  Views Layer    │   │  Services      │
│  (SwiftUI)      │   │  (Business     │
│                 │   │   Logic)       │
│ - Dashboard     │   │                │
│ - Targets       │◄──┤ - Monitoring   │
│ - Devices       │   │ - Discovery    │
│ - Tools         │   │ - Companion    │
│ - Settings      │   │ - Network      │
└────────┬────────┘   └────────┬───────┘
         │                     │
         │    ┌────────────────┘
         │    │
┌────────▼────▼────────┐
│   Models Layer       │
│   (SwiftData)        │
│                      │
│ - NetworkTarget      │
│ - TargetMeasurement  │
│ - LocalDevice        │
│ - SessionRecord      │
└──────────────────────┘

┌──────────────────────────────────┐
│  NetMonitorShared (Framework)    │
│  - CompanionMessage protocol     │
│  - Shared enums                  │
└──────────────────────────────────┘
```

### 1.2 Module Structure

**Main App (76 Swift files, ~11,391 lines)**
- **Models** (8 files): SwiftData models + DTOs
- **Services** (24 files, ~4,732 lines): Business logic, actors
- **Views** (31 files, ~6,659 lines): SwiftUI interfaces
- **Utilities** (4 files): Helpers, extensions
- **MenuBar** (3 files): Menu bar integration

**NetMonitorShared (3 files)**
- Protocol definitions for iOS companion
- Shared enums (TargetProtocol, DeviceType, etc.)

**Tests** (~124 total Swift files including tests)
- Unit tests for services
- Protocol tests
- UI tests (limited)

### 1.3 Data Flow

```
User Action (View)
    ↓
Environment-injected Service
    ↓
Actor-isolated async operation
    ↓
Return Sendable DTO
    ↓
@MainActor: Update SwiftData model
    ↓
SwiftUI automatic view refresh (@Query)
```

**Example: Target Monitoring Flow**
1. `MonitoringSession.startMonitoring()` → Fetch targets from SwiftData
2. For each target → Extract `TargetCheckRequest` (Sendable DTO)
3. Call `NetworkMonitorService.check()` → Actor-isolated network call
4. Return `MeasurementResult` (Sendable DTO)
5. Convert to `TargetMeasurement` @Model on @MainActor
6. Save to SwiftData → SwiftUI reactivity updates views

---

## 2. Code Quality Analysis

### 2.1 Strengths

**1. Actor Isolation Pattern**
All network services are actors, preventing data races:
```swift
actor HTTPMonitorService: NetworkMonitorService { ... }
actor ICMPMonitorService: NetworkMonitorService { ... }
actor TCPMonitorService: NetworkMonitorService { ... }
```

**2. Sendable DTO Pattern**
Services use Sendable DTOs to cross actor boundaries:
```swift
struct TargetCheckRequest: Sendable { ... }
struct MeasurementResult: Sendable { ... }
```

**3. Protocol-Based Architecture**
- `NetworkMonitorService` protocol allows polymorphic service selection
- `DeviceDiscoveryService` protocol for discovery abstraction

**4. SwiftData Schema Versioning**
Future-ready migration infrastructure:
```swift
enum NetMonitorMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [SchemaV1.self]
    }
}
```

### 2.2 Critical Issues

#### Issue #1: `@unchecked Sendable` Anti-Pattern

**Location:** `NetworkTarget`, `TargetMeasurement`, `LocalDevice`

**Problem:**
```swift
@Model
final class NetworkTarget: @unchecked Sendable { ... }
```

SwiftData `@Model` classes are not inherently thread-safe. Using `@unchecked Sendable` to bypass compiler checks is **dangerous** and violates Swift 6 strict concurrency.

**Risk Level:** 🔴 **HIGH**
- Potential data races when models are accessed from multiple actors
- SwiftData models should only be accessed from their `ModelContext`'s actor
- False sense of thread safety

**Recommended Fix:**
- Remove `@unchecked Sendable` conformances
- Always extract Sendable DTOs before crossing actor boundaries
- Document that models are `@MainActor`-bound

#### Issue #2: No Centralized Dependency Injection

**Location:** `NetMonitorApp.setupServices()`

**Problem:**
Services are manually instantiated in app setup:
```swift
let httpService = HTTPMonitorService()
let icmpService = ICMPMonitorService()
let tcpService = TCPMonitorService()
let arpScanner = ARPScannerService()
// ...
```

**Issues:**
- Hard to test (can't inject mocks)
- Tight coupling between app and service implementations
- Service lifetimes manually managed
- Difficult to maintain as app grows

**Recommended Fix:**
- Implement a DI container (e.g., `ServiceRegistry`)
- Protocol-based service registration
- Simplify `setupServices()` to one-liner

#### Issue #3: God Objects

**Location:** `MonitoringSession`, `DeviceDiscoveryCoordinator`

**MonitoringSession Responsibilities:**
1. State management (isMonitoring, latestResults)
2. Target monitoring orchestration
3. Service selection logic
4. Measurement persistence
5. Statistics computation
6. Data pruning
7. Session lifecycle management

**DeviceDiscoveryCoordinator Responsibilities:**
1. Scan orchestration
2. ARP + Bonjour coordination
3. Result merging
4. Device persistence
5. Name resolution
6. Vendor lookup
7. Offline device management

**Risk Level:** 🟡 **MEDIUM**

**Recommended Fix:**
- Extract statistics computation to `StatisticsService` (already exists but unused)
- Extract data pruning to `DataManagementService`
- Separate orchestration from persistence
- Use composed services instead of monolithic coordinators

#### Issue #4: View Complexity

**Location:** `DevicesView.swift` (789 lines)

**Problem:**
Massive view file with embedded sub-views:
- `DevicesView` (main view)
- `DevicePingSheet` (159 lines)
- `DevicePortScanSheet` (228 lines)

**Issues:**
- Hard to test
- Hard to reuse
- Violates single responsibility
- Poor maintainability

**Recommended Fix:**
- Extract sheets to separate files
- Use ViewModels for complex logic
- Extract reusable components

#### Issue #5: Service Pattern Inconsistency

**Examples:**

**Pattern A: Actor with protocol**
```swift
actor HTTPMonitorService: NetworkMonitorService { ... }
```

**Pattern B: @MainActor @Observable**
```swift
@MainActor
@Observable
final class MonitoringSession { ... }
```

**Pattern C: Actor without protocol**
```swift
actor CompanionService { ... }
```

**Pattern D: Regular class (no isolation)**
```swift
final class MACVendorLookupService { ... }
```

**Risk Level:** 🟡 **MEDIUM**

**Recommended Fix:**
- Standardize service patterns
- Document when to use each pattern
- Consistent protocol adoption

#### Issue #6: Code Duplication in Tool Views

All tool views follow similar patterns but duplicate code:
- `PingToolView.swift`
- `TracerouteToolView.swift`
- `PortScannerToolView.swift`
- `DNSLookupToolView.swift`
- `WHOISToolView.swift`
- `SpeedTestToolView.swift`

**Common Pattern:**
1. State management (isRunning, results)
2. Terminal-style output display
3. Run/Stop buttons
4. Progress indicators
5. Copy/Clear actions

**Recommended Fix:**
- Extract `ToolViewBase` protocol
- Create `TerminalOutputView` component
- Shared `ToolViewModel` base class

---

## 3. Swift 6 Concurrency Compliance

### 3.1 Current Status

**Compliance Score:** 60% ⚠️

**Compliant Areas:**
- ✅ Actor-based services
- ✅ Sendable DTO pattern for cross-actor communication
- ✅ `@MainActor` annotation on view-bound classes
- ✅ Task-based async/await usage

**Non-Compliant Areas:**
- ❌ `@unchecked Sendable` on SwiftData models
- ❌ Captures of mutable state in async closures
- ❌ Missing `Sendable` conformance on some service types
- ❌ Non-isolated async methods on `@MainActor` classes

### 3.2 Specific Issues

#### Issue #1: SwiftData Model Sendability
```swift
// ❌ Current (unsafe)
@Model
final class NetworkTarget: @unchecked Sendable { ... }

// ✅ Recommended
@Model
@MainActor
final class NetworkTarget { ... }

// Extract Sendable DTO before crossing actors
struct NetworkTargetDTO: Sendable {
    let id: UUID
    let name: String
    let host: String
    // ...
}
```

#### Issue #2: Closure Captures

**Location:** `CompanionService.receiveMessage`

```swift
// Current (potentially unsafe)
connection.receive(...) { data, _, isComplete, error in
    Task {
        await self?.processReceivedData(data, clientID: clientID)
    }
}
```

**Issue:** Captures `self` and `clientID` in escaping closure without explicit `Sendable` check.

**Fix:** Already implemented (uses `nonisolated` + captured values before closure)

#### Issue #3: ContinuationTracker Pattern

**Location:** `Utilities/ContinuationTracker.swift`

The `ContinuationTracker` class is used to prevent double-resumption of continuations but isn't marked `Sendable`:

```swift
// Should be:
final class ContinuationTracker: @unchecked Sendable {
    private let _hasResumed = Atomic<Bool>(false)
    // ...
}
```

### 3.3 Recommendations

1. **Enable Strict Concurrency Checks**
   - Add `SWIFT_STRICT_CONCURRENCY = complete` to build settings
   - Fix all warnings before 2.0 release

2. **Audit All `@unchecked Sendable`**
   - Document why each is necessary
   - Plan migration away from unchecked conformances

3. **MainActor Isolation**
   - All SwiftData access must be `@MainActor`
   - Views should assume `@MainActor` context

---

## 4. SwiftData Model Design Review

### 4.1 Schema Design

**Models:**
1. **NetworkTarget** - Monitoring targets
2. **TargetMeasurement** - Time-series data
3. **LocalDevice** - Discovered network devices
4. **SessionRecord** - Monitoring session lifecycle

**Relationships:**
```swift
NetworkTarget (1) ←→ (∞) TargetMeasurement
```

**Analysis:**
- ✅ Cascade delete rule properly configured
- ✅ Inverse relationships defined
- ✅ Schema versioning infrastructure in place
- ⚠️ No indexes defined (potential performance issue)
- ⚠️ Large measurement arrays could cause memory issues

### 4.2 Data Retention

**Current:** Manual pruning via `MonitoringSession.pruneOldMeasurements()`
- Runs hourly during active monitoring
- User-configurable retention (1 day, 7 days, 30 days, Forever)

**Issues:**
1. Pruning only runs during active monitoring
2. No automatic pruning on app launch
3. Could accumulate millions of records before pruning
4. No compound indexes for efficient time-based queries

**Recommendations:**
1. Add automatic pruning on app launch
2. Add compound index: `@Index([\.target, \.timestamp])`
3. Consider aggregating old measurements (e.g., hourly rollups)
4. Implement background pruning task

### 4.3 Query Performance

**Current Queries:**
```swift
@Query(sort: \NetworkTarget.name) private var targets: [NetworkTarget]
@Query(sort: \LocalDevice.lastSeen, order: .reverse) private var devices: [LocalDevice]
```

**Missing Indexes:**
- `NetworkTarget.isEnabled` (frequently filtered)
- `TargetMeasurement.timestamp` (time-series queries)
- `LocalDevice.isOnline` (filter queries)

**Recommended:**
```swift
@Model
final class NetworkTarget {
    #Index<NetworkTarget>([\.isEnabled])
    #Index<NetworkTarget>([\.createdAt])
    // ...
}

@Model
final class TargetMeasurement {
    #Index<TargetMeasurement>([\.timestamp])
    #Index<TargetMeasurement>([\.target, \.timestamp])
    // ...
}
```

---

## 5. Service Layer Analysis

### 5.1 Service Inventory

**Monitoring Services (Actor-based):**
1. `HTTPMonitorService` - HTTP/HTTPS checks
2. `ICMPMonitorService` - ICMP ping (via ProcessPingService)
3. `TCPMonitorService` - TCP port checks

**Discovery Services (Actor-based):**
1. `ARPScannerService` - ARP table scanning
2. `BonjourDiscoveryService` - mDNS/Bonjour discovery

**Coordinator Services (@MainActor):**
1. `MonitoringSession` - Monitoring orchestration
2. `DeviceDiscoveryCoordinator` - Discovery orchestration
3. `CompanionMessageHandler` - Protocol handler

**Support Services (mixed patterns):**
1. `CompanionService` (actor) - Bonjour TCP server
2. `NetworkInfoService` - Network interface info
3. `ISPLookupService` - ISP identification
4. `MACVendorLookupService` - OUI lookup
5. `DeviceNameResolver` - DNS reverse lookup
6. `WakeOnLanService` - Magic packet sender
7. `NotificationService` - User notifications
8. `SpeedTestService` - Bandwidth testing
9. `PortScanService` - Port scanning
10. `StatisticsService` - Unused!
11. `ProcessPingService` - Shell command wrapper
12. `ShellCommandRunner` - Generic shell executor
13. `DefaultTargetsProvider` - Seed data

### 5.2 Protocol Adoption

**Good:**
```swift
protocol NetworkMonitorService: Actor {
    func check(request: TargetCheckRequest) async throws -> MeasurementResult
}
```

**Missing:**
- No `VendorLookupService` protocol
- No `NameResolutionService` protocol
- No `SpeedTestService` protocol
- Difficult to mock for testing

### 5.3 Dependency Injection

**Current State:** Manual injection in `NetMonitorApp.setupServices()`

**Partial DI Pattern:**
```swift
init(
    modelContext: ModelContext,
    serviceProvider: MonitorServiceProviding = DefaultMonitorServiceProvider()
) { ... }
```

**Good:** Provides testability hook

**Issue:** Only `MonitoringSession` uses this pattern

**Recommendation:**
1. Create `ServiceRegistry` singleton
2. Protocol-based registration
3. Lazy initialization
4. Lifetime management (singleton, transient, scoped)

**Example:**
```swift
@MainActor
final class ServiceRegistry {
    static let shared = ServiceRegistry()
    
    func register<T>(_ type: T.Type, factory: @escaping () -> T)
    func resolve<T>(_ type: T.Type) -> T
}

// Registration (in app setup)
ServiceRegistry.shared.register(NetworkInfoService.self) { NetworkInfoService() }

// Resolution (in views/services)
let networkInfo = ServiceRegistry.shared.resolve(NetworkInfoService.self)
```

### 5.4 Error Handling

**Good Examples:**
```swift
enum NetworkMonitorError: Error, CustomStringConvertible {
    case invalidHost(String)
    case timeout
    case permissionDenied
    case networkUnreachable
    case unknownError(Error)
}
```

**Issues:**
1. Multiple error enums (`NetMonitorError`, `NetworkMonitorError`, `DeviceDiscoveryError`, `ToolError`)
2. No unified error handling strategy
3. Error messages not localized
4. No error reporting/telemetry

**Recommendation:**
- Consolidate to single `AppError` hierarchy
- Add error codes for tracking
- Implement error reporting service
- Localize all user-facing error messages

---

## 6. View Layer Analysis

### 6.1 View Architecture

**Navigation Pattern:** Split view with sidebar
```
SidebarView (NavigationSplitView)
    ├── Dashboard
    ├── Targets
    ├── Devices
    ├── Tools
    └── Settings
```

**State Management:**
- `@Environment` for shared services
- `@Query` for SwiftData
- `@State` for local view state
- `@Bindable` for model binding
- `@Observable` for custom objects

**Good:**
- ✅ Proper use of SwiftUI observation
- ✅ Environment-based dependency injection
- ✅ Declarative UI composition

**Issues:**
- ⚠️ Large view files (DevicesView: 789 lines)
- ⚠️ Inline child views (hard to test/reuse)
- ⚠️ Business logic in views (should be in ViewModels)
- ⚠️ Direct SwiftData access in views (no abstraction)

### 6.2 View Complexity Breakdown

| View | Lines | Complexity | Issues |
|------|-------|------------|--------|
| DevicesView | 789 | ⚠️ High | Embedded sheets, business logic |
| TargetsView | 289 | ✅ OK | Reasonable |
| DashboardView | 206 | ✅ OK | Reasonable |
| DeviceDetailView | ~200 | ⚠️ Medium | Could extract components |
| ToolsView | ~150 | ✅ OK | Container only |
| SettingsView | ~100 | ✅ OK | Tab container |

**Tool Views (each ~150-300 lines):**
- Similar patterns duplicated across 11 tool views
- Terminal output display duplicated
- State management duplicated

### 6.3 Reusability Analysis

**Reusable Components:**
1. `QuickStatsBar` ✅
2. `ConnectionInfoCard` ✅
3. `GatewayInfoCard` ✅
4. `ISPInfoCard` ✅
5. `LiveDurationView` ✅
6. `DeviceRowView` ✅
7. `TargetStatisticsView` ✅

**Missing Reusable Components:**
1. TerminalOutputView (for tool results)
2. ToolHeaderView (common tool header)
3. DeviceActionMenu (copy IP, wake, etc.)
4. StatusBadge (online/offline indicator)
5. LatencyIndicator (common metric display)

**Recommendation:**
Create shared `Components/` directory with:
- `Terminal/TerminalView.swift`
- `Badges/StatusBadge.swift`
- `Metrics/LatencyView.swift`
- `Menus/DeviceContextMenu.swift`

### 6.4 Accessibility

**Good:**
- `accessibilityIdentifier` used for UI testing
- Proper use of `Label` with system images

**Missing:**
- No `accessibilityLabel` for complex controls
- No `accessibilityHint` for non-obvious actions
- No VoiceOver testing evidence
- No Dynamic Type testing

**Recommendation:**
- Audit all views for VoiceOver compatibility
- Add accessibility labels/hints
- Test with Dynamic Type sizes
- Add accessibility guidelines to CONTRIBUTING.md

---

## 7. Companion Protocol Analysis

### 7.1 Protocol Design

**Transport:** TCP over Bonjour (`_netmon._tcp`)
**Framing:** Length-prefixed (4-byte big-endian length + JSON payload)
**Encoding:** JSON with manual Codable implementation

**Message Types:**
```swift
enum CompanionMessage: Codable, Sendable {
    case statusUpdate(StatusUpdatePayload)
    case targetList(TargetListPayload)
    case deviceList(DeviceListPayload)
    case command(CommandPayload)
    case toolResult(ToolResultPayload)
    case error(ErrorPayload)
    case heartbeat(HeartbeatPayload)
}
```

**Good:**
- ✅ Enum-based type safety
- ✅ Sendable conformance
- ✅ Structured payloads
- ✅ Error messaging

**Issues:**
- ❌ No protocol versioning
- ❌ No backwards compatibility strategy
- ❌ No message ID / request-response correlation
- ❌ No compression (large device lists could be slow)
- ❌ No authentication/encryption
- ❌ Limited error recovery (just logs and drops connection)

### 7.2 Connection Management

**Current:**
- Server listens on port 8849
- Accepts multiple clients (UUID tracking)
- No reconnection logic
- No connection state recovery

**Issues:**
1. No graceful degradation on network changes
2. No client capability negotiation
3. No rate limiting
4. No connection timeout configuration

### 7.3 Recommendations

**Priority 1: Versioning**
```swift
struct MessageEnvelope: Codable {
    let version: Int
    let messageID: UUID
    let payload: CompanionMessage
}
```

**Priority 2: Error Recovery**
- Implement exponential backoff reconnection
- Add connection state machine
- Message queue for offline buffering

**Priority 3: Security**
- Add TLS encryption (NWParameters.tls)
- Implement device pairing mechanism
- Add message authentication

**Priority 4: Performance**
- Compress large payloads (zlib)
- Batch status updates
- Delta encoding for repeated data

---

## 8. Performance Concerns

### 8.1 Memory

**Potential Issues:**

1. **Measurement Accumulation**
   - Measurements stored in memory via `@Query`
   - No pagination for large datasets
   - `latestResults` dictionary grows unbounded during monitoring

2. **Device List**
   - All discovered devices loaded in memory
   - No virtual scrolling for large lists

3. **Service Instance Retention**
   - Services created at app launch, held for app lifetime
   - Some services could be lazily initialized

**Recommendations:**
1. Implement result pagination for measurements
2. Add `FetchDescriptor` limits to queries
3. Lazy service initialization via DI container
4. Monitor memory usage with Instruments

### 8.2 Network Performance

**Good:**
- ✅ Concurrent scanning (ARP scanner uses TaskGroup)
- ✅ Connection pooling disabled for accurate latency measurement
- ✅ Configurable timeouts

**Issues:**
1. **Sequential Monitoring Loop**
   ```swift
   for target in targets {
       startMonitoringTarget(target)
   }
   ```
   Each target gets its own Task, but creation is sequential.

2. **Bonjour Resolution Overhead**
   - Attempts lightweight resolution but still creates NWConnection per service
   - Could batch or cache results

3. **No Request Throttling**
   - Companion service has no rate limiting
   - Could be abused by misbehaving clients

**Recommendations:**
1. Batch target monitoring initialization
2. Cache DNS/hostname resolutions
3. Add rate limiting to companion service

### 8.3 Main Thread Work

**Analyzed with Instruments:** (assumed, not evidenced in code)

**Potential Blockers:**
1. SwiftData saves on main thread (blocking)
2. Large query results synchronously loaded
3. Image/icon rendering (if any)

**Current Mitigations:**
- Most network work is actor-isolated
- UI updates are reactive via SwiftUI

**Recommendations:**
1. Use background contexts for bulk saves
2. Add loading states for large queries
3. Profile with Time Profiler

---

## 9. Testing Infrastructure

### 9.1 Current Test Coverage

**Test Files Found:**
- `NetMonitorTests/` - Unit tests for services
- `NetMonitorTests/Models/` - Model tests
- `NetMonitorTests/Protocol/` - Protocol tests
- `NetMonitorTests/Services/` - Service tests
- `NetMonitorUITests/` - UI automation tests

**Test Structure:**
```
NetMonitorTests/
├── Models/
├── Protocol/
└── Services/

NetMonitorUITests/
├── Helpers/
├── Screens/
└── Tests/
```

**Good:**
- ✅ Organized test structure
- ✅ UI test infrastructure in place

**Unknown (need code review):**
- Coverage percentage
- Mock/stub usage
- Test quality and assertions

### 9.2 Testability Issues

**Hard to Test:**

1. **MonitoringSession**
   - Tightly coupled to ModelContext
   - No interface/protocol
   - Hard to inject mocks

2. **DeviceDiscoveryCoordinator**
   - Multiple dependencies (scanner, modelContext, resolver, vendor service)
   - Side effects (saves to database)

3. **Views**
   - Direct SwiftData access
   - Environment dependencies
   - Hard to unit test

**Recommendations:**

1. **Extract Protocols**
   ```swift
   protocol MonitoringSessionProtocol {
       var isMonitoring: Bool { get }
       func startMonitoring()
       func stopMonitoring()
       func latestMeasurement(for targetID: UUID) -> TargetMeasurement?
   }
   ```

2. **Mock ServiceRegistry**
   ```swift
   #if DEBUG
   extension ServiceRegistry {
       func registerMock<T>(_ type: T.Type, instance: T) { ... }
   }
   #endif
   ```

3. **ViewModels for Complex Views**
   ```swift
   @Observable
   final class DevicesViewModel {
       func scan() async { ... }
       func deleteDevice(_ device: LocalDevice) { ... }
   }
   ```

---

## 10. Documentation Quality

### 10.1 Code Documentation

**Found:**
- `README.md` - Project overview
- `CHANGELOG.md` - Release history
- `PRIVACY.md` - Privacy policy
- `AGENTS.md`, `CLAUDE.md` - AI assistant docs
- `QA-REPORT.md` - Testing notes
- Header comments on most files

**Missing:**
- Architecture decision records (ADRs)
- API documentation (DocC)
- Service integration guides
- Deployment documentation
- Performance benchmarks
- Troubleshooting guide

**Code Comments:**
- Reasonable inline comments
- Some functions documented
- Missing: complex algorithm explanations

**Recommendations:**
1. Generate DocC documentation
2. Add ADRs for major decisions
3. Create CONTRIBUTING.md
4. Document service contracts

---

## 11. Build & Configuration

### 11.1 Build Settings

**Target:** macOS 15.0+
**Language:** Swift 5.x (need to verify 6.0 readiness)

**Missing:**
- No CI/CD configuration visible
- No automated testing workflows
- No linting/formatting configuration (SwiftLint, SwiftFormat)
- No static analysis (e.g., Periphery for dead code)

**Recommendations:**
1. Add SwiftLint configuration
2. Set up GitHub Actions for CI
3. Enable Swift 6 strict concurrency warnings
4. Add code coverage reporting

### 11.2 Dependencies

**External Dependencies:**
- None visible (great! Minimizes supply chain risk)

**Internal Dependencies:**
- NetMonitorShared framework (clean separation)

**Recommendation:**
- Keep dependency-free or use SwiftPM for future additions
- Consider: Sentry for error tracking, Firebase for analytics (if needed)

---

## 12. Security Considerations

### 12.1 Current Security Posture

**Good:**
- ✅ App Sandbox enabled (uses /sbin/ping instead of raw sockets)
- ✅ No hardcoded credentials
- ✅ Network entitlements properly configured

**Concerns:**
1. **Companion Protocol**
   - No encryption (plaintext JSON over local network)
   - No authentication (anyone on network can connect)
   - No authorization (any client can execute commands)

2. **Network Scanning**
   - ARP scanning could be flagged as network reconnaissance
   - No user consent flow for aggressive scanning

3. **Shell Command Execution**
   - `ProcessPingService`, `ShellCommandRunner` execute system commands
   - Inputs appear sanitized but worth audit

**Recommendations:**
1. Add TLS to companion protocol
2. Implement device pairing (e.g., QR code + shared secret)
3. Add user consent for network scanning
4. Security audit of shell command construction

---

## 13. Conclusion

### 13.1 Overall Assessment

NetMonitor is a **well-architected application** with a solid foundation. The use of modern Swift concurrency, SwiftData, and SwiftUI shows good technical judgment. The service layer architecture is mostly sound, and the feature set is comprehensive.

However, the app has **accumulated technical debt** in areas like dependency injection, Swift 6 compliance, and view complexity. The 2.0 refactor is an excellent opportunity to address these issues before they become harder to fix.

### 13.2 Priority Ranking for 2.0

**Must Fix (P0):**
1. Remove `@unchecked Sendable` from models
2. Fix Swift 6 concurrency violations
3. Implement centralized DI container

**Should Fix (P1):**
1. Break up god objects (MonitoringSession, DeviceDiscoveryCoordinator)
2. Extract view logic to ViewModels
3. Add companion protocol versioning
4. Improve test coverage and testability

**Nice to Have (P2):**
1. Extract reusable view components
2. Consolidate tool view patterns
3. Add DocC documentation
4. Performance optimizations
5. Enhanced error handling

**Future (P3):**
1. Companion protocol encryption
2. Advanced analytics
3. Plugin architecture
4. Cloud sync

### 13.3 Success Metrics for 2.0

1. **Swift 6 Compliance:** 100% strict concurrency compliance
2. **Test Coverage:** >70% for services, >50% for views
3. **Code Quality:** SwiftLint score >90%
4. **Performance:** No main thread blocks >16ms
5. **Architecture:** All major services use DI container

---

**Next Steps:** See `REFACTORING-ROADMAP.md` for detailed implementation plan.
