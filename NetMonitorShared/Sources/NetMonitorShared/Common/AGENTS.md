<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-01-28 | Updated: 2026-01-28 -->

# Common

## Purpose

Provides cross-platform shared enums for the NetMonitor ecosystem. All enums conform to `String`, `Codable`, `Sendable`, and `CaseIterable` to support type-safe JSON serialization, UI integration (SF Symbols), and strict concurrency in both macOS and iOS applications.

**Key Responsibility:** Enable safe, serializable type definitions for network protocols, device classifications, and connection types.

## Key Files

| File | Description | Cases | Key Features |
|------|-------------|-------|--------------|
| `Enums.swift` | Shared enum types for cross-platform use | 16 total | SF Symbol `iconName` computed properties, JSON serialization, UI ready |

## Enums

### 1. TargetProtocol (4 Cases)

Monitoring protocol types with SF Symbol icons.

```swift
public enum TargetProtocol: String, Codable, Sendable, CaseIterable {
    case icmp = "ICMP"       // → "waveform.path.ecg"
    case http = "HTTP"       // → "network"
    case https = "HTTPS"     // → "network"
    case tcp = "TCP"         // → "arrow.left.arrow.right"
}
```

**Icon Mapping:**
- `.http`, `.https` → `"network"` (same icon)
- `.icmp` → `"waveform.path.ecg"` (heart rate/ECG for ping)
- `.tcp` → `"arrow.left.arrow.right"` (bidirectional connection)

**Usage:** Select protocol when adding monitoring targets. Used in `NetworkTarget` model and companion protocol `TargetInfo`.

### 2. DeviceType (10 Cases)

Local device type classifications with SF Symbol icons.

```swift
public enum DeviceType: String, Codable, Sendable, CaseIterable {
    case phone = "Phone"          // → "iphone"
    case laptop = "Laptop"        // → "laptopcomputer"
    case tablet = "Tablet"        // → "ipad"
    case tv = "TV"                // → "tv"
    case speaker = "Speaker"      // → "homepod"
    case gaming = "Gaming"        // → "gamecontroller"
    case iot = "IoT"              // → "sensor"
    case router = "Router"        // → "wifi.router"
    case printer = "Printer"      // → "printer"
    case unknown = "Unknown"      // → "questionmark.circle"
}
```

**Icon Mapping:** One-to-one mapping to SF Symbols for visual identification in UI.

**Usage:** Classify discovered network devices. Used in `LocalDevice` model and companion protocol `DeviceInfo`. Icons display in devices list and detail views.

### 3. ConnectionType (4 Cases)

Network connection type classifications.

```swift
public enum ConnectionType: String, Codable, Sendable, CaseIterable {
    case wifi = "WiFi"
    case ethernet = "Ethernet"
    case cellular = "Cellular"
    case unknown = "Unknown"
}
```

**Status:** Currently defined but unused in active code. Available for future features (e.g., connection type filtering, network interface selection).

## For AI Agents

### Working In This Directory

**File Location:** `/Users/blake/Projects/NetMonitor/NetMonitorShared/Sources/NetMonitorShared/Common/Enums.swift`

**Constraints:**

1. **No Platform Imports:** `Foundation` only - no `SwiftUI`, `UIKit`, `AppKit`, or `Network`
2. **Swift 6 Strict Concurrency:** All types must conform to `Sendable`
3. **Public API Only:** Mark all exported types and properties `public`
4. **Codable + JSON:** All enums must serialize to/from JSON
5. **CaseIterable Required:** Enables UI pickers and case enumeration
6. **String Raw Values:** Raw values are JSON representation (PascalCase display names)

### Common Patterns

#### Pattern: Enum with SF Symbol iconName

All device/protocol enums include `iconName` computed property for SwiftUI integration:

```swift
public enum MyEnum: String, Codable, Sendable, CaseIterable {
    case example = "Example"

    public var iconName: String {
        switch self {
        case .example: return "star.fill"
        }
    }
}
```

**Why:** macOS and iOS views use SF Symbols for consistent, scalable icons. Computed properties keep logic centralized and testable.

#### Pattern: Extension for Computed Properties

When `iconName` is too complex for inline definition, use an extension:

