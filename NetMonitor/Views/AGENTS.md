<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-01-28 | Updated: 2026-01-28 -->

# Views

SwiftUI view layer implementing the complete user interface for NetMonitor. Follows MVVM architecture with @Observable coordinators, SwiftData persistence via @Query, and environment-based dependency injection for services and model context.

## Purpose

The Views directory contains the presentational layer of NetMonitor. Views consume @Environment-injected MonitoringSession and DeviceDiscoveryCoordinator coordinators, access persistent data via @Query over SwiftData models, and provide interactive interfaces for monitoring targets, discovering devices, configuring settings, and running network diagnostic tools. All views build on Swift 6 strict concurrency with proper MainActor boundaries.

## Key Files

| File | Lines | Purpose |
|------|-------|---------|
| **DashboardView.swift** | ~178 | Monitoring overview with target status cards, start/stop button, real-time latency display. Routes to TargetStatusCard component. @Query targets from SwiftData. |
| **TargetsView.swift** | ~81 | CRUD interface for monitoring targets. List with swipe-to-delete, add button opens AddTargetSheet, inline enable/disable toggle. |
| **AddTargetSheet.swift** | ~75+ | Modal form for creating new targets. Fields: name, host, protocol selector, port (optional), check interval (slider), timeout (slider). Validation before save. |
| **TargetStatisticsView.swift** | ~120+ | Statistics visualization using Swift Charts. Shows latency trends, availability percentage, response time distribution. |
| **DevicesView.swift** | ~205 | Device discovery split view with list (left) and detail (right). Features: real-time scan progress, search filter, online-only toggle, context menu (copy IP/MAC, ping, port scan, WOL, delete). |
| **DeviceDetailView.swift** | ~250+ | Device detail card with comprehensive info: IP, MAC, vendor, custom name, notes. Actions: copy address, ping, port scan, WOL. Edit capability for name/notes. |
| **DeviceRowView.swift** | ~30 | List row component for device display. Shows icon (by type), name/IP, online status indicator, vendor info. |
| **SettingsView.swift** | ~79 | Tab-based settings container. Sidebar lists 7 tabs (General, Monitoring, Notifications, Network, Data, Appearance, Companion) with routing to detail views. |
| **SidebarView.swift** | ~20 | Navigation sidebar showing 5 main sections: Dashboard, Targets, Devices, Tools, Settings. Current selection binding. |
| **ToolsView.swift** | ~130+ | Grid of network diagnostic tools. 8 tools (Ping, Traceroute, Port Scanner, DNS, WHOIS, Bonjour Browser, Speed Test, WOL). Opens each tool in sheet. |

## Subdirectories

| Directory | Files | Purpose |
|-----------|-------|---------|
| **Settings/** | 7 views | Tabbed settings interface with separate views for each configuration category |
| **Tools/** | 8 views | Network diagnostic tools with self-contained state, input validation, and streaming output |

## For AI Agents

### Working In This Directory

**Environment dependencies:**

All main views expect these @Environment injections from ContentView:
```swift
@Environment(MonitoringSession.self) var session
@Environment(DeviceDiscoveryCoordinator.self) var coordinator
@Environment(\.modelContext) var modelContext
```

MonitoringSession and DeviceDiscoveryCoordinator are optional in some views (like ToolsView) but required for monitoring/device features.

**Data access patterns:**

1. **@Query for SwiftData reads**:
   ```swift
   @Query(sort: \NetworkTarget.name) private var targets: [NetworkTarget]
   @Query(sort: \LocalDevice.lastSeen, order: .reverse) private var devices: [LocalDevice]
   ```
   Sorted by target name or device last seen timestamp (most recent first).

2. **modelContext for writes**:
   ```swift
   @Environment(\.modelContext) private var modelContext
   modelContext.insert(newTarget)
   try? modelContext.save()
   ```

3. **Session data binding**:
   ```swift
   let measurement = session.latestMeasurement(for: target.id)  // Read-only
   session.startMonitoring()  // Action call
   ```

**Sheet and modal patterns:**

- Use `@State private var isPresented = false` for state-driven sheets
- Pass model data directly to sheet views via constructor parameters
- Call `@Environment(\.dismiss)` to close modals from within
- Example: `AddTargetSheet` opened from `TargetsView` toolbar

**Filtering and searching:**

DevicesView demonstrates computed property filtering:
```swift
var filteredDevices: [LocalDevice] {
    var result = devices
    if filterOnlineOnly { result = result.filter { $0.isOnline } }
    if !searchText.isEmpty { result = result.filter { /* search logic */ } }
    return result
}
```

**Context menus:**

DevicesView shows @ViewBuilder context menu pattern:
```swift
@ViewBuilder
private func deviceContextMenu(for device: LocalDevice) -> some View {
    Button("Copy IP") { /* action */ }
    Button("Ping") { /* action */ }
}
```

**Accessibility:**

All interactive elements have `accessibilityIdentifier` for testing:
- Format: `{section}_{type}_{action}` (e.g., `dashboard_button_monitoring_toggle`)
- Use in Xcode UI tests via `.accessibilityIdentifier("identifier")`
- Add to: buttons, toggles, text fields, tabs that change UI behavior

### View Composition Patterns

**Pattern 1: Status card with optional measurement**
```swift
// DashboardView.TargetStatusCard
struct TargetStatusCard: View {
    let target: NetworkTarget
    let measurement: TargetMeasurement?

