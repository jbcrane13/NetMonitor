<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-01-28 | Updated: 2026-01-28 -->

# Tools

Network diagnostic tools providing real-time interactive utilities for network monitoring, device discovery, and system diagnostics. Each tool is self-contained with its own state management, service layer integration, and streaming output handling.

## Purpose

The Tools directory contains eight specialized network diagnostic views (PingToolView, TracerouteToolView, PortScannerToolView, DNSLookupToolView, WHOISToolView, BonjourBrowserToolView, SpeedTestToolView, WakeOnLanToolView) that provide interactive interfaces for network troubleshooting and analysis. Each tool:

- Manages its own @State for input, execution state, output, and errors
- Integrates with a service layer (ProcessPingService, ShellCommandRunner, TCPMonitorService, etc.)
- Implements streaming output via AsyncThrowingStream for real-time feedback
- Provides cancel capability for long-running operations
- Validates input before execution
- Displays errors inline without crashing
- Uses consistent UI patterns (header, input area, output area, footer)
- Includes accessibility identifiers on all interactive elements

Tools are opened as sheets from ToolsView and follow a uniform architecture enabling consistency and testability.

## Key Files

| File | Purpose |
|------|---------|
| **PingToolView.swift** | Interactive ICMP ping with streaming output, packet statistics (min/avg/max/loss), host reachability display |
| **TracerouteToolView.swift** | Network path tracing showing hop-by-hop latencies, hostnames, IP addresses, timeout detection |
| **PortScannerToolView.swift** | TCP port scanning with preset port lists (Common, Web) or custom ranges, batch scanning with progress |
| **DNSLookupToolView.swift** | DNS record queries (A, AAAA, MX, TXT, CNAME, NS, SOA, PTR) using /usr/bin/dig command |
| **WHOISToolView.swift** | Domain WHOIS lookup via /usr/bin/whois command for registration information |
| **BonjourBrowserToolView.swift** | Browse mDNS services on local network, filter by service type (HTTP, SSH, SMB, AirPlay, etc.) |
| **SpeedTestToolView.swift** | Placeholder for bandwidth measurement tool using Network.framework |
| **WakeOnLanToolView.swift** | Send magic packets to wake devices by MAC address, supports multiple MAC formats |

## For AI Agents

### Working In This Directory

**Sheet presentation:**

All tool views are presented as sheets from ToolsView grid buttons:

```swift
// ToolsView
.sheet(isPresented: $showingPingTool) {
    PingToolView()
}
```

Tool views receive `@Environment(\.dismiss)` automatically from the sheet presenter. No additional dependency injection needed - tools are self-contained.

**Service instantiation:**

Tools create their service instances as local properties:

```swift
struct PingToolView: View {
    private let pingService = ProcessPingService()  // Created fresh per sheet
    // ...
}
```

This is safe because each tool instance is temporary (lives only while sheet is open). Don't use shared singletons - each tool gets its own service instance.

**Streaming output pattern:**

Tools receive AsyncThrowingStream from services and append results line-by-line:

```swift
@State private var output: [String] = []

Task {
    do {
        for try await line in await pingService.pingStream(...) {
            await MainActor.run {
                output.append(line)  // Append as stream delivers
            }
        }
    } catch {
        // Handle error
    }
}
```

Never wait for complete output - append as lines arrive for real-time display.

**Cancellation pattern:**

Tools store running state and check it during loops:

```swift
@State private var isRunning = false

private func stopPing() {
    Task {
        await pingService.cancel()
        await MainActor.run {
            isRunning = false
        }
    }
}
```

Cancel button calls `stopPing()` which cancels the service and updates UI state.

**Error handling:**

All tools display errors inline without crashing:

```swift
@State private var errorMessage: String?

} catch {
    await MainActor.run {
        errorMessage = error.localizedDescription  // Show in UI
        isRunning = false
    }
}
```

Error messages appear in red text in the output area. Never throw - always catch and display.

