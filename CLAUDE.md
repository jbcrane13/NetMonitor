# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

NetMonitor is a professional network monitoring application for macOS that provides real-time network diagnostics, target monitoring, local device discovery, and network utilities. It communicates with an iOS companion app and serves as the primary monitoring hub.

**Target Platform**: macOS 15.0+ (Sequoia and later)
**Architecture**: MVVM with SwiftUI
**Language**: Swift 6 with async/await and Actors

## Project Structure

```
NetMonitor/
├── NetMonitor/                          # Main macOS app
│   ├── Models/                          # SwiftData data models
│   │   ├── NetworkTarget.swift          # Monitoring target definition
│   │   ├── TargetMeasurement.swift      # Individual measurement results
│   │   ├── LocalDevice.swift            # Discovered network devices
│   │   ├── SessionRecord.swift          # Monitoring session tracking
│   │   └── Section.swift                # Navigation enum
│   ├── Services/                        # Business logic and networking
│   │   ├── MonitoringSession.swift      # Main monitoring coordinator
│   │   ├── NetworkMonitorService.swift  # Protocol for monitors
│   │   ├── HTTPMonitorService.swift     # HTTP/HTTPS monitoring
│   │   ├── TCPMonitorService.swift      # TCP port monitoring
│   │   ├── ICMPMonitorService.swift     # ICMP ping monitoring
│   │   ├── ICMPSocket.swift             # Low-level ICMP wrapper
│   │   ├── ProcessPingService.swift     # Shell-based ping utility
│   │   ├── ShellCommandRunner.swift     # Generic shell command executor
│   │   ├── ARPScannerService.swift      # ARP-based device discovery
│   │   ├── BonjourDiscoveryService.swift # mDNS service discovery
│   │   ├── DeviceDiscoveryService.swift # Discovery protocol
│   │   ├── DeviceDiscoveryCoordinator.swift # Unified discovery coordinator
│   │   ├── MACVendorLookupService.swift # MAC address vendor lookup
│   │   ├── CompanionService.swift       # Bonjour service for companion app
│   │   ├── CompanionMessageHandler.swift # Companion command processor
│   │   └── WakeOnLanService.swift       # Magic packet sender
│   ├── Views/                           # SwiftUI views
│   │   ├── ContentView.swift            # Main navigation container
│   │   ├── SidebarView.swift            # Navigation sidebar
│   │   ├── DashboardView.swift          # Monitoring overview
│   │   ├── TargetsView.swift            # Target management
│   │   ├── AddTargetSheet.swift         # Target creation form
│   │   ├── DevicesView.swift            # Device discovery & management
│   │   ├── DeviceDetailView.swift       # Device information & actions
│   │   ├── DeviceRowView.swift          # Device list item
│   │   ├── ToolsView.swift              # Network tools container
│   │   ├── Tools/                       # Network diagnostic tools
│   │   │   ├── PingToolView.swift       # Interactive ping utility
│   │   │   ├── TracerouteToolView.swift # Network path tracing
│   │   │   ├── PortScannerToolView.swift # TCP port scanning
│   │   │   ├── DNSLookupToolView.swift  # DNS query tool
│   │   │   ├── WHOISToolView.swift      # Domain WHOIS lookup
│   │   │   ├── BonjourBrowserToolView.swift # mDNS service browser
│   │   │   └── WakeOnLanToolView.swift  # WOL magic packet sender
│   │   ├── SettingsView.swift           # Settings container with tabs
│   │   └── Settings/                    # Settings tab views
│   │       ├── GeneralSettingsView.swift # Launch at login, appearance
│   │       ├── MonitoringSettingsView.swift # Check intervals, retries
│   │       ├── NotificationSettingsView.swift # Alerts, thresholds
│   │       ├── NetworkSettingsView.swift # Interface, proxy settings
│   │       ├── DataSettingsView.swift   # History retention, export
│   │       ├── AppearanceSettingsView.swift # Theme, colors, compact mode
│   │       └── CompanionSettingsView.swift # Companion app service
│   ├── MenuBar/                         # Menu bar integration
│   │   ├── MenuBarController.swift      # NSStatusItem management
│   │   ├── MenuBarPopoverView.swift     # Quick stats popover
│   │   └── MenuBarCommands.swift        # Keyboard shortcuts
│   ├── Preview Content/                 # SwiftUI preview data
│   ├── Assets.xcassets/                 # App assets and icons
│   ├── NetMonitorApp.swift              # App entry point
│   └── Info.plist                       # App configuration
├── NetMonitorShared/                    # Swift Package for shared code
│   └── Sources/NetMonitorShared/
│       ├── Protocol/
│       │   └── CompanionMessage.swift   # JSON message protocol
│       └── Common/
│           └── Enums.swift              # Shared enums
├── NetMonitorTests/                     # Unit tests
│   ├── Services/                        # Service tests
│   └── Protocol/                        # Message protocol tests
├── NetMonitorUITests/                   # UI tests
└── docs/                                # Documentation
    ├── Companion-Protocol-API.md        # API reference
    └── plans/                           # Design documents
```

