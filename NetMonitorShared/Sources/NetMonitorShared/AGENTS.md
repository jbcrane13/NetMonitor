<!-- Parent: ../../AGENTS.md -->
<!-- Generated: 2026-01-28 | Updated: 2026-01-28 -->

# NetMonitorShared Module

## Purpose

Core Swift module providing cross-platform data types and communication protocols for companion app integration. Defines type-safe message types, payloads, and enums that both macOS and iOS platforms use for networked communication and data serialization.

**Key Responsibility:** Enable type-safe, `Sendable`, JSON-serializable message passing between macOS monitor and iOS companion via strict concurrency-compliant enums and structs.

## Structure

```
Sources/NetMonitorShared/
├── Protocol/
│   └── CompanionMessage.swift      # Message types, payloads, and protocol
└── Common/
    └── Enums.swift                  # Shared enums with SF Symbol icons
```

## Subdirectories

| Directory | Purpose | Files |
|-----------|---------|-------|
| `Protocol/` | Message protocol for macOS-iOS communication | CompanionMessage.swift |
| `Common/` | Shared data types (enums) used by both platforms | Enums.swift |

## For AI Agents

### Working In This Directory

**Constraints:**

1. **Swift 6 Strict Concurrency**: All new types MUST conform to `Sendable`
2. **Cross-Platform**: Code runs on both macOS (15+) and iOS (18+)
3. **JSON Protocol**: All message types must conform to both `Codable` and `Sendable`
4. **Public API Only**: All types exported via `public` keyword - no internal implementation leaks
5. **Foundation Only**: Package has ZERO external dependencies - import Foundation only

**Import Rules:**

```swift
import Foundation  // ONLY valid import

// DO NOT add:
// import SwiftUI
// import UIKit
// import AppKit
// import Network
// import SwiftData
// (These are platform-specific - use in main apps instead)
```

### Common Patterns

#### Pattern 1: Message Enum with Type Discrimination

The root `CompanionMessage` enum uses custom `Codable` with a `type` field for JSON serialization. This pattern enables safe decoding of multiple message types from network data.

```swift
public enum CompanionMessage: Codable, Sendable {
    case statusUpdate(StatusUpdatePayload)
    case targetList(TargetListPayload)
    case deviceList(DeviceListPayload)
    case command(CommandPayload)
    case toolResult(ToolResultPayload)
    case error(ErrorPayload)
    case heartbeat(HeartbeatPayload)

    enum CodingKeys: String, CodingKey {
        case type      // JSON: "type": "statusUpdate"
        case payload   // JSON: "payload": { ... }
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)

        switch type {
        case "statusUpdate":
            let payload = try container.decode(StatusUpdatePayload.self, forKey: .payload)
            self = .statusUpdate(payload)
        // ... other cases
        default:
            throw DecodingError.dataCorruptedError(...)
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        switch self {
        case .statusUpdate(let payload):
            try container.encode("statusUpdate", forKey: .type)
            try container.encode(payload, forKey: .payload)
        // ... other cases
        }
    }
}
```

**When Adding a New Message Type:**

1. Add enum case in `CompanionMessage`
2. Add switch case in `init(from:)` to handle decoding
3. Add switch case in `encode(to:)` to handle encoding
4. Create corresponding `PayloadStruct` (see Pattern 2)

#### Pattern 2: Payload Structs

Each message type carries a typed payload struct. All payloads conform to `Codable` and `Sendable`, with explicit initializers for clarity.

```swift
public struct StatusUpdatePayload: Codable, Sendable {
    public let isMonitoring: Bool
    public let onlineTargets: Int
    public let offlineTargets: Int
    public let averageLatency: Double?
    public let timestamp: Date

    public init(
        isMonitoring: Bool,
        onlineTargets: Int,
        offlineTargets: Int,
        averageLatency: Double?,
        timestamp: Date = Date()
    ) {
        self.isMonitoring = isMonitoring
        self.onlineTargets = onlineTargets
        self.offlineTargets = offlineTargets
        self.averageLatency = averageLatency
        self.timestamp = timestamp
    }
}
```

**Conventions:**

- Use `public struct` (value semantics for Sendable)
- Mark all properties `public`
- Add explicit `init()` with convenience defaults (e.g., `Date()`)
- Never use classes (not easily Sendable)
- All types in payload must be `Sendable`