**Input validation:**

Validate input before executing service calls:

```swift
private func runPing() {
    guard !host.isEmpty else { return }  // Block invalid input
    // ...
}
```

Disable input/button during execution (`isRunning` flag controls `.disabled()`).

### Tool View Architecture

**Standard layout (5-part structure):**

```swift
VStack(spacing: 0) {
    header          // Title + close button
    Divider()
    inputArea       // Host/parameters + Run button
    Divider()
    outputArea      // Results/error messages (scrollable)
    Divider()
    footer          // Status + Clear button
}
.frame(minWidth: 500, minHeight: 400)  // Resizable, with minimum size
```

All tools use this 5-part layout for consistency.

**Header:**

```swift
private var header: some View {
    HStack {
        Label("Tool Name", systemImage: "sf.symbol.name")
            .font(.headline)
        Spacer()
        Button { dismiss() } label: {
            Image(systemName: "xmark.circle.fill")
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("tool_button_close")
    }
    .padding()
}
```

Every tool has a title with SF Symbol and close button. Copy this structure.

**Input area:**

Varies by tool but typically includes:
- TextField for primary input (host, domain, etc.)
- Picker for options (record type, port preset, count, etc.)
- Run/Scan button

Example:
```swift
private var inputArea: some View {
    HStack(spacing: 12) {
        TextField("Host", text: $host)
            .textFieldStyle(.roundedBorder)
            .disabled(isRunning)
            .accessibilityIdentifier("tool_textfield_host")

        Picker("Option", selection: $option) {
            // Options
        }
        .disabled(isRunning)

        Button(isRunning ? "Stop" : "Run") { /* action */ }
            .buttonStyle(.borderedProminent)
            .disabled(host.isEmpty && !isRunning)
            .accessibilityIdentifier("tool_button_run")
    }
    .padding()
}
```

**Output area:**

For streaming output (Ping, Traceroute):
```swift
private var outputArea: some View {
    ScrollViewReader { proxy in
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 2) {
                ForEach(Array(output.enumerated()), id: \.offset) { index, line in
                    Text(line)
                        .font(.system(.body, design: .monospaced))
                        .textSelection(.enabled)
                        .id(index)  // For scroll tracking
                }
                if let error = errorMessage {
                    Text(error)
                        .foregroundStyle(.red)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
        }
        .background(Color.black.opacity(0.2))
        .onChange(of: output.count) { _, _ in
            if let lastIndex = output.indices.last {
                proxy.scrollTo(lastIndex, anchor: .bottom)  // Auto-scroll
            }
        }
    }
}
```

For structured results (PortScanner, DNS):
```swift
private var outputArea: some View {
    ScrollView {
        LazyVStack(alignment: .leading, spacing: 4) {
            if results.isEmpty && !isRunning {
                Text("No results yet")
                    .foregroundStyle(.tertiary)
            } else {
                ForEach(results) { result in
                    resultRow(result)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
    }
    .background(Color.black.opacity(0.2))
}

private func resultRow(_ result: Result) -> some View {
    HStack {
        // Result display
    }
}
```

**Footer:**

Shows execution status and control buttons:

```swift
private var footer: some View {
    HStack {
        if isRunning {
            ProgressView()
                .scaleEffect(0.7)
            Text("Running...")
        } else if !results.isEmpty {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
            Text("Completed")
        } else if errorMessage != nil {
            Image(systemName: "exclamationmark.triangle")
                .foregroundStyle(.orange)
            Text("Failed")
        } else {
            Text("Ready")
                .foregroundStyle(.secondary)
        }

        Spacer()

        if !results.isEmpty && !isRunning {
            Button("Clear") {
                results.removeAll()
                errorMessage = nil
            }
            .accessibilityIdentifier("tool_button_clear")
        }
    }
    .padding()
}
```

Copy this pattern - every tool needs execution status feedback.

### Service Integration Patterns

**Pattern 1: ProcessPingService (streaming)**

