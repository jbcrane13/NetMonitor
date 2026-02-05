#!/bin/bash

# run_ui_tests.sh
# Wrapper script to run UI tests with proper authentication handling

set -e  # Exit on any error

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PROJECT_DIR"

echo "🧪 NetMonitor UI Test Runner"
echo "=============================="

# Prepare system for testing
echo "📋 Preparing system for UI tests..."
./scripts/prepare_ui_tests.sh

# Set environment variables to prevent authentication prompts
export DISABLE_AUTHENTICATION=1
export UITEST_MODE=1
export XCODE_RUNNING_FOR_PREVIEWS=0

# Function to run tests with retry logic
run_tests_with_retry() {
    local max_attempts=3
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        echo "🔄 Attempt $attempt of $max_attempts"
        
        # Add a delay between attempts to let system settle
        if [ $attempt -gt 1 ]; then
            echo "⏱️  Waiting 10 seconds for system to stabilize..."
            sleep 10
        fi
        
        # Run the test
        echo "🚀 Running UI tests..."
        if xcodebuild test \
            -project NetMonitor.xcodeproj \
            -scheme NetMonitor \
            -destination 'platform=macOS' \
            -only-testing:NetMonitorUITests \
            2>&1 | tee test_output.log; then
            echo "✅ Tests completed successfully!"
            return 0
        else
            echo "❌ Attempt $attempt failed"
            
            # Check if it's the authentication error
            if grep -q "LocalAuthentication Code=-4" test_output.log; then
                echo "🔐 Authentication error detected. Retrying after system cleanup..."
                
                # Additional cleanup for authentication issues
                sudo pkill -f "CoreServicesUIAgent" 2>/dev/null || true
                sudo pkill -f "UserNotificationCenter" 2>/dev/null || true
                sleep 5
                
                attempt=$((attempt + 1))
            else
                echo "💥 Non-authentication error detected. Check logs for details."
                cat test_output.log
                return 1
            fi
        fi
    done
    
    echo "💀 All attempts failed. UI tests could not complete."
    return 1
}

# Run tests with retry logic
run_tests_with_retry

# Cleanup
rm -f test_output.log

echo "🏁 UI test run completed."