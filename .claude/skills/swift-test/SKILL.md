---
name: swift-test
description: "Run targeted Swift tests for NetMonitor. Accepts an optional test class name to run specific tests, or runs all tests."
---

# Swift Test Runner for NetMonitor

Run NetMonitor unit tests using xcodebuild.

## Usage

The user may provide a test class name or test method to run specific tests.

## Behavior

### If a specific test class is provided (e.g., "HTTPMonitorServiceTests"):

```bash
xcodebuild test -project NetMonitor.xcodeproj -scheme NetMonitor \
  -only-testing:NetMonitorTests/<TestClassName> \
  2>&1 | tail -50
```

### If a specific test method is provided (e.g., "HTTPMonitorServiceTests/checkReachableTarget"):

```bash
xcodebuild test -project NetMonitor.xcodeproj -scheme NetMonitor \
  -only-testing:NetMonitorTests/<TestClassName>/<testMethod> \
  2>&1 | tail -50
```

### If no arguments are provided, run all tests:

```bash
xcodebuild -project NetMonitor.xcodeproj -scheme NetMonitor test \
  2>&1 | tail -80
```

## After tests complete

Summarize the results concisely:
- Total tests passed
- Total tests failed (with failure details if any)
- Total duration

If tests fail, show the relevant failure messages and suggest fixes based on the error output.

## Available test classes

Services:
- HTTPMonitorServiceTests
- TCPMonitorServiceTests
- ARPScannerServiceTests
- BonjourDiscoveryServiceTests
- DeviceDiscoveryCoordinatorTests
- MACVendorLookupServiceTests
- CompanionServiceTests
- CompanionMessageHandlerTests
- ShellCommandRunnerTests
- ProcessPingServiceTests
- MonitoringSessionTests
- WakeOnLanServiceTests
- MenuBarControllerTests
- ICMPMonitorServiceTests

Models:
- EnumsTests
- SectionTests

Protocol:
- CompanionMessageTests
