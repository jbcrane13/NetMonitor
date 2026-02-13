# NetMonitor 2.0 Refactoring Roadmap

**Version:** 2.0  
**Timeline:** Phased approach (estimated 4-6 weeks)  
**Last Updated:** February 13, 2026

---

## Overview

This roadmap outlines a phased refactoring plan for NetMonitor 2.0, prioritized by risk, impact, and dependencies. Each phase includes specific tasks, estimated effort, and success criteria.

**Guiding Principles:**
1. **Safety First:** Fix correctness issues before enhancements
2. **Incremental Progress:** Each phase delivers working software
3. **Test Coverage:** Add tests alongside refactoring
4. **No Regressions:** Maintain feature parity throughout

---

## Priority Definitions

- **P0 (Critical):** Bugs, correctness issues, data safety
- **P1 (High):** Architecture improvements, maintainability
- **P2 (Medium):** Code quality, developer experience
- **P3 (Low):** Nice-to-haves, future enhancements

---

## P0: Critical Fixes (Week 1)

### P0.1: Remove `@unchecked Sendable` from SwiftData Models

**Risk:** 🔴 **HIGH** - Potential data races, Swift 6 blocking issue

**Current Code:**
```swift
@Model
final class NetworkTarget: @unchecked Sendable { ... }
@Model
final class TargetMeasurement: @unchecked Sendable { ... }
@Model
final class LocalDevice: @unchecked Sendable { ... }
```

**Actions:**
1. ✅ Remove `@unchecked Sendable` conformances from all `@Model` classes
2. ✅ Add `@MainActor` annotation to all model classes
3. ✅ Audit all cross-actor model access
4. ✅ Ensure all SwiftData operations happen on `@MainActor`
5. ✅ Update documentation with threading rules

**Success Criteria:**
- No compiler warnings about Sendable violations
- All SwiftData access happens on main actor
- Manual audit confirms no data race potential

**Estimated Effort:** 4 hours

**Files to Modify:**
- `Models/NetworkTarget.swift`
- `Models/TargetMeasurement.swift`
- `Models/LocalDevice.swift`
- `Models/SessionRecord.swift`
- All service files that access models

---

### P0.2: Fix ContinuationTracker Sendability

**Risk:** 🟡 **MEDIUM** - Potential double-resume crashes

**Current Code:**
```swift
final class ContinuationTracker {
    private var hasResumed = false
    // ...
}
```

**Actions:**
1. ✅ Make `hasResumed` atomic using `OSAllocatedUnfairLock`
2. ✅ Add `@unchecked Sendable` conformance with documentation
3. ✅ Add unit tests for concurrent resume attempts
4. ✅ Document why `@unchecked Sendable` is safe here

**Success Criteria:**
- Thread-safe concurrent access
- Unit tests pass for race conditions
- Documented safety reasoning

**Estimated Effort:** 2 hours

**Files to Modify:**
- `Utilities/ContinuationTracker.swift`

---

### P0.3: Enable Swift 6 Strict Concurrency Checks

**Risk:** 🟡 **MEDIUM** - May expose hidden concurrency bugs

**Actions:**
1. ✅ Add `SWIFT_STRICT_CONCURRENCY = complete` to build settings
2. ✅ Fix all compiler errors and warnings
3. ✅ Run comprehensive testing
4. ✅ Document any remaining `@unchecked` usage

**Success Criteria:**
- Clean build with strict concurrency enabled
- All tests pass
- No warnings in Xcode

**Estimated Effort:** 8 hours (depends on issues found)

**Files to Modify:**
- `NetMonitor.xcodeproj/project.pbxproj`
- Various Swift files (TBD based on warnings)

---

### P0.4: Add SwiftData Indexes

**Risk:** 🟡 **MEDIUM** - Performance degradation with large datasets

**Current:** No indexes defined on models

**Actions:**
1. ✅ Add index on `NetworkTarget.isEnabled` (frequent filter)
2. ✅ Add compound index on `TargetMeasurement(target, timestamp)` (time-series queries)
3. ✅ Add index on `LocalDevice.isOnline` (frequent filter)
4. ✅ Add index on `LocalDevice.macAddress` (unique lookups)
5. ✅ Test migration from existing data
6. ✅ Benchmark query performance improvement

**Success Criteria:**
- Indexes created successfully
- No data loss during migration
- Query performance improved (measure with Instruments)

**Estimated Effort:** 4 hours

