# Changelog

All notable changes to NetMonitor will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2026-01-28

### Added

#### Network Monitoring
- Real-time target monitoring with configurable check intervals (5-60 seconds)
- Support for four monitoring protocols: ICMP (ping), HTTP, HTTPS, and TCP
- Historical latency tracking with persistent measurement storage using SwiftData
- Automatic retry mechanism with configurable timeout settings
- Dashboard with real-time target status cards showing latency and reachability
- Target CRUD operations (Create, Read, Update, Delete)
- MonitoringSession coordinator with protocol-based service routing
- HTTPMonitorService for HTTP/HTTPS endpoint checks
- TCPMonitorService for TCP port connectivity monitoring
- ProcessPingService for shell-based ICMP ping operations

#### Device Discovery
- Two-phase device discovery combining ARP scanning and Bonjour (mDNS)
- ARPScannerService for local network device detection using ARP
- BonjourDiscoveryService for mDNS service discovery across 15 service types
- DeviceDiscoveryCoordinator for unified scanning orchestration
- Automatic MAC address vendor lookup with 50+ manufacturer database
- Device categorization (phone, laptop, tablet, router, TV, speaker, gaming, IoT, printer)
- Custom device naming and notes
- Online/offline status tracking with first seen and last seen timestamps
- Split-view device management interface with list and detail views
- Device search and filtering capabilities

#### Network Tools
- PingToolView: Interactive ping with real-time streaming latency display
- TracerouteToolView: Network path tracing with hop-by-hop visualization
- PortScannerToolView: TCP port scanning with common port presets (22, 80, 443, etc.)
- DNSLookupToolView: DNS query tool supporting A, AAAA, MX, TXT, NS record types
- WHOISToolView: Domain registration lookup via whois command
- BonjourBrowserToolView: Browse mDNS services on local network
- WakeOnLanToolView: Send magic packets to wake sleeping devices
- ShellCommandRunner actor for safe shell command execution with streaming support

#### Dashboard & Interface
- Elegant glass-morphic design with cyan accent colors (#06B6D4)
- Real-time statistics dashboard with online/offline target counts
- Navigation split-view with 220px sidebar
- Target status cards with color-coded reachability indicators
- Live latency charts and historical data visualization
- Dark gradient background with glass effect cards

#### Menu Bar Integration
- NSStatusItem with dynamic icon and color states
- Menu bar popover with quick stats and top 5 targets
- Start/stop monitoring control from menu bar
- Icon states: network (stopped), network.green (monitoring), network.slash (issues)
- MenuBarController for status item management
- MenuBarPopoverView for quick access interface

#### Settings
- GeneralSettingsView: Launch at login via SMAppService, appearance mode selection
- MonitoringSettingsView: Default check intervals, timeout configuration, retry behavior
- NotificationSettingsView: Alert sounds, latency threshold configuration
- NetworkSettingsView: Network interface selection, proxy settings
- DataSettingsView: History retention policies, CSV export, clear data
- AppearanceSettingsView: Accent colors, compact mode, theme customization
- CompanionSettingsView: Companion service configuration and port settings
- All settings persist via @AppStorage with `netmonitor.*` key prefix

#### Companion App Support
- CompanionService with Bonjour advertising on `_netmon._tcp` port 8849
- JSON-based message protocol with length-prefixed framing
- CompanionMessageHandler for command processing
- Real-time status updates broadcast to connected companion apps
- Supported commands: startMonitoring, stopMonitoring, scanDevices, ping, wakeOnLan, refreshTargets, refreshDevices
- Target list and device list synchronization
- NetMonitorShared Swift package for shared protocol definitions

#### Architecture & Infrastructure
- MVVM architecture with SwiftUI and @Observable view models
- SwiftData persistence with @Model entities
- Actor-based service layer for thread-safe networking
- Dependency injection via SwiftUI environment
- Network.framework integration (NWConnection, NWListener, NWBrowser)
- Swift 6 strict concurrency mode with async/await
- Protocol-oriented design for testability
- Comprehensive error handling with graceful degradation

#### Testing
- Unit tests for MonitoringSession lifecycle
- Service tests for HTTP, TCP, ARP, Bonjour, shell command execution
- Protocol tests for CompanionMessage encoding/decoding
- Device discovery coordinator merge logic tests
- MAC vendor lookup tests
- UI tests for critical workflows

#### Documentation
- Comprehensive CLAUDE.md project guide
- Companion-Protocol-API.md reference documentation
- Architecture overview and design patterns
- Development commands for building and testing
- Performance requirements and benchmarks

[1.0.0]: https://github.com/yourusername/NetMonitor/releases/tag/v1.0.0
