# UI Automation Testing Strategy

**Project:** NetMonitor (macOS & iOS)
**Created:** 2026-02-04
**Status:** Active

---

## Tool Selection

### Primary Tool: XCUITest

**Why XCUITest over alternatives:**

| Tool | Pros | Cons | Verdict |
|------|------|------|---------|
| **XCUITest** | Native, fast, Swift integration, no setup, reliable | Apple-only | ✅ **Selected** |
| Appium | Cross-platform (iOS/Android) | Heavy setup, slower, WebDriver overhead | Future consideration |
| Maestro | YAML-based, easy to write | External dependency, less Swift integration | Not needed |
| Detox | Good for React Native | N/A for native Swift | Not applicable |

**Rationale:**
1. Both apps are native Swift/SwiftUI - XCUITest is the natural fit
2. No Android version yet - cross-platform benefits don't apply
3. XCUITest is integrated into Xcode - zero setup
4. Tests run fast and can leverage accessibility identifiers
5. Can later wrap with Appium if Android is added

### Test Framework Structure

```
NetMonitor(UITests)/
├── Tests/
│   ├── DashboardUITests.swift
│   ├── ToolsUITests.swift
│   ├── SettingsUITests.swift
│   ├── MonitoringUITests.swift
│   └── ...
├── Screens/                    # Page Object Model
│   ├── DashboardScreen.swift
│   ├── ToolsScreen.swift
│   └── ...
├── Helpers/
│   ├── XCUIElement+Extensions.swift
│   └── TestHelpers.swift
└── Resources/
    └── TestData.swift
```

### Design Patterns

1. **Page Object Model (POM)** - Encapsulate screen interactions
2. **Accessibility Identifiers** - Reliable element location
3. **Test Data Separation** - External test data for maintainability
4. **Parallel Execution** - Run tests in parallel where possible

---

## Coverage Requirements

### macOS App Features

| Feature | Current Tests | Target | Priority |
|---------|--------------|--------|----------|
| Dashboard Overview | ❌ | ✅ | P0 |
| Device Discovery | ❌ | ✅ | P0 |
| Network Monitoring (ICMP) | ❌ | ✅ | P0 |
| Network Monitoring (TCP) | ❌ | ✅ | P0 |
| Network Monitoring (HTTP) | ❌ | ✅ | P0 |
| Speed Test | ❌ | ✅ | P0 |
| Wake-on-LAN | ❌ | ✅ | P0 |
| Ping Tool | ❌ | ✅ | P0 |
| Traceroute Tool | ❌ | ✅ | P0 |
| DNS Lookup Tool | ❌ | ✅ | P0 |
| Port Scanner Tool | ❌ | ✅ | P0 |
| Whois Tool | ❌ | ✅ | P0 |
| Settings | ❌ | ✅ | P0 |
| Export (CSV/JSON) | ❌ | ✅ | P1 |
| Menu Bar | ❌ | ✅ | P1 |
| Companion Service | ❌ | ✅ | P1 |

### iOS App Features

| Feature | Current Tests | Target | Priority |
|---------|--------------|--------|----------|
| Dashboard Overview | Basic | ✅ Full | P0 |
| Device List | ❌ | ✅ | P0 |
| Ping Tool | ❌ | ✅ | P0 |
| Traceroute Tool | ❌ | ✅ | P0 |
| DNS Lookup Tool | ❌ | ✅ | P0 |
| Port Scanner Tool | ❌ | ✅ | P0 |
| Bonjour Discovery | ❌ | ✅ | P0 |
| Speed Test | ❌ | ✅ | P0 |
| Whois Tool | ❌ | ✅ | P0 |
| Wake-on-LAN | ❌ | ✅ | P0 |
| Settings | ❌ | ✅ | P0 |
| Widget | ❌ | ✅ | P1 |
| Background Refresh | ❌ | ✅ | P1 |

---

## Implementation Approach

### Phase 1: Infrastructure (30 min)
- Add accessibility identifiers to all UI elements
- Create Page Object base classes
- Set up test helpers

### Phase 2: Core Feature Tests (2 hr)
- Dashboard tests
- All Tools tests
- Settings tests

### Phase 3: Integration Tests (1 hr)
- End-to-end workflows
- Data persistence
- Error handling

### Phase 4: Execution & Reporting (30 min)
- Run full suite
- Generate coverage report
- Document results

---

## Running Tests

### Command Line

```bash
# macOS - All UI Tests
xcodebuild test -scheme NetMonitor -destination 'platform=macOS' \
  -only-testing:NetMonitorUITests

# iOS - All UI Tests  
xcodebuild test -scheme Netmonitor -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:NetmonitorUITests

# Parallel execution
xcodebuild test -scheme NetMonitor -destination 'platform=macOS' \
  -parallel-testing-enabled YES -parallel-testing-worker-count 4
```

### Xcode
1. Product → Test (⌘U)
2. Or run individual test classes/methods

---

## Future Enhancements

1. **Appium Wrapper** - When Android version is added
2. **CI/CD Integration** - GitHub Actions for automated testing
3. **Visual Regression** - Screenshot comparison testing
4. **Performance Testing** - Launch time, memory usage

---

## Standard Workflow (Reusable)

For future projects, follow this workflow:

1. **Initialize** - Set up XCUITest target in Xcode
2. **Add Identifiers** - Tag all interactive elements with accessibility identifiers
3. **Create Page Objects** - One per screen/feature
4. **Write Tests** - Cover all user journeys
5. **Run in CI** - Automate with GitHub Actions
6. **Maintain** - Update tests with UI changes
