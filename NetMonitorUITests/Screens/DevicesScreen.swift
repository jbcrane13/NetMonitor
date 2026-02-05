//
//  DevicesScreen.swift
//  NetMonitorUITests
//
//  Page object for the Devices view.
//

import XCTest

final class DevicesScreen: BaseScreen {
    let app: XCUIApplication
    
    // MARK: - Elements
    
    var scanButton: XCUIElement {
        app.buttons["devices_button_scan"]
    }
    
    var refreshButton: XCUIElement {
        app.buttons["Scan Network"]
    }
    
    var noDevicesPlaceholder: XCUIElement {
        app.staticTexts["No Devices Found"]
    }
    
    var devicesList: XCUIElement {
        app.tables.firstMatch
    }
    
    // MARK: - Init
    
    init(app: XCUIApplication) {
        self.app = app
    }
    
    // MARK: - BaseScreen
    
    func waitForScreen(timeout: TimeInterval = 5) -> Bool {
        // Devices screen should show scan button or devices list
        return refreshButton.waitForExistence(timeout: timeout) ||
               app.staticTexts["Devices"].waitForExistence(timeout: timeout)
    }
    
    // MARK: - Actions
    
    func scanNetwork() {
        if scanButton.exists {
            scanButton.tap()
        } else if refreshButton.exists {
            refreshButton.tap()
        }
    }
    
    func selectDevice(named name: String) {
        let device = app.staticTexts[name].firstMatch
        if device.exists {
            device.tap()
        }
    }
    
    // MARK: - Verification
    
    var hasDevices: Bool {
        !noDevicesPlaceholder.exists && devicesList.cells.count > 0
    }
    
    func deviceExists(named name: String) -> Bool {
        app.staticTexts[name].firstMatch.exists
    }
    
    var deviceCount: Int {
        devicesList.cells.count
    }
}
