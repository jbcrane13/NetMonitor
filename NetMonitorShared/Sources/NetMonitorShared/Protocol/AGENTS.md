<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-01-28 | Updated: 2026-01-28 -->

# Protocol

## Purpose

Defines the complete JSON message protocol for macOS-iOS communication over Bonjour/TCP. Implements type-safe message dispatch using custom `Codable` with discriminator pattern, enabling bidirectional communication between the NetMonitor macOS app and iOS companion app.

**Key Responsibility:** Serialize/deserialize 7 message types + 10 payload types with strict `Sendable` concurrency conformance for cross-platform messaging.

## Key Files

| File | Purpose | Size | Critical | Lines |
|------|---------|------|----------|-------|
| `CompanionMessage.swift` | Root message enum + all payloads + command actions | ~250 | Yes | 248 |

## Architecture Overview

### Message Structure

All messages follow type-discriminated format:

```json
{
  "type": "statusUpdate",
  "payload": { ... }
}
```

**Root enum** (`CompanionMessage`) has 7 cases:
1. `statusUpdate(StatusUpdatePayload)`
2. `targetList(TargetListPayload)`
3. `deviceList(DeviceListPayload)`
4. `command(CommandPayload)`
5. `toolResult(ToolResultPayload)`
6. `error(ErrorPayload)`
7. `heartbeat(HeartbeatPayload)`

### Payload Types (10 Structs)

| Payload | Contains | Usage | Direction |
|---------|----------|-------|-----------|
| `StatusUpdatePayload` | monitoring flag, counts, latency, timestamp | Broadcast status | macOS → iOS (5s) |
| `TargetListPayload` | array of `TargetInfo` | All targets snapshot | macOS → iOS (on-demand) |
| `TargetInfo` | id, name, host, port, protocol, status, latency | Single target details | In `TargetListPayload` |
| `DeviceListPayload` | array of `DeviceInfo` | All devices snapshot | macOS → iOS (after scan) |
| `DeviceInfo` | id, ip, mac, hostname, vendor, type, online | Single device details | In `DeviceListPayload` |
| `CommandPayload` | `CommandAction` enum, parameters dict | Execute action on macOS | iOS → macOS |
| `CommandAction` | 10 enum cases (startMonitoring, ping, etc.) | Type-safe actions | In `CommandPayload` |
| `ToolResultPayload` | tool name, success flag, result text, timestamp | Tool execution result | macOS → iOS |
| `ErrorPayload` | code, message, timestamp | Error notification | Both directions |
| `HeartbeatPayload` | timestamp, version | Connection keepalive | macOS → iOS (5s) |

### Custom Codable Pattern

```swift
// encode() switches on self, writes type + payload
// decode() reads type string, switches to decode correct payload type
// Unknown type → throws DecodingError.dataCorruptedError
```

Both `StatusUpdatePayload` and `HeartbeatPayload` include timestamps (used for connection freshness).

## For AI Agents

### Working In This Directory

**Golden Rules:**

1. **Swift 6 Strict Concurrency**: ALL types MUST have `Sendable` conformance
2. **Codable + Custom Init**: All structs have explicit `public init()`
3. **No Data Loss**: Optional fields must gracefully handle nil in JSON (use defaults)
4. **Backward Compatible**: Use `CodingKeys` if renaming fields to support older iOS versions
5. **Foundation Only**: Single import, no SwiftUI/UIKit/AppKit

**Type Safety Guarantees:**

- `CommandAction` enum prevents invalid commands at compile time
- Message enum with custom Codable prevents malformed JSON
- All types `Sendable` - safe to send across actors/threads
- `Identifiable` on collection items (TargetInfo, DeviceInfo) enables SwiftUI ForEach

### Common Patterns

#### Pattern 1: Adding a New Message Type

**3-step process:**

1. Add enum case to `CompanionMessage`
2. Add decode switch case in `init(from:)`
3. Add encode switch case in `encode(to:)`
4. Create `NewPayload` struct with `Codable, Sendable`

