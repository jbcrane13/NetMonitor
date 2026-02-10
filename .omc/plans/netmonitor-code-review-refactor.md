# NetMonitor Code Review Refactoring Plan

**Created:** 2026-02-10
**Scope:** 31 findings across 5 phases, ~25 files
**Estimated Complexity:** HIGH
**Team Size:** 3-4 concurrent agents
**Estimated Total Duration:** 15-21 hours (5-7 hours wall-clock with 3 parallel agents)

---

## Context

NetMonitor is a macOS 15+ network monitoring app using Swift 6, SwiftUI `@Observable`, SwiftData, and actor-based services. Four specialist agents reviewed the codebase and identified 31 issues ranging from a critical double-resume crash to polish-level dead code removal. This plan organizes those findings into parallelizable work streams with clear file ownership to prevent merge conflicts.

**Build command:** `xcodebuild -project NetMonitor.xcodeproj -scheme NetMonitor -configuration Debug build`
**Test command:** `xcodebuild -project NetMonitor.xcodeproj -scheme NetMonitor test`

---

## Phase 1: Critical Fixes

**Duration:** 1-2 hours | **Parallelism:** 2 agents | **Gate:** Build must pass before Phase 2

### Task 1.1 — Fix double-resume crash in BonjourDiscoveryService

- **Agent:** `executor` (sonnet)
- **File:** `NetMonitor/Services/BonjourDiscoveryService.swift`
- **Problem:** `resolveHostnameToIP()` (lines 368-391) uses `withCheckedContinuation` with two resume paths: the URLSession callback (line 377) and the DispatchQueue timeout (line 388). If the callback fires AND the timeout fires, it double-resumes and crashes. The existing `attemptLightweightResolution()` (lines 417-470) already solves this correctly with `ContinuationTracker`.
- **Fix:**
  1. Add `let tracker = ContinuationTracker()` at the top of the continuation closure
  2. Guard both `continuation.resume(returning: resolvedHost)` (line 377) and `continuation.resume(returning: nil)` (lines 379, 388) behind `if tracker.tryResume()`
  3. Cancel the URLSession task in the timeout path before resuming
- **Acceptance Criteria:**
  - `ContinuationTracker` guards all resume paths in `resolveHostnameToIP()`
  - Build passes with zero warnings on this file
  - Existing unit tests still pass

### Task 1.2 — Add measurement retention pruning

- **Agent:** `executor` (sonnet)
- **Files:** `NetMonitor/Services/MonitoringSession.swift`, `NetMonitor/Views/Settings/DataSettingsView.swift`
- **Problem:** `updateMeasurement()` (line 180) appends to `target.measurements` forever. At 5s intervals with 10 targets, this produces ~170K records/day with no cleanup.
- **Fix:**
  1. In `MonitoringSession`, add an `@AppStorage("netmonitor.historyRetention")` property with default value of 7 (days)
  2. Add a `pruneOldMeasurements()` method that deletes `TargetMeasurement` records older than the retention period using a SwiftData `FetchDescriptor` with a date predicate
  3. Call `pruneOldMeasurements()` once at monitoring session start (in `startMonitoring()`) and once every hour during active monitoring (add a pruning timer)
  4. Verify that `DataSettingsView` already has a retention slider/picker that writes to `netmonitor.historyRetention` — if not, add one
- **Acceptance Criteria:**
  - Measurements older than the configured retention period are deleted on session start
  - Periodic pruning runs during active monitoring
  - The retention period is user-configurable via Settings > Data
  - Build passes

### Phase 1 Verification

- **Agent:** `build-fixer` (sonnet)
- Run full build: `xcodebuild -project NetMonitor.xcodeproj -scheme NetMonitor -configuration Debug build`
- Run tests: `xcodebuild -project NetMonitor.xcodeproj -scheme NetMonitor test`
- Gate: Both must pass before proceeding to Phase 2

---

## Phase 2: Concurrency Safety

**Duration:** 3-4 hours | **Parallelism:** 3 agents | **Gate:** Build must pass before Phase 3

### Task 2.1 — Create Sendable DTOs for cross-actor boundary

- **Agent:** `executor-high` (opus)
- **Files:**
  - NEW: `NetMonitor/Models/TargetCheckRequest.swift`
  - NEW: `NetMonitor/Models/MeasurementResult.swift`
  - MODIFY: `NetMonitor/Services/MonitoringSession.swift`
  - MODIFY: `NetMonitor/Services/HTTPMonitorService.swift`
  - MODIFY: `NetMonitor/Services/TCPMonitorService.swift`
  - MODIFY: `NetMonitor/Services/ICMPMonitorService.swift`