## Development Commands

### Building
```bash
# Build the project
xcodebuild -project NetMonitor.xcodeproj -scheme NetMonitor -configuration Debug build

# Clean build folder
xcodebuild -project NetMonitor.xcodeproj -scheme NetMonitor clean
```

### Running
```bash
# Build and run from command line
xcodebuild -project NetMonitor.xcodeproj -scheme NetMonitor -configuration Debug build && open ./build/Debug/NetMonitor.app

# Or use Xcode: Cmd+R
```

### Testing
```bash
# Run all tests
xcodebuild -project NetMonitor.xcodeproj -scheme NetMonitor test

# Or use Xcode: Cmd+U
```

### Code Quality
- Swift 6 strict concurrency mode enabled
- Build warnings treated as errors for concurrency issues
- Use Xcode's "Strict Concurrency Checking" in build settings

## Architecture & Key Patterns

### MVVM with @Observable
- **Views**: SwiftUI views with AppKit integration for menu bar
- **ViewModels**: @Observable classes (MonitoringSession, DeviceDiscoveryCoordinator)
- **Models**: SwiftData `@Model` entities for persistence
- **Services**: Actor-based network services

### Concurrency Model
- **Actors**: All services (HTTPMonitorService, ARPScannerService, etc.) are actors for thread safety
- **@MainActor**: UI coordinators (MonitoringSession, DeviceDiscoveryCoordinator) run on main thread
- **async/await**: All asynchronous operations use structured concurrency
- **Continuation-based**: Low-level async (network callbacks) use `withCheckedContinuation`

### Dependency Injection
Services initialized in `NetMonitorApp.swift` and passed via SwiftUI environment:
```swift
@Environment(MonitoringSession.self) private var session
@Environment(DeviceDiscoveryCoordinator.self) private var discoveryCoordinator
```

### Core Frameworks
- **Network.framework**: NWConnection, NWListener, NWBrowser for networking
- **SwiftData**: Primary persistence with @Model and @Query
- **SwiftUI**: UI framework with NavigationSplitView
- **AppKit**: Menu bar integration (NSStatusItem, NSPopover)

## Data Models (SwiftData)

### NetworkTarget
Monitoring targets with configurable protocols and intervals.
```swift
@Model
final class NetworkTarget {
    var id: UUID
    var name: String
    var host: String
    var port: Int?
    var targetProtocol: TargetProtocol  // icmp, http, https, tcp
    var checkInterval: Int              // seconds (1-60)
    var timeout: Int                    // seconds (1-30)
    var isEnabled: Bool
    var createdAt: Date
    @Relationship(deleteRule: .cascade) var measurements: [TargetMeasurement]
}
```