```swift
struct PingToolView: View {
    private let pingService = ProcessPingService()

    private func runPing() {
        Task {
            do {
                for try await line in await pingService.pingStream(host: host, count: count) {
                    await MainActor.run {
                        output.append(line.formatted)
                    }
                }
            } catch {
                // Handle
            }
        }
    }
}
```

`pingStream()` returns AsyncThrowingStream<PingLine>. Iterate with `for try await`.

**Pattern 2: ShellCommandRunner (streaming)**

```swift
struct TracerouteToolView: View {
    private let runner = ShellCommandRunner()

    private func runTraceroute() {
        Task {
            do {
                for try await line in await runner.stream("/usr/sbin/traceroute", arguments: [...]) {
                    if let hop = parseTracerouteLine(line) {
                        await MainActor.run {
                            hops.append(hop)
                        }
                    }
                }
            } catch let error as ToolError {
                // Handle ToolError specifically
            }
        }
    }
}
```

`stream()` runs shell command and yields lines. Handle ToolError for execution failures.

**Pattern 3: TCPMonitorService (batching)**

```swift
struct PortScannerToolView: View {
    private func scanPorts(host: String, ports: [UInt16]) async {
        let batchSize = 50

        for batch in stride(from: 0, to: ports.count, by: batchSize) {
            await withTaskGroup(of: PortResult?.self) { group in
                for port in batchPorts {
                    group.addTask {
                        await self.checkPort(host: host, port: port)
                    }
                }

                for await result in group {
                    await MainActor.run {
                        results.append(result)
                    }
                }
            }
        }
    }
}
```

PortScanner uses `withTaskGroup()` for concurrent port checks with batching.

**Pattern 4: WakeOnLanService (fire-and-forget)**

```swift
struct WakeOnLanToolView: View {
    private let wolService = WakeOnLanService()

    private func sendMagicPacket() {
        Task {
            do {
                try await wolService.sendMagicPacket(
                    mac: macAddress,
                    broadcastAddress: broadcastAddress
                )
                await MainActor.run {
                    resultMessage = "Magic packet sent!"
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
}
```

WOL service returns once packet sent. No streaming - just success/failure.

### Data Models in Tools

Some tools define local structs for results:

```swift
// PingToolView
private let pingService = ProcessPingService()  // Returns PingResult

// TracerouteToolView
struct TracerouteHop: Identifiable {
    let id = UUID()
    let hopNumber: Int
    var hostname: String?
    var ipAddress: String?
    var latencies: [Double] = []
    var isTimeout: Bool
}

// PortScannerToolView
struct PortResult: Identifiable {
    let id = UUID()
    let port: UInt16
    let isOpen: Bool
    let latency: TimeInterval
    let serviceName: String
}

// DNSLookupToolView
// Results stored as [String] (raw dig output lines)

// WHOISToolView
// Results stored as [String] (raw whois output lines)
```

Define local structs in the same file for tool-specific models.

### Enums and Pickers

Tools define enums for preset options:

```swift
// PortScannerToolView
enum PortPreset: String, CaseIterable {
    case common = "Common"
    case web = "Web"
    case custom = "Custom"

    var ports: [UInt16] {
        switch self {
        case .common: return [21, 22, 80, 443, 3306, 5432, 8080, ...]
        case .web: return [80, 443, 8080, 3000, 5000, ...]
        case .custom: return []
        }
    }
}

// DNSLookupToolView
enum DNSRecordType: String, CaseIterable {
    case a = "A"
    case aaaa = "AAAA"
    case mx = "MX"
    case txt = "TXT"
    case cname = "CNAME"
    case ns = "NS"
}
```

Define enums at file level (before struct View).

### Common Parsing Functions

Tools that parse command output define parsing helpers:

