<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-01-28 | Updated: 2026-01-28 -->

# NetMonitorUITests

## Purpose

UI tests for NetMonitor macOS application using XCTest framework. Tests verify:
- Application launch and window initialization
- Launch performance metrics
- UI responsiveness under test conditions
- Integration of accessibility identifiers for automation

## Key Files

| File | Description | Lines | Focus |
|------|-------------|-------|-------|
| `NetMonitorUITests.swift` | Main UI test suite | 54 | App launch, window verification, performance |
| `NetMonitorUITestsLaunchTests.swift` | Launch performance tests | 33 | Baseline launch metrics, screenshot capture |

## For AI Agents

### Working In This Directory

#### Launch the Tests
```bash
# Run all UI tests
xcodebuild test -project /Users/blake/Projects/NetMonitor/NetMonitor.xcodeproj \
  -scheme NetMonitor -testPlan NetMonitorUITests

# Run specific test class
xcodebuild test -project /Users/blake/Projects/NetMonitor/NetMonitor.xcodeproj \
  -scheme NetMonitor -only-testing:NetMonitorUITests/NetMonitorUITests

# Run with verbose output
xcodebuild test -project /Users/blake/Projects/NetMonitor/NetMonitor.xcodeproj \
  -scheme NetMonitor -testPlan NetMonitorUITests -verbose
```

#### Test Mode Detection
Both test classes launch the app with `--uitesting` argument to skip service initialization:
```swift
app.launchArguments = ["--uitesting"]
```

In `NetMonitorApp.swift`, check for this flag and conditionally initialize services:
```swift
let isUITesting = CommandLine.arguments.contains("--uitesting")
if !isUITesting {
    // Initialize CompanionService, DeviceDiscoveryCoordinator, etc.
}
```

#### Important XCTest Patterns

**Setup and Teardown:**
- `setUpWithError()`: Called before each test
- `tearDownWithError()`: Called after each test
- `continueAfterFailure = false`: Stops test on first failure

**App Lifecycle:**
```swift
let app = XCUIApplication()
app.launchArguments = ["--uitesting"]  // Pass test arguments
app.launch()                            // Start the app
// Test assertions here
app.terminate()                         // Clean shutdown
```

**Waiting for Elements:**
```swift
let element = app.windows.firstMatch
XCTAssertTrue(element.waitForExistence(timeout: 5), "Element should exist")
```

**Screenshots:**
```swift
let attachment = XCTAttachment(screenshot: app.screenshot())
attachment.name = "Launch Screen"
attachment.lifetime = .keepAlways  // Keep in test report
add(attachment)
```

### Testing Requirements

#### Accessibility Identifiers
All interactive UI elements need accessibility identifiers for XCTest automation. Required identifiers per view:

**ContentView/Navigation:**
- `mainWindow`: Main application window
- `sidebarView`: Sidebar navigation
- `dashboardTab`, `targetsTab`, `devicesTab`, `toolsTab`, `settingsTab`: Tab buttons

**DashboardView:**
- `monitoringStatusLabel`: Current monitoring state
- `targetCards`: List of target monitoring cards
- `startMonitoringButton`, `stopMonitoringButton`: Control buttons

**TargetsView:**
- `targetsTable`: List of configured targets
- `addTargetButton`: Sheet trigger
- `targetRow-[id]`: Individual target rows (keyed by UUID)
- `deleteTargetButton-[id]`: Delete button per target

**DevicesView:**
- `devicesList`: Device list in split view
- `deviceDetail`: Device detail panel
- `scanButton`: Trigger device discovery
- `deviceRow-[id]`: Individual device rows

**ToolsView (7 tools):**
- `pingTool`, `tracerouteTool`, `portScannerTool`, `dnsLookupTool`, `whoisTool`, `bonjourBrowserTool`, `wakeOnLanTool`
- For each tool: `[toolName]Input`, `[toolName]ExecuteButton`, `[toolName]ResultText`

**SettingsView:**
- `generalTab`, `monitoringTab`, `notificationTab`, `networkTab`, `dataTab`, `appearanceTab`, `companionTab`
- Component: `[settingName]Toggle`, `[settingName]Input`, `[settingName]Slider`

Example in view code:
```swift
Button("Start Monitoring") {
    session.startMonitoring()
}
.accessibilityIdentifier("startMonitoringButton")
```

#### Current State
- **NetMonitorUITests.swift**: Stub tests only (window existence check)
- **NetMonitorUITestsLaunchTests.swift**: Baseline launch metrics with screenshot
- **Missing**: Detailed UI interaction tests (adding targets, scanning devices, using tools)