### TargetMeasurement
Individual check results stored for historical analysis.
```swift
@Model
final class TargetMeasurement {
    var id: UUID
    var timestamp: Date
    var latency: Double?                // milliseconds
    var isReachable: Bool
    var errorMessage: String?
    var target: NetworkTarget?
}
```

### LocalDevice
Discovered network devices with tracking metadata.
```swift
@Model
final class LocalDevice {
    var id: UUID
    var ipAddress: String
    var macAddress: String?
    var hostname: String?
    var vendor: String?
    var deviceType: DeviceType
    var customName: String?
    var notes: String?
    var firstSeen: Date
    var lastSeen: Date
    var isOnline: Bool
}
```

### SessionRecord
Monitoring session lifecycle tracking.
```swift
@Model
final class SessionRecord {
    var id: UUID
    var startedAt: Date
    var pausedAt: Date?
    var stoppedAt: Date?
    var isActive: Bool
}
```

## Services Architecture

### MonitoringSession (Main Coordinator)
`@MainActor @Observable` class coordinating all monitoring:
- Manages target monitoring lifecycle (start/stop)
- Routes checks to appropriate service by protocol
- Publishes `latestResults: [UUID: TargetMeasurement]` to UI
- Persists measurements to SwiftData

### NetworkMonitorService Protocol
Actor protocol all monitors conform to:
```swift
protocol NetworkMonitorService: Actor {
    func check(target: NetworkTarget) async throws -> TargetMeasurement
}
```

### HTTPMonitorService
- HEAD requests for minimal data transfer
- HTTP 200-399 = reachable
- Respects target timeout settings

### TCPMonitorService
- Network.framework NWConnection-based
- Connects to specified host:port
- Returns latency on successful connection

### ShellCommandRunner
Actor for executing shell commands safely:
- `run()`: Execute command and return stdout/stderr/exitCode
- `stream()`: Stream output line-by-line via AsyncThrowingStream
- `cancel()`: Terminate running process
- Supports configurable timeouts

### ProcessPingService
Shell-based ping service using `/sbin/ping`:
- `ping()`: Execute ping and return aggregate PingResult
- `pingStream()`: Stream individual PingLine responses
- Works within App Sandbox (no raw socket access needed)
- Parses macOS ping output format

### ARPScannerService
- Probes IP range using NWConnection TCP
- Retrieves MAC addresses via `/usr/sbin/arp`
- Supports /24 and larger subnets

### BonjourDiscoveryService
- Browses 15 service types (HTTP, SSH, SMB, AirPlay, etc.)
- Resolves services to IP addresses
- Parses TXT records

### DeviceDiscoveryCoordinator
`@MainActor @Observable` coordinator for device discovery:
- Two-phase scan: ARP (60%) + Bonjour (30%) + merge (10%)
- Merges results (ARP for MAC, Bonjour for hostname)
- Marks devices offline when not seen in scan
- Persists to SwiftData

### MACVendorLookupService
- Hardcoded OUI database with 50+ Apple entries
- Supports Samsung, Google, Amazon, Microsoft, Intel, TP-Link, Netgear, Cisco, Raspberry Pi, Sonos

### CompanionService
- Advertises `_netmon._tcp` on port 8849
- JSON message protocol with length-prefixed framing
- Accepts connections from iOS companion app
- Broadcasts state updates

### CompanionMessageHandler
`@MainActor` processor for companion commands:
- Supported commands: startMonitoring, stopMonitoring, scanDevices, ping, wakeOnLan, refreshTargets, refreshDevices
- Generates status updates, target lists, device lists

### WakeOnLanService
- Sends magic packets via UDP broadcast (port 9)
- Supports MAC formats: AA:BB:CC:DD:EE:FF, AA-BB-CC-DD-EE-FF, AABBCCDDEEFF

## Companion Protocol (NetMonitorShared)

### Message Types
```swift
enum CompanionMessage: Codable {
    case statusUpdate(StatusUpdatePayload)
    case targetList(TargetListPayload)
    case deviceList(DeviceListPayload)
    case command(CommandPayload)
    case toolResult(ToolResultPayload)
    case error(ErrorPayload)
    case heartbeat
}
```