```swift
// TracerouteToolView
private func parseTracerouteLine(_ line: String) -> TracerouteHop? {
    // Skip header
    if line.hasPrefix("traceroute to") { return nil }

    // Parse: " 1  router.local (192.168.1.1)  1.234 ms"
    let components = line.trimmingCharacters(in: .whitespaces)
        .components(separatedBy: .whitespaces)
        .filter { !$0.isEmpty }

    // Extract hop number, hostname, IP, latencies
    // Return TracerouteHop
}

// PortScannerToolView
private func parseCustomPorts(_ input: String) -> [UInt16] {
    var ports: Set<UInt16> = []

    let components = input.components(separatedBy: ",")
    for component in components {
        if component.contains("-") {
            // Range: "1-1024"
            let parts = component.split(separator: "-")
            if let start = UInt16(parts[0]), let end = UInt16(parts[1]) {
                ports.insert(contentsOf: start...min(end, 65535))
            }
        } else if let port = UInt16(component.trimmingCharacters(in: .whitespaces)) {
            ports.insert(port)
        }
    }

    return Array(ports).sorted()
}
```

Define parsing functions as private methods in the View struct.

### Accessibility Identifiers

All interactive elements have accessibility identifiers following the pattern:
`{tool}_{type}_{element}` where:
- `{tool}` = tool name (ping, traceroute, portscan, dns, whois, bonjour, speedtest, wol)
- `{type}` = element type (button, textfield, picker)
- `{element}` = element purpose (host, close, run, count, type, etc.)

Examples:
- `ping_button_close` - Close button in Ping tool
- `ping_textfield_host` - Host input in Ping tool
- `ping_picker_count` - Count picker in Ping tool
- `traceroute_button_run` - Run button in Traceroute tool
- `portscan_textfield_custom` - Custom ports input in Port Scanner

Add accessibility identifiers to:
- All TextFields
- All Pickers (not picker rows, the picker itself)
- All Buttons
- Any interactive element used in tests

## Common Patterns

### Pattern 1: Streaming with auto-scroll

```swift
@State private var output: [String] = []

private var outputArea: some View {
    ScrollViewReader { proxy in
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 2) {
                ForEach(Array(output.enumerated()), id: \.offset) { index, line in
                    Text(line)
                        .id(index)
                }
            }
        }
        .onChange(of: output.count) { _, _ in
            if let lastIndex = output.indices.last {
                proxy.scrollTo(lastIndex, anchor: .bottom)
            }
        }
    }
}

private func runTool() {
    Task {
        for try await line in streamingService {
            await MainActor.run {
                output.append(line)  // Triggers onChange, scrolls
            }
        }
    }
}
```

ScrollViewReader tracks `.id()` on text, `onChange` scrolls to latest.

### Pattern 2: Progress display

```swift
@State private var isRunning = false
@State private var scannedCount = 0
@State private var totalItems = 0

private var footer: some View {
    HStack {
        if isRunning {
            ProgressView()
            Text("Scanning \(scannedCount)/\(totalItems)...")
            ProgressView(value: Double(scannedCount), total: Double(totalItems))
                .frame(width: 100)
        }
    }
}
```

Use `ProgressView(value:total:)` for numeric progress bars during long scans.

### Pattern 3: Batch processing with cancellation

```swift
@State private var isRunning = false

private func scanPorts(host: String, ports: [UInt16]) async {
    let batchSize = 50

    for batch in stride(from: 0, to: ports.count, by: batchSize) {
        guard isRunning else { break }  // Check flag to stop

        let batchPorts = Array(ports[batch..<batch+batchSize])

        await withTaskGroup(of: Result?.self) { group in
            for item in batchPorts {
                group.addTask {
                    await processItem(item)
                }
            }

            for await result in group {
                guard isRunning else { break }

                await MainActor.run {
                    results.append(result)
                }
            }
        }
    }
}

private func stopScan() {
    isRunning = false  // Breaks the batch loop
}
```

Check `isRunning` flag at batch boundaries and inside task group.

### Pattern 4: Custom port parsing