#### Pattern 3: Identifiable Payloads

Payloads containing arrays of items conform to `Identifiable` to support SwiftUI ForEach without explicit `id:` parameter.

```swift
public struct TargetInfo: Codable, Sendable, Identifiable {
    public let id: UUID
    public let name: String
    public let host: String
    public let port: Int?
    public let `protocol`: String
    public let isEnabled: Bool
    public let isReachable: Bool?
    public let latency: Double?

    public init(
        id: UUID,
        name: String,
        host: String,
        port: Int?,
        protocol: String,
        isEnabled: Bool,
        isReachable: Bool?,
        latency: Double?
    ) {
        self.id = id
        self.name = name
        self.host = host
        self.port = port
        self.protocol = `protocol`  // Backticks: protocol is keyword
        self.isEnabled = isEnabled
        self.isReachable = isReachable
        self.latency = latency
    }
}
```

**Note:** `id` property is required by `Identifiable` protocol.

#### Pattern 4: Enum with String Raw Values

Shared enums conform to `String`, `Codable`, `Sendable`, and `CaseIterable` for cross-platform compatibility and UI integration.

```swift
/// Monitoring protocol type
public enum TargetProtocol: String, Codable, Sendable, CaseIterable {
    case icmp = "ICMP"
    case http = "HTTP"
    case https = "HTTPS"
    case tcp = "TCP"

    public var iconName: String {
        switch self {
        case .http, .https:
            return "network"
        case .icmp:
            return "waveform.path.ecg"
        case .tcp:
            return "arrow.left.arrow.right"
        }
    }
}
```

**Conventions:**

- Use `String` raw values matching JSON representation
- Raw values are typically PascalCase for display names
- Add `iconName` computed property for SF Symbol integration
- Use `CaseIterable` to enable UI pickers and lists
- Keep case count reasonable (aim for < 20 cases)

#### Pattern 5: Enum Extensions for Computed Properties

Complex computed properties or helper methods go in extensions rather than cluttering the enum declaration.

```swift
extension TargetProtocol {
    public var iconName: String {
        switch self {
        case .http, .https:
            return "network"
        case .icmp:
            return "waveform.path.ecg"
        case .tcp:
            return "arrow.left.arrow.right"
        }
    }

    public var displayName: String {
        self.rawValue  // or custom logic
    }
}
```

### File Organization

**CompanionMessage.swift Structure:**

```
1. Imports (Foundation only)
2. Root CompanionMessage enum
3. CodingKeys helper enum
4. Custom Codable implementation (init, encode)
5. MARK: - Payload Types
6. StatusUpdatePayload struct
7. TargetListPayload struct
8. TargetInfo struct (with Identifiable)
9. DeviceListPayload struct
10. DeviceInfo struct (with Identifiable)
11. CommandPayload struct
12. CommandAction enum
13. ToolResultPayload struct
14. ErrorPayload struct
15. HeartbeatPayload struct
```

**Enums.swift Structure:**

```
1. Imports (Foundation only)
2. /// Doc comment
3. enum ConnectionType: String, Codable, Sendable, CaseIterable { }
4. /// Doc comment
5. enum TargetProtocol: String, Codable, Sendable, CaseIterable { }
6. /// Doc comment
7. enum DeviceType: String, Codable, Sendable, CaseIterable { }
8. MARK: - TargetProtocol Extension
9. extension TargetProtocol { public var iconName: String { } }
```

### Common Tasks

#### Adding a New Message Type

**Example: Add a `configUpdate` message**

In `CompanionMessage.swift`:

```swift
// 1. Add case
public enum CompanionMessage: Codable, Sendable {
    case configUpdate(ConfigUpdatePayload)  // NEW
    // ... existing cases
}

// 2. Add to init(from:) switch
case "configUpdate":
    let payload = try container.decode(ConfigUpdatePayload.self, forKey: .payload)
    self = .configUpdate(payload)

// 3. Add to encode(to:) switch
case .configUpdate(let payload):
    try container.encode("configUpdate", forKey: .type)
    try container.encode(payload, forKey: .payload)

// 4. Add payload struct
public struct ConfigUpdatePayload: Codable, Sendable {
    public let setting: String
    public let value: String

    public init(setting: String, value: String) {
        self.setting = setting
        self.value = value
    }
}
```

