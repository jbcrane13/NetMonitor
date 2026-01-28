<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-01-28 | Updated: 2026-01-28 -->

# NetMonitorShared

## Purpose

Shared Swift Package providing cross-platform data types and communication protocols for NetMonitor macOS app and iOS companion app. Defines message types, payloads, and enums that both platforms use for network communication and type safety.

**Key Responsibility:** Enable type-safe, cross-platform message passing between macOS monitor and iOS companion via JSON-serializable enums and structs with strict concurrency compliance.

## Key Files

| File | Description | Type |
|------|-------------|------|
| `Package.swift` | Swift Package manifest (Swift 6.0, macOS 15+, iOS 18+) with StrictConcurrency | Config |
| `Protocol/CompanionMessage.swift` | Root message enum + 7 payload structs for companion communication | Protocol |
| `Common/Enums.swift` | Shared enums (TargetProtocol, DeviceType, ConnectionType) with SF Symbol mappings | Types |

## Subdirectories

| Directory | Purpose | Files |
|-----------|---------|-------|
| `Sources/NetMonitorShared/Protocol/` | Message protocol for macOS-iOS communication | CompanionMessage.swift |
| `Sources/NetMonitorShared/Common/` | Shared data types used by both platforms | Enums.swift |
| `Tests/` | Unit tests for message encoding/decoding | CompanionMessageTests.swift |

## For AI Agents

### Working In This Directory

**Rules:**
1. **Swift 6 Strict Concurrency**: All new types MUST be `Sendable`
2. **Cross-platform**: Code runs on both macOS (15+) and iOS (18+)
3. **JSON Protocol**: All message types must be `Codable` and `Sendable`
4. **Public API**: All types exported via `public` - no internal implementation leaks
5. **No Dependencies**: Package has ZERO external dependencies - only Foundation

**Import Requirements:**
```swift
import Foundation  // Only valid import

// Do NOT use:
// import SwiftUI (iOS has UIKit parts)
// import AppKit (macOS only)
// import Network (use in main app, not here)
```

**Naming Conventions:**
- **Message Cases**: `statusUpdate`, `targetList`, `command` (camelCase enum cases)
- **Payloads**: `StatusUpdatePayload`, `TargetListPayload` (PascalCase with Payload suffix)
- **Enums**: `TargetProtocol`, `DeviceType`, `ConnectionType` (PascalCase)
- **Command Actions**: `startMonitoring`, `stopMonitoring` (camelCase enum cases)

### File Organization (CompanionMessage.swift)

```swift
// 1. Imports (Foundation only)
import Foundation

// 2. Root Message Enum
public enum CompanionMessage: Codable, Sendable {
    case statusUpdate(StatusUpdatePayload)
    case targetList(TargetListPayload)
    // ...
}

// 3. CodingKeys for custom JSON encoding
enum CodingKeys: String, CodingKey {
    case type
    case payload
}

// 4. Custom Codable implementation (init(from:) and encode(to:))
public init(from decoder: Decoder) throws { }
public func encode(to encoder: Encoder) throws { }

// 5. MARK: - Payload Types
public struct StatusUpdatePayload: Codable, Sendable { }
public struct TargetListPayload: Codable, Sendable { }
// ... other payloads

// 6. Supporting Types
public enum CommandAction: String, Codable, Sendable { }
```

### Adding a New Message Type

**Template:**
```swift
// In CompanionMessage enum
case myMessage(MyPayload)

// In CodingKeys handling
case "myMessage":
    let payload = try container.decode(MyPayload.self, forKey: .payload)
    self = .myMessage(payload)

// In encode(to:)
case .myMessage(let payload):
    try container.encode("myMessage", forKey: .type)
    try container.encode(payload, forKey: .payload)

// Add payload struct
public struct MyPayload: Codable, Sendable {
    public let field: String

    public init(field: String) {
        self.field = field
    }
}
```

### File Organization (Enums.swift)

```swift
// 1. Imports (Foundation only)
import Foundation

// 2. Each enum with doc comment
/// Network connection type
public enum ConnectionType: String, Codable, Sendable, CaseIterable { }

/// Monitoring protocol type
public enum TargetProtocol: String, Codable, Sendable, CaseIterable { }

/// Local device type
public enum DeviceType: String, Codable, Sendable, CaseIterable {
    // Cases first
    case phone = "Phone"
    // ...

    // Computed properties after cases
    public var iconName: String { }
}

// 3. Extensions for helper methods
extension TargetProtocol {
    public var iconName: String { }
}
```

### Testing Requirements

**Test File Location:** `Tests/NetMonitorSharedTests/`

**Required Tests:**