```swift
private func parseCustomPorts(_ input: String) -> [UInt16] {
    var ports: Set<UInt16> = []

    let components = input.components(separatedBy: ",")
    for component in components {
        let trimmed = component.trimmingCharacters(in: .whitespaces)

        if trimmed.contains("-") {
            // Range: "22-25" → [22, 23, 24, 25]
            let parts = trimmed.split(separator: "-")
            if parts.count == 2,
               let start = UInt16(parts[0]),
               let end = UInt16(parts[1]),
               start <= end {
                for port in start...min(end, 65535) {
                    ports.insert(port)
                }
            }
        } else if let port = UInt16(trimmed) {
            // Single port
            ports.insert(port)
        }
    }

    return Array(ports).sorted()
}
```

Supports both ranges ("1-1024") and lists ("22,80,443").

### Pattern 5: Shell command with error recovery

```swift
private func runCommand() {
    Task {
        do {
            for try await line in await runner.stream(command, arguments: args) {
                if let parsed = parseResult(line) {
                    await MainActor.run {
                        results.append(parsed)
                    }
                }
            }
        } catch let error as ToolError {
            await MainActor.run {
                // Check if we have partial results before showing error
                if case .executionFailed = error, !results.isEmpty {
                    // Partial success - don't show error
                } else {
                    errorMessage = error.localizedDescription
                }
            }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
            }
        }
    }
}
```

Traceroute often exits with non-zero even on partial success - check results before showing error.

## Dependencies

### Internal

**Services (Actors):**
- `ProcessPingService` - Shell-based ping using `/sbin/ping`
- `ShellCommandRunner` - Generic shell command executor for traceroute, dig, whois
- `TCPMonitorService` - TCP port monitoring (used for port scanning checks)
- `WakeOnLanService` - Magic packet sender
- `BonjourDiscoveryService` - mDNS service discovery
- `BonjourBrowserModel` - ViewModel wrapper for Bonjour browsing

**Models (Tool-specific structs):**
- `PingResult` - Summary from ProcessPingService (min/avg/max latency, packet loss)
- `PingLine` - Individual ping response from streaming
- `TracerouteHop` - Hop information (number, hostname, IP, latencies)
- `PortResult` - Port scan result (port, isOpen, latency, serviceName)

**Enums (Tool-specific):**
- `PortPreset` (common, web, custom) - PortScannerToolView
- `DNSRecordType` (a, aaaa, mx, txt, cname, ns, soa, ptr) - DNSLookupToolView

### External

**Apple Frameworks:**
- **SwiftUI** - All views, @State, @Environment, @MainActor
- **Foundation** - Date, TimeInterval, UUID, String parsing
- **Network.framework** - NWConnection for port scanning (in TCPMonitorService)
- **AppKit** - NSPasteboard for copy-to-pasteboard functionality

**System utilities** (via ShellCommandRunner):**
- `/sbin/ping` - ICMP echo requests
- `/usr/sbin/traceroute` - Network path tracing
- `/usr/bin/dig` - DNS queries
- `/usr/bin/whois` - Domain information lookup
- `/usr/sbin/arp` - ARP lookups (via ARPScannerService in Bonjour browser)

## Architecture Notes

### Service Access Pattern

Tools don't use dependency injection - they create service instances locally:

```swift
struct PingToolView: View {
    private let pingService = ProcessPingService()  // Scoped to this view
}
```

This is safe because:
1. Tool views are sheet-based (temporary, short-lived)
2. Each tool instance needs fresh service state
3. No cross-tool service sharing needed

Don't try to inject services via @Environment - keep them local.

### MainActor Boundaries

All tool views run on MainActor (implicit in SwiftUI):
- View body is MainActor
- @State updates are safe to mutate in body code
- Async service calls use `await` and then `await MainActor.run { }` for UI updates

```swift
Task {
    do {
        let result = try await pingService.ping(...)  // Background thread
        await MainActor.run {
            self.output.append(result)  // Main thread for UI update
        }
    }
}
```

### Streaming Output Flow