**Example: Add `configUpdate` message**

```swift
// CompanionMessage enum:
case configUpdate(ConfigUpdatePayload)

// init(from:) switch:
case "configUpdate":
    let payload = try container.decode(ConfigUpdatePayload.self, forKey: .payload)
    self = .configUpdate(payload)

// encode(to:) switch:
case .configUpdate(let payload):
    try container.encode("configUpdate", forKey: .type)
    try container.encode(payload, forKey: .payload)

// New payload struct:
public struct ConfigUpdatePayload: Codable, Sendable {
    public let setting: String
    public let value: String

    public init(setting: String, value: String) {
        self.setting = setting
        self.value = value
    }
}
```

#### Pattern 2: Payload with Optional Fields

Use explicit `init()` with defaults to ensure JSON decode handles missing fields:

```swift
public struct MyPayload: Codable, Sendable {
    public let required: String
    public let optional: String?      // May be null in JSON
    public let withDefault: Int       // Optional in JSON, defaults to 0

    public init(
        required: String,
        optional: String? = nil,
        withDefault: Int = 0
    ) {
        self.required = required
        self.optional = optional
        self.withDefault = withDefault
    }
}
```

#### Pattern 3: Identifiable Payloads

For collection types (TargetInfo, DeviceInfo), conform to `Identifiable`:

```swift
public struct TargetInfo: Codable, Sendable, Identifiable {
    public let id: UUID          // Required by Identifiable
    public let name: String
    // ...

    public init(id: UUID, name: String, ...) {
        self.id = id
        self.name = name
        // ...
    }
}
```

Enables:
```swift
List(targets) { target in           // Uses target.id automatically
    TargetRow(target)
}
```

#### Pattern 4: Enum with Command Actions

Type-safe command dispatch prevents invalid actions:

```swift
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

// Usage:
let command = CommandPayload(
    action: .ping,                  // Type-safe, no typos
    parameters: ["host": "google.com"]
)
```

#### Pattern 5: Maintaining Backward Compatibility

When renaming fields, use `CodingKeys` to decode old JSON format:

```swift
public struct MyPayload: Codable, Sendable {
    public let newName: String      // New field name in code

    enum CodingKeys: String, CodingKey {
        case newName = "oldFieldName"  // Maps to old JSON key
    }
}

// Old JSON still works:
// { "oldFieldName": "value" }  → decodes to newName
```

#### Pattern 6: Date Encoding

Uses ISO 8601 by default (JSONDecoder standard):

```swift
public struct StatusUpdatePayload: Codable, Sendable {
    public let timestamp: Date

    public init(timestamp: Date = Date()) {
        self.timestamp = timestamp
    }
}

// JSON encoding:
// "timestamp": "2026-01-28T12:30:45.123Z"

// Decode from any ISO 8601 format (automatic)
```

### File Organization

```
CompanionMessage.swift
├─ Imports (Foundation only)
├─ MARK: - Message Types
│  ├─ CompanionMessage enum (7 cases)
│  ├─ CodingKeys helper
│  ├─ init(from:) with 7 switch cases
│  └─ encode(to:) with 7 switch cases
├─ MARK: - Payload Types
│  ├─ StatusUpdatePayload
│  ├─ TargetListPayload
│  ├─ TargetInfo (Identifiable)
│  ├─ DeviceListPayload
│  ├─ DeviceInfo (Identifiable)
│  ├─ CommandPayload
│  ├─ CommandAction enum
│  ├─ ToolResultPayload
│  ├─ ErrorPayload
│  └─ HeartbeatPayload
```

### Common Tasks

#### Task: Send Target Status to iOS