- **Problem:** `NetworkTarget` and `TargetMeasurement` are `@Model` classes marked `@unchecked Sendable`. Passing them across actor boundaries is technically unsafe — SwiftData model objects are bound to their `ModelContext`'s actor.
- **Fix:**
  1. Create `TargetCheckRequest` struct (Sendable): `id: UUID, host: String, port: Int?, targetProtocol: TargetProtocol, timeout: TimeInterval`
  2. Create `MeasurementResult` struct (Sendable): `targetID: UUID, timestamp: Date, latency: Double?, isReachable: Bool, errorMessage: String?`
  3. Change `NetworkMonitorService.check(target:)` protocol signature to accept `TargetCheckRequest` and return `MeasurementResult`
  4. Update all three monitor service implementations (HTTP, TCP, ICMP) to use the new types
  5. In `MonitoringSession.monitorTarget()`, extract `TargetCheckRequest` from `NetworkTarget` on `@MainActor` before calling the actor-isolated service, then convert `MeasurementResult` back to `TargetMeasurement` on `@MainActor`
  6. Keep `@unchecked Sendable` on `NetworkTarget` and `TargetMeasurement` for now (other code still relies on it), but add a `// TODO: Remove @unchecked Sendable once all cross-actor usage eliminated` comment
- **Acceptance Criteria:**
  - No `@Model` objects cross actor boundaries in the monitoring hot path
  - All three monitor services accept `TargetCheckRequest` and return `MeasurementResult`
  - Build passes with strict concurrency checking
  - All existing tests pass

### Task 2.2 — Add .onDisappear task cancellation + fix ShellCommandRunner leak

- **Agent:** `executor` (sonnet)
- **Files:**
  - `NetMonitor/Views/Tools/PingToolView.swift`
  - `NetMonitor/Views/Tools/TracerouteToolView.swift`
  - `NetMonitor/Views/Tools/PortScannerToolView.swift`
  - `NetMonitor/Views/Tools/SpeedTestToolView.swift`
  - `NetMonitor/Views/Tools/DNSLookupToolView.swift`
  - `NetMonitor/Views/Tools/WHOISToolView.swift`
  - `NetMonitor/Views/Tools/BonjourBrowserToolView.swift`
  - `NetMonitor/Views/Tools/WakeOnLanToolView.swift`
  - `NetMonitor/Views/DevicesView.swift` (DevicePingSheet, DevicePortScanSheet)
  - `NetMonitor/Views/DeviceDetailView.swift`
  - `NetMonitor/Services/ShellCommandRunner.swift`
- **Problem A:** Zero `.onDisappear` handlers in any tool view. If a user navigates away while a ping/traceroute/scan is running, the Task keeps running and updating disposed state.
- **Problem B:** `ShellCommandRunner.stream()` (line 144-215) has no `continuation.onTermination` handler. If the consuming `for await` loop is cancelled, the Process keeps running.
- **Fix A:** Add `.onDisappear` to every tool view that has a running task:
  ```swift
  .onDisappear {
      runningTask?.cancel()
  }
  ```
  For views that have a `stop*()` method, call that instead to ensure clean state reset.
- **Fix B:** In `ShellCommandRunner.stream()`, after `try process.run()` (line 208), add:
  ```swift
  continuation.onTermination = { @Sendable _ in
      Task { await self.cancel() }
  }
  ```
- **Acceptance Criteria:**
  - Every tool view with async work has `.onDisappear` that cancels running tasks
  - `ShellCommandRunner.stream()` terminates the `Process` when the stream consumer cancels
  - Build passes
  - Existing `ShellCommandRunnerTests` still pass

### Task 2.3 — Replace silent `try? modelContext.save()` with logged error handling + Remove redundant `MainActor.run`

- **Agent:** `executor` (sonnet)
- **Files (save errors):**
  - `NetMonitor/Services/MonitoringSession.swift` (1 occurrence, line 181)
  - `NetMonitor/Services/DeviceDiscoveryCoordinator.swift` (4 occurrences, lines 141, 152, 201, 248)
  - `NetMonitor/Views/TargetsView.swift` (1 occurrence, line 54)
  - `NetMonitor/Views/AddTargetSheet.swift` (1 occurrence, line 109)
  - `NetMonitor/Services/DefaultTargetsProvider.swift` (1 occurrence, line 71)
  - `NetMonitor/Views/DeviceDetailView.swift` (1 occurrence, line 395)