1. **Message Encoding/Decoding**
   - Each message case encodes to JSON with `type` and `payload`
   - Each message case decodes from JSON correctly
   - Invalid message types throw `DecodingError`

2. **Payload Initialization**
   - All payload structs initialize with correct values
   - Date fields use `Date()` default in initializers
   - Optional fields handle nil correctly

3. **Enum Case Iteration**
   - `CaseIterable` conformance returns all cases
   - `RawValue` matches expected strings
   - SF Symbol `iconName` values are valid

**Example Test:**
```swift
import Testing
@testable import NetMonitorShared

@Suite("Companion Message Protocol Tests")
struct CompanionMessageTests {

    @Test("statusUpdate message encodes correctly")
    func statusUpdateEncoding() throws {
        let payload = StatusUpdatePayload(
            isMonitoring: true,
            onlineTargets: 5,
            offlineTargets: 2,
            averageLatency: 45.2
        )
        let message = CompanionMessage.statusUpdate(payload)

        let json = try JSONEncoder().encode(message)
        let decoded = try JSONDecoder().decode(CompanionMessage.self, from: json)

        if case .statusUpdate(let decodedPayload) = decoded {
            #expect(decodedPayload.isMonitoring == true)
            #expect(decodedPayload.onlineTargets == 5)
        } else {
            Issue.record("Expected statusUpdate case")
        }
    }

    @Test("invalid message type throws DecodingError")
    func invalidMessageType() throws {
        let json = """
        {"type": "unknownMessage", "payload": {}}
        """.data(using: .utf8)!

        // Should throw DecodingError
        _ = try JSONDecoder().decode(CompanionMessage.self, from: json)
    }
}
```

### Common Patterns

**Pattern 1: Enum Case with Payload**
```swift
// Use for messages with typed data
case targetList(TargetListPayload)  // Compiler ensures payload exists
```

**Pattern 2: CodingKeys for Type Discrimination**
```swift
// Custom Codable allows "type" field in JSON while cases are anonymous
enum CodingKeys: String, CodingKey {
    case type      // Maps to JSON "type": "statusUpdate"
    case payload   // Maps to JSON "payload": { ... }
}
```

**Pattern 3: Identifiable Payload Structs**
```swift
// Enables SwiftUI ForEach without explicit id:
public struct TargetInfo: Codable, Sendable, Identifiable {
    public let id: UUID  // Required by Identifiable
    public let name: String
    // ...
}
```

**Pattern 4: Computed Property for Display**
```swift
// Icon resolution from enum values
public var iconName: String {
    switch self {
    case .phone: return "iphone"
    case .laptop: return "laptopcomputer"
    // ...
    }
}
```

**Pattern 5: Default Initializers**
```swift
public init(
    isMonitoring: Bool,
    onlineTargets: Int,
    timestamp: Date = Date()  // Convenience default
) {
    self.isMonitoring = isMonitoring
    self.onlineTargets = onlineTargets
    self.timestamp = timestamp
}
```

## Message Protocol Reference

**Companion Message Types:** 7 cases

| Case | Payload | Direction | Purpose |
|------|---------|-----------|---------|
| `statusUpdate` | StatusUpdatePayload | macOS → iOS | Monitor status (online/offline targets, avg latency) |
| `targetList` | TargetListPayload | macOS → iOS | List of monitoring targets with current status |
| `deviceList` | DeviceListPayload | macOS → iOS | List of discovered devices |
| `command` | CommandPayload | iOS → macOS | Execute action (startMonitoring, ping, wakeOnLan) |
| `toolResult` | ToolResultPayload | macOS → iOS | Tool execution result (ping, traceroute, DNS lookup) |
| `error` | ErrorPayload | macOS ↔ iOS | Error message with code and timestamp |
| `heartbeat` | HeartbeatPayload | macOS → iOS | Connection keepalive (version "1.0") |

**Payload Structures:**

1. **StatusUpdatePayload**
   - `isMonitoring: Bool` - Monitor running state
   - `onlineTargets: Int` - Count of reachable targets
   - `offlineTargets: Int` - Count of unreachable targets
   - `averageLatency: Double?` - Optional average latency in ms
   - `timestamp: Date` - When status was captured

2. **TargetListPayload**
   - `targets: [TargetInfo]` - Array of monitoring targets

3. **TargetInfo** (Identifiable)
   - `id: UUID` - Target identifier
   - `name: String` - Display name
   - `host: String` - Hostname or IP
   - `port: Int?` - Optional port number
   - `protocol: String` - HTTP/HTTPS/ICMP/TCP
   - `isEnabled: Bool` - Monitoring enabled state
   - `isReachable: Bool?` - Latest reachability status
   - `latency: Double?` - Latest latency in milliseconds

4. **DeviceListPayload**
   - `devices: [DeviceInfo]` - Array of discovered devices

