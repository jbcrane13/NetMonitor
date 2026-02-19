# NetMonitor Pro

**Professional network monitoring and diagnostics for macOS.**

[![macOS 15+](https://img.shields.io/badge/macOS-15.0%2B-blue?logo=apple&logoColor=white)](https://www.apple.com/macos/)
[![Swift 6](https://img.shields.io/badge/Swift-6-F05138?logo=swift&logoColor=white)](https://swift.org)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![Xcode](https://img.shields.io/badge/Xcode-16%2B-147EFB?logo=xcode&logoColor=white)](https://developer.apple.com/xcode/)

Monitor your network in real-time, discover every device on your LAN, and troubleshoot connectivity with ten built-in diagnostic tools — all from a single native macOS app.

---

## Screenshots

<!-- Replace with actual screenshots -->
<!--
<p align="center">
  <img src="docs/screenshots/dashboard.png" width="720" alt="Dashboard Overview" />
</p>
<p align="center">
  <img src="docs/screenshots/devices.png" width="720" alt="Device Discovery" />
</p>
<p align="center">
  <img src="docs/screenshots/tools.png" width="720" alt="Network Tools" />
</p>
<p align="center">
  <img src="docs/screenshots/settings.png" width="720" alt="Settings" />
</p>
-->

*Screenshots coming soon.*

---

## Features

### Real-Time Network Monitoring

Monitor network targets across four protocols — **HTTP**, **HTTPS**, **ICMP**, and **TCP**. Configure custom check intervals (5-60 seconds) and timeouts per target. Track latency, uptime, and reachability with persistent historical data.

When monitoring is active, NetMonitor periodically scans the local network to discover and track all connected devices, providing ambient awareness without any manual configuration.

### Local Device Discovery

Automatically discover every device on your network using a dual-scan approach:

- **ARP scanning** identifies devices at Layer 2 with MAC addresses
- **Bonjour (mDNS)** discovers services advertised by Apple devices, printers, servers, and IoT hardware
- **MAC vendor lookup** identifies manufacturers (Apple, Samsung, Google, Cisco, Raspberry Pi, and 50+ more)

Devices are classified by type (phone, laptop, router, printer, IoT, etc.) with smart icons, custom naming, and notes.

### Intelligent Dashboard

A unified overview of your network health:

- **Connection info** — local IP address, active interface, and default gateway
- **ISP details** — internet service provider and public IP
- **Device summary** — online/offline counts and recently seen devices
- **Quick stats** — at-a-glance metrics for the entire monitored network
- **Live duration** — elapsed monitoring time with 1-second refresh

### Network Diagnostic Tools

Ten built-in tools cover every common troubleshooting scenario:

| Tool | Description |
|------|-------------|
| **Ping** | Interactive latency testing with real-time streaming results |
| **Traceroute** | Hop-by-hop network path visualization to any destination |
| **Port Scanner** | TCP port scanning with common port presets (HTTP, SSH, DNS, etc.) |
| **DNS Lookup** | Query A, AAAA, MX, TXT, and NS records for any domain |
| **Speed Test** | Bandwidth measurement for download and upload throughput |
| **WHOIS** | Domain registration and ownership lookup with parsed output |
| **Wake-on-LAN** | Send magic packets to wake sleeping devices on the network |
| **Bonjour Browser** | Browse and explore all mDNS services on the local network |
| **Network Map** | Radial topology visualization of discovered devices |
| **Compact Mode** | Menu bar popover for glanceable monitoring without the full window |

All tools validate input before execution, support cancellation for long-running operations, and display errors inline.

### iOS Companion App

Pair with **NetMonitor Mobile** on iPhone or iPad for remote monitoring:

- Zero-configuration discovery over Bonjour (`_netmon._tcp`)
- Remote start/stop of monitoring sessions
- Synchronized target and device lists
- Companion command execution (ping, wake-on-LAN, device scan)
- Length-prefixed JSON protocol — see [`docs/Companion-Protocol-API.md`](docs/Companion-Protocol-API.md)

### Menu Bar Integration

Quick-glance monitoring from the macOS menu bar:

- Dynamic status icon reflects current monitoring state
- Popover shows discovered devices and network status
- Start/stop scanning without opening the main window
- Keyboard shortcuts for common actions

### Dark Mode with Glass Effect

A professional dark interface designed for focused network work:

- Cyan accent color (#06B6D4) with dark gradient backgrounds
- Glass-morphic cards with subtle blur and transparency
- SF Pro Display/Text typography, SF Mono for IPs and MACs
- Full accessibility support with VoiceOver identifiers throughout

### Customization

Seven settings panels cover every preference:

- **General** — launch at login, appearance mode
- **Monitoring** — default check intervals, timeouts, retry behavior
- **Notifications** — alert sounds, latency thresholds
- **Network** — interface selection, proxy configuration
- **Data** — history retention, CSV export, clear data
- **Appearance** — accent colors, compact mode, dark theme
- **Companion** — service toggle, port configuration, connected devices

---

## Requirements

| Requirement | Version |
|-------------|---------|
| macOS | 15.0+ (Sequoia) |
| Xcode | 16.0+ |
| Swift | 6.0+ |
| Architecture | Apple Silicon or Intel |

---

## Installation

### From Source

```bash
git clone https://github.com/blakecrane/NetMonitor.git
cd NetMonitor
open NetMonitor.xcodeproj
# Press Cmd+R to build and run
```

Or build from the command line:

```bash
xcodebuild -project NetMonitor.xcodeproj \
  -scheme NetMonitor \
  -configuration Release \
  build
```

### Mac App Store

<!-- [Download on the Mac App Store](https://apps.apple.com/app/netmonitor-pro/id6759060882) -->
*Coming soon.*

---

## Architecture

NetMonitor follows **MVVM** with SwiftUI and is built entirely in **Swift 6** with strict concurrency checking enabled.

```
┌──────────────────────────────────────────────────────┐
│  SwiftUI Views  (NavigationSplitView)                │
│  Dashboard · Targets · Devices · Tools · Settings    │
├──────────────────────────────────────────────────────┤
│  @Observable ViewModels  (@MainActor)                │
│  MonitoringSession · DeviceDiscoveryCoordinator      │
├──────────────────────────────────────────────────────┤
│  Actor Services                                      │
│  HTTP · TCP · ICMP · ARP · Bonjour · Companion · WOL │
├──────────────────────────────────────────────────────┤
│  SwiftData Persistence                               │
│  NetworkTarget · LocalDevice · SessionRecord          │
├──────────────────────────────────────────────────────┤
│  Network.framework · Foundation                       │
└──────────────────────────────────────────────────────┘
```

Key patterns:

- **Actors** isolate all network services for thread safety
- **async/await** with structured concurrency throughout
- **SwiftData** `@Model` entities for persistent storage
- **`@Environment`** injection connects views to coordinators
- **Shared SPM package** (`NetMonitorShared/`) defines the companion protocol used by both macOS and iOS apps

See [`docs/ADR.md`](docs/ADR.md) for the full architecture decision log.

### Project Structure

```
NetMonitor/
├── NetMonitor/                # Main macOS app
│   ├── Models/                # SwiftData models
│   ├── Services/              # Actor-based network services
│   ├── Views/                 # SwiftUI views
│   │   ├── Tools/             # Diagnostic tool views
│   │   └── Settings/          # Settings tab views
│   └── MenuBar/               # NSStatusItem integration
├── NetMonitorShared/          # SPM package (companion protocol)
├── NetMonitorTests/           # Unit tests
├── NetMonitorUITests/         # UI tests
└── docs/                      # Documentation & ADRs
```

---

## Contributing

Contributions are welcome. Please:

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/your-feature`)
3. Commit your changes with conventional commits (`feat:`, `fix:`, `docs:`, `refactor:`)
4. Open a pull request against `main`

Read [`docs/ADR.md`](docs/ADR.md) before making structural changes, and append a new entry when introducing architectural decisions.

---

## License

This project is licensed under the **MIT License**. See [LICENSE](LICENSE) for details.

Copyright (c) 2026 Blake Crane
