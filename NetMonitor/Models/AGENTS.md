<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-01-28 | Updated: 2026-01-28 -->

# Models

## Purpose

The Models directory contains SwiftData persistence entities that define the data structures for NetMonitor. These @Model classes represent the core domain objects: monitoring targets, measurement results, discovered devices, and session tracking. All models support SwiftData's schema versioning and relationship management with cascade deletion. Models are accessed via SwiftUI's @Environment(\.modelContext) and @Query macros for reactive UI updates.

## Key Files

| File | Type | Purpose |
|------|------|---------|
| **NetworkTarget.swift** | @Model | Monitoring target configuration with protocol, host, port, intervals, and cascade relationship to measurements |
| **TargetMeasurement.swift** | @Model | Individual check results (latency, reachability, error messages) with statistics calculation |
| **LocalDevice.swift** | @Model | Discovered network devices with IP, MAC, hostname, vendor, device type, and online status tracking |
| **SessionRecord.swift** | @Model | Monitoring session lifecycle (started, paused, stopped, active state) for session history |
| **Section.swift** | Enum | Navigation section enumeration (Dashboard, Targets, Devices, Tools, Settings) with SF Symbol icon names |

## Architecture

### Data Model Hierarchy

```
NetworkTarget (1)
├── measurements: [TargetMeasurement] (many)
│   └── Cascade delete rule: Deletion of target deletes all measurements
└── targetProtocol: TargetProtocol (enum from NetMonitorShared)

LocalDevice (1)
├── ipAddress: String (unique identifier for network)
├── macAddress: String (unique identifier on network)
└── deviceType: DeviceType (enum from NetMonitorShared)

SessionRecord (1)
├── startedAt: Date
├── pausedAt: Date?
└── stoppedAt: Date?
```

### Sendability & Concurrency

All @Model classes use `@unchecked Sendable` to satisfy Swift 6 strict concurrency requirements:

```swift
@Model
final class NetworkTarget: @unchecked Sendable {
    // @unchecked Sendable: SwiftData @Model classes with @Relationship
    // cannot safely conform to Sendable due to mutable state and
    // relationship management. Access should be confined to MainActor
    // or properly isolated actor contexts.
}
```

**Why @unchecked Sendable?**
- SwiftData @Model classes have mutable state managed by the framework
- @Relationship properties create internal pointers that aren't thread-safe
- Sendable conformance is needed for async/await type checking
- @unchecked Sendable documents that manual isolation is required

**Usage rule:** Models are accessed only via:
1. **@Query** macros in SwiftUI views (runs on MainActor)
2. **@Environment(\.modelContext)** for writes (MainActor-only)
3. **Coordinator classes** decorated with @MainActor (MonitoringSession, DeviceDiscoveryCoordinator)

## For AI Agents

### Working In This Directory

**When modifying models:**

1. **Preserve @Model and @unchecked Sendable** - Do not remove these attributes
2. **Use cascade delete rules** - Foreign key relationships should cascade: `@Relationship(deleteRule: .cascade, inverse: \TargetMeasurement.target)`
3. **Add computed properties** - Use extensions for UI-specific helpers (displayName, formattedLatency, etc.)
4. **Maintain immutable IDs** - Never reassign UUID id fields; use explicit init(id:) to preserve identities
5. **Initialize dates with .now** - Use Date.now default values instead of Date()
6. **Follow naming conventions** - Properties are lowerCamelCase; @Model classes are singular nouns

**Example: Adding a new property to NetworkTarget**

```swift
@Model
final class NetworkTarget: @unchecked Sendable {
    // ... existing properties ...

    // ✅ CORRECT: New property with sensible default
    var isMonitored: Bool = true

    // ❌ AVOID: Removing @unchecked Sendable
    // ❌ AVOID: Reassigning id after initialization
    // ❌ AVOID: Using Date() instead of .now
}
```

### Adding Computed Properties

Computed properties should be in extensions to keep implementation clear:

```swift
extension NetworkTarget {
    /// Display label for target status indicators
    var statusLabel: String {
        isEnabled ? "Monitoring" : "Disabled"
    }

    /// Latest measurement or nil if never checked
    var latestMeasurement: TargetMeasurement? {
        measurements.sorted { $0.timestamp > $1.timestamp }.first
    }
}
```

### Testing Requirements

**Model tests location:** `/Users/blake/Projects/NetMonitor/NetMonitorTests/`

**Required test coverage:**

| Model | Test Focus | Status |
|-------|-----------|--------|
| NetworkTarget | Initialization, UUID uniqueness, cascade deletion of measurements | ✅ |
| TargetMeasurement | Latency calculation, statistics aggregation, error message handling | ✅ |
| LocalDevice | Display name resolution (custom > hostname > IP), online/offline status | ✅ |
| SessionRecord | Session state transitions, duration calculations | ✅ |
| Section | Enum cases, icon name mapping, identifiability | ✅ |