5. **DeviceInfo** (Identifiable)
   - `id: UUID` - Device identifier (default: UUID())
   - `ipAddress: String` - IPv4 address
   - `macAddress: String` - MAC address
   - `hostname: String?` - Optional hostname
   - `vendor: String?` - Optional vendor name
   - `deviceType: String` - Device type (phone, laptop, etc.)
   - `isOnline: Bool` - Currently online state

6. **CommandPayload**
   - `action: CommandAction` - Command enum (type-safe)
   - `parameters: [String: String]?` - Optional parameters

7. **CommandAction** - 10 command types
   - `startMonitoring` - Begin monitoring targets
   - `stopMonitoring` - Pause monitoring
   - `scanDevices` - Discover local network devices
   - `ping` - Execute ping tool
   - `traceroute` - Execute traceroute tool
   - `portScan` - Execute port scan tool
   - `dnsLookup` - Execute DNS query
   - `wakeOnLan` - Send magic packet
   - `refreshTargets` - Reload target list
   - `refreshDevices` - Reload device list

8. **ToolResultPayload**
   - `tool: String` - Tool name (ping, traceroute, dnsLookup)
   - `success: Bool` - Execution succeeded
   - `result: String` - Output/result text
   - `timestamp: Date` - When tool executed

9. **ErrorPayload**
   - `code: String` - Error code for categorization
   - `message: String` - Human-readable error message
   - `timestamp: Date` - When error occurred

10. **HeartbeatPayload**
    - `timestamp: Date` - Heartbeat time
    - `version: String` - Protocol version (default "1.0")

**Shared Enums:**

1. **TargetProtocol** (CaseIterable, Sendable)
   - Cases: `icmp`, `http`, `https`, `tcp`
   - Raw values: "ICMP", "HTTP", "HTTPS", "TCP"
   - SF Symbol icons: 🏥 (network), ❤️ (waveform), 🔗 (arrow.left.arrow.right)

2. **DeviceType** (CaseIterable, Sendable)
   - Cases: 10 types (phone, laptop, tablet, tv, speaker, gaming, iot, router, printer, unknown)
   - Raw values: PascalCase display names
   - SF Symbol icons: iphone, laptopcomputer, ipad, tv, homepod, gamecontroller, sensor, wifi.router, printer, questionmark.circle

3. **ConnectionType** (CaseIterable, Sendable)
   - Cases: `wifi`, `ethernet`, `cellular`, `unknown`
   - Raw values: "WiFi", "Ethernet", "Cellular", "Unknown"

## Dependencies

**Internal Only:**
- `Foundation` - JSON coding, Date, UUID, Sendable
- No external package dependencies

**Used By:**
- macOS app: `NetMonitor` imports `NetMonitorShared` for CompanionMessage types
- iOS companion app: Decodes messages sent from macOS
- Tests: `NetMonitorSharedTests` validates JSON roundtripping

**Building:**
```bash
# Build package from command line
swift build --package-path NetMonitorShared

# Run tests
swift test --package-path NetMonitorShared

# Build for Xcode workspace
# (NetMonitor.xcodeproj includes NetMonitorShared as package dependency)
```

## Anti-Patterns

| Don't | Why | Do Instead |
|-------|-----|-----------|
| Add SwiftUI import | iOS and macOS vary in UI | Use only Foundation |
| Make payload classes | Classes aren't `Sendable` easily | Use structs with Codable |
| Omit `public` on types | Swift packages require explicit public API | Mark all exported types `public` |
| Use custom property names in JSON | Breaks iOS decoding | Use `CodingKeys` for name mapping |
| Forget `Sendable` conformance | Breaks strict concurrency checking | Add `Sendable` to all public types |
| Hardcode message type strings | Prone to typos/mismatches | Use switch statement on type field |
| Put business logic in messages | Messages are data transfer | Implement logic in app services |
| Ignore optional/nil handling | JSON roundtripping loses type info | Explicit `init()` with defaults |

## Implementation Notes

- **JSON Framing**: macOS app uses length-prefixed framing over TCP (prepends message length as UInt32)
- **Date Encoding**: Uses ISO 8601 format by default (JSONDecoder/JSONEncoder)
- **Message Flow**: Typically macOS broadcasts statusUpdate, targetList every 5-10 seconds; iOS sends commands on user action
- **Error Handling**: ErrorPayload for network-level errors; individual messages use optional fields for graceful degradation
- **Version**: Currently protocol version "1.0" - add new message cases rather than versioning existing payloads
- **Thread Safety**: All types `Sendable`; use on any thread - iOS SwiftUI main thread, macOS uses actor context

<!-- MANUAL: Last verified 2026-01-28 -->