- **Files (MainActor.run removal):**
  - `NetMonitor/Views/DevicesView.swift` (5 occurrences: lines 355, 363, 368, 548, 554)
  - `NetMonitor/Views/Tools/TracerouteToolView.swift` (7 occurrences: lines 213, 226, 245, 253, 310, 321, 331)
  - `NetMonitor/Views/Tools/WakeOnLanToolView.swift` (2 occurrences: lines 194, 200)
  - `NetMonitor/Views/Tools/PingToolView.swift` (4 occurrences: lines 205, 216, 236, 255)
  - `NetMonitor/Views/Tools/SpeedTestToolView.swift` (11 occurrences: lines 334, 340, 346, 349, 394, 434, 443, 454, 507, 516, 527)
  - `NetMonitor/Views/Tools/BonjourBrowserToolView.swift` (1 occurrence: line 295)
  - `NetMonitor/Views/Tools/DNSLookupToolView.swift` (2 occurrences: lines 210, 224)
  - `NetMonitor/Views/Tools/WHOISToolView.swift` (2 occurrences: lines 343, 353)
  - `NetMonitor/Views/Tools/PortScannerToolView.swift` (1 occurrence: line 318)
- **Fix (save errors):** Replace each `try? modelContext.save()` with:
  ```swift
  do {
      try modelContext.save()
  } catch {
      Logger.data.error("Failed to save context: \(error.localizedDescription)")
  }
  ```
  Add `import os` and define a shared Logger extension (see Task 4.1 for full os.Logger adoption — here just add the minimal Logger needed for the save calls).
- **Fix (MainActor.run):** In views that are already `@MainActor` (all SwiftUI views), Tasks launched from the view body inherit `@MainActor`. The `await MainActor.run { ... }` wrappers are redundant. Remove them and use the enclosed code directly. **Caveats:**
  - Only remove when the enclosing Task is NOT `Task.detached` and NOT inside a `nonisolated` method
  - **CRITICAL: Do NOT remove `MainActor.run` inside `for try await` loops that iterate over actor-isolated async sequences.** After each `await` in a `for try await` loop, execution returns to the actor's isolation context, not the calling Task's. Example: `DevicePingSheet.runPing()` lines 355, 363, 368 — these `MainActor.run` calls may be necessary if the `for await` crosses an actor boundary
  - Verify each site individually before removing
- **Acceptance Criteria:**
  - Zero `try? modelContext.save()` in source files (excluding docs/plans)
  - Zero redundant `await MainActor.run { }` in tool views where Task inherits @MainActor
  - An `os.Logger` is used for save-error logging (subsystem: `com.netmonitor`, category: `data`)
  - Build passes

### Phase 2 Verification

- **Agent:** `build-fixer` (sonnet)
- Run full build and all tests
- Gate: Must pass before Phase 3

---

## Phase 3: Architecture Cleanup

**Duration:** 6-8 hours | **Parallelism:** 3 agents | **Gate:** Build must pass before Phase 4

**IMPORTANT: Task 3.1 and 3.2 create new files that Tasks 3.3 and 3.4 depend on. Execute in two waves.**

### Wave A (parallel)

### Task 3.1 — Extract PortScanService actor

- **Agent:** `executor-high` (opus)
- **Files:**
  - NEW: `NetMonitor/Services/PortScanService.swift`
  - MODIFY: `NetMonitor/Views/Tools/PortScannerToolView.swift`
  - MODIFY: `NetMonitor/Views/DevicesView.swift` (DevicePortScanSheet section)
- **Problem:** Port scanning logic exists in two places with two different implementations: `DevicePortScanSheet` uses BSD sockets (lines 561-613), while `PortScannerToolView` uses `NWConnection` (lines 331-388). The `NWConnection` approach is preferred (consistent with the rest of the codebase, no manual socket management).
- **Fix:**
  1. Create `PortScanService` actor with:
     - `func scanPorts(host: String, ports: [UInt16]) -> AsyncThrowingStream<PortScanResult, Error>` (streaming results)
     - `func scanPorts(host: String, ports: [UInt16]) async -> [PortScanResult]` (batch results)
     - `func cancel()`
     - Move `ContinuationTracker`-based `checkPort()` from `PortScannerToolView` into the service
     - Move `serviceName(for:)` static mapping into the service (consolidate both copies)
     - Use `NWConnection`-based approach (from PortScannerToolView) as the canonical implementation
  2. Refactor `PortScannerToolView` to use `PortScanService` instead of inline scanning
  3. Refactor `DevicePortScanSheet` to use `PortScanService` instead of BSD sockets
  4. Make `DevicePortScanSheet` use concurrent scanning (it currently scans sequentially, one port at a time)
