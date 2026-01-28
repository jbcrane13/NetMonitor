# NetMonitor

A professional network monitoring application for macOS that provides real-time network diagnostics, target monitoring, local device discovery, and comprehensive network utilities.

## Features

### Network Monitoring
- Real-time target monitoring with configurable check intervals (5-60 seconds)
- Support for multiple protocols: ICMP (ping), HTTP, HTTPS, and TCP
- Historical latency tracking with persistent measurement storage
- Automatic retry with configurable timeout settings
- Live dashboard with target status cards and statistics

### Device Discovery
- Two-phase discovery combining ARP scanning and Bonjour (mDNS) service detection
- Automatic MAC address vendor lookup (50+ manufacturers)
- Device categorization (phones, laptops, tablets, routers, IoT, etc.)
- Custom device naming and notes
- Online/offline status tracking with first seen/last seen timestamps

### Network Tools
Eight diagnostic utilities with intuitive interfaces:

1. **Ping** - Interactive ping with real-time streaming latency display
2. **Traceroute** - Network path tracing with hop-by-hop visualization
3. **Port Scanner** - TCP port scanning with common port presets
4. **DNS Lookup** - DNS query tool supporting A, AAAA, MX, TXT, NS records
5. **WHOIS** - Domain registration and ownership lookup
6. **Bonjour Browser** - Browse mDNS services on the local network
7. **Wake-on-LAN** - Send magic packets to wake sleeping devices

### Dashboard & UI
- Elegant glass-morphic design with cyan accent colors
- Real-time statistics and target status overview
- Split-view device management with detailed device information
- Menu bar integration with quick stats popover
- Launch at login support

### Settings
Comprehensive configuration options:
- Monitoring intervals and timeout preferences
- Notification and alert settings
- Network interface selection
- Data retention and CSV export
- Appearance customization (themes, compact mode)
- Companion app service configuration

### Companion App Support
- Bonjour service advertising for iOS companion app discovery
- JSON-based message protocol with length-prefixed framing
- Real-time status updates and command processing
- Supports: start/stop monitoring, device scanning, ping, Wake-on-LAN

## Screenshots

> Screenshots coming soon

## Requirements

- **macOS**: 15.0+ (Sequoia or later)
- **Xcode**: 16.0+
- **Swift**: 6.0+

## Building

### From Command Line

```bash
# Clean build
xcodebuild -project NetMonitor.xcodeproj -scheme NetMonitor clean

# Build Debug configuration
xcodebuild -project NetMonitor.xcodeproj -scheme NetMonitor -configuration Debug build

# Build and run
xcodebuild -project NetMonitor.xcodeproj -scheme NetMonitor -configuration Debug build && open ./build/Debug/NetMonitor.app
```

### From Xcode

1. Open `NetMonitor.xcodeproj`
2. Select the NetMonitor scheme
3. Press `Cmd+R` to build and run

## Testing

```bash
# Run all tests from command line
xcodebuild -project NetMonitor.xcodeproj -scheme NetMonitor test

# Or use Xcode: Cmd+U
```

Tests include:
- Service layer unit tests (monitoring, discovery, shell command execution)
- Protocol tests (companion message encoding/decoding)
- UI tests for critical workflows

## Architecture

NetMonitor uses a modern Swift architecture optimized for macOS:

### Design Patterns
- **MVVM**: SwiftUI views with `@Observable` view models
- **Dependency Injection**: Services passed via SwiftUI environment
- **Protocol-Oriented**: `NetworkMonitorService` protocol with specialized implementations
- **Actor-Based Services**: Thread-safe networking with Swift actors

### Key Technologies
- **SwiftUI**: Modern declarative UI with `NavigationSplitView`
- **SwiftData**: Persistent storage with `@Model` entities
- **Network.framework**: Low-level networking (`NWConnection`, `NWListener`, `NWBrowser`)
- **AppKit**: Menu bar integration (`NSStatusItem`, `NSPopover`)
- **Swift Concurrency**: async/await with structured concurrency

### Project Structure
```
NetMonitor/
├── NetMonitor/                    # Main macOS app
│   ├── Models/                    # SwiftData models
│   ├── Services/                  # Actor-based services
│   ├── Views/                     # SwiftUI views
│   ├── MenuBar/                   # Menu bar integration
│   └── NetMonitorApp.swift        # App entry point
├── NetMonitorShared/              # Shared Swift package
│   └── Sources/
│       ├── Protocol/              # Companion protocol
│       └── Common/                # Shared enums
├── NetMonitorTests/               # Unit tests
├── NetMonitorUITests/             # UI tests
└── docs/                          # Documentation
```

### Core Services
- **MonitoringSession**: Main coordinator for target monitoring lifecycle
- **DeviceDiscoveryCoordinator**: Unified device discovery orchestration
- **HTTPMonitorService**: HTTP/HTTPS endpoint monitoring
- **TCPMonitorService**: TCP port connectivity checks
- **ProcessPingService**: Shell-based ICMP ping with streaming
- **ARPScannerService**: Local network device scanning
- **BonjourDiscoveryService**: mDNS service discovery
- **CompanionService**: iOS companion app integration

## Permissions

NetMonitor requires local network access to function. The app will request permission on first launch.

**Info.plist declaration:**
```xml
<key>NSLocalNetworkUsageDescription</key>
<string>NetMonitor needs local network access to discover devices and monitor network targets on your local network.</string>
```

## Performance

- Dashboard refresh: 1 second intervals
- Target checks: Configurable 5-60 seconds
- Device scans: Complete /24 subnet in < 30 seconds
- Memory usage: < 150MB during typical operation
- CPU usage: < 5% during active monitoring
- Startup time: < 2 seconds

## License

MIT License

Copyright (c) 2026

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
