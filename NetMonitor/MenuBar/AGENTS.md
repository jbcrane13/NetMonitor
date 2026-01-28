<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-01-28 | Updated: 2026-01-28 -->

# MenuBar

Manages macOS menu bar integration through NSStatusItem, providing quick access to monitoring status, target statistics, and essential controls without requiring the main application window.

## Purpose

The MenuBar directory provides menu bar (system tray) integration for NetMonitor using AppKit's NSStatusItem and NSPopover. It displays monitoring status, aggregated statistics, and a quick list of monitored targets, allowing users to control monitoring and access the main app from the menu bar. This directory also defines keyboard shortcuts for common actions accessible from anywhere in macOS.

## Key Files

| File | Description |
|------|-------------|
| **MenuBarController.swift** | NSStatusItem management with icon state updates (network, network.slash, exclamationmark.triangle) and popover lifecycle control |
| **MenuBarPopoverView.swift** | SwiftUI view for popover content: header with monitoring state, quick stats (online/offline/latency), top 5 targets, footer with launch button |
| **MenuBarCommands.swift** | Global keyboard shortcuts: Cmd+Shift+M (toggle monitoring), Cmd+R (scan network); uses NotificationCenter for command dispatch |

## For AI Agents

### Working In This Directory

**When modifying menu bar functionality:**

1. **MenuBarController** is `@MainActor @Observable`:
   - Manages NSStatusItem (system status bar icon)
   - Controls NSPopover visibility and content
   - Updates icon based on monitoring state via `updateIcon(isMonitoring:hasIssues:)`
   - Do NOT access from background threads - it's MainActor-only

2. **MenuBarPopoverView** is a SwiftUI view:
   - Receives `@Bindable var session: MonitoringSession` to observe changes
   - Calls `onClose()` callback when "Open NetMonitor" button tapped
   - Displays data via computed properties delegated to MonitoringSession for testability
   - All bindings should come from the MonitoringSession

3. **MenuBarCommands** provides global keyboard shortcuts:
   - Uses CommandGroup to integrate with app menu
   - Dispatches actions via NotificationCenter.post(name:) pattern
   - Shortcuts are always active, even when main window not focused

**Architecture pattern:**
```swift
// MenuBarController setup in NetMonitorApp.setupServices()
let menuBarController = MenuBarController(monitoringSession: session)
menuBarController.setup()  // Must call after creation

// MenuBarController manages popover lifecycle
// PopoverView receives session binding
// Commands define shortcuts and emit notifications
```

**Icon update flow:**
```
MonitoringSession state change
  ↓
View observes change via @Bindable
  ↓
MenuBarController.updateIcon(isMonitoring:, hasIssues:) called
  ↓
Icon updated: network (stopped) → network (green, monitoring) → exclamationmark.triangle (issues)
```

### Common Patterns

**Pattern 1: Icon state management**

MenuBarController.updateIcon() handles three states:
- **Not monitoring** (`!isMonitoring`) → "network.slash" icon (gray)
- **Monitoring, no issues** (`isMonitoring && !hasIssues`) → "network" icon (green)
- **Monitoring with issues** (`isMonitoring && hasIssues`) → "exclamationmark.triangle" icon (red)

Icon colors set via `button.contentTintColor`:
```swift
if hasIssues {
    button.contentTintColor = .systemRed      // Issues detected
} else if isMonitoring {
    button.contentTintColor = .systemGreen    // Monitoring active
} else {
    button.contentTintColor = nil             // Default gray
}
```

**Pattern 2: Popover content updates**

MenuBarPopoverView displays:
1. **Header** - Title, monitoring state indicator (green/gray circle), start/stop button
2. **Quick stats** - Online count, offline count, average latency (delegated to MonitoringSession properties)
3. **Target list** - Top 5 targets with status (reachable=green, offline=red) and latency
4. **Footer** - "Open NetMonitor" button, session running time

Statistics computation delegated to MonitoringSession:
```swift
private var onlineTargetCount: Int { session.onlineTargetCount }
private var offlineTargetCount: Int { session.offlineTargetCount }
private var averageLatencyString: String { session.averageLatencyString }
```

This keeps popover view simple and testable.

**Pattern 3: Popover lifecycle**

```swift
// Setup (called once in MenuBarController.setup())
popover = NSPopover()
popover?.contentSize = NSSize(width: 320, height: 400)
popover?.behavior = .transient               // Closes when focus lost
popover?.animates = true
popover?.contentViewController = NSHostingController(rootView: MenuBarPopoverView(...))

// Toggle visibility (called when menu bar icon clicked)
if popover.isShown {
    closePopover()                           // performClose(nil)
} else {
    popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
}
```

**Pattern 4: Keyboard shortcuts with notifications**

MenuBarCommands defines shortcuts that work globally:
```swift
// Cmd+Shift+M: Toggle monitoring
Button(isMonitoring ? "Stop Monitoring" : "Start Monitoring") {
    if isMonitoring {
        stopMonitoring()
    } else {
        startMonitoring()
    }
}
.keyboardShortcut("m", modifiers: [.command, .shift])

// Cmd+R: Scan network
Button("Scan Network") {
    NotificationCenter.default.post(
        name: .scanNetworkRequested,
        object: nil
    )
}
.keyboardShortcut("r", modifiers: [.command])
```