- **Acceptance Criteria:**
  - Single `PortScanService` actor handles all port scanning
  - No BSD socket code remains in view files
  - `serviceName(for:)` mapping exists in one place only
  - `DevicePortScanSheet` scans ports concurrently (batches of 50, matching PortScannerToolView)
  - Build passes

### Task 3.2 — Extract SpeedTestService actor

- **Agent:** `executor` (sonnet)
- **Files:**
  - NEW: `NetMonitor/Services/SpeedTestService.swift`
  - MODIFY: `NetMonitor/Views/Tools/SpeedTestToolView.swift`
- **Problem:** `SpeedTestToolView` contains ~150 lines of URLSession measurement logic (measurePing, measureDownload, measureUpload) mixed into the view.
- **Fix:**
  1. Create `SpeedTestService` actor with:
     - `func measurePing() async -> Double?`
     - `func measureDownload(duration: TimeInterval) -> AsyncStream<SpeedSample>`
     - `func measureUpload(duration: TimeInterval) -> AsyncStream<SpeedSample>`
     - `func cancel()`
     - Define `SpeedSample` struct: `bytesTransferred: Int64, speedMbps: Double, elapsed: TimeInterval`
  2. Move all URLSession logic from `SpeedTestToolView` into the service
  3. Slim down `SpeedTestToolView` to consume the service streams and update `@State` properties
  4. Remove all `await MainActor.run { }` from the refactored view (should be unnecessary after the refactor since state updates will happen in the consuming Task)
- **Acceptance Criteria:**
  - Zero URLSession code in `SpeedTestToolView`
  - `SpeedTestService` is a standalone actor
  - Speed test functionality works identically (ping, download, upload phases)
  - Build passes

### Task 3.3 — Deduplicate ping views

- **Agent:** `executor` (sonnet)
- **Files:**
  - MODIFY: `NetMonitor/Views/Tools/PingToolView.swift`
  - MODIFY: `NetMonitor/Views/DevicesView.swift` (DevicePingSheet)
- **Depends on:** None (can run parallel with 3.1/3.2, different files)
- **Problem:** `DevicePingSheet` (lines 238-383 in DevicesView.swift) duplicates PingToolView's streaming ping output. Both use `ProcessPingService` and render line-by-line output.
- **Fix:**
  1. Add an optional `prefillHost: String?` parameter to `PingToolView.init()`
  2. When `prefillHost` is set, pre-populate the host field and optionally auto-start
  3. Replace `DevicePingSheet`'s body with `PingToolView(prefillHost: device.ipAddress)` wrapped in the sheet chrome (dismiss button, title)
  4. Remove the duplicated ping logic from `DevicePingSheet` (~100 lines)
- **Acceptance Criteria:**
  - `DevicePingSheet` is a thin wrapper around `PingToolView`
  - Ping from device detail produces identical output to the standalone ping tool
  - Build passes

### Wave B (after Wave A completes)

### Task 3.4 — Extract ToolSheetContainer generic view

- **Agent:** `executor` (sonnet)
- **Files:**
  - NEW: `NetMonitor/Views/Tools/ToolSheetContainer.swift`
  - MODIFY: All 8 tool views in `NetMonitor/Views/Tools/`
- **Depends on:** Tasks 3.1, 3.2, 3.3 (those tasks modify tool views; this task should apply to the already-refactored versions)
- **Problem:** All 8 tool views repeat the same layout structure: header with title + dismiss button, divider, input area, divider, output area with scroll, footer with clear/action buttons. This is ~40-50 lines of boilerplate per view.
- **Fix:**
  1. Create `ToolSheetContainer<InputArea: View, OutputArea: View>: View` with:
     - `title: String`
     - `iconName: String`
     - `@ViewBuilder inputArea: () -> InputArea`
     - `@ViewBuilder outputArea: () -> OutputArea`
     - `onDismiss: () -> Void`
     - Optional: `clearAction: (() -> Void)?`
     - Optional: `isRunning: Bool` (for progress indicator)
  2. **Apply incrementally to reduce blast radius:**
     - First: Apply to PingToolView, DNSLookupToolView, WHOISToolView (3 simpler views)
     - Run build to verify
     - Then: Apply to remaining 5 views (TracerouteToolView, PortScannerToolView, SpeedTestToolView, BonjourBrowserToolView, WakeOnLanToolView)
  3. Target: eliminate ~280-350 lines of duplicated layout code across the 8 views
