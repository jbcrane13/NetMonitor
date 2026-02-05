# UI Test Authentication Fix

## Problem
UI tests fail with `LocalAuthentication Code=-4 "System authentication is running."` error.

## Root Cause
The macOS LocalAuthentication framework detects an ongoing authentication process and blocks the UI test framework from initializing.

## Solutions Applied

### 1. App-Level Fixes ✅
- Enhanced UI testing detection in `NetMonitorApp.swift`
- Disabled notification authorization requests during UI tests
- Added startup delays to avoid race conditions
- Implemented comprehensive environment variable detection

### 2. Test Configuration ✅
- Updated `BaseUITests.swift` with retry logic
- Added comprehensive launch arguments and environment variables
- Implemented multi-attempt launch strategy

### 3. System-Level Scripts ✅
- `scripts/fix_ui_test_auth.sh` - Resets authentication state
- `scripts/run_ui_tests.sh` - Wrapper with retry logic
- `scripts/prepare_ui_tests.sh` - System preparation

## Manual Workaround (When Needed)

If automated scripts don't resolve the issue, try these manual steps:

### Option 1: Disable Touch ID (Temporary)
```bash
# Disable Touch ID for the session
sudo bioutil -d
```

### Option 2: Reset Authentication State
```bash
# Kill authentication processes
sudo pkill -f "coreautha"
sudo pkill -f "coreauthd"
sudo pkill -f "LocalAuthentication"

# Reset keychain cache
killall -HUP cfprefsd

# Wait and retry
sleep 5
```

### Option 3: Run Tests Individually
Instead of running the full test suite, run individual tests to avoid the initialization conflict:

```bash
cd ~/Projects/NetMonitor

# Run individual test methods
xcodebuild test -project NetMonitor.xcodeproj -scheme NetMonitor -destination 'platform=macOS' -only-testing:NetMonitorUITests/ToolsUITests/testToolsViewLoads

# Or run tests by class
xcodebuild test -project NetMonitor.xcodeproj -scheme NetMonitor -destination 'platform=macOS' -only-testing:NetMonitorUITests/DashboardUITests
```

## Alternative Test Strategy

### Use Unit Tests + Manual UI Verification
Since the authentication issue is at the system level, consider this hybrid approach:

1. **Unit tests** for business logic (these work reliably)
2. **Manual UI verification** for critical user flows
3. **Automated screenshots** for UI regression detection

```bash
# Run unit tests (these work fine)
xcodebuild test -project NetMonitor.xcodeproj -scheme NetMonitor -destination 'platform=macOS' -only-testing:NetMonitorTests

# Manual verification script
./scripts/manual_ui_check.sh
```

## Environment Setup for CI/CD

If running in continuous integration, set these environment variables:

```bash
export DISABLE_AUTHENTICATION=1
export UITEST_MODE=1
export CI=true
export DISABLE_NOTIFICATIONS=1
export DISABLE_MONITORING=1
```

## Future Improvements

Consider these long-term solutions:

1. **Snapshot Testing**: Use [swift-snapshot-testing](https://github.com/pointfreeco/swift-snapshot-testing) for UI verification
2. **Component Testing**: Test SwiftUI views in isolation
3. **E2E Alternative**: Use external automation tools that don't conflict with LocalAuthentication

## Status

✅ **App-level authentication handling implemented**  
✅ **Test configuration optimized**  
✅ **System-level workaround scripts created**  
⚠️ **System authentication conflict remains** (macOS-level issue)

## Verification Command

```bash
# Test the fix
cd ~/Projects/NetMonitor
./scripts/run_ui_tests.sh

# If that fails, try manual approach:
./scripts/fix_ui_test_auth.sh
sleep 10
xcodebuild test -project NetMonitor.xcodeproj -scheme NetMonitor -destination 'platform=macOS' -only-testing:NetMonitorUITests/ToolsUITests/testToolsViewLoads
```