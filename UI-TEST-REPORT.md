# NetMonitor UI Test Report

Date: 2026-02-05
Scope: NetMonitorUITests (Dashboard, Tools, Settings, Monitoring, Export)

## Summary
- Added broader UI coverage for Dashboard refresh actions, Monitoring duration, Tools execution flows, and Settings controls.
- Updated UI screen object identifiers to match production accessibility identifiers for Tool views.
- UI tests could not be executed in this environment due to sandboxed Xcode cache and CoreSimulator access restrictions.

## Test Updates
- Dashboard: ISP card presence + gateway/ISP refresh coverage.
- Monitoring: duration timer visibility while monitoring.
- Tools: execute flows for Traceroute, Port Scanner, DNS, WHOIS, Speed Test, Bonjour refresh, Wake-on-LAN field validation.
- Settings: controls coverage across General, Monitoring, Notifications, Network, Appearance, Companion + history retention picker.
- Export: cancel export dialog returns to Data settings.

## Accessibility Identifier Alignment
- Port Scanner: updated to `portscan_*` identifiers.
- DNS: updated to `dns_textfield_hostname`.
- Wake-on-LAN: updated to `wol_button_send`.
- Added additional tool control identifiers (clear buttons, pickers) to UI screen models for test coverage.

## Test Execution
Command:
```
xcodebuild test -scheme NetMonitor -destination 'platform=macOS' -only-testing:NetMonitorUITests
```

Result: Failed to start due to environment restrictions.

Key errors:
- CoreSimulatorService connection invalid / simulator services unavailable.
- Operation not permitted errors for module cache and SwiftPM manifest cache.
- Unable to resolve package dependencies due to cache access.

## Next Steps
1. Re-run the command on a developer machine with full Xcode/Simulator access.
2. If failures reproduce, capture the `ResultBundle_*.xcresult` referenced in logs.
3. Confirm accessibility identifiers exist for any UI elements that fail to resolve in tools/settings views.
