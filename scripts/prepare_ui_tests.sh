#!/bin/bash

# prepare_ui_tests.sh
# Script to prepare the system for reliable UI testing by clearing authentication states

echo "Preparing system for UI tests..."

# Kill any running authentication processes
sudo pkill -f "authenticationservice" 2>/dev/null || true
sudo pkill -f "LocalAuthentication" 2>/dev/null || true  
sudo pkill -f "SecurityAgent" 2>/dev/null || true

# Clear keychain access prompts
security list-keychains -s login.keychain 2>/dev/null || true

# Wait for any ongoing authentication to complete
echo "Waiting for system authentication to stabilize..."
sleep 3

# Clear accessibility permissions that might trigger prompts
echo "Clearing accessibility caches..."
sudo killall "System Events" 2>/dev/null || true
sudo killall "Accessibility" 2>/dev/null || true

# Reset touch ID if configured (might be causing issues)
if command -v bioutil &> /dev/null; then
    echo "Checking Touch ID status..."
    bioutil -r 2>/dev/null || true
fi

echo "System preparation complete."
echo "You may now run UI tests."