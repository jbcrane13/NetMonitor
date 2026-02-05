//
//  BaseUITests.swift
//  NetMonitorUITests
//
//  Base class for all UI tests with consistent setup and configuration.
//

import XCTest

/// Base class for UI tests with consistent configuration
class BaseUITests: XCTestCase {
    
    var app: XCUIApplication!
    
    override func setUpWithError() throws {
        continueAfterFailure = false
        
        app = XCUIApplication()
        
        // Configure launch arguments and environment for UI testing
        // This helps avoid authentication prompts and other system interactions
        app.launchArguments = [
            "--uitesting",
            "--disable-animations",
            "--reset-defaults",
            "--disable-keychain-access",
            "--disable-local-auth"
        ]
        
        app.launchEnvironment = [
            "UITEST_MODE": "1",
            "XCUITest": "1",
            "DISABLE_AUTHENTICATION": "1",
            "DISABLE_NOTIFICATIONS": "1",
            "DISABLE_MONITORING": "1",
            "DISABLE_KEYCHAIN": "1",
            "DISABLE_BIOMETRICS": "1",
            "CI": "false" // Set to false unless running in CI
        ]
        
        // Add longer delay before launch to avoid race conditions with system services
        // This is especially important for authentication-related system services
        Thread.sleep(forTimeInterval: 2.0)
        
        // Attempt to launch with retry logic for authentication issues
        var launchAttempts = 0
        let maxLaunchAttempts = 3
        
        while launchAttempts < maxLaunchAttempts {
            do {
                app.launch()
                
                // Wait for app to be ready
                if app.wait(for: .runningForeground, timeout: 15) {
                    break // Success!
                } else {
                    throw NSError(domain: "UITestError", code: 1, userInfo: [NSLocalizedDescriptionKey: "App failed to reach running state"])
                }
            } catch {
                launchAttempts += 1
                
                if launchAttempts < maxLaunchAttempts {
                    print("Launch attempt \(launchAttempts) failed, retrying after delay...")
                    app.terminate()
                    Thread.sleep(forTimeInterval: 3.0)
                } else {
                    throw error
                }
            }
        }
    }
    
    override func tearDownWithError() throws {
        app?.terminate()
        app = nil
        
        // Add delay after teardown to ensure clean state
        Thread.sleep(forTimeInterval: 0.5)
    }
    
    /// Take a screenshot with a descriptive name
    func takeScreenshot(name: String) -> XCTAttachment {
        let screenshot = app.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        return attachment
    }
    
    /// Wait for element to appear with better error messaging
    func waitForElement(_ element: XCUIElement, timeout: TimeInterval = 5, description: String? = nil) -> Bool {
        let exists = element.waitForExistence(timeout: timeout)
        if !exists {
            let desc = description ?? "Element '\(element.description)'"
            XCTFail("\(desc) did not appear within \(timeout) seconds")
        }
        return exists
    }
    
    /// Safely tap an element with existence check
    func safeTap(_ element: XCUIElement, timeout: TimeInterval = 3) -> Bool {
        if waitForElement(element, timeout: timeout) && element.isHittable {
            element.tap()
            return true
        }
        return false
    }
}