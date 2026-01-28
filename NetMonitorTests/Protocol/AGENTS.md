<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-01-28 | Updated: 2026-01-28 -->

# Protocol

## Purpose

Tests for the NetMonitorShared companion message protocol. Verifies JSON encoding/decoding of all 7 message types that communicate between the macOS app and iOS companion app via the Bonjour service.

## Key Files

| File | Description |
|------|-------------|
| `CompanionMessageTests.swift` | Comprehensive test suite for `CompanionMessage` enum and all payload types (7 message types, round-trip encoding/decoding) |

## For AI Agents

### Working In This Directory

**Test Framework**: Swift Testing (`@Suite`, `@Test`, `#expect`, `Issue.record()`)

**Key Responsibilities**:
- Verify that all 7 message types encode to JSON correctly
- Verify that JSON decodes back to correct message types
- Validate payload serialization (all fields present and correct types)
- Test edge cases (optional fields, date serialization, arrays)

**Import Pattern**:
```swift
import Foundation
import Testing
@testable import NetMonitorShared
```

The `@testable` import gives access to internal `CompanionMessage` types for testing.

### Common Patterns

#### Round-Trip Testing
```swift
@Test("Test message type") func testMessage() throws {
    let message = CompanionMessage.statusUpdate(StatusUpdatePayload(...))
    let data = try JSONEncoder().encode(message)
    let decoded = try JSONDecoder().decode(CompanionMessage.self, from: data)

    if case .statusUpdate(let payload) = decoded {
        #expect(payload.field == expectedValue)
    } else {
        Issue.record("Expected statusUpdate message type")
    }
}
```

**Pattern Notes**:
- All encoding/decoding uses `JSONEncoder` / `JSONDecoder`
- Switch on decoded enum to extract payload
- Use `#expect()` for assertions (Swift Testing syntax)
- Use `Issue.record()` to report test failures

#### JSON String Testing
```swift
let message = CompanionMessage.command(...)
let data = try JSONEncoder().encode(message)
let json = String(data: data, encoding: .utf8)
#expect(json?.contains("expectedString") == true)
```

Used when verifying JSON structure rather than decoding.

#### Direct JSON Decoding
```swift
let json = """
{
    "type": "deviceList",
    "payload": { ... }
}
"""
let data = json.data(using: .utf8)!
let message = try JSONDecoder().decode(CompanionMessage.self, from: data)
```

Used to test decoding from known JSON strings (testing decoder robustness).

### Message Types & Payload Structure

The `CompanionMessage` enum dispatches to 7 payload types via custom `Codable` implementation:

| Case | Payload Type | Fields |
|------|------|--------|
| `statusUpdate` | `StatusUpdatePayload` | `isMonitoring: Bool`, `onlineTargets: Int`, `offlineTargets: Int`, `averageLatency: Double?`, `timestamp: Date` |
| `targetList` | `TargetListPayload` | `targets: [TargetInfo]` (id, name, host, port?, protocol, isEnabled, isReachable?, latency?) |
| `deviceList` | `DeviceListPayload` | `devices: [DeviceInfo]` (id, ipAddress, macAddress, hostname?, vendor?, deviceType, isOnline) |
| `command` | `CommandPayload` | `action: CommandAction` enum, `parameters: [String: String]?` |
| `toolResult` | `ToolResultPayload` | `tool: String`, `success: Bool`, `result: String`, `timestamp: Date` |
| `error` | `ErrorPayload` | `code: String`, `message: String`, `timestamp: Date` |
| `heartbeat` | `HeartbeatPayload` | `timestamp: Date`, `version: String` |

**Key Detail**: `CompanionMessage` uses custom `Codable` with `CodingKeys.type` and `CodingKeys.payload` to encode type discriminator in JSON:
```json
{
  "type": "statusUpdate",
  "payload": { "isMonitoring": true, ... }
}
```

### Test Coverage

Current test suite covers:
- ✓ `statusUpdate` encoding/decoding (4 fields validated)
- ✓ `command` encoding and JSON structure verification
- ✓ `deviceList` decoding from raw JSON (round-trip)
- ✓ `heartbeat` encoding/decoding
- ✓ `error` encoding/decoding
- ✓ `toolResult` encoding/decoding
- ✓ `targetList` encoding/decoding with complex payload

**Gaps to Consider**:
- No testing of malformed JSON (invalid types, missing required fields)
- No testing of optional field omission handling
- No testing of date serialization format
- No testing of CommandAction enum serialization completeness
- No testing of array boundary conditions (empty arrays, large arrays)

### Adding New Tests

**Template**:
```swift
@Test("Description of what is being tested")
func testFunctionName() throws {
    // 1. Create message
    let message = CompanionMessage.messageType(Payload(...))

    // 2. Encode to JSON
    let data = try JSONEncoder().encode(message)

    // 3. Decode back
    let decoded = try JSONDecoder().decode(CompanionMessage.self, from: data)

    // 4. Validate
    if case .messageType(let payload) = decoded {
        #expect(payload.field == expectedValue)
    } else {
        Issue.record("Expected messageType message type")
    }
}
```

**When to Add Tests**:
- When adding new message type to `CompanionMessage`
- When adding new field to any payload struct
- When changing JSON serialization logic
- When fixing encoding/decoding bugs

## Dependencies

### Internal Dependencies
- `NetMonitorShared` (package under test)
  - `CompanionMessage` enum
  - All 7 payload types
  - `CommandAction` enum
  - Type definitions: `TargetInfo`, `DeviceInfo`

### Framework Dependencies
- `Foundation` - Core types (Date, UUID, JSONEncoder/Decoder)
- `Testing` - Swift Testing framework (@Suite, @Test, #expect, Issue)

### Related Code
- **Protocol Definition**: `/Users/blake/Projects/NetMonitor/NetMonitorShared/Sources/NetMonitorShared/Protocol/CompanionMessage.swift`
- **Service Layer**: `CompanionService.swift` and `CompanionMessageHandler.swift` in `/Users/blake/Projects/NetMonitor/NetMonitor/Services/` (produces/consumes these messages)
- **API Reference**: `/Users/blake/Projects/NetMonitor/docs/Companion-Protocol-API.md`

### Running Tests

```bash
# Run all protocol tests
xcodebuild -project NetMonitor.xcodeproj -scheme NetMonitor test -testPlan NetMonitorTests

# Run just this file
xcodebuild -project NetMonitor.xcodeproj -scheme NetMonitor test -only CompanionMessageTests

# Or in Xcode: Cmd+U (run all tests)
```

<!-- MANUAL: -->
- Payload struct initializers all support default values where sensible
- Optional fields (e.g., `parameters: [String: String]?`) should be tested both `nil` and populated
- Date fields serialize via `ISO8601DateFormatter` by default