```swift
// In CompanionService (macOS):
let payload = StatusUpdatePayload(
    isMonitoring: session.isMonitoring,
    onlineTargets: session.latestResults.filter { $0.value.isReachable }.count,
    offlineTargets: session.latestResults.filter { !$0.value.isReachable }.count,
    averageLatency: computeAverageLatency()
)
let message = CompanionMessage.statusUpdate(payload)

let encoder = JSONEncoder()
let jsonData = try encoder.encode(message)
// Send jsonData over TCP with length prefix
```

#### Task: Receive Command from iOS

```swift
// In CompanionMessageHandler (macOS):
let decoder = JSONDecoder()
let message = try decoder.decode(CompanionMessage.self, from: jsonData)

if case .command(let payload) = message {
    switch payload.action {
    case .startMonitoring:
        await session.startMonitoring()
    case .ping:
        let host = payload.parameters?["host"] ?? "localhost"
        let result = try await pingService.ping(host: host)
        // Send ToolResultPayload back to iOS
    default:
        // Handle other actions
    }
}
```

#### Task: Add New Device Field

1. Update `DeviceInfo.swift`:
```swift
public struct DeviceInfo: Codable, Sendable, Identifiable {
    public let id: UUID
    public let ipAddress: String
    public let macAddress: String
    public let hostname: String?
    public let vendor: String?
    public let deviceType: String
    public let isOnline: Bool
    public let newField: String?     // NEW

    public init(
        id: UUID = UUID(),
        ipAddress: String,
        macAddress: String,
        hostname: String?,
        vendor: String? = nil,
        deviceType: String = "unknown",
        isOnline: Bool,
        newField: String? = nil       // NEW with default
    ) {
        self.id = id
        self.ipAddress = ipAddress
        self.macAddress = macAddress
        self.hostname = hostname
        self.vendor = vendor
        self.deviceType = deviceType
        self.isOnline = isOnline
        self.newField = newField       // NEW
    }
}
```

2. Update macOS app where creating DeviceInfo:
```swift
// In DeviceDiscoveryCoordinator:
let device = DeviceInfo(
    id: uuid,
    ipAddress: ip,
    macAddress: mac,
    hostname: hostname,
    vendor: vendor,
    deviceType: type,
    isOnline: isOnline,
    newField: computeNewField()      // NEW
)
```

3. Update iOS companion to use new field (automatic decoding)

#### Task: Handle Optional Field in Decode

```swift
public struct MyPayload: Codable, Sendable {
    public let requiredField: String
    public let optionalField: Int?

    enum CodingKeys: String, CodingKey {
        case requiredField
        case optionalField
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.requiredField = try container.decode(String.self, forKey: .requiredField)
        // Optional field: decodeIfPresent returns nil if missing
        self.optionalField = try container.decodeIfPresent(Int.self, forKey: .optionalField)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(requiredField, forKey: .requiredField)
        if let optionalField = optionalField {
            try container.encode(optionalField, forKey: .optionalField)
        }
    }
}
```

### Testing Requirements

**Location:** `/Users/blake/Projects/NetMonitor/NetMonitorTests/Protocol/CompanionMessageTests.swift`

**Must Test:**

1. **Each message type encodes/decodes correctly**
   - Verify `type` field matches case name
   - Verify payload data preserved in roundtrip

2. **Unknown message type throws error**
   - Test that invalid type string causes DecodingError

3. **All payload types roundtrip**
   - Encode then decode returns equal values
   - Works for nil/optional fields

4. **CommandAction enum has all cases**
   - 10 cases mapped to string values
   - Can encode/decode each

5. **Date handling**
   - ISO 8601 encoding/decoding works
   - Timestamp defaults to Date()

**Test Template:**