**Files to Modify:**
- `Models/NetworkTarget.swift`
- `Models/TargetMeasurement.swift`
- `Models/LocalDevice.swift`
- `Models/SchemaV1.swift` (bump to V2 if needed)

---

### P0.5: Fix Data Retention Issues

**Risk:** 🟡 **MEDIUM** - Unbounded data growth

**Current Issues:**
- Pruning only runs during active monitoring
- No pruning on app launch
- Could accumulate millions of records

**Actions:**
1. ✅ Add automatic pruning on app launch
2. ✅ Run pruning even when monitoring is stopped
3. ✅ Add background Task for periodic pruning
4. ✅ Log pruning activity
5. ✅ Add user preference for aggressive pruning

**Success Criteria:**
- Old data pruned even when monitoring disabled
- Pruning runs on schedule regardless of monitoring state
- No memory/storage leaks

**Estimated Effort:** 4 hours

**Files to Modify:**
- `Services/MonitoringSession.swift`
- `NetMonitorApp.swift`

---

## P1: Architecture Improvements (Week 2-3)

### P1.1: Implement Centralized Dependency Injection

**Benefit:** Testability, maintainability, loose coupling

**Design:**
```swift
@MainActor
final class ServiceRegistry {
    static let shared = ServiceRegistry()
    
    private var factories: [ObjectIdentifier: () -> Any] = [:]
    private var singletons: [ObjectIdentifier: Any] = [:]
    
    enum Lifetime {
        case singleton
        case transient
    }
    
    func register<T>(
        _ type: T.Type,
        lifetime: Lifetime = .singleton,
        factory: @escaping () -> T
    ) {
        let key = ObjectIdentifier(type)
        factories[key] = factory
        
        if lifetime == .singleton {
            singletons[key] = factory()
        }
    }
    
    func resolve<T>(_ type: T.Type) -> T {
        let key = ObjectIdentifier(type)
        
        if let singleton = singletons[key] as? T {
            return singleton
        }
        
        guard let factory = factories[key] else {
            fatalError("Service \(type) not registered")
        }
        
        return factory() as! T
    }
}
```

**Actions:**
1. ✅ Create `ServiceRegistry` class
2. ✅ Define service registration in `NetMonitorApp.setupServices()`
3. ✅ Update all views to use `@Environment(\.serviceRegistry)`
4. ✅ Extract service protocols where missing
5. ✅ Update tests to inject mocks via registry
6. ✅ Document DI patterns in ARCHITECTURE.md

**Success Criteria:**
- All services registered in one place
- Views use injected dependencies
- Tests can register mocks
- Zero service creation in views

**Estimated Effort:** 12 hours

**Files to Create:**
- `Infrastructure/ServiceRegistry.swift`
- `Infrastructure/EnvironmentValues+ServiceRegistry.swift`

**Files to Modify:**
- `NetMonitorApp.swift`
- All view files
- All service consumers

---

### P1.2: Break Up MonitoringSession God Object

**Current Responsibilities (7):**
1. State management
2. Target monitoring orchestration
3. Service selection
4. Persistence
5. Statistics computation
6. Data pruning
7. Session lifecycle

**Refactored Architecture:**
```
MonitoringCoordinator (orchestration)
    ├── MonitoringState (state management)
    ├── TargetMonitor (individual target monitoring)
    ├── MeasurementStore (persistence)
    └── StatisticsService (computation)
```

**Actions:**
1. ✅ Extract `MonitoringState` as separate `@Observable` class
2. ✅ Extract `MeasurementStore` for persistence operations
3. ✅ Use existing `StatisticsService` for calculations
4. ✅ Slim down `MonitoringSession` to pure orchestration
5. ✅ Update tests to test components independently
6. ✅ Update views to use new architecture

**Success Criteria:**
- Each class has single responsibility
- <200 lines per class
- Unit tests for each component
- No regressions in functionality

**Estimated Effort:** 16 hours

**Files to Create:**
- `Services/Monitoring/MonitoringState.swift`
- `Services/Monitoring/MeasurementStore.swift`
- `Services/Monitoring/TargetMonitor.swift`

**Files to Modify:**
- `Services/MonitoringSession.swift`
- Views that depend on MonitoringSession

---

### P1.3: Break Up DeviceDiscoveryCoordinator

**Current Responsibilities (7):**
1. Scan orchestration
2. ARP + Bonjour coordination
3. Result merging
4. Device persistence
5. Name resolution
6. Vendor lookup
7. Offline device management