- **Acceptance Criteria:**
  - `ToolSheetContainer` provides the shared layout
  - All 8 tool views use it
  - Visual appearance is unchanged
  - Build passes after each batch

### Phase 3 Verification

- **Agent:** `build-fixer` (sonnet)
- Run full build and all tests
- Gate: Must pass before Phase 4

---

## Phase 4: Quality of Life

**Duration:** 3-4 hours | **Parallelism:** 3 agents | **Gate:** Build must pass before Phase 5

### Task 4.1 — Adopt os.Logger across all services

- **Agent:** `executor` (sonnet)
- **Files:**
  - NEW: `NetMonitor/Services/Logging.swift` (Logger extension)
  - MODIFY: `NetMonitor/Services/CompanionService.swift` (11 print statements)
  - MODIFY: `NetMonitor/Services/BonjourDiscoveryService.swift` (1 print statement)
  - MODIFY: `NetMonitor/Services/DeviceDiscoveryCoordinator.swift` (1 print statement)
- **Fix:**
  1. Create `Logging.swift` with a Logger extension:
     ```swift
     import os
     extension Logger {
         static let companion = Logger(subsystem: "com.netmonitor", category: "companion")
         static let discovery = Logger(subsystem: "com.netmonitor", category: "discovery")
         static let monitoring = Logger(subsystem: "com.netmonitor", category: "monitoring")
         static let data = Logger(subsystem: "com.netmonitor", category: "data")
         static let network = Logger(subsystem: "com.netmonitor", category: "network")
     }
     ```
  2. Replace all `print()` statements in service files with appropriate Logger calls
  3. Map: `print("CompanionService: ...")` -> `Logger.companion.info/error/debug(...)`
  4. If Task 2.3 already added a minimal Logger for save errors, merge it into this central definition
- **Acceptance Criteria:**
  - Zero `print()` statements in `NetMonitor/Services/` directory
  - All logging uses `os.Logger` with subsystem `com.netmonitor`
  - Build passes

### Task 4.2a — Rename Section enum to NavigationSection

- **Agent:** `executor` (sonnet)
- **Files:**
  - MODIFY: `NetMonitor/Models/Section.swift`
  - MODIFY: `NetMonitor/Views/SidebarView.swift`
  - MODIFY: `NetMonitor/Views/ContentView.swift` (references Section at lines 13, 25-41)
- **Fix:**
  1. Rename `Section` to `NavigationSection` in `Section.swift`
  2. Run `grep -r "Section" --include="*.swift"` across the project to find ALL references (not just SidebarView)
  3. Update `SidebarView.swift` and `ContentView.swift` (both reference the enum)
  4. Rename the file to `NavigationSection.swift`
  5. Do NOT update `SwiftUI.Section` references in Settings views — those are a different type
- **Acceptance Criteria:**
  - No `Section` enum (renamed to `NavigationSection`)
  - All references updated (verified by grep)
  - Build passes

### Task 4.2b — Sheet presentation cleanup

- **Agent:** `executor` (sonnet)
- **Files:**
  - MODIFY: `NetMonitor/Views/DevicesView.swift` (DevicePingSheet, DevicePortScanSheet)
  - MODIFY: `NetMonitor/Views/ToolsView.swift`
- **Fix:**
  1. In `DevicePingSheet` and `DevicePortScanSheet`, remove the `@Binding var isPresented: Bool` and use `@Environment(\.dismiss)` instead
  2. Update callers in `DevicesView` to remove the manual `Binding(get:set:)` construction
  3. In `ToolsView`, convert from manual `Binding` management to `.sheet(item:)` pattern using the `NetworkTool` enum directly
  4. **Note:** `.sheet(item:)` resets sheet content on dismiss vs `.sheet(isPresented:)` which preserves it — verify tool state is properly reset