#### Adding a New Enum

**Example: Add a `NetworkSpeed` enum**

In `Enums.swift`:

```swift
/// Network speed classification
public enum NetworkSpeed: String, Codable, Sendable, CaseIterable {
    case slow = "Slow"
    case medium = "Medium"
    case fast = "Fast"
    case verySlow = "VerySlow"

    public var threshold: Int {
        switch self {
        case .verySlow: return 10
        case .slow: return 50
        case .medium: return 200
        case .fast: return 1000
        }
    }
}
```

#### Renaming a Field in a Payload

Use `CodingKeys` to maintain backward compatibility:

```swift
public struct MyPayload: Codable, Sendable {
    public let newFieldName: String

    enum CodingKeys: String, CodingKey {
        case newFieldName = "oldFieldName"  // Maps to old JSON key
    }
}
```

This allows iOS to decode JSON from older macOS versions without breaking.

### Testing Requirements

**Location:** Tests live in `/Users/blake/Projects/NetMonitor/NetMonitorTests/Protocol/CompanionMessageTests.swift`

**Test Coverage:**

1. **Message Encoding**
   - Each message case encodes with correct `type` field
   - Payload data encodes correctly
   - Date fields encode as ISO 8601

2. **Message Decoding**
   - Valid JSON decodes to correct message case
   - Invalid message type throws `DecodingError`
   - Optional fields decode as nil when absent

3. **Payload Round-Tripping**
   - Encode then decode returns equal values
   - Works for all payload types

4. **Enum Case Iteration**
   - `CaseIterable` returns all cases
   - `rawValue` matches expected strings
   - SF Symbol `iconName` returns valid symbols

**Test Template:**

```swift
import Testing
@testable import NetMonitorShared

@Suite("Companion Message Protocol")
struct CompanionMessageTests {

    @Test("statusUpdate message encodes and decodes")
    func roundTripStatusUpdate() throws {
        let payload = StatusUpdatePayload(
            isMonitoring: true,
            onlineTargets: 5,
            offlineTargets: 2,
            averageLatency: 45.2
        )
        let original = CompanionMessage.statusUpdate(payload)

        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(CompanionMessage.self, from: encoded)

        if case .statusUpdate(let decodedPayload) = decoded {
            #expect(decodedPayload.isMonitoring == true)
            #expect(decodedPayload.onlineTargets == 5)
            #expect(decodedPayload.offlineTargets == 2)
        } else {
            Issue.record("Expected statusUpdate case")
        }
    }

    @Test("unknown message type throws error")
    func unknownMessageType() throws {
        let json = """
        {"type": "unknownType", "payload": {}}
        """.data(using: .utf8)!

        let error = try #require(
            await throws: {
                try JSONDecoder().decode(CompanionMessage.self, from: json)
            } as Error
        )
        #expect(error is DecodingError)
    }
}
```

## Message Protocol Reference

### Message Types (7 Total)

| Message | Payload | Direction | Purpose |
|---------|---------|-----------|---------|
| `statusUpdate` | StatusUpdatePayload | macOS → iOS | Monitor status (counts, latency) |
| `targetList` | TargetListPayload | macOS → iOS | All monitoring targets with status |
| `deviceList` | DeviceListPayload | macOS → iOS | All discovered devices |
| `command` | CommandPayload | iOS → macOS | Execute action on macOS |
| `toolResult` | ToolResultPayload | macOS → iOS | Tool execution result |
| `error` | ErrorPayload | Both | Error message with code |
| `heartbeat` | HeartbeatPayload | macOS → iOS | Connection keepalive |

### Payloads and Structures (10 Total)

#### 1. StatusUpdatePayload

```swift
public struct StatusUpdatePayload: Codable, Sendable {
    public let isMonitoring: Bool
    public let onlineTargets: Int
    public let offlineTargets: Int
    public let averageLatency: Double?  // milliseconds
    public let timestamp: Date
}
```

Used by macOS to broadcast current monitoring state every 5-10 seconds.

#### 2. TargetListPayload