```swift
import Testing
@testable import NetMonitorShared

@Suite("Companion Message Protocol")
struct CompanionMessageTests {

    @Test("statusUpdate roundtrips correctly")
    func statusUpdateRoundtrip() throws {
        let payload = StatusUpdatePayload(
            isMonitoring: true,
            onlineTargets: 5,
            offlineTargets: 2,
            averageLatency: 45.2
        )
        let message = CompanionMessage.statusUpdate(payload)

        let encoder = JSONEncoder()
        let encoded = try encoder.encode(message)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(CompanionMessage.self, from: encoded)

        if case .statusUpdate(let decodedPayload) = decoded {
            #expect(decodedPayload.isMonitoring == true)
            #expect(decodedPayload.onlineTargets == 5)
            #expect(decodedPayload.offlineTargets == 2)
            #expect(decodedPayload.averageLatency == 45.2)
        } else {
            Issue.record("Expected statusUpdate case")
        }
    }

    @Test("unknown message type throws DecodingError")
    func unknownMessageType() throws {
        let json = """
        {"type": "unknownType", "payload": {}}
        """.data(using: .utf8)!

        let decoder = JSONDecoder()
        #expect(throws: DecodingError.self) {
            try decoder.decode(CompanionMessage.self, from: json)
        }
    }

    @Test("TargetInfo conforms to Identifiable")
    func targetInfoIdentifiable() {
        let info = TargetInfo(
            id: UUID(),
            name: "Google",
            host: "google.com",
            port: 443,
            protocol: "HTTPS",
            isEnabled: true,
            isReachable: true,
            latency: 45.2
        )
        #expect(info.id != UUID())  // Has non-nil id
    }
}
```

## Message Reference

### Message Types (7)

| Type | Payload | Direction | Frequency | Purpose |
|------|---------|-----------|-----------|---------|
| `statusUpdate` | StatusUpdatePayload | macOS → iOS | Every 5-10s | Broadcast monitoring state |
| `targetList` | TargetListPayload | macOS → iOS | On-demand | All targets snapshot |
| `deviceList` | DeviceListPayload | macOS → iOS | After scan | All devices snapshot |
| `command` | CommandPayload | iOS → macOS | User action | Execute action on macOS |
| `toolResult` | ToolResultPayload | macOS → iOS | On-demand | Tool execution result |
| `error` | ErrorPayload | Both | Errors | Error notification |
| `heartbeat` | HeartbeatPayload | macOS → iOS | Every 5-10s | Connection keepalive |

### Payload Structs (10)

1. **StatusUpdatePayload**: isMonitoring (Bool), onlineTargets (Int), offlineTargets (Int), averageLatency (Double?), timestamp (Date)

2. **TargetListPayload**: targets ([TargetInfo])

3. **TargetInfo** (Identifiable): id (UUID), name (String), host (String), port (Int?), protocol (String), isEnabled (Bool), isReachable (Bool?), latency (Double?)

4. **DeviceListPayload**: devices ([DeviceInfo])

5. **DeviceInfo** (Identifiable): id (UUID), ipAddress (String), macAddress (String), hostname (String?), vendor (String?), deviceType (String), isOnline (Bool)

6. **CommandPayload**: action (CommandAction), parameters ([String: String]?)

7. **CommandAction** (Enum): startMonitoring, stopMonitoring, scanDevices, ping, traceroute, portScan, dnsLookup, wakeOnLan, refreshTargets, refreshDevices

8. **ToolResultPayload**: tool (String), success (Bool), result (String), timestamp (Date)

9. **ErrorPayload**: code (String), message (String), timestamp (Date)

10. **HeartbeatPayload**: timestamp (Date), version (String = "1.0")

## Dependencies

**Internal:**
- `Foundation` - JSON coding, Date, UUID, Sendable

**Imports From:**
- Shared enums (TargetProtocol, DeviceType, ConnectionType) from `../Common/Enums.swift`

**Used By:**
- macOS app: CompanionService encodes/sends messages, CompanionMessageHandler decodes/processes
- iOS companion app: Decodes all message types, encodes CommandPayload
- Tests: NetMonitorTests/Protocol/CompanionMessageTests.swift

**No External Dependencies:**
- Pure Foundation + Swift standard library
- Zero third-party packages

<!-- MANUAL: Last verified 2026-01-28 -->