**Example test pattern:**

```swift
@Test func targetMeasurementStatisticsCalculation() {
    let measurements = [
        TargetMeasurement(timestamp: .now, latency: 10, isReachable: true),
        TargetMeasurement(timestamp: .now, latency: 20, isReachable: true),
        TargetMeasurement(timestamp: .now, latency: 30, isReachable: false),
    ]

    let stats = TargetMeasurement.calculateStatistics(from: measurements)

    #expect(stats.averageLatency == 20)
    #expect(stats.minLatency == 10)
    #expect(stats.maxLatency == 30)
    #expect(stats.uptimePercentage == 66.67)
}
```

**To run tests:**
```bash
xcodebuild -project NetMonitor.xcodeproj -scheme NetMonitor test
# Or: Cmd+U in Xcode
```

### Common Patterns

**Pattern 1: Creating a target with default intervals**
```swift
let target = NetworkTarget(
    name: "Production Server",
    host: "api.example.com",
    targetProtocol: .https,
    checkInterval: 30.0,      // seconds
    timeout: 10.0,            // seconds
    isEnabled: true
)
```

**Pattern 2: Recording a measurement result**
```swift
let measurement = TargetMeasurement(
    timestamp: .now,
    latency: 45.2,            // milliseconds
    isReachable: true,
    errorMessage: nil
)
// MonitoringSession stores via modelContext
```

**Pattern 3: Calculating statistics from historical data**
```swift
let allMeasurements = target.measurements
let stats = TargetMeasurement.calculateStatistics(from: allMeasurements)

// Access formatted strings for UI
Text("Avg: \(stats.averageLatencyFormatted) ms")
Text("Uptime: \(stats.uptimeFormatted)%")
```

**Pattern 4: Device display names with fallback**
```swift
let device = LocalDevice(
    ipAddress: "192.168.1.100",
    macAddress: "aa:bb:cc:dd:ee:ff",
    hostname: "MacBook-Pro",
    deviceType: .laptop
)

// displayName computed property returns:
// 1. customName if set
// 2. hostname if available
// 3. ipAddress as fallback
Text(device.displayName)  // Shows "MacBook-Pro"
```

**Pattern 5: Session state tracking**
```swift
var session = SessionRecord(isActive: true)

// Session running:
session.isActive  // true

// Session paused:
session.pausedAt = .now
session.isActive  // still true (paused != stopped)

// Session stopped:
session.stoppedAt = .now
session.isActive  // false
```

### Relationship Management

**Cascade deletion rule:**
When a NetworkTarget is deleted, all associated TargetMeasurement records are automatically deleted:

```swift
@Relationship(deleteRule: .cascade, inverse: \TargetMeasurement.target)
var measurements: [TargetMeasurement] = []
```

**Accessing relationships:**
```swift
// From view via @Query
@Query var targets: [NetworkTarget]

// From coordinator via modelContext
let targets = try? modelContext.fetch(FetchDescriptor<NetworkTarget>())

// Access measurements
for target in targets {
    for measurement in target.measurements {
        // Each measurement.target points back to this target
    }
}
```

### SwiftData Container Setup

The ModelContainer is configured in NetMonitorApp.swift:

```swift
import SwiftData

@main
struct NetMonitorApp: App {
    let container = ModelContainer(
        for: [NetworkTarget.self, TargetMeasurement.self, LocalDevice.self, SessionRecord.self],
        inMemory: false,  // Persisted to disk
        isAutosaveEnabled: true
    )
}
```

Models are queried in views via:
```swift
@Query var targets: [NetworkTarget]  // Reactive, auto-updates on changes
@Environment(\.modelContext) var context  // For manual inserts/updates
```

## Dependencies

### Internal

**Shared Package** (NetMonitorShared):
- `TargetProtocol` enum (icmp, http, https, tcp) - imported in NetworkTarget
- `DeviceType` enum (phone, laptop, tablet, tv, speaker, gaming, iot, router, printer, unknown) - imported in LocalDevice
- `ConnectionType` enum (wifi, ethernet, cellular, unknown) - available for extension

### External

**Apple Frameworks:**
- **Foundation** - UUID, Date, Codable
- **SwiftData** - @Model macro, @Relationship, ModelContainer, ModelContext, @Query

### Reverse Dependencies

**Services that use these models:**
- MonitoringSession (creates/updates TargetMeasurement, accesses NetworkTarget)
- DeviceDiscoveryCoordinator (creates/updates LocalDevice)
- HTTPMonitorService, TCPMonitorService, ICMPMonitorService (return TargetMeasurement)
- ARPScannerService, BonjourDiscoveryService (return LocalDevice)

**Views that query these models:**
- DashboardView (@Query targets, displays latest measurements)
- TargetsView (@Query targets, CRUD interface)
- DevicesView (@Query devices, discovery UI)

<!-- MANUAL: Add project-specific conventions or gotchas discovered during development -->
