# SERVICES KNOWLEDGE BASE

Actor-based network services for monitoring and discovery.

## STRUCTURE

```
Services/
├── NetworkMonitorService.swift    # Protocol + error types (MUST be Actor)
├── DeviceDiscoveryService.swift   # Protocol + DiscoveredDevice struct
├── HTTPMonitorService.swift       # URLSession HEAD requests
├── ICMPMonitorService.swift       # Wraps ICMPSocket
├── ICMPSocket.swift               # /sbin/ping subprocess
├── TCPMonitorService.swift        # Raw socket connect()
├── ARPScannerService.swift        # NWConnection probe + arp cache
├── BonjourDiscoveryService.swift  # NWBrowser mDNS discovery
├── DeviceDiscoveryCoordinator.swift  # @MainActor merger
├── MonitoringSession.swift        # @MainActor coordinator
├── CompanionService.swift         # Bonjour server on :8849
├── CompanionMessageHandler.swift  # Command processor
├── MACVendorLookupService.swift   # OUI prefix database
└── WakeOnLanService.swift         # Magic packet sender
```

## WHERE TO LOOK

| Task | File |
|------|------|
| Add new monitor protocol | `NetworkMonitorService.swift` |
| HTTP/HTTPS health check | `HTTPMonitorService.swift` |
| ICMP ping | `ICMPMonitorService.swift` + `ICMPSocket.swift` |
| TCP port check | `TCPMonitorService.swift` |
| ARP scanning | `ARPScannerService.swift` |
| Bonjour/mDNS | `BonjourDiscoveryService.swift` |
| Start/stop monitoring | `MonitoringSession.swift` |
| Companion commands | `CompanionMessageHandler.swift` |

## CRITICAL RULES

1. **All monitoring services MUST be actors**
   ```swift
   protocol NetworkMonitorService: Actor { ... }
   ```

2. **Coordinators are @MainActor**
   - `MonitoringSession` - monitoring state
   - `DeviceDiscoveryCoordinator` - device merge
   - `CompanionMessageHandler` - command dispatch

3. **SwiftData access confined**
   - Only coordinators access ModelContext
   - Pure actors return value types (TargetMeasurement struct)

## ANTI-PATTERNS

| Don't | Do Instead |
|-------|------------|
| Class implementing NetworkMonitorService | Actor implementing protocol |
| Raw ICMP socket calls | Use ICMPSocket actor (wraps /sbin/ping) |
| Direct arp command | Use ARPScannerService.readARPCache() |
| Sync continuation resume | Use ResumeTracker pattern |

## KEY IMPLEMENTATIONS

### HTTPMonitorService
- URLSession.shared with HEAD request
- Status 200-399 = reachable
- Measures CFAbsoluteTimeGetCurrent() delta

### ICMPSocket
- Spawns `/sbin/ping -c 1 -W {timeout} {host}`
- Parses latency via regex: `time[=<](\d+\.?\d*)\s*ms`
- ICMPPacket struct unused (for future raw socket)

### TCPMonitorService
- Darwin socket() + connect() with O_NONBLOCK
- poll() with timeout
- getaddrinfo() for DNS resolution

### ARPScannerService
- getifaddrs() for network interface info
- NWConnection TCP:80 probes (concurrent)
- Reads `/usr/sbin/arp -n {ip}` for MAC

### BonjourDiscoveryService
- NWBrowser for 15 service types
- NWConnection for resolution
- Groups by IP, extracts TXT records

## CONTINUATION SAFETY

Both ARP and Bonjour services use ResumeTracker for callback safety:

```swift
final class ResumeTracker: @unchecked Sendable {
    private let lock = NSLock()
    private var _hasResumed = false
    func tryResume() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        guard !_hasResumed else { return false }
        _hasResumed = true
        return true
    }
}
```

Required because Network.framework callbacks can fire multiple times.

## DEPENDENCIES

```
MonitoringSession
  └── HTTP/ICMP/TCPMonitorService

DeviceDiscoveryCoordinator
  └── ARPScannerService
  └── BonjourDiscoveryService

CompanionMessageHandler
  └── MonitoringSession
  └── DeviceDiscoveryCoordinator
  └── WakeOnLanService
  └── ICMPMonitorService

ICMPMonitorService
  └── ICMPSocket

CompanionService
  └── NetMonitorShared (message types)
```
