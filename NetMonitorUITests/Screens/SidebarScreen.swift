//
//  SidebarScreen.swift
//  NetMonitorUITests
//
//  Page object for the main sidebar navigation.
//

import XCTest

final class SidebarScreen: BaseScreen {
    let app: XCUIApplication
    
    // MARK: - Elements
    
    var sidebar: XCUIElement {
        app.outlines["sidebar_navigation"]
    }
    
    var dashboardNavItem: XCUIElement {
        app.staticTexts["sidebar_dashboard"].firstMatch
    }
    
    var targetsNavItem: XCUIElement {
        app.staticTexts["sidebar_targets"].firstMatch
    }
    
    var devicesNavItem: XCUIElement {
        app.staticTexts["sidebar_devices"].firstMatch
    }
    
    var toolsNavItem: XCUIElement {
        app.staticTexts["sidebar_tools"].firstMatch
    }
    
    var settingsNavItem: XCUIElement {
        app.staticTexts["sidebar_settings"].firstMatch
    }
    
    // MARK: - Init
    
    init(app: XCUIApplication) {
        self.app = app
    }
    
    // MARK: - BaseScreen
    
    func waitForScreen(timeout: TimeInterval = 5) -> Bool {
        // Look for any sidebar element
        return app.staticTexts["Dashboard"].waitForExistence(timeout: timeout)
    }
    
    // MARK: - Navigation Actions
    
    @discardableResult
    func navigateToDashboard() -> DashboardScreen {
        // Try accessibility identifier first, fall back to text
        if dashboardNavItem.exists {
            dashboardNavItem.tap()
        } else {
            app.staticTexts["Dashboard"].firstMatch.tap()
        }
        return DashboardScreen(app: app)
    }
    
    @discardableResult
    func navigateToTargets() -> TargetsScreen {
        if targetsNavItem.exists {
            targetsNavItem.tap()
        } else {
            app.staticTexts["Targets"].firstMatch.tap()
        }
        return TargetsScreen(app: app)
    }
    
    @discardableResult
    func navigateToDevices() -> DevicesScreen {
        if devicesNavItem.exists {
            devicesNavItem.tap()
        } else {
            app.staticTexts["Devices"].firstMatch.tap()
        }
        return DevicesScreen(app: app)
    }
    
    @discardableResult
    func navigateToTools() -> ToolsScreen {
        if toolsNavItem.exists {
            toolsNavItem.tap()
        } else {
            app.staticTexts["Tools"].firstMatch.tap()
        }
        return ToolsScreen(app: app)
    }
    
    @discardableResult
    func navigateToSettings() -> SettingsScreen {
        if settingsNavItem.exists {
            settingsNavItem.tap()
        } else {
            app.staticTexts["Settings"].firstMatch.tap()
        }
        return SettingsScreen(app: app)
    }
}