```
Service AsyncThrowingStream
        ↓
for try await line in stream
        ↓
await MainActor.run { self.output.append(line) }
        ↓
ScrollView auto-scrolls via onChange
        ↓
LazyVStack renders new line
        ↓
User sees real-time results
```

Never accumulate output in background - append immediately for responsiveness.

### Error Handling Strategy

Each tool:
1. Displays errors inline (red text in output area)
2. Never crashes on network/command failure
3. Shows user-friendly error messages
4. Maintains partial results when possible

Example (Traceroute):
```swift
} catch let error as ToolError {
    if case .executionFailed = error, !hops.isEmpty {
        // Partial success - skip error display
    } else {
        errorMessage = error.localizedDescription
    }
}
```

### Preview Pattern

All tools include #Preview block:

```swift
#Preview {
    PingToolView()
}
```

Simple instantiation - no dependencies to inject. Tool is self-contained.

## Build & Run

**Requirements:**
- macOS 15.0+ (Sequoia)
- Xcode 16.0+
- Swift 6 strict concurrency

**Build all tools:**
```bash
xcodebuild -project NetMonitor.xcodeproj -scheme NetMonitor build
```

**Run tool preview in Xcode canvas:**
1. Open PingToolView.swift
2. Canvas → Resume (Cmd+Shift+A)
3. View updates as you edit

## Notes for Developers

### When Adding a New Tool View

1. **Create file** in Views/Tools/ (e.g., `NewToolView.swift`)
2. **Use 5-part layout**: header, divider, inputArea, divider, outputArea, divider, footer
3. **Create local service** as private property
4. **Add @State for**: input, isRunning, output/results, errorMessage
5. **Implement runAction()** that creates Task with service call
6. **Implement stopAction()** that cancels service and updates isRunning
7. **Add error handling**: catch exceptions and update errorMessage
8. **Add accessibility identifiers** to all interactive elements
9. **Add #Preview** block for Xcode canvas
10. **Add accessibility identifiers** in format `{tool}_{type}_{element}`

### When Modifying Existing Tool

- **Check @State usage** - all input/output is mutable state
- **Verify service integration** - service calls are async and require await
- **Test streaming** - output should append line-by-line, not wait for completion
- **Test cancellation** - Stop button should cancel running operation
- **Verify accessibility IDs** - if renaming elements, update IDs
- **Update #Preview** - test in Xcode canvas after changes
- **Check error display** - errors should show inline without crashing

### Common Gotchas

1. **Awaiting from MainActor** - Always use `await MainActor.run { }` for UI updates from async calls
2. **Streaming completion** - Don't try to get full output at end - stream as it arrives
3. **Service cancellation** - Must call `await service.cancel()` in separate Task, not in view body
4. **Accessibility IDs** - Must be unique within tool view; use `{tool}_{type}_{element}` format
5. **Output area scroll** - Use ScrollViewReader with `.id()` and `.onChange()` for auto-scroll
6. **Modal closure** - Use `@Environment(\.dismiss)` to close sheet, not manual state
7. **Batch processing** - Check `isRunning` flag in loop to allow stopping mid-batch
8. **Custom port parsing** - Support both ranges ("1-1024") and lists ("22,80,443")
9. **Partial success** - Some commands (traceroute) exit non-zero on partial success - check results before showing error
10. **Frame sizing** - Use `.frame(minWidth: 500, minHeight: 400)` for consistent resizable tools

### Performance Tips

- **Lazy rendering**: Use LazyVStack for large result lists (port scan results, hop lists)
- **Limit output lines**: Store recent lines only (first 1000), not unlimited history
- **Stream immediately**: Append to output as lines arrive, don't batch updates
- **Batch scanning**: Use `withTaskGroup()` with batch size (50 ports at a time) to avoid flooding
- **Cancel promptly**: Stop button should cancel service immediately, not wait for cleanup

<!-- MANUAL: Add tool-specific patterns or gotchas discovered -->