**Refactored Architecture:**
```
DiscoveryCoordinator (orchestration)
    ├── DiscoveryState (state management)
    ├── DeviceMerger (result consolidation)
    ├── DeviceEnricher (name + vendor lookup)
    └── DeviceStore (persistence)
```

**Actions:**
1. ✅ Extract `DeviceMerger` for result merging logic
2. ✅ Extract `DeviceEnricher` for name/vendor enrichment
3. ✅ Extract `DeviceStore` for persistence
4. ✅ Slim down coordinator to orchestration only
5. ✅ Add unit tests for each component
6. ✅ Update views

**Success Criteria:**
- Clean separation of concerns
- Each class testable in isolation
- No functional regressions

**Estimated Effort:** 16 hours

**Files to Create:**
- `Services/Discovery/DeviceMerger.swift`
- `Services/Discovery/DeviceEnricher.swift`
- `Services/Discovery/DeviceStore.swift`

**Files to Modify:**
- `Services/DeviceDiscoveryCoordinator.swift`

---

### P1.4: Add Companion Protocol Versioning

**Risk:** 🟡 **MEDIUM** - Protocol evolution without breaking changes

**Design:**
```swift
struct MessageEnvelope: Codable, Sendable {
    let version: Int
    let messageID: UUID
    let timestamp: Date
    let payload: CompanionMessage
    
    static let currentVersion = 1
}
```

**Actions:**
1. ✅ Wrap all messages in versioned envelope
2. ✅ Add version negotiation handshake
3. ✅ Implement backwards compatibility layer
4. ✅ Add message ID for request-response correlation
5. ✅ Update iOS companion app
6. ✅ Document protocol versioning strategy

**Success Criteria:**
- Version 1 clients can connect
- Future versions can negotiate capabilities
- No breaking changes for existing clients

**Estimated Effort:** 8 hours

**Files to Modify:**
- `NetMonitorShared/Sources/NetMonitorShared/Protocol/CompanionMessage.swift`
- `Services/CompanionService.swift`
- `Services/CompanionMessageHandler.swift`

---

### P1.5: Improve Test Coverage

**Current Coverage:** Unknown (likely <50%)
**Target Coverage:** >70% for services, >50% for views

**Actions:**
1. ✅ Run code coverage analysis
2. ✅ Add unit tests for all service layer classes
3. ✅ Add unit tests for model extensions
4. ✅ Add integration tests for key workflows
5. ✅ Add snapshot tests for complex views (optional)
6. ✅ Configure CI to enforce minimum coverage

**Success Criteria:**
- >70% line coverage for Services/
- >50% line coverage for Views/
- All critical paths tested
- CI fails on coverage regression

**Estimated Effort:** 20 hours

**Files to Create:**
- Many new test files

---

## P2: Code Quality Improvements (Week 4)

### P2.1: Extract Reusable View Components

**Goal:** Reduce duplication, improve consistency

**Components to Extract:**

1. **TerminalOutputView**
   - Used by: Ping, Traceroute, DNS, WHOIS, Speed Test
   - Features: Scrollable output, monospaced font, auto-scroll

2. **ToolHeaderView**
   - Used by: All tool views
   - Features: Title, close button, target info

3. **StatusBadge**
   - Used by: Dashboard, Targets, Devices
   - Features: Colored dot + text

4. **MetricCard**
   - Used by: Dashboard cards
   - Features: Consistent metric display

**Actions:**
1. ✅ Create `Views/Components/` directory
2. ✅ Extract TerminalOutputView with generic output type
3. ✅ Extract ToolHeaderView with customization points
4. ✅ Extract StatusBadge with color/text binding
5. ✅ Extract MetricCard component
6. ✅ Update all consumers to use new components
7. ✅ Add preview providers for each component

**Success Criteria:**
- Reduced LOC in tool views by >30%
- Consistent UI across all tools
- Components have comprehensive previews
- No visual regressions

**Estimated Effort:** 12 hours

**Files to Create:**
- `Views/Components/TerminalOutputView.swift`
- `Views/Components/ToolHeaderView.swift`
- `Views/Components/StatusBadge.swift`
- `Views/Components/MetricCard.swift`

**Files to Modify:**
- All tool view files

---

### P2.2: Extract Tool View Logic to ViewModels

**Goal:** Testability, separation of concerns

**Pattern:**
```swift
@Observable
final class PingToolViewModel {
    @MainActor
    var results: [String] = []
    var isRunning: Bool = false
    
    func start(host: String) async {
        // Business logic
    }
    
    func stop() {
        // Cancellation logic
    }
}

struct PingToolView: View {
    @State private var viewModel = PingToolViewModel()
    
    var body: some View {
        // Pure UI, delegates to viewModel
    }
}
```

