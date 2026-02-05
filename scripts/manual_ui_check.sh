#!/bin/bash

# manual_ui_check.sh
# Manual UI verification script as alternative to automated UI tests

echo "🖥️  NetMonitor Manual UI Verification"
echo "====================================="
echo ""
echo "This script will guide you through manual UI verification"
echo "since automated UI tests are blocked by system authentication."
echo ""

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PROJECT_DIR"

# Build and run the app for manual testing
echo "🔨 Building NetMonitor app..."
xcodebuild build -project NetMonitor.xcodeproj -scheme NetMonitor -destination 'platform=macOS' -configuration Debug

if [ $? -eq 0 ]; then
    echo "✅ Build successful!"
    echo ""
    echo "🚀 Launching NetMonitor for manual verification..."
    
    # Launch the app
    open "build/Debug/NetMonitor.app" 2>/dev/null || \
    open "/Users/blake/Library/Developer/Xcode/DerivedData/NetMonitor-*/Build/Products/Debug/NetMonitor.app" 2>/dev/null || \
    echo "⚠️  Could not auto-launch app. Please build and run from Xcode."
    
    echo ""
    echo "📋 Manual Verification Checklist:"
    echo ""
    echo "Core Functionality:"
    echo "□ App launches without crashes"
    echo "□ Dashboard view loads and displays data"
    echo "□ Sidebar navigation works (Dashboard, Targets, Devices, Tools)"
    echo "□ Settings view opens and closes properly"
    echo ""
    echo "Tools View:"
    echo "□ Tools view displays all 8 tool cards"
    echo "□ Ping tool opens and has input field and Run button"
    echo "□ Traceroute tool opens properly"
    echo "□ Port Scanner tool opens properly"
    echo "□ DNS Lookup tool opens properly"
    echo "□ WHOIS tool opens properly"
    echo "□ Speed Test tool opens properly"
    echo "□ Bonjour Browser tool opens properly"
    echo "□ Wake on LAN tool opens with MAC address field"
    echo ""
    echo "Devices & Targets:"
    echo "□ Devices view shows discovered devices (may be empty)"
    echo "□ Targets view shows monitoring targets"
    echo "□ Add target functionality works"
    echo ""
    echo "💡 Tips:"
    echo "   - Use --uitesting launch argument if needed"
    echo "   - Check console output for any errors"
    echo "   - Test with minimal system interference"
    echo ""
    echo "✅ Manual verification complete when all items checked."
    
else
    echo "❌ Build failed. Check build errors above."
    exit 1
fi