    var body: some View {
        VStack {
            HStack { /* header */ }
            Text(target.host).font(.caption)
            if let measurement = measurement {
                HStack { /* metrics */ }
            } else {
                Text("Not yet measured")
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(12)
    }
}
```

**Pattern 2: Split view with list and detail**
```swift
// DevicesView structure
NavigationSplitView {
    deviceList
        .frame(minWidth: 300)
} detail: {
    if let selected = selectedDevice {
        DeviceDetailView(device: selected)
    } else {
        ContentUnavailableView(...)
    }
}
.searchable(text: $searchText, prompt: "Search...")
```

**Pattern 3: Modal sheet opening**
```swift
// TargetsView
Button { showingAddSheet = true } label: { Label("Add", ...) }
.sheet(isPresented: $showingAddSheet) {
    AddTargetSheet()  // Receives modelContext via @Environment
}
```

**Pattern 4: Tab navigation with ViewBuilder**
```swift
// SettingsView
@ViewBuilder
private func settingsContent(for tab: SettingsTab) -> some View {
    switch tab {
    case .general: GeneralSettingsView()
    case .monitoring: MonitoringSettingsView()
    // ...
    }
}
```

**Pattern 5: Tool view with streaming output**
```swift
// PingToolView structure
@State private var output: [String] = []
@State private var isRunning = false

func executePing() {
    Task {
        do {
            for try await line in try await pingService.pingStream(...) {
                await MainActor.run { output.append(line) }
            }
        } catch { /* error handling */ }
    }
}
```

### Settings Subdirectory

**Location:** `Views/Settings/`

**Files and patterns:**

| View | Keys | Purpose |
|------|------|---------|
| **GeneralSettingsView.swift** | `netmonitor.general.*` | Launch at login (SMAppService), menu bar/dock visibility, version info |
| **MonitoringSettingsView.swift** | `netmonitor.monitoring.*` | Default check interval, timeout, retry count, auto-start on launch |
| **NotificationSettingsView.swift** | `netmonitor.notifications.*` | Alert sound enable, latency threshold, offline alert, status change notifications |
| **NetworkSettingsView.swift** | `netmonitor.network.*` | Preferred network interface, proxy settings, DNS server override |
| **DataSettingsView.swift** | `netmonitor.data.*` | History retention days, CSV export, clear all data (with confirmation) |
| **AppearanceSettingsView.swift** | `netmonitor.appearance.*` | Accent color picker, dark mode toggle, compact mode, custom theme colors |
| **CompanionSettingsView.swift** | `netmonitor.companion.*` | Companion service enable/disable, port number, connected device list (read-only) |

**All settings use @AppStorage** with "netmonitor.*" prefix for persistence:
```swift
@AppStorage("netmonitor.monitoring.checkInterval") var checkInterval = 30
@AppStorage("netmonitor.notifications.alertSound") var alertSoundEnabled = true
```

Settings views use `.formStyle(.grouped)` or `.listStyle(.sidebar)` for consistent presentation.

### Tools Subdirectory

**Location:** `Views/Tools/`

**Files and self-contained state:**

| View | Service | Input | Output |
|------|---------|-------|--------|
| **PingToolView.swift** | ProcessPingService | Host, count (5, 10, 20), timeout | Real-time ping lines, statistics (min/avg/max/loss) |
| **TracerouteToolView.swift** | ShellCommandRunner | Host, max hops (30) | Hop-by-hop list with latency, IP, hostname |
| **PortScannerToolView.swift** | TCPMonitorService | Host, port range or presets (SSH, HTTP, HTTPS, etc.) | Open/closed ports with latency |
| **DNSLookupToolView.swift** | ShellCommandRunner | Host, record type (A, AAAA, MX, TXT, NS, CNAME) | DNS query results or "No records found" |
| **WHOISToolView.swift** | ShellCommandRunner | Domain, query type (registrar, admin, tech contact) | WHOIS record text output |
| **BonjourBrowserToolView.swift** | BonjourDiscoveryService | Service type filter (HTTP, SSH, SMB, AirPlay, etc.) | Service list with hostname, IP, port, TXT records |
| **SpeedTestToolView.swift** | Network.framework | Test server, protocol (HTTP, HTTPS) | Download/upload speed Mbps, latency, jitter |
| **WakeOnLanToolView.swift** | WakeOnLanService | Device MAC address, broadcast address | Success/failure message with send time |

**Tool view structure (common):**
```swift
struct ToolView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var input = ""
    @State private var isRunning = false
    @State private var output: [String] = []
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            inputArea
            Divider()
            outputArea
            Divider()
            footer
        }
        .frame(minWidth: 500, minHeight: 400)
    }

    private func execute() { /* service call */ }
}
```

**Key tool view features:**
- Input validation (non-empty, valid format) before execution
- Real-time streaming output in Text(.lineLimit(.max)) or List
- Cancel button during execution (runs `task.cancel()`)
- Error messages displayed inline (red text, optional icon)
- Copy button for output text
- Loading spinner (.progressViewStyle(.circular)) during execution
- Accessibility identifiers on all inputs/buttons

### Testing Requirements

**Test locations:** `NetMonitorTests/Views/` (create if needed)

**Test framework:** Swift Testing (`import Testing`)

**Required test coverage for views:**

| View | Test Cases | Strategy |
|------|-----------|----------|
| DashboardView | Empty state, single target, multiple targets, start/stop monitoring | Mock MonitoringSession via @Environment |
| TargetsView | List rendering, add button opens sheet, delete via swipe, enable/disable toggle | Mock @Query with PreviewContainer |
| AddTargetSheet | Form validation (empty name/host), port optional, protocol selection, interval/timeout sliders | Direct instantiation, @State binding tests |
| DevicesView | Empty state, device list, search filter, online-only toggle, scan progress overlay | Mock DeviceDiscoveryCoordinator |
| DeviceDetailView | Display device info, edit name/notes, context menu actions (copy, WOL) | Pass LocalDevice directly |
| SettingsView | Tab switching, content updates for each tab | Verify correct child view renders |
| ToolsView | Grid layout, tool buttons open correct sheets | Verify sheet state binding |

**Preview pattern (required):**
```swift
#Preview {
    TargetView()
        .modelContainer(PreviewContainer().container)
        .environment(MonitoringSession(...))  // If needed
}
```

### Common Patterns

**Pattern 1: Real-time update from session**
```swift
// DashboardView
@Environment(MonitoringSession.self) private var session
let measurement = session.latestMeasurement(for: target.id)