**Actions:**
1. ✅ Create ViewModels for each tool view
2. ✅ Move business logic from views to ViewModels
3. ✅ Add unit tests for ViewModels
4. ✅ Update views to use ViewModels
5. ✅ Document ViewModel pattern

**Success Criteria:**
- All tool views have ViewModels
- Views are <100 lines
- ViewModels have unit tests
- No business logic in views

**Estimated Effort:** 16 hours

**Files to Create:**
- `ViewModels/Tools/PingToolViewModel.swift`
- `ViewModels/Tools/TracerouteToolViewModel.swift`
- `ViewModels/Tools/PortScannerToolViewModel.swift`
- (etc. for all tools)

---

### P2.3: Consolidate Error Handling

**Current:** Multiple error enums scattered across files

**Proposed:**
```swift
enum AppError: LocalizedError, CustomStringConvertible {
    enum Category {
        case network
        case permission
        case validation
        case storage
    }
    
    case network(NetworkError)
    case permission(PermissionError)
    case validation(ValidationError)
    case storage(StorageError)
    
    var category: Category { ... }
    var errorDescription: String? { ... }
    var recoverySuggestion: String? { ... }
}

enum NetworkError: Error {
    case timeout
    case unreachable
    case invalidResponse
}
// ... etc
```

**Actions:**
1. ✅ Create unified `AppError` hierarchy
2. ✅ Migrate all existing errors to new hierarchy
3. ✅ Add localized error messages
4. ✅ Add recovery suggestions where applicable
5. ✅ Update error handling throughout app
6. ✅ Document error handling strategy

**Success Criteria:**
- Single error hierarchy
- All errors localized
- Consistent error presentation
- Better error messages for users

**Estimated Effort:** 8 hours

**Files to Create:**
- `Models/Errors/AppError.swift`
- `Models/Errors/NetworkError.swift`
- `Models/Errors/PermissionError.swift`
- `Models/Errors/ValidationError.swift`

**Files to Modify:**
- All service files
- All view files

---

### P2.4: Add SwiftLint Configuration

**Goal:** Consistent code style, catch common issues

**Actions:**
1. ✅ Add SwiftLint to project
2. ✅ Create `.swiftlint.yml` configuration
3. ✅ Fix all existing violations
4. ✅ Add SwiftLint to CI pipeline
5. ✅ Document code style guidelines

**Rules to Enable:**
- Line length: 120 characters
- Function length: 50 lines
- File length: 500 lines
- Cyclomatic complexity: 10
- Force unwrapping: warning
- Unused imports: error

**Success Criteria:**
- Zero SwiftLint errors
- <10 SwiftLint warnings
- CI enforces lint checks

**Estimated Effort:** 6 hours

**Files to Create:**
- `.swiftlint.yml`
- `.github/workflows/lint.yml` (if using GitHub Actions)

---

### P2.5: Extract Device Context Menu to Component

**Location:** Currently duplicated in DevicesView context menu

**Actions:**
1. ✅ Create `DeviceContextMenu` view
2. ✅ Support all actions (copy IP/MAC, ping, scan, wake, remove)
3. ✅ Add action callbacks via closures
4. ✅ Update DevicesView to use component
5. ✅ Add to other locations that show device actions

**Success Criteria:**
- Reusable across multiple views
- Consistent behavior
- Reduced duplication

**Estimated Effort:** 3 hours

**Files to Create:**
- `Views/Components/DeviceContextMenu.swift`

---

## P3: Nice-to-Haves (Week 5+)

### P3.1: Add DocC Documentation

**Actions:**
1. ✅ Enable DocC in build settings
2. ✅ Add documentation comments to all public APIs
3. ✅ Create documentation catalog
4. ✅ Add tutorials for common workflows
5. ✅ Generate and host documentation

**Estimated Effort:** 12 hours

---

### P3.2: Performance Optimizations

**Actions:**
1. ✅ Profile with Instruments (Time Profiler, Allocations)
2. ✅ Optimize hot paths identified
3. ✅ Add background contexts for bulk SwiftData operations
4. ✅ Implement result pagination for large datasets
5. ✅ Add caching layer for expensive operations

**Estimated Effort:** 16 hours

---

### P3.3: Enhanced Companion Protocol

