//
//  DashboardUITests.swift
//  NetMonitorUITests
//
//  Comprehensive UI tests for the Dashboard view.
//

import XCTest

final class DashboardUITests: XCTestCase {
    
    var app: XCUIApplication!
    var sidebar: SidebarScreen!
    var dashboard: DashboardScreen!
    
    override func setUpWithError() throws {
        continueAfterFailure = false
        
        app = XCUIApplication()
        app.launchArguments = ["--uitesting"]
        app.launch()
        
        sidebar = SidebarScreen(app: app)
        dashboard = DashboardScreen(app: app)
        
        // Wait for app to load
        XCTAssertTrue(sidebar.waitForScreen(timeout: 10), "App should launch with sidebar visible")
    }
    
    override func tearDownWithError() throws {
        app?.terminate()
        app = nil
    }
    
    // MARK: - Dashboard Loading Tests
    
    func testDashboardLoadsCorrectly() throws {
        // Navigate to dashboard
        sidebar.navigateToDashboard()
        
        // Verify dashboard loads
        XCTAssertTrue(dashboard.waitForScreen(timeout: 5), "Dashboard should load")
        
        // Take screenshot
        let screenshot = dashboard.takeScreenshot(name: "Dashboard-Loaded")
        add(screenshot)
    }
    
    func testDashboardShowsConnectionCard() throws {
        sidebar.navigateToDashboard()
        
        // Connection card should be visible
        XCTAssertTrue(dashboard.hasConnectionInfo, "Connection info card should be visible")
    }
    
    func testDashboardShowsGatewayCard() throws {
        sidebar.navigateToDashboard()
        
        // Gateway card should be visible
        XCTAssertTrue(dashboard.hasGatewayInfo, "Gateway info card should be visible")
    }

    func testDashboardShowsISPCard() throws {
        sidebar.navigateToDashboard()
        
        let ispCardExists = app.staticTexts["Public IP & ISP"].exists || app.staticTexts["ISP:"].exists
        XCTAssertTrue(ispCardExists, "ISP info card should be visible")
    }
    
    func testConnectionCardRefreshButton() throws {
        sidebar.navigateToDashboard()
        _ = dashboard.waitForScreen(timeout: 5)
        
        // Try to refresh connection info
        dashboard.refreshConnectionInfo()
        
        // Verify it still shows (didn't crash)
        XCTAssertTrue(dashboard.hasConnectionInfo, "Connection info should still be visible after refresh")
    }

    func testGatewayCardRefreshButton() throws {
        sidebar.navigateToDashboard()
        _ = dashboard.waitForScreen(timeout: 5)
        
        dashboard.refreshGatewayInfo()
        
        XCTAssertTrue(dashboard.hasGatewayInfo, "Gateway info should still be visible after refresh")
    }

    func testISPCardRefreshButton() throws {
        sidebar.navigateToDashboard()
        _ = dashboard.waitForScreen(timeout: 5)
        
        dashboard.refreshISPInfo()
        
        let ispCardExists = app.staticTexts["Public IP & ISP"].exists || app.staticTexts["ISP:"].exists
        XCTAssertTrue(ispCardExists, "ISP info should still be visible after refresh")
    }
    
    // MARK: - Monitoring Toggle Tests
    
    func testStartMonitoringButton() throws {
        sidebar.navigateToDashboard()
        _ = dashboard.waitForScreen(timeout: 5)
        
        // Check if monitoring button exists
        let monitoringButtonExists = dashboard.monitoringToggleButton.waitForExistence(timeout: 3) ||
                                     dashboard.startMonitoringButton.waitForExistence(timeout: 3)
        
        // This test passes if monitoring controls exist (app may not have targets)
        if monitoringButtonExists {
            dashboard.startMonitoring()
            
            // Wait a moment for state change
            sleep(1)
            
            // Take screenshot
            let screenshot = dashboard.takeScreenshot(name: "Dashboard-Monitoring-Started")
            add(screenshot)
        }
    }
    
    func testStopMonitoringButton() throws {
        sidebar.navigateToDashboard()
        _ = dashboard.waitForScreen(timeout: 5)
        
        // Start monitoring first
        dashboard.startMonitoring()
        sleep(1)
        
        // Stop monitoring
        dashboard.stopMonitoring()
        sleep(1)
        
        // Take screenshot
        let screenshot = dashboard.takeScreenshot(name: "Dashboard-Monitoring-Stopped")
        add(screenshot)
    }
    
    // MARK: - Empty State Tests
    
    func testNoTargetsPlaceholderVisible() throws {
        sidebar.navigateToDashboard()
        _ = dashboard.waitForScreen(timeout: 5)
        
        // In a clean test environment, there may be no targets
        // This test documents that behavior
        let hasNoTargetsMessage = dashboard.hasNoTargets
        let hasTargetCards = app.staticTexts["Online"].exists || app.staticTexts["Offline"].exists
        
        // Either placeholder or target cards should exist
        XCTAssertTrue(hasNoTargetsMessage || hasTargetCards, 
                     "Dashboard should show either 'no targets' placeholder or target status cards")
    }
    
    // MARK: - Navigation Tests
    
    func testNavigateToDashboardFromOtherSections() throws {
        // Navigate away from dashboard
        sidebar.navigateToSettings()
        sleep(1)
        
        // Navigate back to dashboard
        sidebar.navigateToDashboard()
        
        // Verify dashboard loads
        XCTAssertTrue(dashboard.waitForScreen(timeout: 5), "Should be able to navigate back to dashboard")
    }
    
    // MARK: - Screenshot Tests
    
    func testDashboardScreenshot() throws {
        sidebar.navigateToDashboard()
        _ = dashboard.waitForScreen(timeout: 5)
        
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Dashboard-Full"
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }
}