```swift
public struct TargetListPayload: Codable, Sendable {
    public let targets: [TargetInfo]
}
```

Complete list of monitoring targets. Sent when iOS requests refresh or targets change.

#### 3. TargetInfo (Identifiable)

```swift
public struct TargetInfo: Codable, Sendable, Identifiable {
    public let id: UUID
    public let name: String
    public let host: String
    public let port: Int?
    public let `protocol`: String  // "HTTP", "ICMP", "TCP", "HTTPS"
    public let isEnabled: Bool
    public let isReachable: Bool?  // Latest check result
    public let latency: Double?    // milliseconds
}
```

Individual monitoring target with current status. `Identifiable` for SwiftUI integration.

#### 4. DeviceListPayload

```swift
public struct DeviceListPayload: Codable, Sendable {
    public let devices: [DeviceInfo]
}
```

All discovered local network devices. Sent after ARP/Bonjour scans complete.

#### 5. DeviceInfo (Identifiable)

```swift
public struct DeviceInfo: Codable, Sendable, Identifiable {
    public let id: UUID
    public let ipAddress: String
    public let macAddress: String
    public let hostname: String?
    public let vendor: String?
    public let deviceType: String
    public let isOnline: Bool
}
```

Single device with identification and status. `Identifiable` for SwiftUI.

#### 6. CommandPayload

```swift
public struct CommandPayload: Codable, Sendable {
    public let action: CommandAction  // Type-safe
    public let parameters: [String: String]?
}

public enum CommandAction: String, Codable, Sendable {
    case startMonitoring
    case stopMonitoring
    case scanDevices
    case ping
    case traceroute
    case portScan
    case dnsLookup
    case wakeOnLan
    case refreshTargets
    case refreshDevices
}
```

Command from iOS to macOS. Type-safe `CommandAction` enum prevents invalid commands.

**Example:**
```json
{
  "type": "command",
  "payload": {
    "action": "ping",
    "parameters": {
      "host": "google.com",
      "count": "4"
    }
  }
}
```

#### 7. ToolResultPayload

```swift
public struct ToolResultPayload: Codable, Sendable {
    public let tool: String        // "ping", "traceroute", "dnsLookup"
    public let success: Bool
    public let result: String      // stdout from tool
    public let timestamp: Date
}
```

Result of network tool execution. Sent from macOS to iOS after tool completes.

#### 8. ErrorPayload

```swift
public struct ErrorPayload: Codable, Sendable {
    public let code: String        // "NETWORK_ERROR", "PERMISSION_DENIED", etc.
    public let message: String     // Human-readable error message
    public let timestamp: Date
}
```

Error notification sent from either platform. Enables graceful error handling without breaking connection.

#### 9. HeartbeatPayload

```swift
public struct HeartbeatPayload: Codable, Sendable {
    public let timestamp: Date
    public let version: String     // Protocol version, currently "1.0"
}
```

Keepalive message to maintain connection and verify version compatibility.

### Shared Enums (3 Total)

#### 1. TargetProtocol

```swift
public enum TargetProtocol: String, Codable, Sendable, CaseIterable {
    case icmp = "ICMP"
    case http = "HTTP"
    case https = "HTTPS"
    case tcp = "TCP"

    public var iconName: String {
        switch self {
        case .http, .https: return "network"
        case .icmp: return "waveform.path.ecg"
        case .tcp: return "arrow.left.arrow.right"
        }
    }
}
```

Monitoring protocol types with SF Symbol icons for UI display.

#### 2. DeviceType

```swift
public enum DeviceType: String, Codable, Sendable, CaseIterable {
    case phone = "Phone"
    case laptop = "Laptop"
    case tablet = "Tablet"
    case tv = "TV"
    case speaker = "Speaker"
    case gaming = "Gaming"
    case iot = "IoT"
    case router = "Router"
    case printer = "Printer"
    case unknown = "Unknown"

    public var iconName: String {
        switch self {
        case .phone: return "iphone"
        case .laptop: return "laptopcomputer"
        case .tablet: return "ipad"
        case .tv: return "tv"
        case .speaker: return "homepod"
        case .gaming: return "gamecontroller"
        case .iot: return "sensor"
        case .router: return "wifi.router"
        case .printer: return "printer"
        case .unknown: return "questionmark.circle"
        }
    }
}
```

