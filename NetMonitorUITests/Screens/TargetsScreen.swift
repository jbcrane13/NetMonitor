//
//  TargetsScreen.swift
//  NetMonitorUITests
//
//  Page object for the Targets view.
//

import XCTest

final class TargetsScreen: BaseScreen {
    let app: XCUIApplication
    
    // MARK: - Elements
    
    var addTargetButton: XCUIElement {
        app.buttons["Add Target"].firstMatch
    }
    
    var sortButton: XCUIElement {
        app.buttons["Sort"]
    }
    
    var noTargetsPlaceholder: XCUIElement {
        app.staticTexts["No Targets"]
    }
    
    var targetsList: XCUIElement {
        app.outlines.firstMatch
    }
    
    // MARK: - Add Target Sheet Elements
    
    var addTargetNameField: XCUIElement {
        app.textFields["add_target_field_name"]
    }
    
    var addTargetHostField: XCUIElement {
        app.textFields["add_target_field_host"]
    }
    
    var addTargetPortField: XCUIElement {
        app.textFields["add_target_field_port"]
    }
    
    var addTargetProtocolPicker: XCUIElement {
        app.segmentedControls["add_target_picker_protocol"]
    }
    
    var addTargetCancelButton: XCUIElement {
        app.buttons["add_target_button_cancel"]
    }
    
    var addTargetAddButton: XCUIElement {
        app.buttons["add_target_button_add"]
    }
    
    // Protocol segment buttons (fallback)
    var icmpProtocolButton: XCUIElement {
        app.buttons["ICMP"]
    }
    
    var httpProtocolButton: XCUIElement {
        app.buttons["HTTP"]
    }
    
    var httpsProtocolButton: XCUIElement {
        app.buttons["HTTPS"]
    }
    
    var tcpProtocolButton: XCUIElement {
        app.buttons["TCP"]
    }
    
    // MARK: - Init
    
    init(app: XCUIApplication) {
        self.app = app
    }
    
    // MARK: - BaseScreen
    
    func waitForScreen(timeout: TimeInterval = 5) -> Bool {
        addTargetButton.waitForExistence(timeout: timeout)
    }
    
    // MARK: - Actions
    
    func openAddTargetSheet() {
        addTargetButton.tap()
        _ = addTargetNameField.waitForExistence(timeout: 5)
    }
    
    func cancelAddTarget() {
        if addTargetCancelButton.exists {
            addTargetCancelButton.tap()
        } else {
            app.buttons["Cancel"].tap()
        }
    }
    
    func addTarget(name: String, host: String, port: String? = nil, protocol targetProtocol: String = "HTTPS") {
        // Fill in name
        addTargetNameField.tap()
        addTargetNameField.typeText(name)
        
        // Fill in host
        addTargetHostField.tap()
        addTargetHostField.typeText(host)
        
        // Fill in port if provided
        if let port = port {
            addTargetPortField.tap()
            addTargetPortField.typeText(port)
        }
        
        // Select protocol
        selectProtocol(targetProtocol)
        
        // Submit
        submitAddTarget()
    }
    
    func selectProtocol(_ protocol: String) {
        switch `protocol`.uppercased() {
        case "ICMP":
            if icmpProtocolButton.exists { icmpProtocolButton.tap() }
        case "HTTP":
            if httpProtocolButton.exists { httpProtocolButton.tap() }
        case "HTTPS":
            if httpsProtocolButton.exists { httpsProtocolButton.tap() }
        case "TCP":
            if tcpProtocolButton.exists { tcpProtocolButton.tap() }
        default:
            break
        }
    }
    
    func submitAddTarget() {
        if addTargetAddButton.exists && addTargetAddButton.isEnabled {
            addTargetAddButton.tap()
        } else {
            app.buttons["Add"].tap()
        }
    }
    
    func selectTarget(named name: String) {
        let target = app.staticTexts[name].firstMatch
        if target.exists {
            target.tap()
        }
    }
    
    func deleteTarget(named name: String) {
        let target = app.staticTexts[name].firstMatch
        if target.exists {
            // Right-click or swipe to delete
            target.rightClick()
            if app.menuItems["Delete"].exists {
                app.menuItems["Delete"].tap()
            }
        }
    }
    
    // MARK: - Verification
    
    var hasNoTargets: Bool {
        noTargetsPlaceholder.exists
    }
    
    func targetExists(named name: String) -> Bool {
        app.staticTexts[name].firstMatch.waitForExistence(timeout: 2)
    }
    
    var targetCount: Int {
        // Count rows in the list
        app.cells.count
    }
}