```swift
// In file, after enum definition:
// MARK: - MyEnum Extension

extension MyEnum {
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

**Current Usage:** `TargetProtocol` uses extension pattern (see lines 48-61 of Enums.swift).

### File Organization

**Enums.swift Structure:**

```
1. import Foundation
2. /// ConnectionType doc comment
3. public enum ConnectionType { }
4. /// TargetProtocol doc comment
5. public enum TargetProtocol { }
6. /// DeviceType doc comment
7. public enum DeviceType { ... with inline iconName ... }
8. // MARK: - TargetProtocol Extension
9. extension TargetProtocol { public var iconName: String { } }
```

**Key Principle:** Group related enums by use case. Put simple enums first, complex computed properties in extensions after main definitions.

### Common Tasks

#### Adding a New Case to an Enum

**Example: Add `.vpn` to `ConnectionType`**

```swift
public enum ConnectionType: String, Codable, Sendable, CaseIterable {
    case wifi = "WiFi"
    case ethernet = "Ethernet"
    case cellular = "Cellular"
    case vpn = "VPN"        // NEW
    case unknown = "Unknown"
}
```

**Checklist:**
- [ ] Add case with PascalCase raw value
- [ ] Update any switch statements on this enum (search for `case .unknown` to find all places)
- [ ] Add test case if icon mapping exists (see Testing Requirements below)
- [ ] Update parent AGENTS.md if adding entire new enum type

#### Adding a New Enum Type

**Example: Add `NetworkSpeed` enum**

```swift
// After existing enums, before extensions:

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

**Checklist:**
- [ ] Doc comment with `///`
- [ ] Conform to `String, Codable, Sendable, CaseIterable`
- [ ] Raw values match JSON format (PascalCase)
- [ ] Add computed properties inline if simple, or in extension if complex
- [ ] Write tests (see Testing Requirements)
- [ ] Update parent AGENTS.md with new enum summary

#### Renaming a Case

**Maintain backward compatibility via `CodingKeys`:**

```swift
public enum DeviceType: String, Codable, Sendable, CaseIterable {
    case mobilePhone = "MobilePhone"  // New internal name

    enum CodingKeys: String, CodingKey {
        case mobilePhone = "Phone"  // Old JSON value
    }
}
```

This allows iOS companions with older code to decode JSON using old case names while macOS uses new names internally.

### Testing Requirements

**Location:** Tests live in `/Users/blake/Projects/NetMonitor/NetMonitorTests/Protocol/` (extend or create `EnumsTests.swift`)

**Test Coverage:**

1. **Case Existence**
   - `CaseIterable.allCases` returns expected count
   - Raw values match enum cases

2. **JSON Serialization**
   - Encoding: `.http` → `"HTTP"` (JSON string)
   - Decoding: `"HTTP"` → `.http` (Swift case)
   - Round-trip: encode then decode returns identical enum

3. **Icon Names**
   - All cases return valid SF Symbol names
   - HTTP/HTTPS return same icon (`"network"`)
   - No empty or nil icons

4. **Codable Compliance**
   - Invalid case value throws `DecodingError`
   - All cases are `Sendable` (compile-time check)

**Test Template:**