### Payloads
- **StatusUpdatePayload**: isMonitoring, onlineTargets, offlineTargets, averageLatency
- **TargetListPayload**: Array of TargetInfo (name, host, protocol, status, latency)
- **DeviceListPayload**: Array of DeviceInfo (name, ipAddress, macAddress, vendor, isOnline)
- **CommandPayload**: action string + parameters dictionary
- **ToolResultPayload**: tool, success, result

See `docs/Companion-Protocol-API.md` for complete API reference.

## Shared Enums

### TargetProtocol
```swift
enum TargetProtocol: String, Codable, CaseIterable {
    case icmp, http, https, tcp
    var iconName: String  // SF Symbol names
}
```

### DeviceType
```swift
enum DeviceType: String, Codable, CaseIterable {
    case phone, laptop, tablet, tv, speaker, gaming, iot, router, printer, unknown
    var iconName: String  // SF Symbol names
}
```

### ConnectionType
```swift
enum ConnectionType: String, Codable {
    case wifi, ethernet, cellular, unknown
}
```

## UI Architecture

### Navigation Structure
NavigationSplitView with sidebar (220px) + detail:
1. **Dashboard**: Monitoring status, target cards, quick stats
2. **Targets**: Target list with CRUD, add via sheet
3. **Devices**: Split view with list + detail, scan button
4. **Tools**: Grid of network diagnostic tools
5. **Settings**: Tabbed preferences interface

### Network Tools (Views/Tools/)
Seven diagnostic utilities with consistent UX:
- **PingToolView**: Interactive ping with real-time latency display, streaming results
- **TracerouteToolView**: Network path tracing with hop-by-hop visualization
- **PortScannerToolView**: TCP port scanning with common port presets
- **DNSLookupToolView**: DNS query tool for A, AAAA, MX, TXT, NS records
- **WHOISToolView**: Domain registration lookup via whois command
- **BonjourBrowserToolView**: Browse mDNS services on local network
- **WakeOnLanToolView**: Send magic packets to wake devices

All tools follow consistent patterns:
- Input validation before execution
- Cancel button for long-running operations
- Error messages displayed inline
- Accessibility identifiers on all interactive elements

### Settings (Views/Settings/)
Tabbed interface with six setting categories:
- **GeneralSettingsView**: Launch at login (SMAppService), appearance mode
- **MonitoringSettingsView**: Default intervals, timeouts, retry behavior
- **NotificationSettingsView**: Alert sounds, latency thresholds
- **NetworkSettingsView**: Interface preference, proxy settings
- **DataSettingsView**: History retention, CSV export, clear data
- **AppearanceSettingsView**: Accent colors, compact mode
- **CompanionSettingsView**: Companion service enable/port, connected devices

Settings use `@AppStorage` with `netmonitor.*` key prefix for persistence.

### Menu Bar Integration
- **MenuBarController**: NSStatusItem with dynamic icon/color
- **MenuBarPopoverView**: Quick stats, top 5 targets, start/stop button
- Icon states: network (stopped), network (green=monitoring), network.slash (issues)

