# NetMonitor macOS v1.0 - Release Readiness Plan

**Created:** 2026-01-28
**Status:** DRAFT - Iteration 2
**Goal:** Take NetMonitor from current Phase 4 completion to feature-complete, release-quality v1.0
**Target Platform:** macOS 15.0+ (Sequoia) - NOTE: Deviates from PRD 14.0 requirement per project implementation decision

---

## Executive Summary

NetMonitor has completed Phases 1-4 with solid foundational architecture. However, several PRD features remain unimplemented, and the application requires polish, testing, and release preparation before App Store submission.

**Current State:**
- Core monitoring (HTTP/HTTPS/ICMP/TCP) - COMPLETE
- Device discovery (ARP + Bonjour) - COMPLETE
- 7 Network tools - COMPLETE (including Speed Test)
- Settings UI - COMPLETE
- Menu bar integration - COMPLETE
- Companion communication - COMPLETE
- Device "Add to Targets" action - COMPLETE (DeviceDetailView.swift lines 216-219, 274-286)

**Missing for v1.0:**
- Dashboard information cards (Connection, Gateway, ISP)
- Statistics aggregation (2min/10min/all-time)
- Default targets on first launch
- Network Map visualization
- Notification system (actual delivery)
- Upload speed test
- Wake-on-LAN standalone tool view (PRD 3.4.7)
- App Icon assets
- Production-level test coverage
- Release documentation

---

## Bug Classification System

All bugs are classified using this priority system:

| Priority | Definition | Response Time | Release Block? |
|----------|------------|---------------|----------------|
| **P0 (Critical)** | App crashes, data loss, security vulnerability | Immediate | YES |
| **P1 (High)** | Core feature broken, significant UX degradation, no workaround | < 24 hours | YES |
| **P2 (Medium)** | Feature partially broken, workaround exists, minor UX issues | < 1 week | NO (defer to v1.1) |
| **P3 (Low)** | Cosmetic issues, minor inconveniences, polish items | Next sprint | NO |

**Release Gate:** Zero P0/P1 bugs. P2 bugs documented for v1.1.

---

## Performance Metrics

| Metric | Target | Measurement Method |
|--------|--------|-------------------|
| App launch time | < 2 seconds | Instruments Time Profiler (cold start) |
| Dashboard refresh | < 100ms | Console timestamp logging |
| Memory usage (idle) | < 100MB | Instruments Allocations |
| Memory usage (active) | < 150MB | Instruments Allocations under load |
| CPU usage (monitoring) | < 5% | Activity Monitor average over 5 min |
| Device scan (/24 subnet) | < 30 seconds | Timer from scan start to completion |
| Target check latency overhead | < 50ms | Measured latency vs actual RTT |

**Verification:** All metrics validated via Instruments profiling before release.

---

## Part 1: Gap Analysis (PRD vs. Implementation)

### 1.1 Dashboard (Section 3.1)

| PRD Feature | Status | Notes |
|-------------|--------|-------|
| Session start time | DONE | Displayed in header |
| Running duration timer | PARTIAL | Shows start time, no live HH:MM:SS |
| Start/Stop controls | DONE | Button works correctly |
| Connection Details Card | NOT IMPLEMENTED | Need SSID, signal, channel, link speed |
| Gateway Information Card | NOT IMPLEMENTED | Need gateway IP, MAC, vendor, latency |
| ISP Information Card | NOT IMPLEMENTED | Need public IP, ISP, ASN, geolocation |
| Quick Stats Bar | PARTIAL | Online/offline count in popover only |

### 1.2 Target Monitoring (Section 3.2)

| PRD Feature | Status | Notes |
|-------------|--------|-------|
| Add/Edit/Remove targets | DONE | TargetsView, AddTargetSheet |
| Target properties (all) | DONE | Name, host, port, protocol, interval, timeout |
| Default targets | NOT IMPLEMENTED | Should seed Cloudflare, Google, Quad9, etc. |
| Target statistics table | PARTIAL | Basic stats, missing jitter/packet loss |
| Latency stats (2min/10min/all) | NOT IMPLEMENTED | Only shows overall avg/min/max |
| Jitter stats | NOT IMPLEMENTED | Not calculated |
| Packet loss % | NOT IMPLEMENTED | Not tracked per-window |
| Target detail view graphs | PARTIAL | Basic chart exists, needs enhancement |
| Export statistics | NOT IMPLEMENTED | CSV export stub exists |