10 device type classifications with SF Symbol icons for UI display.

#### 3. ConnectionType

```swift
public enum ConnectionType: String, Codable, Sendable, CaseIterable {
    case wifi = "WiFi"
    case ethernet = "Ethernet"
    case cellular = "Cellular"
    case unknown = "Unknown"
}
```

Network connection type classifications (currently unused but available for future features).

## Message Flow Examples

### Example 1: Status Update (Broadcast)

macOS sends every 5 seconds:

```json
{
  "type": "statusUpdate",
  "payload": {
    "isMonitoring": true,
    "onlineTargets": 5,
    "offlineTargets": 1,
    "averageLatency": 45.2,
    "timestamp": "2026-01-28T12:30:45.123Z"
  }
}
```

### Example 2: Device List (On Request)

iOS requests `command` with `scanDevices`, macOS responds with:

```json
{
  "type": "deviceList",
  "payload": {
    "devices": [
      {
        "id": "550E8400-E29B-41D4-A716-446655440000",
        "ipAddress": "192.168.1.10",
        "macAddress": "AA:BB:CC:DD:EE:FF",
        "hostname": "iPhone-Blake",
        "vendor": "Apple",
        "deviceType": "Phone",
        "isOnline": true
      }
    ]
  }
}
```

### Example 3: Tool Result (After Ping)

macOS returns ping result:

```json
{
  "type": "toolResult",
  "payload": {
    "tool": "ping",
    "success": true,
    "result": "PING google.com (142.250.185.46): 56 data bytes\n64 bytes from 142.250.185.46: icmp_seq=0 ttl=55 time=45.2 ms",
    "timestamp": "2026-01-28T12:30:45.123Z"
  }
}
```

## Dependencies

**Internal Only:**
- `Foundation` - JSON coding, Date, UUID, Sendable protocol
- No external package dependencies

**Used By:**
- macOS app (`NetMonitor`): Imports `NetMonitorShared` for message types
- iOS companion app: Decodes and encodes messages
- Tests: Validates JSON serialization

**Compilation:**

```bash
# Build Swift package
swift build --package-path /Users/blake/Projects/NetMonitor/NetMonitorShared

# Run tests
swift test --package-path /Users/blake/Projects/NetMonitor/NetMonitorShared

# Xcode integration (automatic)
# NetMonitor.xcodeproj includes package as dependency
```

## Anti-Patterns

| Don't | Why | Do Instead |
|-------|-----|-----------|
| Add `import SwiftUI` | Not available in iOS or macOS consistently | Import only `Foundation` |
| Use `class` for payloads | Classes not easily Sendable | Use `struct` with Codable |
| Omit `public` keyword | Swift packages require explicit public API | Mark all exported types `public` |
| Change JSON key names | Breaks iOS decode from older macOS | Use CodingKeys for mapping |
| Skip Sendable conformance | Violates strict concurrency | Add to all types: `Sendable` |
| Hardcode message strings | Prone to typos and mismatches | Use enum switch on type field |
| Store business logic | Modules are data transfer only | Implement in app services |
| Add optional without nil handling | JSON roundtrips lose nil | Use explicit `init()` defaults |
| Use generic type names | Conflicts with SwiftUI types | Prefix with domain (e.g., `TargetInfo`) |
| Forget `CaseIterable` | UI pickers can't iterate | Add `CaseIterable` to enums |

## Implementation Notes

**JSON Framing:** macOS app uses length-prefixed TCP framing (4-byte UInt32 message length + JSON data)

**Date Encoding:** Uses ISO 8601 format by default (JSONDecoder/JSONEncoder standard)

**Message Broadcast:** macOS sends `statusUpdate` every 5-10 seconds; iOS sends `command` on user action only

**Error Handling:** Use `ErrorPayload` for transport errors; optional fields handle graceful degradation

**Version Strategy:** Currently protocol "1.0". Add new message cases rather than versioning existing payloads

**Thread Safety:** All types `Sendable` conforming - safe to use on any thread (iOS main, macOS actor context)

**JSON Compatibility:** Encoding/decoding works across all platforms supporting Foundation.Codable

<!-- MANUAL: Last verified 2026-01-28 -->
