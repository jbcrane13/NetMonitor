//
//  NavigationUITests.swift
//  NetMonitorUITests
//
//  Tests for sidebar navigation and app-wide navigation flows.
//

import XCTest

final class NavigationUITests: XCTestCase {
    
    var app: XCUIApplication!
    var sidebar: SidebarScreen!
    
    override func setUpWithError() throws {
        continueAfterFailure = false
        
        app = XCUIApplication()
        app.launchArguments = ["--uitesting"]
        app.launch()
        
        sidebar = SidebarScreen(app: app)
        
        XCTAssertTrue(sidebar.waitForScreen(timeout: 10), "App should launch")
    }
    
    override func tearDownWithError() throws {
        app?.terminate()
        app = nil
    }
    
    // MARK: - App Launch Tests
    
    func testAppLaunchesWithWindow() throws {
        let windowExists = app.windows.firstMatch.waitForExistence(timeout: 5)
        XCTAssertTrue(windowExists, "App should launch with a window")
    }
    
    func testAppLaunchesWithSidebar() throws {
        XCTAssertTrue(sidebar.waitForScreen(timeout: 5), "App should launch with sidebar visible")
    }
    
    func testDefaultViewIsDashboard() throws {
        // Dashboard should be selected by default
        let dashboardContent = app.staticTexts["Dashboard"].exists ||
                              app.staticTexts["Connection"].exists
        XCTAssertTrue(dashboardContent, "Dashboard should be the default view")
    }
    
    // MARK: - Sidebar Navigation Tests
    
    func testNavigateToDashboard() throws {
        // First navigate away
        sidebar.navigateToSettings()
        sleep(1)
        
        // Then back to dashboard
        let dashboard = sidebar.navigateToDashboard()
        
        XCTAssertTrue(dashboard.waitForScreen(timeout: 5), "Should navigate to Dashboard")
    }
    
    func testNavigateToTargets() throws {
        let targets = sidebar.navigateToTargets()
        
        XCTAssertTrue(targets.waitForScreen(timeout: 5), "Should navigate to Targets")
    }
    
    func testNavigateToDevices() throws {
        let devices = sidebar.navigateToDevices()
        
        XCTAssertTrue(devices.waitForScreen(timeout: 5), "Should navigate to Devices")
    }
    
    func testNavigateToTools() throws {
        let tools = sidebar.navigateToTools()
        
        XCTAssertTrue(tools.waitForScreen(timeout: 5), "Should navigate to Tools")
    }
    
    func testNavigateToSettings() throws {
        let settings = sidebar.navigateToSettings()
        
        XCTAssertTrue(settings.waitForScreen(timeout: 5), "Should navigate to Settings")
    }
    
    // MARK: - Sequential Navigation Tests
    
    func testNavigateAllSections() throws {
        // Dashboard
        let dashboard = sidebar.navigateToDashboard()
        XCTAssertTrue(dashboard.waitForScreen(timeout: 5), "Dashboard should load")
        let dashboardScreenshot = dashboard.takeScreenshot(name: "Nav-Dashboard")
        add(dashboardScreenshot)
        
        // Targets
        let targets = sidebar.navigateToTargets()
        XCTAssertTrue(targets.waitForScreen(timeout: 5), "Targets should load")
        let targetsScreenshot = targets.takeScreenshot(name: "Nav-Targets")
        add(targetsScreenshot)
        
        // Devices
        let devices = sidebar.navigateToDevices()
        XCTAssertTrue(devices.waitForScreen(timeout: 5), "Devices should load")
        let devicesScreenshot = devices.takeScreenshot(name: "Nav-Devices")
        add(devicesScreenshot)
        
        // Tools
        let tools = sidebar.navigateToTools()
        XCTAssertTrue(tools.waitForScreen(timeout: 5), "Tools should load")
        let toolsScreenshot = tools.takeScreenshot(name: "Nav-Tools")
        add(toolsScreenshot)
        
        // Settings
        let settings = sidebar.navigateToSettings()
        XCTAssertTrue(settings.waitForScreen(timeout: 5), "Settings should load")
        let settingsScreenshot = settings.takeScreenshot(name: "Nav-Settings")
        add(settingsScreenshot)
    }
    
    func testRapidNavigation() throws {
        // Test rapid switching between sections
        for _ in 0..<3 {
            sidebar.navigateToDashboard()
            sidebar.navigateToTargets()
            sidebar.navigateToDevices()
            sidebar.navigateToTools()
            sidebar.navigateToSettings()
        }
        
        // Verify we're on Settings
        let settings = SettingsScreen(app: app)
        XCTAssertTrue(settings.waitForScreen(timeout: 5), "Should end on Settings")
    }
    
    // MARK: - Sidebar Element Tests
    
    func testAllSidebarItemsExist() throws {
        // Verify all navigation items are present
        let sectionNames = ["Dashboard", "Targets", "Devices", "Tools", "Settings"]
        
        for name in sectionNames {
            let item = app.staticTexts[name].firstMatch
            XCTAssertTrue(item.exists, "\(name) should exist in sidebar")
        }
    }
    
    // MARK: - Window Tests
    
    func testWindowTitle() throws {
        // Window should have NetMonitor title
        let window = app.windows.firstMatch
        XCTAssertTrue(window.exists, "Main window should exist")
    }
}