### Design System
- **Colors**: Cyan accent (#06B6D4), dark gradient background
- **Glass Effect**: Cards with 5% white opacity, blur
- **Typography**: SF Pro Display/Text, SF Mono for IPs/MACs

## Testing

Tests use Swift Testing framework (`import Testing`):

### Service Tests
- `MonitoringSessionTests`: Session lifecycle
- `HTTPMonitorServiceTests`: HTTP request handling
- `ARPScannerServiceTests`: IP range calculation, MAC lookup
- `BonjourDiscoveryServiceTests`: Service discovery
- `DeviceDiscoveryCoordinatorTests`: Merge logic
- `MACVendorLookupServiceTests`: Vendor lookup
- `CompanionServiceTests`: Message handling
- `ShellCommandRunnerTests`: Command execution, streaming, timeouts
- `ProcessPingServiceTests`: Ping execution, streaming, cancellation

### Protocol Tests
- `CompanionMessageTests`: JSON encoding/decoding

## Performance Requirements

- Dashboard refresh: 1 second intervals
- Target check intervals: Configurable 5-60 seconds
- Device scan: Complete /24 subnet in < 30 seconds
- Memory usage: < 150MB typical operation
- CPU usage: < 5% during active monitoring
- Startup time: < 2 seconds to launch

## macOS Permissions

Required in Info.plist:
```xml
<key>NSLocalNetworkUsageDescription</key>
<string>NetMonitor needs local network access to discover devices and monitor network targets on your local network.</string>
```

## Implementation Status

### Phase 1: Foundation (COMPLETE)
- SwiftData models and relationships
- UI shell with sidebar navigation
- Basic view structure

### Phase 2: Core Monitoring Engine (COMPLETE)
- MonitoringSession coordinator
- HTTPMonitorService for HTTP/HTTPS
- Dashboard with real-time target status
- Target CRUD operations
- Statistics persistence

### Phase 3: Discovery & Companion (COMPLETE)
- ARPScannerService for local device discovery
- BonjourDiscoveryService for mDNS
- DeviceDiscoveryCoordinator (unified scanning)
- MACVendorLookupService (50+ vendors)
- DevicesView with search/filter
- DeviceDetailView with actions
- Menu bar integration
- CompanionService (Bonjour advertising)
- CompanionMessageHandler (command processing)
- WakeOnLanService (magic packets)

### Phase 4: Tools, Settings & Polish (COMPLETE)
- **Infrastructure**:
  - ShellCommandRunner actor for shell command execution
  - ProcessPingService for shell-based ping operations
  - TCPMonitorService for TCP port monitoring
- **Network Tools UI** (7 tools):
  - PingToolView with real-time streaming
  - TracerouteToolView with hop visualization
  - PortScannerToolView with common port presets
  - DNSLookupToolView for multiple record types
  - WHOISToolView for domain lookups
  - BonjourBrowserToolView for mDNS browsing
  - WakeOnLanToolView for magic packets
- **Settings UI** (7 setting views):
  - GeneralSettingsView (launch at login, appearance)
  - MonitoringSettingsView (intervals, timeouts)
  - NotificationSettingsView (alerts, thresholds)
  - NetworkSettingsView (interface, proxy)
  - DataSettingsView (retention, export)
  - AppearanceSettingsView (theme, colors)
  - CompanionSettingsView (service config)
- **Polish**:
  - Comprehensive error handling in all tool views
  - 51 accessibility identifiers across new UI
  - Unit tests for ShellCommandRunner and ProcessPingService

### Pending Implementation
- **Statistics Aggregation**: 2min/10min/all-time calculations
- **Network Map**: Radial topology visualization
- **CloudKit Sync**: Remote configuration sync
- **Speed Test Tool**: Bandwidth measurement

## Error Handling Strategy

- Graceful degradation when network/permissions unavailable
- Permission denied: User-friendly alerts with instructions
- Network unreachable: Connection status with retry options
- External service failures: Cached data with timestamps
- Retry with exponential backoff for transient failures
- Comprehensive logging without blocking UI

## Key Conventions

### File Naming
- Services: `*Service.swift` (actors)
- Coordinators: `*Coordinator.swift` (@MainActor @Observable)
- Views: `*View.swift`
- Models: Singular noun (NetworkTarget, LocalDevice)

### Code Style
- Actors for all service classes
- @MainActor for UI-bound coordinators
- async/await for all async operations
- Protocol-first design for testability
- SwiftData @Model for persistence
- @Environment for dependency injection

### Git Workflow
- Feature branches: `claude/<feature-name>-<id>`
- Conventional commits: `feat:`, `fix:`, `docs:`, `refactor:`
- PR required for main branch
