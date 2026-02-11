# NetMonitor App Store Screenshot Guide

## Status Report

### ✅ Completed
1. Built macOS NetMonitor Release version successfully
   - Location: `/Users/blake/Library/Developer/Xcode/DerivedData/NetMonitor-edgafaekllxklwdfccpobkksmuvt/Build/Products/Release/NetMonitor.app`
   - App is running and ready for screenshots

2. Created iOS Simulators
   - iPhone 16 Pro Max (6.9"): `B4BD6AED-C354-443D-BC10-026854FD64BA`
   - iPhone 16 Pro (6.3"): `BE0ED125-81C1-4FED-ADA5-98221B140C40`
   - iOS 26.2 runtime

3. iOS app build started (in progress)

### ❌ Blocked Issues
1. **macOS Screen Capture Permission Issue**
   - `screencapture` command fails with "could not create image from display"
   - TCC (Transparency, Consent, and Control) is blocking screen capture
   - Node screen_record action is blocked by gateway policy

## Manual Screenshot Instructions

### macOS NetMonitor

The app is already running. You need to take screenshots manually:

#### Option 1: Using Cmd+Shift+4 (Recommended)
1. Press `Cmd+Shift+4`, then press `Space`
2. Click on the NetMonitor window to capture it
3. Screenshots will be saved to Desktop
4. Move them to `/Users/blake/Projects/NetMonitor/Screenshots/AppStore/`

#### Option 2: Use the helper script below

Required Screenshots:
- ✅ Dashboard view (main screen)
- ✅ Targets view  
- ✅ Devices view
- ✅ Tools view
- ✅ Settings window
- ✅ Menu bar popover (click the menu bar icon)

### iOS NetMonitor

#### Wait for build to complete, then:

```bash
# Check if build is done
ps aux | grep xcodebuild

# Once done, install and launch on simulators
cd /Users/blake/Projects/NetMonitor-ios/Netmonitor

# For iPhone 16 Pro Max
xcrun simctl install B4BD6AED-C354-443D-BC10-026854FD64BA ./build/Build/Products/Release-iphonesimulator/Netmonitor.app
xcrun simctl launch B4BD6AED-C354-443D-BC10-026854FD64BA com.blakemiller.netmonitor

# Wait 3 seconds for app to load, then take screenshots
sleep 3
xcrun simctl io B4BD6AED-C354-443D-BC10-026854FD64BA screenshot /Users/blake/Projects/NetMonitor-ios/Screenshots/AppStore/iPhone-16-Pro-Max-01-dashboard.png

# Navigate through app and take more screenshots as needed

# For iPhone 16 Pro
xcrun simctl install BE0ED125-81C1-4FED-ADA5-98221B140C40 ./build/Build/Products/Release-iphonesimulator/Netmonitor.app  
xcrun simctl launch BE0ED125-81C1-4FED-ADA5-98221B140C40 com.blakemiller.netmonitor
sleep 3
xcrun simctl io BE0ED125-81C1-4FED-ADA5-98221B140C40 screenshot /Users/blake/Projects/NetMonitor-ios/Screenshots/AppStore/iPhone-16-Pro-01-dashboard.png
```

## App Store Screenshot Requirements

### macOS
- Recommended sizes: 1280x800, 1440x900, 2560x1600, or 2880x1800
- Format: PNG or JPEG
- Min 6 screenshots required

### iOS
- iPhone 16 Pro Max (6.9"): 1320 x 2868 pixels
- iPhone 16 Pro (6.3"): 1206 x 2622 pixels
- Format: PNG or JPEG
- Max 10 screenshots per device size

## Naming Convention

### macOS:
- `01-dashboard.png`
- `02-targets.png`
- `03-devices.png`
- `04-tools.png`
- `05-settings.png`
- `06-menubar-popover.png`

### iOS:
- `iPhone-16-Pro-Max-01-dashboard.png`
- `iPhone-16-Pro-Max-02-targets.png`
- etc.

## Next Steps

1. Wait for iOS build to complete
2. Follow instructions above to capture screenshots
3. Review screenshots for quality and clarity
4. Ensure no debug overlays or test data visible
5. Verify screenshots meet App Store size requirements
