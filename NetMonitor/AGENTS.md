<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-01-28 | Updated: 2026-01-28 -->

# NetMonitor

Professional network monitoring application for macOS providing real-time network diagnostics, target monitoring, local device discovery, and network utilities. Communicates with an iOS companion app and serves as the primary monitoring hub.

## Purpose

The NetMonitor app directory contains the complete macOS application implementation using SwiftUI and SwiftData. It orchestrates network monitoring services, manages the UI layer, and coordinates with the iOS companion app via Bonjour networking. The architecture follows MVVM with @Observable coordinators and actor-based services for Swift 6 strict concurrency compliance.

## Key Files

| File | Type | Purpose |
|------|------|---------|
| **NetMonitorApp.swift** | Entry Point | @main app struct with SwiftData container setup and centralized service initialization |
| **ContentView.swift** | Navigation | NavigationSplitView with sidebar/detail panes and section routing |
| **Info.plist** | Config | App metadata and localization (358 bytes) |
| **NetMonitor.entitlements** | Security | Sandbox permissions and capability declarations |

## Subdirectories

| Directory | Size | Purpose |
|-----------|------|---------|
| **Models/** | 5 files | SwiftData @Model entities for persistence (targets, measurements, devices, sessions) |
| **Services/** | 18 files | Actor-based network services for monitoring, discovery, and shell operations |
| **Views/** | 10 files | SwiftUI main views (ContentView, Dashboard, Targets, Devices, Tools, Settings) |
| **Views/Settings/** | 7 files | Tabbed settings interface (General, Monitoring, Notifications, Network, Data, Appearance, Companion) |
| **Views/Tools/** | 8 files | Network diagnostic tools (Ping, Traceroute, Port Scanner, DNS, WHOIS, Bonjour, Speed Test) |
| **MenuBar/** | 3 files | NSStatusItem menu bar integration with popover and keyboard shortcuts |
| **Utilities/** | 2 files | Helper utilities for WOL actions and continuation tracking |
| **Preview Content/** | 1 file | SwiftUI preview data for development (PreviewContainer.swift) |
| **Assets.xcassets/** | - | App icons and visual assets |

## Architecture Overview

### Service Initialization Flow

**NetMonitorApp.swift** (entry point) → **setupServices()** →

1. **Service instantiation**: HTTPMonitorService, ICMPMonitorService, TCPMonitorService, ARPScannerService, BonjourDiscoveryService, WakeOnLanService
2. **Coordinator creation**: MonitoringSession, DeviceDiscoveryCoordinator
3. **Companion setup**: CompanionService + CompanionMessageHandler
4. **Menu bar**: MenuBarController initialization
5. **Auto-start**: Resume monitoring if enabled in settings

Services are injected into coordinators via dependency injection during initialization, ensuring loose coupling and testability.

### Data Flow

```
NetMonitorApp
├── MonitoringSession (MainActor, Observable)
│   ├── HTTPMonitorService (Actor)
│   ├── ICMPMonitorService (Actor)
│   ├── TCPMonitorService (Actor)
│   └── latestResults: [UUID: TargetMeasurement]
├── DeviceDiscoveryCoordinator (MainActor, Observable)
│   ├── ARPScannerService (Actor)
│   ├── BonjourDiscoveryService (Actor)
│   └── discoveredDevices: [LocalDevice]
├── CompanionService (Bonjour networking)
│   └── CompanionMessageHandler (MainActor)
└── MenuBarController (NSStatusItem)

ContentView
├── SidebarView (Section navigation)
├── DashboardView (monitoring overview)
├── TargetsView (CRUD targets)
├── DevicesView (device discovery UI)
├── ToolsView (diagnostic tools)
└── SettingsView (preferences)
```

### Concurrency Model

- **MainActor**: MonitoringSession, DeviceDiscoveryCoordinator, CompanionMessageHandler (UI coordination)
- **Actors**: All services (HTTPMonitorService, TCPMonitorService, ARPScannerService, BonjourDiscoveryService, ShellCommandRunner, etc.)
- **async/await**: Structured concurrency throughout
- **@unchecked Sendable**: SwiftData @Model classes that cannot conform to Sendable due to relationships
- **Continuation-based**: Low-level async operations use withCheckedContinuation

## For AI Agents

### Working In This Directory

**When implementing features:**

1. **Always use dependency injection** - Services instantiated in NetMonitorApp.setupServices() are passed to coordinators
2. **Maintain MainActor boundaries** - UI coordinators and view models must be @MainActor @Observable
3. **Service access via @Environment** - Views access MonitoringSession and DeviceDiscoveryCoordinator via @Environment
4. **SwiftData persistence** - Models are @Model entities accessed via @Environment(\ModelContext)
5. **Follow actor isolation** - All network services are actors; no synchronous access

**Key patterns to follow:**

```swift
// ✅ CORRECT: Services created in app, injected into coordinators
let httpService = HTTPMonitorService()
let session = MonitoringSession(modelContext: context, httpService: httpService, ...)

// ✅ CORRECT: Views receive via environment
@Environment(MonitoringSession.self) var session

// ✅ CORRECT: MainActor for UI coordination
@MainActor @Observable class MonitoringSession

// ❌ AVOID: Creating services in views or view models
let service = HTTPMonitorService()  // Should come from environment

// ❌ AVOID: Non-MainActor UI coordinators
@Observable class SomeUICoordinator  // Missing @MainActor
```

### View Structure

**Navigation hierarchy:**
- ContentView (NavigationSplitView)
  - SidebarView (Section selection)
  - Detail pane routes to active section
    - .dashboard → DashboardView
    - .targets → TargetsView
    - .devices → DevicesView
    - .tools → ToolsView
    - .settings → SettingsView

**Settings tabs:**
- GeneralSettingsView (launch at login, appearance mode)
- MonitoringSettingsView (check intervals, timeouts, retries)
- NotificationSettingsView (alert sounds, thresholds)
- NetworkSettingsView (interface preference, proxy)
- DataSettingsView (retention, export, clear)
- AppearanceSettingsView (colors, accent, compact mode)
- CompanionSettingsView (service enable, port, connected devices)

**Tool views:**
- PingToolView (interactive ping, real-time streaming)
- TracerouteToolView (network path with hop visualization)
- PortScannerToolView (TCP scanning, common port presets)
- DNSLookupToolView (A, AAAA, MX, TXT, NS records)
- WHOISToolView (domain registration lookup)
- BonjourBrowserToolView (mDNS service browsing)
- SpeedTestToolView (bandwidth measurement)

### Testing Requirements

**Test locations:** `/Users/blake/Projects/NetMonitor/NetMonitorTests/`

**Test framework:** Swift Testing (`import Testing`)

**Required test coverage:**

| Component | Tests | Status |
|-----------|-------|--------|
| MonitoringSession | Session lifecycle, target routing, results publishing | ✅ |
| HTTPMonitorService | HTTP/HEAD requests, status codes, latency | ✅ |
| TCPMonitorService | Connection establishment, timeout handling | ✅ |
| ICMPMonitorService | Ping execution, sequence tracking | ✅ |
| ARPScannerService | IP range scanning, MAC lookup, device detection | ✅ |
| BonjourDiscoveryService | Service browsing, resolution, TXT records | ✅ |
| DeviceDiscoveryCoordinator | Multi-source merge, offline tracking | ✅ |
| ShellCommandRunner | Command execution, streaming, cancellation, timeouts | ✅ |
| ProcessPingService | Ping parsing, streaming, macOS output format | ✅ |
| CompanionService | Message framing, connection handling | ✅ |
| CompanionMessageHandler | Command processing, state updates | ✅ |
| MACVendorLookupService | Vendor lookup for 50+ manufacturers | ✅ |
| WakeOnLanService | Magic packet generation, broadcast | ✅ |

**To run tests:**
```bash
xcodebuild -project NetMonitor.xcodeproj -scheme NetMonitor test
# Or: Cmd+U in Xcode
```

**UI test mode:** ContentView detects UI testing via ProcessInfo.processInfo.arguments and skips service initialization for clean test teardown.

### Common Patterns

**Pattern 1: Monitoring target checks**
```swift
// MonitoringSession.startMonitoring() routes to appropriate service by protocol
switch target.targetProtocol {
case .http, .https:
    let measurement = try await httpService.check(target: target)
case .icmp:
    let measurement = try await icmpService.check(target: target)
case .tcp:
    let measurement = try await tcpService.check(target: target)
}
```

**Pattern 2: Device discovery coordination**
```swift
// DeviceDiscoveryCoordinator orchestrates ARP + Bonjour scans
let arpDevices = await arpScanner.scan(range: ipRange)  // 60% of scan time
let bonjourDevices = await bonjourScanner.discover()     // 30%
let merged = merge(arpDevices, bonjourDevices)           // 10%
```

**Pattern 3: Shell command execution with streaming**
```swift
// ShellCommandRunner supports both one-shot and streaming execution
let result = try await runner.run(command: "ping", args: ["-c", "4", "host"])
// OR for streaming:
for try await line in try await runner.stream(command: "traceroute", args: ["host"]) {
    // Process each output line as it arrives
}
```

**Pattern 4: Companion command handling**
```swift
// CompanionMessageHandler processes iOS app commands
case .command(let payload):
    switch payload.action {
    case "startMonitoring":
        monitoringSession.startMonitoring()
        return .statusUpdate(...)
    case "ping":
        return .toolResult(...)
    }
```

**Pattern 5: Settings with AppStorage**
```swift
// Settings use @AppStorage with "netmonitor.*" key prefix
@AppStorage("netmonitor.autoStartMonitoring") var autoStartMonitoring = false
@AppStorage("netmonitor.checkInterval") var checkInterval = 30
```

### Accessibility

All interactive elements have `accessibilityIdentifier` attributes for testing:

- `detail_dashboard`, `detail_targets`, `detail_devices`, `detail_tools`, `detail_settings` (main views)
- Button IDs for actions (start/stop monitoring, add target, scan devices)
- List identifiers for dynamically rendered content

### Error Handling

**Service-level errors:**
- Network timeouts: return failed measurement with error message
- Invalid responses: catch, log, return reachable=false
- Permission denied: user-friendly alerts via MainActor

**UI-level errors:**
- Show inline error messages in tool views
- "No results" states for failed commands
- Retry buttons for transient failures

**Logging:**
- All services log errors without blocking UI
- No crashes on network failures
- Graceful degradation when services unavailable

## Dependencies

### Internal

**Models** (SwiftData entities):
- NetworkTarget (monitoring target configuration)
- TargetMeasurement (individual check results)
- LocalDevice (discovered network devices)
- SessionRecord (monitoring session tracking)
- Section (navigation enum)

**Services** (Actor-based):
- NetworkMonitorService (protocol)
- HTTPMonitorService (HTTP/HTTPS monitoring)
- TCPMonitorService (TCP port monitoring)
- ICMPMonitorService (ICMP ping)
- ICMPSocket (low-level ICMP wrapper)
- ProcessPingService (shell-based ping)
- ShellCommandRunner (generic shell executor)
- ARPScannerService (ARP device discovery)
- BonjourDiscoveryService (mDNS service discovery)
- DeviceDiscoveryService (protocol)
- DeviceDiscoveryCoordinator (unified discovery coordinator)
- MACVendorLookupService (MAC vendor lookup)
- CompanionService (Bonjour service for iOS app)
- CompanionMessageHandler (command processor)
- WakeOnLanService (magic packet sender)
- MonitoringSession (main monitoring coordinator)

**Utilities**:
- ContinuationTracker (tracks active continuations)
- WakeOnLanAction (WOL action binding helper)

**Shared** (NetMonitorShared package):
- CompanionMessage (JSON message protocol)
- TargetProtocol enum
- DeviceType enum
- ConnectionType enum

### External

**Apple Frameworks**:
- **SwiftUI** - UI framework
- **SwiftData** - Persistence layer
- **Foundation** - Core utilities (UUID, Date, ProcessInfo, etc.)
- **Network** - NWConnection, NWListener, NWBrowser for networking
- **AppKit** - NSStatusItem, NSPopover for menu bar integration
- **Darwin** - System C interop for ICMP sockets, shell commands
- **Combine** - Async stream support (legacy, migrating to async/await)

**System utilities** (via shell):
- `/sbin/ping` - ICMP ping execution
- `/usr/sbin/arp` - ARP table querying
- `/usr/bin/traceroute` - Network path tracing
- `/usr/bin/dig` - DNS queries
- `/usr/bin/whois` - Domain registration lookup
- `/System/Library/CoreServices/Finder.app` - File operations

## Build & Run

**Requirements:**
- macOS 15.0+ (Sequoia and later)
- Xcode 16.0+
- Swift 6 with strict concurrency enabled

**Build:**
```bash
xcodebuild -project NetMonitor.xcodeproj -scheme NetMonitor -configuration Debug build
```

**Run:**
```bash
xcodebuild -project NetMonitor.xcodeproj -scheme NetMonitor -configuration Debug build && open ./build/Debug/NetMonitor.app
# Or: Cmd+R in Xcode
```

**Clean:**
```bash
xcodebuild -project NetMonitor.xcodeproj -scheme NetMonitor clean
```

## Performance Characteristics

- **Dashboard refresh**: 1-second intervals for real-time updates
- **Target check intervals**: Configurable 5-60 seconds per target
- **Device scan duration**: Complete /24 subnet in <30 seconds
- **Memory footprint**: <150MB typical operation
- **CPU usage**: <5% during active monitoring
- **Startup time**: <2 seconds to main UI
- **Companion networking**: Bonjour discovery + TCP connections on port 8849

## macOS Permissions

Required in Info.plist:
```xml
<key>NSLocalNetworkUsageDescription</key>
<string>NetMonitor needs local network access to discover devices and monitor network targets on your local network.</string>
```

Required entitlements:
- Local network access (NSLocalNetworkUsageDescription)
- Bonjour service publishing (_netmon._tcp)
- UDP broadcast for Wake on LAN

## Notes for Developers

### Where to Start

1. **Read NetMonitorApp.swift** - Understand service initialization and dependency injection
2. **Study MonitoringSession** - Core monitoring coordination logic
3. **Examine ContentView** - Main navigation structure
4. **Explore Services/** - Implementation of HTTP, TCP, ICMP, ARP, Bonjour, and Companion services
5. **Review Views/** - SwiftUI implementation patterns

### Common Tasks

| Task | File | Key Class |
|------|------|-----------|
| Add new monitoring protocol | Services/ | Implement NetworkMonitorService |
| Add settings option | Views/Settings/ | Use @AppStorage("netmonitor.*") |
| Add network tool | Views/Tools/ | Create *ToolView.swift following existing patterns |
| Modify target structure | Models/NetworkTarget.swift | Update @Model and persist with SwiftData |
| Handle companion command | Services/CompanionMessageHandler.swift | Add case to handle() method |
| Debug service issue | Services/*Service.swift | Check actor isolation and MainActor crossings |

### Known Constraints

1. **Swift 6 strict concurrency** - All async operations must be properly isolated
2. **SwiftData relationships** - Cannot directly conform to Sendable; use @unchecked Sendable with caution
3. **App Sandbox** - Raw socket ICMP unavailable; use ProcessPingService instead
4. **UI thread** - All SwiftUI view updates must run on MainActor
5. **Network Framework** - NWConnection requires explicit timeout handling

### Architecture Decisions

1. **Actor-based services** - Provides thread-safe concurrent execution of network operations
2. **Dependency injection** - Services created in NetMonitorApp, injected into coordinators for testability
3. **MainActor coordinators** - MonitoringSession and DeviceDiscoveryCoordinator use @Observable for reactive UI
4. **SwiftData persistence** - Centralized schema in NetMonitorApp with single ModelContainer
5. **Companion over Multipeer** - Bonjour chosen for simplicity and broader iOS/macOS compatibility
6. **Separate Scan Phases** - ARP (fast, MAC info) + Bonjour (slower, hostname info) run in parallel

<!-- MANUAL: Add project-specific conventions or gotchas discovered during development -->