- **Acceptance Criteria:**
  - Sheet views use `@Environment(\.dismiss)` instead of `@Binding var isPresented`
  - `ToolsView` uses `.sheet(item:)` pattern
  - Build passes

### Task 4.3 — Standardize error types + SwiftData migration plan

- **Agent:** `executor` (sonnet)
- **Files:**
  - NEW: `NetMonitor/Models/NetMonitorError.swift`
  - NEW: `NetMonitor/Models/SchemaV1.swift`
  - MODIFY: Service files with ad-hoc error enums (as needed)
  - MODIFY: `NetMonitor/NetMonitorApp.swift` (ModelContainer config)
- **Fix (errors):**
  1. Create `NetMonitorError` enum conforming to `LocalizedError` with cases covering common failure modes: `.networkUnavailable`, `.permissionDenied`, `.timeout`, `.commandFailed(String)`, `.saveFailed(Error)`
  2. Add `LocalizedError` conformance to existing error enums (`ToolError` in ShellCommandRunner, etc.) if they don't already have it
  3. This is additive — don't rewrite all error handling, just ensure conformance and add the shared type
- **Fix (migration):**
  1. Create `SchemaV1.swift` defining a `VersionedSchema` with the current model set
  2. Create a `SchemaMigrationPlan` (even if empty) to establish the migration infrastructure
  3. Update `ModelContainer` initialization in `NetMonitorApp.swift` to use the migration plan
  4. Improve `ModelContainer` error handling: instead of `fatalError` on failure, show a fallback UI or attempt in-memory container
- **Acceptance Criteria:**
  - `NetMonitorError` exists with `LocalizedError` conformance
  - `SchemaV1` and `SchemaMigrationPlan` are defined
  - `ModelContainer` failure does not crash the app
  - Build passes

### Phase 4 Verification

- **Agent:** `build-fixer` (sonnet)
- Run full build and all tests

---

## Phase 5: Polish

**Duration:** 2-3 hours | **Parallelism:** 3 agents | **Gate:** Final build + test

### Task 5.1 — View cleanup batch (Agent A)

- **Agent:** `executor` (sonnet)
- **Files:**
  - `NetMonitor/Views/DeviceDetailView.swift` — Remove 6 unused `@State` properties (pingResults, isPinging, pingTask, portScanResults, isScanning, scanProgress at lines 18-26 — verify these are unused after Phase 3 refactoring)
  - `NetMonitor/Views/TargetStatisticsView.swift` — Remove `#available(macOS 13.0, *)` check (app targets macOS 15+) and replace `.cornerRadius(12)` with `.clipShape(RoundedRectangle(cornerRadius: 12))`
  - `NetMonitor/Views/GatewayInfoCard.swift` — Replace `.cornerRadius(12)` (line 152)
  - `NetMonitor/Views/ConnectionInfoCard.swift` — Replace `.cornerRadius(4)` (line 79) and `.cornerRadius(12)` (line 112)
  - `NetMonitor/Views/QuickStatsBar.swift` — Replace `.cornerRadius(12)` (line 59)
  - `NetMonitor/Views/DashboardView.swift` — Replace `.cornerRadius(8)` (line 50) and `.cornerRadius(12)` (line 167)
- **Acceptance Criteria:**
  - Zero deprecated `.cornerRadius()` calls in view files (use `.clipShape()` instead)
  - No `#available(macOS 13.0, *)` checks (deployment target is macOS 15)
  - No unused `@State` properties in `DeviceDetailView`
  - Build passes

### Task 5.2 — Service/model cleanup batch (Agent B)

- **Agent:** `executor` (sonnet)
- **Files:**
  - `NetMonitor/Views/ToolsView.swift` — Remove `NetworkTool.isComplex` computed property (lines 49-56, unused)
  - `NetMonitor/Views/ToolsView.swift` — Fix double `.frame()` constraints (check if ToolsView applies frame AND individual tool views also apply frame, causing layout conflicts)
  - `NetMonitor/Views/Tools/PingToolView.swift` — Change `private let pingService = ProcessPingService()` (line 20) to `@State private var pingService = ProcessPingService()` (actors as view properties should be `@State` to survive view re-creation)
  - `NetMonitor/Views/Tools/WakeOnLanToolView.swift` — Fix broadcast address handling: either pass the UI-entered broadcast address through to `WakeOnLanService.wake()` or remove the broadcast address field if the service always uses 255.255.255.255
  - `NetMonitor/Views/ISPInfoCard.swift` — Consolidate `loadISPInfo()` and `refresh()` (they are character-for-character identical). Either delete `refresh()` and have the button call `loadISPInfo()`, or have `refresh()` delegate to `loadISPInfo()`.