#### Stub Test Locations
1. **testExample()** - Generic app launch verification
2. **testLaunchPerformance()** - XCTApplicationLaunchMetric baseline
3. **testLaunch()** - Screenshot capture with multi-config support

### Common Patterns

#### Test Structure Template
```swift
@MainActor
func testAddTargetFlow() throws {
    app.launch()

    // Wait for main UI to load
    let mainWindow = app.windows.firstMatch
    XCTAssertTrue(mainWindow.waitForExistence(timeout: 5))

    // Navigate to targets
    let targetsTab = app.buttons["targetsTab"]
    targetsTab.tap()

    // Click add button
    let addButton = app.buttons["addTargetButton"]
    XCTAssertTrue(addButton.waitForExistence(timeout: 2))
    addButton.tap()

    // Fill form
    let hostInput = app.textFields["targetHostInput"]
    hostInput.typeText("example.com")

    // Save
    app.buttons["saveTargetButton"].tap()

    // Verify
    let targetRow = app.staticTexts["example.com"]
    XCTAssertTrue(targetRow.waitForExistence(timeout: 3))
}
```

#### Handling Async UI Updates
```swift
// For changes that take a moment to appear
let expectedElement = app.staticTexts["expectedText"]
let predicate = NSPredicate(format: "exists == true")
let expectation = XCTNSPredicateExpectation(predicate: predicate, object: expectedElement)
wait(for: [expectation], timeout: 5)
```

#### Taking Screenshots at Key Points
```swift
// Verify specific state, then capture
let screenshot = app.screenshot()
let attachment = XCTAttachment(image: screenshot)
attachment.name = "Dashboard - Monitoring Active"
attachment.lifetime = .keepAlways
add(attachment)
```

#### Testing Sheet/Modal Dialogs
```swift
// Sheet appears when adding target
app.buttons["addTargetButton"].tap()
let sheetTitle = app.staticTexts["Add Target"]
XCTAssertTrue(sheetTitle.waitForExistence(timeout: 3))

// Fill fields in sheet
app.textFields.firstMatch.typeText("test.example.com")
app.buttons["saveTargetButton"].tap()

// Wait for sheet to dismiss
XCTAssertFalse(sheetTitle.exists)
```

#### Performance Baseline Testing
```swift
// Establishes baseline performance metric
measure(metrics: [XCTApplicationLaunchMetric()]) {
    app.launch()
    app.terminate()
}
// Subsequent runs compared against baseline
```

## Dependencies

### XCTest Framework
- `XCTest`: Core testing framework (macOS 10.15+)
- `XCUIApplication`: App automation API
- `XCUIElement`: UI element queries
- `XCTApplicationLaunchMetric`: Performance measurement

### NetMonitor App Requirements

The app must support test mode via `--uitesting` flag:
1. **Skip service initialization** (CompanionService, DeviceDiscoveryCoordinator)
2. **Use preview/mock data** where possible
3. **Ensure all UI elements have accessibility identifiers**
4. **Allow rapid app restart** (no persistent state blocking shutdown)

### Test Isolation
- Each test runs with fresh app instance
- App terminated after each test
- No shared state between test methods
- UI tests are independent and parallelizable

## Implementation Notes

### Launch Argument Handling

In `NetMonitorApp.swift`:
```swift
import Foundation

@main
struct NetMonitorApp: App {
    var body: some Scene {
        let isUITesting = CommandLine.arguments.contains("--uitesting")

        return WindowGroup {
            ContentView()
                .environment(\.isUITesting, isUITesting)
        }
    }
}
```

Create environment key:
```swift
private struct IsUITestingKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    var isUITesting: Bool {
        get { self[IsUITestingKey.self] }
        set { self[IsUITestingKey.self] = newValue }
    }
}
```

### Accessibility Best Practices
- Use `.accessibilityIdentifier()` for automation
- Use `.accessibilityLabel()` for screen reader users
- Don't use app layout as test target (use IDs instead)
- Test real user interactions (tap, type, scroll)

### Timeout Recommendations
| Operation | Timeout |
|-----------|---------|
| App launch | 5 seconds |
| Window appearance | 2-3 seconds |
| Network request | 10 seconds |
| Sheet/Modal | 2-3 seconds |
| Animation completion | 1-2 seconds |

### Performance Baseline Maintenance
- XCTApplicationLaunchMetric stored in `PerformanceMetrics.plist`
- Re-baseline when app grows significantly (>2s increase)
- Track on each major build to catch regressions early

<!-- MANUAL: Add integration tests as UI grows -->
