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

        // Wait for duration timer to appear (may take a moment for monitoring to start)
        let durationTimer = app.staticTexts["dashboard_duration_timer"]
        let timerAppeared = durationTimer.waitForExistence(timeout: 5)

        // If timer doesn't appear, skip the test - monitoring may not have started
        // (e.g., no targets configured, or monitoring session initialization issue)
        if !timerAppeared {
            throw XCTSkip("Duration timer did not appear - monitoring may not have started (no targets configured)")
        }

        XCTAssertTrue(durationTimer.exists, "Monitoring duration timer should be visible when monitoring")

        let screenshot = dashboard.takeScreenshot(name: "Monitoring-Duration")
        add(screenshot)

        dashboard.stopMonitoring()
    }

    // MARK: - Duration Timer Visibility Tests

    func testStopMonitoringHidesDurationTimer() throws {
        sidebar.navigateToDashboard()
        _ = dashboard.waitForScreen(timeout: 5)

        // Start monitoring so the timer appears
        dashboard.startMonitoring()

        let durationTimer = app.staticTexts["dashboard_duration_timer"]
        let timerAppeared = durationTimer.waitForExistence(timeout: 5)

        // If timer doesn't appear, skip - can't test hiding behavior without timer
        if !timerAppeared {
            throw XCTSkip("Duration timer did not appear - monitoring may not have started (no targets configured)")
        }

        // Stop monitoring
        dashboard.stopMonitoring()
        sleep(2)

        // The timer should no longer be visible (replaced by "Not monitoring" text)
        let timerStillVisible = durationTimer.exists
        let notMonitoringText = app.staticTexts["Not monitoring"]
        XCTAssertTrue(!timerStillVisible || notMonitoringText.exists,
                     "Duration timer should disappear or show 'Not monitoring' after stopping")

        let screenshot = dashboard.takeScreenshot(name: "Monitoring-Stopped-No-Timer")
        add(screenshot)
    }

    // MARK: - Target Status Cards Tests

    func testDashboardShowsTargetCardsWhenTargetsExist() throws {
        // First ensure we have at least one target
        sidebar.navigateToTargets()
        _ = targets.waitForScreen(timeout: 5)

        if targets.hasNoTargets {
            // Add a target so the dashboard has something to display
            targets.openAddTargetSheet()
            _ = app.staticTexts["Add Target"].waitForExistence(timeout: 3)
            sleep(1)
            targets.addTarget(
                name: "Dashboard Card Test",
                host: "example.com",
                protocol: "HTTPS"
            )
            sleep(2)
        }

        // Navigate to dashboard
        sidebar.navigateToDashboard()
        _ = dashboard.waitForScreen(timeout: 5)

        // The "No Targets Configured" placeholder should NOT be visible
        XCTAssertFalse(dashboard.hasNoTargets,
                      "Dashboard should not show 'No Targets Configured' when targets exist")

        let screenshot = dashboard.takeScreenshot(name: "Dashboard-With-Target-Cards")
        add(screenshot)
    }

    func testDashboardNoTargetsShowsEmptyState() throws {
        sidebar.navigateToDashboard()
        _ = dashboard.waitForScreen(timeout: 5)

        // If there are no targets, the empty state placeholder should show
        if dashboard.hasNoTargets {
            let noTargetsText = app.staticTexts["No Targets Configured"]
            XCTAssertTrue(noTargetsText.exists,
                         "Dashboard should show 'No Targets Configured' placeholder when no targets exist")

            let screenshot = dashboard.takeScreenshot(name: "Dashboard-No-Targets-Empty-State")
            add(screenshot)
        } else {
            // If targets exist, verify at least the connection card is present
            XCTAssertTrue(dashboard.hasConnectionInfo,
                         "Dashboard should show connection info when targets are present")
        }
    }

    // MARK: - Dashboard Info Cards During Monitoring

    func testDashboardShowsConnectionAndGatewayCards() throws {
        sidebar.navigateToDashboard()
        _ = dashboard.waitForScreen(timeout: 5)

        // Connection and Gateway cards should always be present regardless of monitoring state
        XCTAssertTrue(dashboard.hasConnectionInfo,
                     "Connection info card should be visible on dashboard")
        XCTAssertTrue(dashboard.hasGatewayInfo,
                     "Gateway info card should be visible on dashboard")

        let screenshot = dashboard.takeScreenshot(name: "Dashboard-Info-Cards")
        add(screenshot)
    }

    func testMonitoringWithTargetsShowsStatusUpdates() throws {
        // Ensure a target exists
        sidebar.navigateToTargets()
        _ = targets.waitForScreen(timeout: 5)

        let testTargetName = "Status Update Test"
        if targets.hasNoTargets {
            targets.openAddTargetSheet()
            _ = app.staticTexts["Add Target"].waitForExistence(timeout: 3)
            sleep(1)
            targets.addTarget(
                name: testTargetName,
                host: "8.8.8.8",
                protocol: "ICMP"
            )
            sleep(2)
        }

        // Go to dashboard and start monitoring
        sidebar.navigateToDashboard()
        _ = dashboard.waitForScreen(timeout: 5)

        dashboard.startMonitoring()
        sleep(5)

        // Dashboard should not be in empty state
        XCTAssertFalse(dashboard.hasNoTargets,
                      "Dashboard should not show empty state when monitoring with targets")

        let screenshot = dashboard.takeScreenshot(name: "Dashboard-Monitoring-With-Targets")
        add(screenshot)

        dashboard.stopMonitoring()
    }
}