```swift
import Testing
@testable import NetMonitorShared

@Suite("Enums - TargetProtocol")
struct TargetProtocolTests {

    @Test("All cases encode to correct JSON string")
    func encodesCases() throws {
        let encoder = JSONEncoder()

        let icmp = try encoder.encode(TargetProtocol.icmp)
        let icmpString = try #require(String(data: icmp, encoding: .utf8))
        #expect(icmpString.contains("\"ICMP\""))

        let http = try encoder.encode(TargetProtocol.http)
        let httpString = try #require(String(data: http, encoding: .utf8))
        #expect(httpString.contains("\"HTTP\""))
    }

    @Test("All cases decode from JSON string")
    func decodesCases() throws {
        let decoder = JSONDecoder()

        let icmpData = "\"ICMP\"".data(using: .utf8)!
        let icmp = try decoder.decode(TargetProtocol.self, from: icmpData)
        #expect(icmp == .icmp)

        let httpData = "\"HTTP\"".data(using: .utf8)!
        let http = try decoder.decode(TargetProtocol.self, from: httpData)
        #expect(http == .http)
    }

    @Test("CaseIterable returns all 4 cases")
    func caseIterableCount() {
        #expect(TargetProtocol.allCases.count == 4)
    }

    @Test("Icon names return valid SF Symbols")
    func iconNamesValid() {
        #expect(TargetProtocol.http.iconName == "network")
        #expect(TargetProtocol.https.iconName == "network")
        #expect(TargetProtocol.icmp.iconName == "waveform.path.ecg")
        #expect(TargetProtocol.tcp.iconName == "arrow.left.arrow.right")
    }

    @Test("Invalid case throws DecodingError")
    func invalidCaseThrows() throws {
        let decoder = JSONDecoder()
        let invalidData = "\"UNKNOWN\"".data(using: .utf8)!

        let error = try #require(
            throws: {
                try decoder.decode(TargetProtocol.self, from: invalidData)
            } as Error
        )
        #expect(error is DecodingError)
    }
}

@Suite("Enums - DeviceType")
struct DeviceTypeTests {

    @Test("All 10 cases present")
    func allCases() {
        let expected = [
            DeviceType.phone,
            DeviceType.laptop,
            DeviceType.tablet,
            DeviceType.tv,
            DeviceType.speaker,
            DeviceType.gaming,
            DeviceType.iot,
            DeviceType.router,
            DeviceType.printer,
            DeviceType.unknown
        ]
        #expect(Set(DeviceType.allCases) == Set(expected))
    }

    @Test("Each device type has unique icon")
    func uniqueIcons() {
        let icons = DeviceType.allCases.map(\.iconName)
        #expect(Set(icons).count == icons.count, "Icons should be unique")
    }

    @Test("Phone icon is 'iphone'")
    func phoneIcon() {
        #expect(DeviceType.phone.iconName == "iphone")
    }
}

@Suite("Enums - ConnectionType")
struct ConnectionTypeTests {

    @Test("All 4 cases present")
    func allCases() {
        #expect(ConnectionType.allCases.count == 4)
    }

    @Test("Encodes to correct JSON")
    func encodesCorrectly() throws {
        let encoder = JSONEncoder()
        let wifi = try encoder.encode(ConnectionType.wifi)
        let wifiString = try #require(String(data: wifi, encoding: .utf8))
        #expect(wifiString.contains("\"WiFi\""))
    }
}
```

## Dependencies

**Internal Only:**
- `Foundation` - Codable protocol, UUID, Date, Sendable

**Used By:**
- `NetMonitor` macOS app: Imports enums for `NetworkTarget`, `LocalDevice`, settings, and UI
- `NetMonitorShared` package: Enums included in companion message protocol types (`TargetInfo`, `DeviceInfo`)
- Tests: JSON serialization validation

**Compilation:**

```bash
# Part of NetMonitorShared Swift package
swift build --package-path /Users/blake/Projects/NetMonitor/NetMonitorShared

# Run enum tests
swift test --package-path /Users/blake/Projects/NetMonitor/NetMonitorShared \
  --filter EnumsTests
```

## Anti-Patterns

| Don't | Why | Do Instead |
|-------|-----|-----------|
| Add new import (SwiftUI, AppKit, etc.) | Not available cross-platform | Import only `Foundation` |
| Use non-string raw values | JSON expects string types | Use `String` raw values |
| Omit `CaseIterable` | UI pickers need all cases enumerable | Add `CaseIterable` to all enums |
| Forget `Sendable` conformance | Violates strict concurrency | Add `Sendable` to all types |
| Hardcode SF Symbol names in Views | Breaks single source of truth | Use `enum.iconName` computed property |
| Reuse case names (e.g., `.unknown`) | Confusing with multiple enums | Prefix in context or use distinct names |
| Add methods with side effects | Enums are pure data | Keep enums simple, move logic to services |
| Skip doc comments | Next developer won't understand purpose | Add `///` doc comments to all types |
| Change raw values | Breaks iOS decode from older macOS JSON | Use `CodingKeys` for backward compat |

## Implementation Notes

**JSON Format:** Raw values become JSON strings. `TargetProtocol.http` → `"HTTP"` in JSON.

**SF Symbols:** All `iconName` values must be valid SF Symbol names available on macOS 15+ and iOS 18+. Test with Xcode's SF Symbols app.

**Icon Reuse:** HTTP and HTTPS intentionally share `"network"` icon - they're semantically similar.

**Case Count:** Keep per-enum under 20 cases for maintainability. If exceeding, consider splitting or hierarchy.

**Raw Value Strategy:** Use PascalCase for display values (e.g., "VerySlow"). Helps with human readability in JSON logs.

**Backward Compatibility:** If renaming cases, use `CodingKeys` to map old JSON values. Never delete cases - mark unused with deprecation comment.

<!-- MANUAL: Last verified 2026-01-28 -->
