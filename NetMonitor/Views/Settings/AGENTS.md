<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-01-28 | Updated: 2026-01-28 -->

# Settings

## Purpose

This directory contains the seven settings tab views that comprise NetMonitor's preferences interface. Each view handles a distinct category of user-configurable settings, from startup behavior to network configuration. All settings are persisted via @AppStorage using the `netmonitor.*` key prefix for consistency.

Settings are organized in a NavigationSplitView with a tab sidebar that routes to the appropriate settings view. The parent SettingsView coordinates navigation and view selection.

## Key Files

| File | Purpose | Dependencies |
|------|---------|--------------|
| **GeneralSettingsView.swift** | Startup behavior (launch at login, menu bar/dock visibility), version info | ServiceManagement, @AppStorage |
| **AppearanceSettingsView.swift** | Visual theme (accent color presets, compact mode toggle) | @AppStorage, Color |
| **MonitoringSettingsView.swift** | Monitoring defaults (check intervals, timeouts, retry configuration) | @AppStorage, Picker, Stepper |
| **NotificationSettingsView.swift** | Alert settings (enable/disable, event types, latency threshold slider) | @AppStorage, Toggle, Slider |
| **NetworkSettingsView.swift** | Interface selection (WiFi/Ethernet/Auto) and proxy settings | @AppStorage, PreferredInterface enum |
| **DataSettingsView.swift** | History retention, CSV export, data clearing with confirmation | SwiftData, FileDocument, HistoryRetention enum |
| **CompanionSettingsView.swift** | Companion service control (enable/port), connected devices list, help section | @AppStorage, ConnectedDevice model |

## For AI Agents

### Working In This Directory

**Standard Pattern**: Each view follows the same structure:
1. @AppStorage properties for persistence (use `netmonitor.{category}.{setting}` keys)
2. @State for transient UI state (dialogs, confirmations)
3. Form with grouped layout
4. SwiftUI.Section grouping related controls
5. Accessibility identifiers on all interactive elements
6. navigationTitle matching the SettingsTab.rawValue
7. #Preview for Xcode preview support

**Typical tasks in this directory:**
- Adding new settings preferences (add @AppStorage property, add Section to Form)
- Modifying setting defaults (change default values in @AppStorage declarations)
- Adjusting picker/slider ranges (modify the associated options arrays)
- Adding validation or conditional logic based on other settings
- Implementing destructive actions (use .alert or confirmation dialogs)

### Common Patterns

**@AppStorage Key Convention**:
```swift
@AppStorage("netmonitor.{category}.{settingName}")
```
Examples: `netmonitor.monitoring.defaultInterval`, `netmonitor.notifications.enabled`

**Form Layout Pattern**:
```swift
Form {
    SwiftUI.Section {
        // Controls here
    } header: {
        Text("Section Title")
    } footer: {
        Text("Help text explaining the setting")
    }
}
.formStyle(.grouped)
.padding()
.navigationTitle("Tab Name")
```

**Accessibility Pattern** (required on all interactive elements):
```swift
.accessibilityIdentifier("settings_[type]_[propertyName]")
// Examples: settings_toggle_launchAtLogin, settings_picker_defaultInterval, settings_button_export
```

**Conditional Controls**:
```swift
Toggle("Main setting", isOn: $mainSetting)

if mainSetting {
    // Related controls only show when main toggle is on
    Stepper("Sub-setting: \(value)", value: $value, in: 1...5)
}
```

**Destructive Actions**:
```swift
@State private var showConfirmation = false

Button("Clear All Data...", role: .destructive) {
    showConfirmation = true
}
.alert("Confirm Action?", isPresented: $showConfirmation) {
    Button("Cancel", role: .cancel) { }
    Button("Proceed", role: .destructive) { doAction() }
} message: {
    Text("Explain the irreversible consequence")
}
```

**Enums for Picker Options**:
```swift
enum OptionName: String, CaseIterable {
    case option1 = "Display Name"
    case option2 = "Display Name"
}

Picker("Label", selection: $selected) {
    ForEach(OptionName.allCases, id: \.self) { option in
        Text(option.rawValue).tag(option.rawValue)
    }
}
```

## Dependencies

### Internal Dependencies
- **Parent**: `../SettingsView.swift` (orchestrates tab selection and routing)
- **Models**: DataSettingsView uses `TargetMeasurement`, `NetworkTarget`, `LocalDevice`, `SessionRecord` (SwiftData deletion)
- **Enums**:
  - PreferredInterface (NetworkSettingsView)
  - HistoryRetention (DataSettingsView)
  - SettingsTab (SettingsView, defines tab metadata)

### External Dependencies
- **SwiftUI**: Form, Section, Toggle, Picker, Stepper, Slider, TextField, Button, fileExporter, alert
- **SwiftData**: @Environment(\.modelContext) in DataSettingsView
- **ServiceManagement**: SMAppService in GeneralSettingsView (launch at login)
- **UniformTypeIdentifiers**: UTType in DataSettingsView (CSV export)
- **Foundation**: FileManager, Date formatting in CompanionSettingsView

### Key Integrations
- **@AppStorage**: Central persistence mechanism for all settings (no database dependency)
- **SwiftData modelContext**: DataSettingsView for bulk deletion operations
- **SMAppService**: GeneralSettingsView system integration for launch at login
- **FileDocument + fileExporter**: DataSettingsView CSV export workflow

### Setting Categories & Keys

| Category | Keys | View |
|----------|------|------|
| **general** | launchAtLogin, showInMenuBar, showInDock | GeneralSettingsView |
| **appearance** | accentColor, compactMode | AppearanceSettingsView |
| **monitoring** | defaultInterval, defaultTimeout, retryEnabled, retryCount | MonitoringSettingsView |
| **notifications** | enabled, targetDown, targetRecovery, latencyThreshold | NotificationSettingsView |
| **network** | preferredInterface, useSystemProxy | NetworkSettingsView |
| **data** | historyRetention | DataSettingsView |
| **companion** | enabled, port | CompanionSettingsView |

### Data Flow Notes
1. All settings are read from/written to UserDefaults via @AppStorage
2. No network requests from settings views
3. DataSettingsView has direct SwiftData access for destructive operations (delete all)
4. CompanionSettingsView shows connected devices but sources them from service (not implemented in current view)
5. GeneralSettingsView triggers system-level changes (SMAppService registration)

<!-- MANUAL: -->
