//
//  DashboardScreen.swift
//  NetMonitorUITests
//
//  Page object for the Dashboard view.
//

import XCTest

final class DashboardScreen: BaseScreen {
    let app: XCUIApplication
    
    // MARK: - Elements
    
    var monitoringToggleButton: XCUIElement {
        app.buttons["dashboard_button_monitoring_toggle"]
    }
    
    var startMonitoringButton: XCUIElement {
        app.buttons["Start Monitoring"]
    }
    
    var stopMonitoringButton: XCUIElement {
        app.buttons["Stop Monitoring"]
    }
    
    var connectionRefreshButton: XCUIElement {
        app.buttons["connection_card_button_refresh"]
    }
    
    var gatewayRefreshButton: XCUIElement {
        app.buttons["gateway_card_button_refresh"]
    }
    
    var ispRefreshButton: XCUIElement {
        app.buttons["isp_card_button_refresh"]
    }
    
    var noTargetsPlaceholder: XCUIElement {
        app.staticTexts["No Targets Configured"]
    }
    
    // Card elements by text content
    var connectionCard: XCUIElement {
        app.staticTexts["Connection"].firstMatch
    }
    
    var gatewayCard: XCUIElement {
        app.staticTexts["Default Gateway"].firstMatch
    }
    
    // MARK: - Init
    
    init(app: XCUIApplication) {
        self.app = app
    }
    
    // MARK: - BaseScreen
    
    func waitForScreen(timeout: TimeInterval = 5) -> Bool {
        // Dashboard should show the connection card or title
        return connectionCard.waitForExistence(timeout: timeout) ||
               app.staticTexts["Dashboard"].waitForExistence(timeout: timeout)
    }
    
    // MARK: - Actions
    
    func startMonitoring() {
        if monitoringToggleButton.exists && monitoringToggleButton.label.contains("Start") {
            tapElement(monitoringToggleButton)
        } else if startMonitoringButton.exists {
            tapElement(startMonitoringButton)
        }
    }

    func stopMonitoring() {
        if monitoringToggleButton.exists && monitoringToggleButton.label.contains("Stop") {
            tapElement(monitoringToggleButton)
        } else if stopMonitoringButton.exists {
            tapElement(stopMonitoringButton)
        }
    }

    /// Tap an element, falling back to coordinate-based tap if not hittable.
    private func tapElement(_ element: XCUIElement) {
        if element.isHittable {
            element.tap()
        } else {
            element.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        }
    }
    
    func refreshConnectionInfo() {
        if connectionRefreshButton.exists {
            connectionRefreshButton.tap()
        }
    }
    
    func refreshGatewayInfo() {
        if gatewayRefreshButton.exists {
            gatewayRefreshButton.tap()
        }
    }
    
    func refreshISPInfo() {
        if ispRefreshButton.exists {
            ispRefreshButton.tap()
        }
    }
    
    // MARK: - Verification
    
    var isMonitoring: Bool {
        stopMonitoringButton.exists ||
        (monitoringToggleButton.exists && monitoringToggleButton.label.contains("Stop"))
    }
    
    var hasConnectionInfo: Bool {
        connectionCard.exists
    }
    
    var hasGatewayInfo: Bool {
        gatewayCard.exists
    }
    
    var hasNoTargets: Bool {
        noTargetsPlaceholder.exists
    }
    
    func targetCard(named name: String) -> XCUIElement {
        app.staticTexts[name].firstMatch
    }
    
    func targetCardExists(named name: String) -> Bool {
        targetCard(named: name).exists
    }
}