Notification receivers in ContentView or other views listen for:
- `.scanNetworkRequested` - Trigger device discovery scan
- `.monitoringStateChanged` - Monitoring state updates
- `.targetStatusChanged` - Target status changes

**Pattern 5: Menu bar controller initialization**

In NetMonitorApp.setupServices():
```swift
let menuBarController = MenuBarController(monitoringSession: session)
menuBarController.setup()
self.environment(\.menuBarController, menuBarController)  // If using environment injection

// Cleanup in deinit or app termination:
menuBarController.teardown()
```

### View Hierarchy

```
NSStatusBar (system menu bar)
  └── NSStatusItem (status bar icon)
      ├── button (click target)
      │   └── image (network/network.slash/exclamationmark.triangle)
      └── NSPopover (.transient behavior)
          └── NSHostingController
              └── MenuBarPopoverView (SwiftUI)
                  ├── header
                  │   ├── "NetMonitor" title
                  │   ├── monitoring state indicator (green/gray circle)
                  │   └── start/stop button
                  ├── quickStats
                  │   ├── online count
                  │   ├── offline count
                  │   └── average latency
                  ├── targetList
                  │   └── ForEach(top 5 targets)
                  │       └── targetRow (status circle, name, latency/offline)
                  └── footer
                      ├── "Open NetMonitor" button
                      └── session running time
```

### Testing Patterns

MenuBarPopoverView preview includes:
```swift
#Preview {
    let container = try! ModelContainer(
        for: NetworkTarget.self, TargetMeasurement.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    let context = container.mainContext
    let httpService = HTTPMonitorService()
    let icmpService = ICMPMonitorService()
    let tcpService = TCPMonitorService()
    let session = MonitoringSession(
        modelContext: context,
        httpService: httpService,
        icmpService: icmpService,
        tcpService: tcpService
    )

    return MenuBarPopoverView(session: session, onClose: {})
}
```

For testing MenuBarController, verify:
- Icon updates correctly when `updateIcon(isMonitoring:hasIssues:)` called
- Popover shows/hides on button click
- PopoverView receives session binding correctly
- Commands trigger appropriate callbacks

### Accessibility

All interactive elements have accessibility labels:
- Menu bar icon: `accessibilityDescription: "NetMonitor"`
- Start/Stop button: `.help()` text varies based on state
- "Open NetMonitor" button: Clearly labeled action
- Quick stats: Context labels (Online, Offline, Avg Latency)

## Dependencies

### Internal

**Coordinators** (from Views/):
- **MonitoringSession** (@MainActor @Observable)
  - Provides: `isMonitoring`, `latestResults`, `onlineTargetCount`, `offlineTargetCount`, `averageLatencyString`, `startTime`
  - Methods: `startMonitoring()`, `stopMonitoring()`

**Models** (from Models/):
- **TargetMeasurement** - Individual check results with latency and reachability

**Enums** (from Models/):
- **Section** - Navigation sections (used if needed for routing)

### External

**Apple Frameworks**:
- **SwiftUI** - MenuBarPopoverView UI
- **AppKit** - NSStatusItem, NSStatusBar, NSPopover, NSHostingController
- **Foundation** - NotificationCenter, Notification.Name extensions

**System resources**:
- macOS menu bar (NSStatusBar.system)
- System fonts and colors (systemRed, systemGreen)
- SF Symbols (network, network.slash, exclamationmark.triangle, stop.fill, play.fill)

## Integration Points

**From NetMonitorApp.swift:**
```swift
let menuBarController = MenuBarController(monitoringSession: session)
menuBarController.setup()
// Later: menuBarController.teardown()
```

**From Views (notification listeners):**
```swift
NotificationCenter.default.addObserver(
    forName: .scanNetworkRequested,
    object: nil,
    queue: .main
) { _ in
    // Trigger device scan
    discoveryCoordinator.startScan()
}
```

**From Views (environment if needed):**
```swift
@Environment(MenuBarController.self) var menuBarController
```

## Known Constraints

1. **MainActor requirement** - MenuBarController is `@MainActor`, cannot access from background services
2. **Popover transient behavior** - Closes automatically when user focuses another window; cannot persist across focus changes
3. **Icon size limitations** - SF Symbols at status bar size may be less detailed; test visibility
4. **Menu bar space** - Status item takes fixed width in system menu bar; keep label short or use icon-only
5. **Preview limitations** - MenuBarPopoverView previews correctly, but NSStatusItem cannot be previewed; test in running app

## Performance

- **Icon updates** - Immediate, no animation (uses contentTintColor change)
- **Popover show/hide** - ~200ms with animation enabled
- **View rendering** - Minimal with top 5 targets limit and scroll view constraints
- **Notification dispatch** - Synchronous, fires immediately; listeners should defer heavy work

<!-- MANUAL: Add implementation notes from development -->

**Recent Changes (Jan 19, 2026):**
- MenuBarController migrated from ObservableObject to @Observable macro (modern concurrency)
- MenuBarPopoverView statistics delegated to MonitoringSession for testability
- Preview updated with proper dependency injection (all services initialized)

**Known Issues:**
- None currently documented

**Future Enhancements:**
- Option to hide menu bar icon in settings
- Customizable stats in popover (user chooses which metrics to display)
- Click-to-expand target list (show all targets instead of top 5)
- Menu bar graph sparkline for historical latency trend