### 1.3 Local Device Discovery (Section 3.3)

| PRD Feature | Status | Notes |
|-------------|--------|-------|
| ARP scan | DONE | ARPScannerService |
| Bonjour/mDNS | DONE | BonjourDiscoveryService |
| NetBIOS resolution | NOT IMPLEMENTED | Not required for v1.0 |
| Manual scan trigger | DONE | Button in DevicesView |
| Device info (all fields) | DONE | IP, MAC, hostname, vendor, type, etc. |
| Network Map visualization | NOT IMPLEMENTED | Radial topology view |
| Device actions (all) | DONE | Ping, Port Scan, Wake, Add to Targets all implemented |

### 1.4 Network Tools (Section 3.4)

| PRD Feature | Status | Notes |
|-------------|--------|-------|
| Ping Tool | DONE | PingToolView with streaming |
| Traceroute Tool | DONE | TracerouteToolView |
| Port Scanner | DONE | PortScannerToolView |
| DNS Lookup | DONE | DNSLookupToolView |
| WHOIS Lookup | DONE | WHOISToolView |
| Speed Test (Download) | DONE | SpeedTestToolView |
| Speed Test (Upload) | NOT IMPLEMENTED | Only download implemented |
| Wake on LAN | PARTIAL | WakeOnLanService + DeviceDetailView action exist; standalone WakeOnLanToolView missing per PRD 3.4.7 |
| Bonjour Browser | DONE | BonjourBrowserToolView |

### 1.5 Settings (Section 3.5)

| PRD Feature | Status | Notes |
|-------------|--------|-------|
| General settings | DONE | Launch at login, menu bar, dock |
| Notifications | UI ONLY | Settings exist but no actual notifications sent |
| Network settings | DONE | Basic settings |
| Companion settings | DONE | Service toggle, port config |
| Data management | DONE | Export, clear data, retention |

### 1.6 Menu Bar Integration (Section 3.6)

| PRD Feature | Status | Notes |
|-------------|--------|-------|
| Mini status display | DONE | MenuBarPopoverView |
| Quick stats | DONE | Online/offline/latency |
| Start/Stop monitoring | DONE | Button in popover |
| Recent alerts | NOT IMPLEMENTED | No alert history |
| Open main window | DONE | Button works |

---

## Part 2: Missing Features (Prioritized)

### Priority 1: Critical for v1.0 (Must Have)

#### 2.1 Dashboard Information Cards
**Effort:** 3-4 days

Create three new dashboard cards:

##### 2.1.1 ConnectionInfoCard + NetworkInfoService

**Technical Specification:**

```swift
actor NetworkInfoService {
    struct ConnectionInfo: Sendable {
        let connectionType: ConnectionType  // wifi, ethernet, cellular, unknown
        let ssid: String?                   // WiFi network name
        let bssid: String?                  // Access point MAC
        let signalStrength: Int?            // dBm (-30 to -90)
        let channel: Int?                   // WiFi channel
        let linkSpeed: Int?                 // Mbps
        let interfaceName: String           // en0, en1, etc.
    }

    func getCurrentConnection() async throws -> ConnectionInfo
}
```