// View reacts to @Observable changes automatically
VStack {
    if let m = measurement {
        Text("\(m.latency ?? 0, format: .number)ms")
            .foregroundStyle(m.isReachable ? .green : .red)
    }
}
```

**Pattern 2: Swipe-to-delete in List**
```swift
// TargetsView
List {
    ForEach(targets) { target in
        TargetRow(target: target)
    }
    .onDelete { offsets in
        for index in offsets {
            modelContext.delete(targets[index])
        }
        try? modelContext.save()
    }
}
```

**Pattern 3: Computed property filtering with toggle**
```swift
// DevicesView
@State private var filterOnlineOnly = false
@State private var searchText = ""

var filteredDevices: [LocalDevice] {
    devices.filter { device in
        (!filterOnlineOnly || device.isOnline) &&
        (searchText.isEmpty || device.displayName.contains(searchText))
    }
}
```

**Pattern 4: Async task with MainActor UI update**
```swift
// Tool views
func executeCommand() {
    Task {
        do {
            for try await line in output {
                await MainActor.run {
                    self.results.append(line)  // Update @State on main thread
                }
            }
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
            }
        }
    }
}
```

**Pattern 5: Context menu with copy to pasteboard**
```swift
// DevicesView
Button("Copy IP") {
    NSPasteboard.general.clearContents()
    NSPasteboard.general.setString(device.ipAddress, forType: .string)
}
```

### Key Design Principles

1. **MainActor safety**: All views run on main thread; no background work in view body
2. **Reactive updates**: Use @State, @Environment, @Query bindings for automatic UI reactivity
3. **Error gracefully**: Show error messages inline, don't crash on network failures
4. **Lazy load**: Use LazyVGrid/List for performance with many items
5. **Accessibility first**: Add identifiers to all interactive elements, support keyboard navigation
6. **Consistent styling**: Use .ultraThinMaterial, .cornerRadius(12), system fonts, SF Symbols
7. **Responsive layout**: Support window resizing via .frame(minWidth:, minHeight:)
8. **Preview for development**: Every view should have #Preview block for Xcode canvas

## Dependencies

### Internal

**Coordinators (MainActor @Observable):**
- MonitoringSession - Monitoring lifecycle coordination
- DeviceDiscoveryCoordinator - Device scan coordination

**Models (SwiftData @Model):**
- NetworkTarget - Monitoring target configuration
- TargetMeasurement - Individual measurement results
- LocalDevice - Discovered network device
- SessionRecord - Monitoring session tracking

**Services (Actors, accessed via coordinator methods):**
- HTTPMonitorService - HTTP/HTTPS monitoring
- TCPMonitorService - TCP port monitoring
- ICMPMonitorService - ICMP ping
- ProcessPingService - Shell-based ping
- ARPScannerService - ARP device discovery
- BonjourDiscoveryService - mDNS service discovery
- ShellCommandRunner - Generic shell command executor
- WakeOnLanService - Magic packet sender

**Enums (NetMonitorShared):**
- TargetProtocol (icmp, http, https, tcp) with .iconName
- DeviceType (phone, laptop, tablet, tv, speaker, gaming, iot, router, printer, unknown) with .iconName
- Section (dashboard, targets, devices, tools, settings) for navigation

**Utilities:**
- PreviewContainer - SwiftUI preview data helper
- WakeOnLanAction - WOL action binding helper

### External

**Apple Frameworks:**
- **SwiftUI** - All view components, @State, @Environment, @Query
- **SwiftData** - Model persistence, @Query for fetching
- **Foundation** - UUID, Date, ProcessInfo, NSPasteboard
- **AppKit** - NSPasteboard for clipboard (copy IP/MAC in DevicesView)
- **ServiceManagement** - SMAppService for launch at login in GeneralSettingsView
- **Charts** - Swift Charts for TargetStatisticsView visualization

**System utilities** (via ShellCommandRunner):**
- `/sbin/ping` - ICMP ping in PingToolView
- `/usr/bin/traceroute` - Network path in TracerouteToolView
- `/usr/bin/dig` - DNS queries in DNSLookupToolView
- `/usr/bin/whois` - Domain lookup in WHOISToolView

## Architecture Notes

### View Initialization Flow

1. **ContentView** initializes with dependencies:
   - Receives MonitoringSession and DeviceDiscoveryCoordinator via @Environment from NetMonitorApp
   - Creates NavigationSplitView with SidebarView + detail routing

2. **SidebarView** selects section, ContentView routes to:
   - .dashboard → DashboardView (requires MonitoringSession)
   - .targets → TargetsView (requires modelContext)
   - .devices → DevicesView (requires DeviceDiscoveryCoordinator)
   - .tools → ToolsView (standalone tools)
   - .settings → SettingsView (uses @AppStorage only)

3. **Sheet navigation**:
   - AddTargetSheet opens from TargetsView toolbar
   - Tool views open as sheets from ToolsView grid buttons
   - Settings tabs route via NavigationSplitView inside SettingsView

### MainActor Boundaries

**MainActor rules:**
- All View structs are implicitly @MainActor (SwiftUI requirement)
- @Environment injections (MonitoringSession, DeviceDiscoveryCoordinator) are @MainActor
- Tool views can create local actor services (ProcessPingService, ShellCommandRunner) but use `await` for calls
- Sheet views receive @Environment(\.dismiss) for modal closure

### Data Flow

```
SwiftData (persistent)
├── @Query in views → automatic updates on changes
└── modelContext.save() after insert/delete

