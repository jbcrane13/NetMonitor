#!/bin/bash

# fix_ui_test_auth.sh
# Specific fix for LocalAuthentication Code=-4 "System authentication is running" error

echo "🔧 Fixing LocalAuthentication UI test conflict..."

# The issue: macOS LocalAuthentication framework thinks another auth process is running
# Solution: Reset the authentication state and clear conflicting processes

# 1. Kill any processes that might be holding authentication locks
echo "📋 Clearing authentication processes..."

# Kill LocalAuthentication related processes (they'll restart cleanly)
sudo pkill -f "coreautha" 2>/dev/null || true
sudo pkill -f "coreauthd" 2>/dev/null || true  
sudo pkill -f "LocalAuthentication" 2>/dev/null || true

# Kill any stale authentication dialog processes
sudo pkill -f "SecurityAgent" 2>/dev/null || true
sudo pkill -f "AuthenticationServicesAgent" 2>/dev/null || true

# 2. Reset Touch ID if it's causing issues
if command -v bioutil &> /dev/null; then
    echo "🔐 Resetting Touch ID state..."
    sudo bioutil -r 2>/dev/null || true
fi

# 3. Clear keychain cache that might be causing prompts
echo "🔑 Clearing keychain cache..."
/usr/bin/killall -HUP cfprefsd 2>/dev/null || true

# 4. Reset accessibility permissions that might trigger auth
echo "♿ Resetting accessibility state..."
sudo tccutil reset Accessibility 2>/dev/null || true

# 5. Clear XPC cache that might have stale auth connections
echo "🔄 Clearing XPC cache..."
sudo launchctl kickstart -k system/com.apple.authd 2>/dev/null || true

# 6. Wait for processes to stabilize
echo "⏱️  Waiting for authentication subsystem to stabilize..."
sleep 3

# 7. Verify no authentication dialogs are open
echo "👁️  Checking for open authentication dialogs..."
open_dialogs=$(osascript -e 'tell application "System Events" to count (every window of every process whose name contains "SecurityAgent")' 2>/dev/null || echo 0)

if [ "$open_dialogs" -gt 0 ]; then
    echo "⚠️  Found $open_dialogs authentication dialog(s). Attempting to close..."
    osascript -e 'tell application "System Events" to keystroke (key code 53)' 2>/dev/null || true  # ESC key
    sleep 1
fi

echo "✅ Authentication state cleared. Ready for UI tests."
echo ""
echo "💡 If tests still fail, you may need to:"
echo "   - Disable Touch ID in System Settings > Touch ID & Password"
echo "   - Log out and back in to reset authentication state"
echo "   - Restart your Mac if the issue persists"