- **Acceptance Criteria:**
  - `NetworkTool.isComplex` removed
  - `PingToolView.pingService` is `@State`
  - WakeOnLan broadcast address is correctly handled
  - ISPInfoCard has a single data-loading method (no duplicate `loadISPInfo`/`refresh`)
  - Build passes

### Task 5.3 — Architecture cleanup batch (Agent C)

- **Agent:** `executor` (sonnet)
- **Files:**
  - `NetMonitor/Services/MonitoringSession.swift` — Add protocol-based DI: define a `MonitorServiceProviding` protocol and accept it in the initializer instead of creating services internally. This makes testing easier without requiring full service mocks.
  - `NetMonitor/Views/ContentView.swift` — Update MonitoringSession creation (lines 50-58) to use the new protocol/default
  - `NetMonitorShared/Sources/NetMonitorShared/Common/Enums.swift` — Move `.iconName` computed properties from the shared package to extension files in the main app target. The shared package should not reference SF Symbol names (it's shared with iOS companion which may use different icons).
- **Acceptance Criteria:**
  - `MonitoringSession` accepts services via protocol in its initializer
  - `ContentView.swift` and `NetMonitorApp.swift` updated to use the new protocol
  - Existing behavior unchanged (default implementations provided)
  - `.iconName` not in shared package
  - Build passes

### Task 5.4 — Address remaining MEDIUM findings (Agent C)

- **Agent:** `executor` (sonnet)
- **Files:**
  - `NetMonitor/Views/DeviceDetailView.swift` — Fix Bonjour waste: `loadBonjourServices()` (line 398) creates a new `BonjourDiscoveryService` every time. Either inject via `@Environment(DeviceDiscoveryCoordinator.self)` and query cached results, or scope the scan to relevant service types only.
  - `NetMonitor/Models/SessionRecord.swift` + `NetMonitor/Services/MonitoringSession.swift` — Wire SessionRecord into monitoring: create records in `startMonitoring()`, update `stoppedAt` in `stopMonitoring()`. Currently the model exists but is never written to.
  - `NetMonitor/Services/ARPScannerService.swift` — Add concurrency throttling: the `withTaskGroup` at line 47 launches 254 concurrent NWConnection probes with no limit. Add a sliding-window pattern with max concurrency of ~50 (matching the pattern used in `resolveDeviceNames()`).
- **Acceptance Criteria:**
  - DeviceDetailView reuses existing Bonjour data instead of starting a full network scan
  - SessionRecord entries are created and updated during monitoring lifecycle
  - ARP scanner limits concurrent probes to ~50
  - Build passes

### Phase 5 Final Verification

- **Agent:** `build-fixer` (sonnet)
- Run full build: `xcodebuild -project NetMonitor.xcodeproj -scheme NetMonitor -configuration Debug build`
- Run all tests: `xcodebuild -project NetMonitor.xcodeproj -scheme NetMonitor test`
- Verify zero warnings related to concurrency
- Gate: FINAL — all phases complete

---

## Dependency Graph

```
Phase 1:  [1.1] ─────┐
          [1.2] ──────┤
                      ▼
          ────── BUILD GATE ──────
                      │
Phase 2:  [2.1] ──────┤
          [2.2] ──────┤  (all 3 parallel)
          [2.3] ──────┤
                      ▼
          ────── BUILD GATE ──────
                      │
Phase 3:  [3.1] ──────┤
  Wave A: [3.2] ──────┤  (all 3 parallel)
          [3.3] ──────┤
                      ▼
  Wave B: [3.4] ──────┤  (depends on 3.1, 3.2, 3.3)
                      ▼
          ────── BUILD GATE ──────
                      │
Phase 4:  [4.1] ──────┤
          [4.2] ──────┤  (all 3 parallel)
          [4.3] ──────┤
                      ▼
          ────── BUILD GATE ──────
                      │
Phase 5:  [5.1] ──────┤
          [5.2] ──────┤  (all 3 parallel)
          [5.3] ──────┤
                      ▼
          ────── FINAL VERIFICATION ──────
```

## File Ownership Map (Conflict Prevention)

Within each phase, no two parallel tasks modify the same file. Cross-phase, files may be touched by multiple tasks, but phases are gated sequentially.

| Phase | Agent A | Agent B (shared files) | Agent C |
|-------|---------|---------|---------|
| **1** | BonjourDiscoveryService | MonitoringSession, DataSettingsView | — |
| **2** | Models/*, MonitoringSession, HTTP/TCP/ICMPMonitorService | **Tasks 2.2+2.3 (SAME AGENT):** All Tool Views, DevicesView, DeviceDetailView, ShellCommandRunner, DeviceDiscoveryCoordinator, TargetsView, AddTargetSheet, DefaultTargetsProvider | — |
| **3A** | SpeedTestService (new), SpeedTestToolView | **Tasks 3.1+3.3 (SAME AGENT):** PortScanService (new), PortScannerToolView, PingToolView, DevicesView (both sheets) | — |
| **3B** | ToolSheetContainer (new), all 8 tool views | — | — |
| **4** | Logging.swift (new), CompanionService, BonjourDiscoveryService, DeviceDiscoveryCoordinator | Section.swift, SidebarView, ContentView, DevicesView, ToolsView (Tasks 4.2a + 4.2b) | NetMonitorError (new), SchemaV1 (new), NetMonitorApp |
| **5** | DeviceDetailView, TargetStatisticsView, GatewayInfoCard, ConnectionInfoCard, QuickStatsBar, DashboardView | ToolsView, PingToolView, WakeOnLanToolView, ISPInfoCard | MonitoringSession, ContentView, NetMonitorShared/Enums, SessionRecord, ARPScannerService |

**Phase 2 MANDATORY:** Tasks 2.2 and 2.3 MUST be assigned to the SAME agent. Both touch 8+ tool view files and DeviceDetailView. Running them in parallel on different agents will cause merge conflicts. The agent should run 2.2 first (`.onDisappear` additions), then 2.3 (`MainActor.run` removal + `try?` replacement).

**Phase 3A MANDATORY:** Tasks 3.1 and 3.3 MUST be assigned to the SAME agent. Both modify `DevicesView.swift`. Run 3.3 first (ping dedup, smaller change at lines 238-383) then 3.1 (port scan extraction at lines 480-618). If 3.3 removes ~100 lines, it shifts line numbers for 3.1's section.

---

## Guardrails

### MUST Have
- Every phase gated by a clean build
- No regressions in existing test suite
- Sendable DTOs for all cross-actor model passing
- Zero double-resume continuation bugs
- Measurement retention pruning active

### MUST NOT Have
- No new `@unchecked Sendable` annotations
- No new `print()` statements (use os.Logger)
- No new `try? modelContext.save()` (use do/catch)
- No new `await MainActor.run { }` in `@MainActor`-isolated contexts
- No architecture redesign beyond what's specified (keep scope tight)

---

## Success Criteria

1. **Zero critical bugs:** Double-resume fixed, measurement growth bounded
2. **Clean concurrency:** Sendable DTOs in use, tasks cancelled on view disappear, no process leaks
3. **DRY architecture:** PortScanService, SpeedTestService, ToolSheetContainer eliminate duplication
4. **Observable quality:** os.Logger throughout, no silent error swallowing, migration infrastructure
5. **Clean build:** Zero warnings, zero test failures, all phases verified
6. **Completeness:** SessionRecord wired in, ARP throttled, DeviceDetailView Bonjour waste fixed

---

## Consensus Record

**Ralplan Cycle:** Planner → Architect → Critic → Consensus
**Date:** 2026-02-10
**Verdict:** APPROVED WITH CHANGES (all changes applied)

**Architect verdict:** APPROVE WITH CHANGES — 7 issues identified, all applied
**Critic verdict:** APPROVE WITH CHANGES — 5 issues identified, all applied

**Key consensus changes applied:**
1. Task 2.3: Added critical caveat about `MainActor.run` in `for try await` loops
2. Task 4.2: Split into 4.2a (rename) + 4.2b (sheets), added ContentView.swift
3. Phase 2: Tasks 2.2+2.3 mandatory same agent
4. Phase 3A: Tasks 3.1+3.3 mandatory same agent (3.3 first)
5. Added Task 5.4 for 3 missing MEDIUM findings (Bonjour waste, SessionRecord, ARP throttling)
6. Task 3.4: Incremental application (3 views, build, then 5 views)
7. Task 5.3: Added ContentView.swift to file list
8. Task 5.2: Sharpened ISPInfoCard acceptance criteria