**Features:**
1. ✅ Add TLS encryption
2. ✅ Implement device pairing (QR code + shared secret)
3. ✅ Add message compression for large payloads
4. ✅ Implement delta encoding for status updates
5. ✅ Add connection state recovery

**Estimated Effort:** 20+ hours

---

### P3.4: Accessibility Improvements

**Actions:**
1. ✅ Audit all views for VoiceOver compatibility
2. ✅ Add accessibility labels and hints
3. ✅ Test with all Dynamic Type sizes
4. ✅ Add keyboard navigation support
5. ✅ Test with assistive technologies

**Estimated Effort:** 8 hours

---

### P3.5: CI/CD Pipeline

**Actions:**
1. ✅ Set up GitHub Actions workflows
2. ✅ Automated testing on PR
3. ✅ Code coverage reporting
4. ✅ SwiftLint enforcement
5. ✅ Automated builds for releases

**Estimated Effort:** 6 hours

---

## Implementation Order

### Phase 1: Foundation (Week 1)
```
P0.1 → P0.2 → P0.3 → P0.4 → P0.5
```
**Goal:** Fix critical concurrency and data issues

### Phase 2: Architecture (Weeks 2-3)
```
P1.1 → (P1.2 || P1.3) → P1.4 → P1.5
```
**Goal:** Establish solid architectural patterns

### Phase 3: Quality (Week 4)
```
P2.1 → P2.2 → P2.3 → P2.4 → P2.5
```
**Goal:** Improve code quality and maintainability

### Phase 4: Polish (Week 5+)
```
P3.1 → P3.2 → P3.3 → P3.4 → P3.5
```
**Goal:** Add nice-to-haves, optimize, document

---

## Testing Strategy

Each phase must include:

1. **Unit Tests**
   - New functionality must have tests
   - Refactored code must maintain/improve coverage

2. **Integration Tests**
   - Key workflows tested end-to-end
   - Companion protocol compatibility

3. **Regression Testing**
   - All existing features continue to work
   - Performance doesn't degrade

4. **Manual QA**
   - Full app walkthrough
   - UI/UX validation
   - Accessibility testing

---

## Risk Mitigation

### High-Risk Changes
- **Concurrency model changes (P0.1-P0.3):** Extensive testing, manual verification
- **Service architecture changes (P1.1-P1.3):** Incremental refactoring, feature flags
- **Protocol versioning (P1.4):** Backwards compatibility testing

### Rollback Plan
- Each phase committed to separate branch
- Can revert individual phases if issues found
- Feature flags for risky changes

### Communication
- Daily progress updates
- Weekly demos
- Document breaking changes

---

## Success Metrics

### Code Quality
- [ ] Swift 6 strict concurrency: **0 warnings**
- [ ] SwiftLint: **0 errors, <10 warnings**
- [ ] Test coverage: **>70% services, >50% views**
- [ ] File length: **<500 lines per file**
- [ ] Function complexity: **<10 cyclomatic complexity**

### Performance
- [ ] App launch time: **<2 seconds**
- [ ] Memory usage: **<200MB under normal use**
- [ ] Main thread blocks: **0 > 16ms**
- [ ] Network monitoring latency: **<100ms overhead**

### Architecture
- [ ] All services registered in DI container
- [ ] No god objects (>300 lines)
- [ ] All services have protocols
- [ ] Views use injected dependencies

### Documentation
- [ ] All public APIs documented
- [ ] Architecture decision records for major changes
- [ ] README updated with 2.0 features
- [ ] Migration guide for contributors

---

## Estimated Total Effort

| Phase | Effort | Calendar Time |
|-------|--------|---------------|
| P0 (Critical) | 22 hours | Week 1 |
| P1 (Architecture) | 72 hours | Weeks 2-3 |
| P2 (Quality) | 45 hours | Week 4 |
| P3 (Polish) | 62+ hours | Week 5+ |
| **Total** | **~201 hours** | **~5 weeks** |

*Assumes full-time development. Adjust timeline for part-time work.*

---

## Checkpoint Reviews

After each phase:
1. Code review of all changes
2. Full test suite run
3. Performance profiling
4. Manual QA session
5. Go/no-go decision for next phase

---

## Next Steps

1. ✅ Review and approve this roadmap
2. ✅ Create tracking issues for each P0/P1 item
3. ✅ Begin Phase 1 (P0 fixes)
4. Set up project board for progress tracking
5. Schedule weekly review meetings

---

**Document Status:** ✅ **READY FOR REVIEW**
**Last Updated:** 2026-02-13
**Next Review:** After Phase 1 completion