Session (observable)
├── MonitoringSession.latestResults updates dashboard in real-time
└── Views react via @Environment binding

Discovery (observable)
├── DeviceDiscoveryCoordinator.discoveredDevices updates DevicesView
└── coordinator.scanProgress drives UI during scan

AppStorage (preferences)
├── GeneralSettingsView reads/writes startup settings
├── MonitoringSettingsView reads/writes check intervals
└── Other settings views read/write via @AppStorage
```

## Build & Run

**Requirements:**
- macOS 15.0+ (Sequoia)
- Xcode 16.0+
- Swift 6 strict concurrency

**Common tasks:**

Build views only (no compilation without Models/Services):
```bash
xcodebuild -project NetMonitor.xcodeproj -scheme NetMonitor build
```

Run preview canvas for individual view:
```
Xcode → File → Open → Views/DashboardView.swift
Canvas → Resume (Cmd+Shift+A)
```

## Notes for Developers

### When Adding a New View

1. **Create file** in Views/ or appropriate subdirectory (Settings/ or Tools/)
2. **Add @Environment injections** for MonitoringSession/DeviceDiscoveryCoordinator if needed
3. **Add #Preview block** for Xcode canvas development
4. **Add accessibility identifiers** to interactive elements
5. **Use @AppStorage** for preferences (Settings views)
6. **Use @Query** for SwiftData reads (DashboardView, TargetsView, DevicesView)
7. **Call modelContext methods** for writes (save after insert/delete)
8. **Add to test suite** in NetMonitorTests/Views/

### When Modifying Existing View

- **Check @Environment dependencies** - view may require services not injected
- **Update #Preview** if changing @State initialization
- **Test in Xcode canvas** before running app
- **Verify accessibility identifiers** still match if renaming elements
- **Update AGENTS.md** if changing data flow or patterns

### Common Gotchas

1. **@Query in sheet** - Sheet inherits parent's @Environment; @Query works automatically
2. **modelContext.save() required** - Changes to @Model don't persist without explicit save()
3. **Searchable before List** - .searchable() must be called on view, not List itself
4. **Observable updates** - @Environment(MonitoringSession.self) changes drive view updates automatically; no need to re-query
5. **Accessibility identifiers** - Must be unique per view; use `{view}_{element}_{action}` format
6. **Overlay during scan** - DevicesView shows progress overlay via .overlay modifier with conditional content

### Performance Tips

- **Lazy render**: Use LazyVGrid for dashboard cards (multiple targets)
- **Limit @Query results**: Sort and filter in SwiftData query, not in view body
- **Memoize computed properties**: Device filtering happens in computed var, not view body
- **Stream tool output**: Show results as they arrive, don't wait for complete command
- **Cancel long operations**: Tool views provide Cancel button that calls `task.cancel()`

<!-- MANUAL: Add project-specific view patterns or gotchas discovered -->
