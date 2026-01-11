# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

NetMonitor is a professional network monitoring application for macOS that provides real-time network diagnostics, target monitoring, local device discovery, and network utilities. It communicates with an iOS companion app and serves as the primary monitoring hub.

**Target Platform**: macOS 15.0+ (Sequoia and later)
**Architecture**: MVVM with SwiftUI
**Language**: Swift with async/await and Actors

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
# Run from command line
xcodebuild -project NetMonitor.xcodeproj -scheme NetMonitor -configuration Debug

# Or use Xcode: ⌘+R
```

### Testing
```bash
# Run all tests
xcodebuild -project NetMonitor.xcodeproj -scheme NetMonitor test

# Or use Xcode: ⌘+U
```

### Code Quality
- Swift 6 strict concurrency mode enabled
- Build warnings treated as errors for concurrency issues
- Use Xcode's "Strict Concurrency Checking" in build settings

## Architecture & Key Patterns

### MVVM Architecture
- **Views**: SwiftUI views with AppKit integration where needed for advanced macOS features
- **ViewModels**: Handle business logic, expose published properties to views
- **Models**: SwiftData/Core Data entities for persistence
- **Services**: Protocol-oriented network services (monitoring, discovery, tools)

### Concurrency Model
- Use Swift async/await for asynchronous operations
- Use Actors for thread-safe state management
- Combine publishers for reactive data flow between layers

### Dependency Injection
Design services with protocol abstraction for testability:
```swift
protocol NetworkMonitorService {
    func startMonitoring(target: NetworkTarget) async throws
    func stopMonitoring(target: NetworkTarget)
}
```

### Core Frameworks
- **Network.framework** + **NWPathMonitor**: Primary networking and path monitoring
- **MultipeerConnectivity**: Local device discovery and companion app communication
- **Bonjour/mDNS**: Service discovery and advertising (`_netmon._tcp` on port 8849)
- **SwiftData**: Data persistence (preferred) or Core Data as fallback
- **Swift Charts**: Data visualizations (latency graphs, packet loss charts)
- **CloudKit**: Optional remote sync for configurations and historical data

## Key Data Models

All models should use SwiftData `@Model` macro or Core Data for persistence:

### MonitoringSession
- Session tracking with start/stop times and running state
- Single active session model with historical archives

### NetworkTarget
- Configurable monitoring targets (ICMP, HTTP, HTTPS, TCP)
- Properties: name, host, port, protocol, checkInterval, timeout, isEnabled
- Default targets pre-configured: Gateway, Cloudflare DNS (1.1.1.1), Google DNS (8.8.8.8), major services

### TargetStatistics
- Time-series data: timestamp, latency, reachability, error messages
- Aggregate stats at 2min/10min/all-time intervals (min/avg/max latency, jitter, packet loss)

### LocalDevice
- Discovered network devices via ARP scan and Bonjour
- MAC address, IP address, hostname, vendor lookup, device type
- Track firstSeen, lastSeen, online status
- Support custom names and notes

### ConnectionInfo & ISPInfo
- Current connection details (WiFi/Ethernet, SSID, signal strength)
- Gateway info (IP, MAC, vendor, latency)
- Public IP, ISP name, ASN, geolocation from external service

## UI Architecture

### Window Structure
- **Sidebar Navigation** (220px): Dashboard, Targets, Devices, Tools, Settings
- **Main Content Area**: Dynamic content based on navigation selection
- **Split Views**: Used in Targets (list + detail) and Devices (list + map/detail)

### Design System
- **Colors**: Cyan accent (#06B6D4), dark gradient background (Slate 950 → Blue 950)
- **Glass Effect**: Cards with 5% white opacity, 10% border opacity, blur effect
- **Typography**: SF Pro Display (headings), SF Pro Text (body), SF Mono (IPs/MACs)
- **Spacing**: Consistent 8px grid, 12-16px card corners

### Navigation Sections
1. **Dashboard**: Overview cards, session info, quick stats, target summary
2. **Targets**: Split view with target list and detail graphs
3. **Devices**: Device list + network map visualization with radial topology
4. **Tools**: Grid of tools (Ping, Traceroute, Port Scanner, DNS Lookup, WHOIS, Speed Test, WOL, Bonjour Browser)
5. **Settings**: General, Notifications, Network, Companion App, Data Management

## Companion App Communication

### Bonjour Service
- Service type: `_netmon._tcp`
- Port: 8849
- JSON message protocol
- Real-time push: connection info, gateway, ISP, targets, devices, tool results
- Accept commands from companion to trigger actions

### CloudKit Sync
- Sync target configurations, device custom names/notes
- Store last 24 hours of historical statistics
- Optional feature, toggle in settings

## Performance Requirements

- Dashboard refresh: 1 second intervals
- Target check intervals: Configurable 5-60 seconds
- Device scan: Complete /24 subnet in < 30 seconds
- Memory usage: < 150MB typical operation
- CPU usage: < 5% during active monitoring
- Startup time: < 2 seconds to launch

## Network Tools Implementation Notes

### Ping Tool
Use `NWConnection` or raw ICMP sockets with proper permissions. Support packet count, size, and interval configuration.

### Traceroute
Implement with increasing TTL values, support ICMP/UDP protocols, display hop-by-hop latency with reverse DNS.

### Port Scanner
Use TCP connect scanning with configurable concurrency limits. Support port ranges and common port presets.

### DNS Lookup
Support record types: A, AAAA, MX, TXT, CNAME, NS, SOA. Allow custom DNS server selection.

### Speed Test
Implement download/upload measurement with server selection. Store historical results for comparison.

### Wake on LAN
Send magic packets to discovered devices or manually entered MACs.

### Bonjour Browser
Enumerate available service types, resolve services to IP addresses, display TXT records.

## Error Handling Strategy

- Graceful degradation when network/permissions unavailable
- Permission denied: Show user-friendly alerts with instructions to enable Local Network access
- Network unreachable: Display connection status with retry options
- External service failures: Use cached data when possible, show last-updated timestamps
- Implement retry with exponential backoff for transient failures
- Comprehensive logging for debugging without blocking UI

## Testing Considerations

- Mock network services with protocols for unit testing ViewModels
- Test target monitoring with configurable success/failure scenarios
- Validate statistics aggregation (2min/10min/all-time calculations)
- Test device discovery with simulated network devices
- Test companion app communication with mock Bonjour services
- UI tests for critical flows: adding targets, running tools, viewing statistics

## macOS Specific Considerations

### Permissions
Request Local Network access in Info.plist:
```xml
<key>NSLocalNetworkUsageDescription</key>
<string>NetMonitor needs local network access to discover devices and monitor network targets.</string>
```

### Menu Bar Integration
Create NSStatusItem for menu bar presence with mini stats display and quick actions (start/stop monitoring).

### AppKit Integration
Use `NSViewRepresentable` for advanced features not available in SwiftUI (e.g., custom network visualizations).

## Development Priorities

1. **Core Networking Layer**: Implement protocol-based monitoring services (ICMP, HTTP, TCP)
2. **Data Persistence**: Set up SwiftData models and relationships
3. **UI Shell**: Create sidebar navigation and basic view structure
4. **Dashboard**: Implement session tracking and connection info display
5. **Target Monitoring**: Build target management and statistics collection
6. **Device Discovery**: Implement ARP scanning and Bonjour discovery
7. **Network Tools**: Add individual tools one by one
8. **Companion Communication**: Implement Bonjour service and JSON protocol
9. **Settings & Polish**: Complete settings, notifications, theme support

## Phase 2: Core Monitoring Engine (COMPLETE)

Phase 2 adds real-time network monitoring capabilities.

### Monitoring Services

**NetworkMonitorService Protocol:**
- Actor-based protocol for thread-safe monitoring
- All implementations must be actors
- Returns TargetMeasurement with latency and reachability

**HTTPMonitorService:**
- Uses URLSession for HTTP/HTTPS checks
- HEAD requests for minimal data transfer
- Respects timeout settings
- Maps HTTP status codes (200-399 = reachable)

**ICMPMonitorService:**
- ICMP Echo Request/Reply (ping)
- CFSocket wrapper for low-level access
- Sequence number tracking
- Note: Full CFSocket implementation pending

### MonitoringSession

**@MainActor @Observable State Holder:**
```swift
@MainActor
@Observable
final class MonitoringSession {
    var isMonitoring: Bool
    var latestResults: [UUID: TargetMeasurement]
}
```

**Key Features:**
- Coordinates monitoring of all enabled targets
- Routes checks to appropriate service by protocol
- Publishes results to UI via @Observable
- Manages task lifecycle (start/stop/cancel)
- Background SwiftData saves for persistence

### Dashboard

**Live Monitoring UI:**
- Real-time target status cards
- Start/Stop monitoring button
- Latency display per target
- Status indicators (green/red/gray)
- Grid layout for multiple targets

**Statistics:**
- Average, min, max latency
- Uptime percentage
- Line charts with recent measurements
- @Query with predicates for efficient data access

### Targets Management

**CRUD Operations:**
- Add new targets via sheet
- Edit target settings
- Enable/disable individual targets
- Delete targets

**Target Configuration:**
- Name, host, optional port
- Protocol selection (HTTP/HTTPS/ICMP/TCP)
- Check interval (1-60 seconds)
- Timeout (1-30 seconds)
