//
//  MonitoringUITests.swift
//  NetMonitorUITests
//
//  UI tests for monitoring functionality.
//

import XCTest

final class MonitoringUITests: XCTestCase {
    
    var app: XCUIApplication!
    var sidebar: SidebarScreen!
    var dashboard: DashboardScreen!
    var targets: TargetsScreen!
    
    override func setUpWithError() throws {
        continueAfterFailure = false
        
        app = XCUIApplication()
        app.launchArguments = ["--uitesting"]
        app.launch()
        
        sidebar = SidebarScreen(app: app)
        dashboard = DashboardScreen(app: app)
        targets = TargetsScreen(app: app)
        
        XCTAssertTrue(sidebar.waitForScreen(timeout: 10), "App should launch")
    }
    
    override func tearDownWithError() throws {
        app?.terminate()
        app = nil
    }
    
    // MARK: - Monitoring Button Tests
    
    func testMonitoringButtonExists() throws {
        sidebar.navigateToDashboard()
        _ = dashboard.waitForScreen(timeout: 5)
        
        let monitoringButtonExists = dashboard.monitoringToggleButton.exists ||
                                     dashboard.startMonitoringButton.exists ||
                                     app.buttons["Start Monitoring"].exists ||
                                     app.buttons["Stop Monitoring"].exists
        
        XCTAssertTrue(monitoringButtonExists, "Monitoring control button should exist")
    }
    
    func testStartMonitoring() throws {
        sidebar.navigateToDashboard()
        _ = dashboard.waitForScreen(timeout: 5)
        
        dashboard.startMonitoring()
        
        sleep(2)
        
        let screenshot = dashboard.takeScreenshot(name: "Monitoring-Started")
        add(screenshot)
    }
    
    func testStopMonitoring() throws {
        sidebar.navigateToDashboard()
        _ = dashboard.waitForScreen(timeout: 5)
        
        // Start first
        dashboard.startMonitoring()
        sleep(2)
        
        // Then stop
        dashboard.stopMonitoring()
        sleep(1)
        
        let screenshot = dashboard.takeScreenshot(name: "Monitoring-Stopped")
        add(screenshot)
    }
    
    func testMonitoringToggle() throws {
        sidebar.navigateToDashboard()
        _ = dashboard.waitForScreen(timeout: 5)
        
        // Get initial state
        let initiallyMonitoring = dashboard.isMonitoring
        
        // Toggle
        if initiallyMonitoring {
            dashboard.stopMonitoring()
        } else {
            dashboard.startMonitoring()
        }
        sleep(2)
        
        // Toggle back
        if initiallyMonitoring {
            dashboard.startMonitoring()
        } else {
            dashboard.stopMonitoring()
        }
        sleep(1)
        
        let screenshot = dashboard.takeScreenshot(name: "Monitoring-Toggled")
        add(screenshot)
    }
    
    // MARK: - Target Status Tests
    
    func testTargetStatusCardsUpdate() throws {
        // First add a target if needed
        sidebar.navigateToTargets()
        _ = targets.waitForScreen(timeout: 5)
        
        // Check if we have targets
        if targets.hasNoTargets {
            // Add a test target
            targets.openAddTargetSheet()
            _ = app.staticTexts["Add Target"].waitForExistence(timeout: 3)
            sleep(1)
            
            targets.addTarget(
                name: "Test Monitor Target",
                host: "8.8.8.8",
                protocol: "ICMP"
            )
            sleep(2)
        }
        
        // Now go to dashboard and start monitoring
        sidebar.navigateToDashboard()
        _ = dashboard.waitForScreen(timeout: 5)
        
        dashboard.startMonitoring()
        
        // Wait for status update
        sleep(5)
        
        let screenshot = dashboard.takeScreenshot(name: "Monitoring-Status-Update")
        add(screenshot)
        
        dashboard.stopMonitoring()
    }
    
    // MARK: - Monitoring Settings Tests
    
    func testMonitoringSettingsExist() throws {
        sidebar.navigateToSettings()
        let settings = SettingsScreen(app: app)
        _ = settings.waitForScreen(timeout: 5)
        
        settings.selectMonitoringTab()
        sleep(1)
        
        // Verify monitoring settings are shown
        let hasMonitoringSettings = app.staticTexts["Monitoring"].exists
        XCTAssertTrue(hasMonitoringSettings, "Monitoring settings should be visible")
        
        let screenshot = settings.takeScreenshot(name: "Monitoring-Settings")
        add(screenshot)
    }
    
    // MARK: - Dashboard Cards During Monitoring
    
    func testDashboardCardsVisibleDuringMonitoring() throws {
        sidebar.navigateToDashboard()
        _ = dashboard.waitForScreen(timeout: 5)
        
        dashboard.startMonitoring()
        sleep(2)
        
        // Verify cards still visible
        XCTAssertTrue(dashboard.hasConnectionInfo || app.staticTexts["Connection"].exists,
                     "Connection card should be visible during monitoring")
        
        dashboard.stopMonitoring()
    }

    func testMonitoringShowsDurationTimer() throws {
        sidebar.navigateToDashboard()
        _ = dashboard.waitForScreen(timeout: 5)
        
        dashboard.startMonitoring()
        sleep(2)
        
        let durationTimer = app.staticTexts["dashboard_duration_timer"]
        XCTAssertTrue(durationTimer.exists, "Monitoring duration timer should be visible when monitoring")
        
        let screenshot = dashboard.takeScreenshot(name: "Monitoring-Duration")
        add(screenshot)
        
        dashboard.stopMonitoring()
    }
}