**WiFi SSID Access (macOS 14+):**
- Use `CWWiFiClient.shared().interface()` from CoreWLAN framework
- **IMPORTANT:** SSID access requires Location Services permission on macOS 14+
- Reference: [Apple Developer Documentation - CWInterface](https://developer.apple.com/documentation/corewlan/cwinterface)
- Alternative: Use `networksetup -getairportnetwork en0` via ShellCommandRunner (no permission needed, but less reliable)

**Implementation approach:**
1. Attempt CoreWLAN first (requires adding Location permission to Info.plist)
2. Fallback to shell command if permission denied
3. Gracefully degrade UI if neither works

**Acceptance Criteria:**
- [ ] NetworkInfoService actor compiles with no warnings
- [ ] ConnectionInfoCard displays on Dashboard
- [ ] WiFi SSID shown when connected to WiFi (with permission)
- [ ] Graceful "Unknown Network" displayed when permission denied
- [ ] Ethernet connection detected and displayed correctly
- [ ] Signal strength updates every 5 seconds
- [ ] Unit tests cover both WiFi and Ethernet scenarios

##### 2.1.2 GatewayInfoCard

**Implementation:**
- Use `netstat -nr | grep default` to get gateway IP
- Use existing ARPScannerService to resolve gateway MAC
- Use existing MACVendorLookupService for vendor
- Add single ping for gateway latency via ProcessPingService

**Acceptance Criteria:**
- [ ] Gateway IP correctly detected
- [ ] Gateway MAC resolved via ARP
- [ ] Vendor name displayed (or "Unknown" if not in database)
- [ ] Latency ping executes and displays result
- [ ] Refresh button triggers new lookup
- [ ] Card gracefully handles "no gateway found"

##### 2.1.3 ISPInfoCard + ISPLookupService

**Technical Specification:**

```swift
actor ISPLookupService {
    struct ISPInfo: Sendable, Codable {
        let publicIP: String
        let isp: String
        let organization: String?
        let asn: String?
        let city: String?
        let region: String?
        let country: String?
        let timezone: String?
    }

    func lookup() async throws -> ISPInfo
}
```

**API Details:**
- **Primary:** `https://ipapi.co/json/` (free tier: 1000 requests/day, no key required)
- **Fallback:** `https://ip-api.com/json/` (free tier: 45 requests/minute, no key)
- **Response format (ipapi.co):**
```json
{
  "ip": "203.0.113.1",
  "org": "ACME Inc",
  "asn": "AS12345",
  "city": "San Francisco",
  "region": "California",
  "country_name": "United States",
  "timezone": "America/Los_Angeles"
}
```

**Rate Limiting:**
- Cache results for 5 minutes (UserDefaults with timestamp)
- Show cached data immediately, refresh in background
- Display "Rate limited" message if API returns 429

**Privacy Disclosure:**
- Add to Settings > Privacy section: "ISP information is retrieved from ipapi.co. Your public IP address is sent to this service."
- Add Info.plist privacy description if required

**Acceptance Criteria:**
- [ ] ISPLookupService fetches data from ipapi.co
- [ ] Fallback to ip-api.com on primary failure
- [ ] Results cached for 5 minutes
- [ ] Public IP displayed correctly
- [ ] ISP name and ASN displayed
- [ ] Location (city, country) displayed
- [ ] Refresh button respects rate limits
- [ ] Offline state shows "Unable to determine"
- [ ] Privacy disclosure added to Settings

#### 2.2 Default Targets on First Launch
**Effort:** 1 day

**Technical Specification:**

```swift
struct DefaultTargetsProvider {
    static let userDefaultsKey = "netmonitor.hasSeededDefaultTargets"

    static let defaultTargets: [(name: String, host: String, protocol: TargetProtocol, interval: Int)] = [
        ("Gateway", "GATEWAY_IP", .icmp, 30),      // Special: detect at runtime
        ("Cloudflare DNS", "1.1.1.1", .icmp, 30),
        ("Google DNS", "8.8.8.8", .icmp, 30),
        ("Quad9 DNS", "9.9.9.9", .icmp, 30),
        ("Google", "google.com", .https, 60),
        ("Apple", "apple.com", .https, 60)
    ]

    static func seedIfNeeded(modelContext: ModelContext) async
}
```

**Gateway Detection:**
- Use `netstat -nr | grep default` output
- Parse first IPv4 gateway address
- If detection fails, skip gateway target (don't seed invalid IP)

**Seeding Logic:**
1. Check `UserDefaults.standard.bool(forKey: userDefaultsKey)`
2. If false AND SwiftData has 0 NetworkTarget records:
   - Detect gateway IP
   - Insert all default targets
   - Set UserDefaults flag to true
3. If true OR targets exist: do nothing

**Acceptance Criteria:**
- [ ] First launch seeds 6 default targets
- [ ] Gateway target uses actual gateway IP (or skipped if undetectable)
- [ ] Subsequent launches do not re-seed
- [ ] Manual delete of all targets does not trigger re-seed (flag persists)
- [ ] Targets are enabled by default
- [ ] Unit test verifies seeding logic with mock ModelContext

#### 2.3 Notification System Implementation
**Effort:** 2 days

**Acceptance Criteria:**
- [ ] NotificationService requests permission on first launch
- [ ] Permission denial gracefully handled (notifications disabled in UI)
- [ ] "Target offline" notification fires within 5 seconds of detection
- [ ] "Target recovered" notification fires when target comes back online
- [ ] "High latency" notification fires when threshold exceeded
- [ ] Notifications respect user settings (can be disabled per type)
- [ ] Notification click opens main window
- [ ] Unit tests verify notification content formatting

#### 2.4 App Icon
**Effort:** 1 day

**Acceptance Criteria:**
- [ ] AppIcon.appiconset contains all required sizes (16, 32, 64, 128, 256, 512 @1x and @2x)
- [ ] Icon visible in Dock when running
- [ ] Icon visible in Finder
- [ ] Icon visible in App Switcher (Cmd+Tab)
- [ ] Menu bar icon distinct from app icon
- [ ] No placeholder or default macOS icon shown

### Priority 2: Important for Quality (Should Have)

#### 2.5 Statistics Aggregation
**Effort:** 2-3 days

**Acceptance Criteria:**
- [ ] 2-minute rolling average displayed per target
- [ ] 10-minute rolling average displayed per target
- [ ] All-time statistics displayed per target
- [ ] Jitter (latency variance) calculated and displayed
- [ ] Packet loss percentage calculated for each time window
- [ ] Statistics update in real-time during monitoring
- [ ] Statistics persist across app restarts
- [ ] Unit tests verify calculation accuracy

#### 2.6 Wake-on-LAN Tool View (PRD 3.4.7)
**Effort:** 2-3 hours

**Clarification:** WakeOnLanService exists and is integrated into DeviceDetailView for device actions (PRD 3.3.5). However, PRD Section 3.4.7 requires a **standalone WakeOnLanToolView** in the Tools section.

**PRD 3.4.7 Requirements:**
- Device selector (dropdown of known devices with MAC addresses)
- Manual MAC address input field
- Broadcast address configuration (default: 255.255.255.255)
- Send magic packet button
- Status feedback (sent successfully, error messages)

**Implementation:**
- Create `WakeOnLanToolView.swift` in `NetMonitor/Views/Tools/`
- Add `wakeOnLan` case to `NetworkTool` enum
- Add to `ToolsView` grid
- Reuse existing `WakeOnLanService` for packet sending
- Reuse existing `WakeOnLanAction` patterns

**Acceptance Criteria:**
- [ ] WakeOnLanToolView appears in Tools section
- [ ] Dropdown lists all devices with known MAC addresses
- [ ] Manual MAC input accepts valid formats (AA:BB:CC:DD:EE:FF, AA-BB-CC-DD-EE-FF, AABBCCDDEEFF)
- [ ] Invalid MAC shows validation error
- [ ] Broadcast address field with sensible default
- [ ] "Send" button triggers magic packet
- [ ] Success message shown on send
- [ ] Error message shown on failure
- [ ] Accessible via keyboard navigation

#### 2.7 Live Running Duration Timer
**Effort:** 0.5 day

**Acceptance Criteria:**
- [ ] Duration displayed as HH:MM:SS format
- [ ] Updates every second while monitoring active
- [ ] Pauses when monitoring paused
- [ ] Resets to 00:00:00 when monitoring stopped
- [ ] Uses SwiftUI TimelineView for efficient updates

### Priority 3: Nice to Have (Could Defer to v1.1)

#### 2.8 Network Map Visualization
**Effort:** 5-7 days
**Recommendation:** Defer to v1.1

#### 2.9 Upload Speed Test
**Effort:** 2 days
**Recommendation:** Defer to v1.1

#### 2.10 CloudKit Sync
**Effort:** 5+ days
**Recommendation:** Defer to v1.1

---

## Part 3: Polish & UX Improvements

### 3.1 Dashboard Refinements
- Add gradient background per design system
- Implement glass-effect cards consistently
- Add Quick Stats Bar below header
- Improve empty state messaging

### 3.2 Target List Enhancements
- Add sorting options (by name, status, latency)
- Add filtering (online/offline, by protocol)
- Show inline status indicator
- Add swipe actions for quick enable/disable

### 3.3 Menu Bar Improvements
- Show target names instead of UUID prefix
- Add "Recent Alerts" section
- Improve icon states (add warning state)
- Add keyboard shortcut to toggle

### 3.4 Settings Polish
- Add "Reset to Defaults" button
- Implement "Show in Dock" toggle functionality
- Add "Check for Updates" (if not App Store)
- Link to documentation/support

### 3.5 Tool Views Consistency
- Standardize header/footer layout
- Add keyboard shortcuts for common actions
- Improve error message presentation
- Add loading states consistently

### 3.6 Accessibility
- Verify VoiceOver works for all views
- Add accessibility labels to all icons
- Test keyboard navigation
- Ensure proper contrast ratios

---

## Part 4: Testing Completeness

### 4.1 Current Test Coverage

| Test File | Lines | Coverage |
|-----------|-------|----------|
| ARPScannerServiceTests | 68 | Basic |
| BonjourDiscoveryServiceTests | 144 | Good |
| CompanionServiceTests | 35 | Minimal |
| DeviceDiscoveryCoordinatorTests | 194 | Good |
| DeviceDiscoveryServiceTests | 30 | Minimal |
| HTTPMonitorServiceTests | 64 | Basic |
| MACVendorLookupServiceTests | 86 | Good |
| MonitoringSessionTests | 57 | Basic |
| NetworkMonitorServiceTests | 32 | Minimal |
| ProcessPingServiceTests | 97 | Good |
| ShellCommandRunnerTests | 77 | Good |
| CompanionMessageTests | ~50 | Basic |

**Total:** ~884 lines of test code

### 4.2 Missing Tests (Priority Order)

1. **TCPMonitorService** - No tests exist
2. **ICMPMonitorService** - No tests exist
3. **WakeOnLanService** - No tests exist
4. **CompanionMessageHandler** - Minimal coverage
5. **MenuBarController** - No tests exist
6. **New services** - NetworkInfoService, ISPLookupService, NotificationService

### 4.3 Integration Tests Needed

- Full monitoring cycle (start -> check -> persist -> stop)
- Device discovery with merge logic
- Companion protocol end-to-end
- Settings persistence and application

### 4.4 UI Tests Needed

- Navigation through all sections
- Target CRUD operations
- Device scan workflow
- Tool execution flows
- Settings modification

### 4.5 Test Coverage Target

- **Unit tests:** 80%+ line coverage for Services
- **Integration tests:** All major workflows
- **UI tests:** Happy path for all sections

---

## Part 5: Documentation

### 5.1 User-Facing Documentation

- [ ] README.md - Project overview, screenshots, requirements
- [ ] CHANGELOG.md - Version history
- [ ] User Guide - How to use each feature
- [ ] FAQ - Common questions and troubleshooting

### 5.2 Technical Documentation

- [x] CLAUDE.md - AI assistant guidance (exists, needs update)
- [x] AGENTS.md - Architecture overview (exists)
- [x] Companion-Protocol-API.md - API reference (exists)
- [ ] CONTRIBUTING.md - How to contribute
- [ ] ARCHITECTURE.md - System design deep-dive

### 5.3 App Store Metadata

- [ ] App description (short and long)
- [ ] Keywords
- [ ] Screenshots (all required sizes)
- [ ] Privacy policy URL
- [ ] Support URL
- [ ] Marketing URL (optional)

---

## Part 6: Release Checklist

### 6.1 Pre-Release Technical

- [ ] All Priority 1 features implemented
- [ ] Zero P0/P1 bugs (per classification system above)
- [ ] Build succeeds with zero warnings
- [ ] All tests pass
- [ ] Performance metrics verified via Instruments
- [ ] Memory leaks addressed (Instruments Leaks profile clean)
- [ ] App reviewed for data privacy

### 6.2 App Assets

- [ ] App icon (all sizes with actual graphics)
- [ ] Menu bar icon variants
- [ ] Accent color finalized
- [ ] Launch screen (if needed)

### 6.3 App Store Requirements

- [ ] Bundle identifier registered
- [ ] App Store Connect entry created
- [ ] Screenshots prepared (minimum 3)
- [ ] App preview video (optional)
- [ ] Privacy nutrition labels completed
- [ ] Age rating determined
- [ ] Pricing decided
- [ ] Categories selected

### 6.4 Entitlements & Permissions

- [x] Network client entitlement
- [x] Network server entitlement
- [x] Local network usage description
- [ ] Notification permission request
- [ ] Location permission (for WiFi SSID) - required for CoreWLAN on macOS 14+

### 6.5 Final Verification

- [ ] Test on macOS 15.0 (minimum supported)
- [ ] Test on latest macOS (currently 15.x)
- [ ] Test clean install experience
- [ ] Test upgrade from development version
- [ ] Verify app notarization works
- [ ] Verify companion app communication

---

## Part 7: Implementation Order

### Sprint 1: Critical Features (Week 1-2)
1. App Icon design and implementation
2. Default targets on first launch
3. Notification system implementation
4. Dashboard Connection Info Card
5. Dashboard Gateway Info Card

### Sprint 2: Dashboard & Stats (Week 2-3)
6. Dashboard ISP Info Card
7. Live running duration timer
8. Statistics aggregation (windowed)
9. Quick Stats Bar on dashboard

### Sprint 3: Tools & Actions (Week 3)
10. Wake-on-LAN tool view
11. Upload speed test (if time permits)

### Sprint 4: Testing & Polish (Week 4)
12. Missing unit tests
13. UI test suite
14. UI polish items
15. Accessibility audit

### Sprint 5: Release Prep (Week 5)
16. Documentation
17. App Store metadata
18. Screenshots
19. Final testing and bug fixes
20. Submission

---

## Appendix A: File Changes Summary

### New Files Required
```
NetMonitor/Services/
  NetworkInfoService.swift       # WiFi/connection info
  ISPLookupService.swift        # Public IP lookup
  NotificationService.swift      # UNUserNotificationCenter wrapper
  DefaultTargetsProvider.swift   # First-launch seeding

NetMonitor/Views/
  ConnectionInfoCard.swift       # Dashboard card
  GatewayInfoCard.swift          # Dashboard card
  ISPInfoCard.swift              # Dashboard card
  QuickStatsBar.swift            # Dashboard component

NetMonitor/Views/Tools/
  WakeOnLanToolView.swift        # WOL tool UI (PRD 3.4.7)

NetMonitorTests/Services/
  TCPMonitorServiceTests.swift
  ICMPMonitorServiceTests.swift
  WakeOnLanServiceTests.swift
  NotificationServiceTests.swift
  NetworkInfoServiceTests.swift
  ISPLookupServiceTests.swift
```

### Files to Modify
```
NetMonitor/Views/DashboardView.swift     # Add cards and stats bar
NetMonitor/Views/ToolsView.swift         # Add WOL tool
NetMonitor/NetMonitorApp.swift           # Initialize new services, call DefaultTargetsProvider
NetMonitor/Services/MonitoringSession.swift # Wire notifications
NetMonitor/Preview Content/PreviewContainer.swift # Add default targets
NetMonitor/Info.plist                    # Add Location permission for SSID
```

---

## Appendix B: Effort Estimates

| Category | Estimated Days |
|----------|----------------|
| Priority 1 Features | 8-10 |
| Priority 2 Features | 3-4 |
| Testing | 4-5 |
| Polish & UX | 3-4 |
| Documentation | 2-3 |
| Release Prep | 2-3 |
| **Total** | **22-29 days** |

---

## Definition of Done

The release is ready when:

1. All Priority 1 features implemented and passing acceptance criteria
2. Priority 2 features complete or consciously deferred to v1.1 with rationale documented
3. Test coverage meets targets (80%+ for services)
4. All UI tests pass
5. Documentation is complete (README, CHANGELOG, User Guide)
6. App Store assets are ready (icon, screenshots, metadata)
7. Zero P0/P1 bugs remain (per classification system)
8. Performance metrics verified:
   - App launch < 2 seconds
   - Memory < 150MB under load
   - CPU < 5% during monitoring
   - Device scan < 30 seconds
9. Accessibility audit passed (VoiceOver, keyboard navigation, contrast)
10. App successfully submitted to App Store Connect

---

**PLAN_READY: .omc/plans/netmonitor-release-readiness.md**
