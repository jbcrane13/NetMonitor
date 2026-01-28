<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-01-28 | Updated: 2026-01-28 -->

# Utilities

## Purpose

Core helper utilities for concurrency safety and Shortcuts integration. This directory contains reusable components that prevent common pitfalls in async/await patterns and provide user-facing automation capabilities.

## Key Files

| File | Description |
|------|-------------|
| `ContinuationTracker.swift` | Thread-safe tracker preventing double-resume crashes in continuation-based async code |
| `WakeOnLanAction.swift` | @Observable state container + view modifier for Wake-on-LAN operations with built-in alert UI |

## For AI Agents

### Working In This Directory

1. **ContinuationTracker** is a utility class for preventing double-resume bugs:
   - Use `tryResume()` guard in every code path that could resume a continuation
   - Protects against: timeout handlers, state callbacks, error handlers racing
   - Marked `@unchecked Sendable` with NSLock for safe cross-thread access

2. **WakeOnLanAction** is a reusable state container for WOL operations:
   - Instantiate in views that need WOL: `@State private var wolAction = WakeOnLanAction()`
   - Call `await wolAction.wake(device:)` or `await wolAction.wake(macAddress:displayName:)`
   - Attach alert via `.wakeOnLanAlert(_:)` modifier
   - Maintains internal `WakeOnLanService` instance (don't create separately)

### Common Patterns

#### Preventing Double-Resume in Callback-Based Code

```swift
let tracker = ContinuationTracker()
return await withCheckedContinuation { continuation in
    // Multiple code paths could trigger resumption
    connection.stateUpdateHandler = { state in
        if state == .ready, tracker.tryResume() {
            continuation.resume(returning: true)
        }
    }
    // Timeout handler runs independently
    DispatchQueue.global().asyncAfter(deadline: .now() + 5) {
        if tracker.tryResume() {
            continuation.resume(returning: false)
        }
    }
}
```

**Key points:**
- Create one `ContinuationTracker` per continuation
- Guard EVERY resumption with `tracker.tryResume()`
- Only the first code path to call `tryResume()` gets `true`
- NSLock ensures thread-safe flag check+set

#### Using WakeOnLanAction in Views

```swift
struct DeviceDetailView: View {
    @State private var wolAction = WakeOnLanAction()
    var device: LocalDevice

    var body: some View {
        VStack {
            Button("Wake Device") {
                Task {
                    await wolAction.wake(device: device)
                }
            }
        }
        .wakeOnLanAlert(wolAction)
    }
}
```

**Key points:**
- Create instance at view level with `@State`
- Pass device or MAC + display name
- Modifier handles alert presentation automatically
- No need to manage `WakeOnLanService` yourself

### Implementation Notes

#### ContinuationTracker Implementation

- **Thread Safety**: Uses `NSLock` (explicit locking required, cannot use atomic Bool due to Swift 6 strict concurrency)
- **@unchecked Sendable**: Marked unsafe because NSLock synchronizes internal access
- **Reset Capability**: `reset()` method for reuse in testing/pooling scenarios
- **Query State**: `hasResumed` property for inspection (rare use case)

#### WakeOnLanAction Implementation

- **@Observable**: Modern Observation framework (not ObservableObject)
- **@MainActor**: `wake()` methods confined to main thread for safety
- **Encapsulated Service**: Creates `WakeOnLanService` internally (no injection needed)
- **Alert State**: Manages both `showAlert` and `alertMessage` for simple presentation
- **View Modifier Pattern**: `WakeOnLanAlertModifier` + extension for clean API

## Dependencies

### ContinuationTracker
- **Frameworks**: Foundation (NSLock)
- **Import**: Standard (no special frameworks needed)
- **Used By**: Services wrapping callback-based APIs (ARPScannerService, BonjourDiscoveryService, TCPMonitorService)

### WakeOnLanAction
- **Frameworks**: SwiftUI (@Observable macro, View protocol), Foundation
- **Dependencies**: `WakeOnLanService` (actor)
- **Models**: `LocalDevice` (for device parameter)
- **Used By**: DeviceDetailView, WakeOnLanToolView

## Patterns

### Thread Safety with NSLock

ContinuationTracker uses traditional NSLock pattern (required for Swift 6 strict concurrency with @unchecked Sendable):

```swift
final class ContinuationTracker: @unchecked Sendable {
    private let lock = NSLock()
    private var _hasResumed = false

    func tryResume() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        if _hasResumed { return false }
        _hasResumed = true
        return true
    }
}
```

This is the **correct** pattern when strict concurrency prevents atomic operations.

### Observable State with MainActor Confinement

WakeOnLanAction uses @Observable + @MainActor for UI integration:

```swift
@Observable
final class WakeOnLanAction {
    var showAlert: Bool = false
    private(set) var alertMessage: String?

    @MainActor
    func wake(device: LocalDevice) async {
        // UI updates confined to main thread
    }
}
```

### View Modifier Pattern

Standard SwiftUI pattern for attaching behavior to views:

```swift
struct WakeOnLanAlertModifier: ViewModifier {
    @Bindable var action: WakeOnLanAction

    func body(content: Content) -> some View {
        content.alert(/* ... */)
    }
}

extension View {
    func wakeOnLanAlert(_ action: WakeOnLanAction) -> some View {
        modifier(WakeOnLanAlertModifier(action: action))
    }
}
```

## Testing Notes

- **ContinuationTracker**: Unit test by verifying `tryResume()` returns true once then false
- **WakeOnLanAction**: Mock `WakeOnLanService` if testing alert presentation logic independently
- Both utilities are internal; test through their usage in services/views

<!-- MANUAL: No additional configuration needed -->
