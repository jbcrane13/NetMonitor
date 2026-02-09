//
//  SettingsScreen.swift
//  NetMonitorUITests
//
//  Page object for the Settings view.
//

import XCTest

final class SettingsScreen: BaseScreen {
    let app: XCUIApplication
    
    // MARK: - Tab Elements
    
    var generalTab: XCUIElement {
        app.staticTexts["settings_tab_general"]
    }
    
    var monitoringTab: XCUIElement {
        app.staticTexts["settings_tab_monitoring"]
    }
    
    var notificationsTab: XCUIElement {
        app.staticTexts["settings_tab_notifications"]
    }
    
    var networkTab: XCUIElement {
        app.staticTexts["settings_tab_network"]
    }
    
    var dataTab: XCUIElement {
        app.staticTexts["settings_tab_data"]
    }
    
    var appearanceTab: XCUIElement {
        app.staticTexts["settings_tab_appearance"]
    }
    
    var companionTab: XCUIElement {
        app.staticTexts["settings_tab_companion"]
    }
    
    // Fallback text-based tabs
    var generalTabText: XCUIElement {
        app.staticTexts["General"].firstMatch
    }
    
    var monitoringTabText: XCUIElement {
        app.staticTexts["Monitoring"].firstMatch
    }
    
    var notificationsTabText: XCUIElement {
        app.staticTexts["Notifications"].firstMatch
    }
    
    var networkTabText: XCUIElement {
        app.staticTexts["Network"].firstMatch
    }
    
    var dataTabText: XCUIElement {
        app.staticTexts["Data"].firstMatch
    }
    
    var appearanceTabText: XCUIElement {
        app.staticTexts["Appearance"].firstMatch
    }
    
    var companionTabText: XCUIElement {
        app.staticTexts["Companion"].firstMatch
    }
    
    // MARK: - General Settings Elements

    var launchAtLoginToggle: XCUIElement {
        let checkbox = app.checkBoxes["settings_toggle_launchAtLogin"]
        if checkbox.exists { return checkbox }
        return app.switches["settings_toggle_launchAtLogin"].firstMatch
    }

    var showInMenuBarToggle: XCUIElement {
        let checkbox = app.checkBoxes["settings_toggle_showInMenuBar"]
        if checkbox.exists { return checkbox }
        return app.switches["settings_toggle_showInMenuBar"].firstMatch
    }

    var showInDockToggle: XCUIElement {
        let checkbox = app.checkBoxes["settings_toggle_showInDock"]
        if checkbox.exists { return checkbox }
        return app.switches["settings_toggle_showInDock"].firstMatch
    }
    
    // MARK: - Data Settings Elements
    
    var historyRetentionPicker: XCUIElement {
        app.popUpButtons["settings_picker_historyRetention"]
    }
    
    var exportButton: XCUIElement {
        app.buttons["settings_button_export"]
    }
    
    var clearDataButton: XCUIElement {
        app.buttons["settings_button_clearData"]
    }
    
    // MARK: - Init
    
    init(app: XCUIApplication) {
        self.app = app
    }
    
    // MARK: - BaseScreen
    
    func waitForScreen(timeout: TimeInterval = 5) -> Bool {
        generalTabText.waitForExistence(timeout: timeout)
    }
    
    // MARK: - Navigation
    
    func selectGeneralTab() {
        if generalTab.exists {
            generalTab.tap()
        } else {
            generalTabText.tap()
        }
    }
    
    func selectMonitoringTab() {
        if monitoringTab.exists {
            monitoringTab.tap()
        } else {
            monitoringTabText.tap()
        }
    }
    
    func selectNotificationsTab() {
        if notificationsTab.exists {
            notificationsTab.tap()
        } else {
            notificationsTabText.tap()
        }
    }
    
    func selectNetworkTab() {
        if networkTab.exists {
            networkTab.tap()
        } else {
            networkTabText.tap()
        }
    }
    
    func selectDataTab() {
        if dataTab.exists {
            dataTab.tap()
        } else {
            dataTabText.tap()
        }
    }
    
    func selectAppearanceTab() {
        if appearanceTab.exists {
            appearanceTab.tap()
        } else {
            appearanceTabText.tap()
        }
    }
    
    func selectCompanionTab() {
        if companionTab.exists {
            companionTab.tap()
        } else {
            companionTabText.tap()
        }
    }
    
    // MARK: - General Settings Actions
    
    func toggleLaunchAtLogin() {
        if launchAtLoginToggle.exists {
            launchAtLoginToggle.tap()
        } else {
            // Try to find by text
            app.checkBoxes["Launch at login"].tap()
        }
    }
    
    func toggleShowInMenuBar() {
        if showInMenuBarToggle.exists {
            showInMenuBarToggle.tap()
        } else {
            app.checkBoxes["Show in menu bar"].tap()
        }
    }
    
    func toggleShowInDock() {
        if showInDockToggle.exists {
            showInDockToggle.tap()
        } else {
            app.checkBoxes["Show in Dock"].tap()
        }
    }
    
    // MARK: - Data Settings Actions
    
    func exportData() {
        selectDataTab()
        _ = exportButton.waitForExistence(timeout: 2)
        if exportButton.exists {
            exportButton.tap()
        } else {
            app.buttons["Export Data to CSV..."].tap()
        }
    }
    
    func clearAllData() {
        selectDataTab()
        _ = clearDataButton.waitForExistence(timeout: 2)
        if clearDataButton.exists {
            clearDataButton.tap()
        } else {
            app.buttons["Clear All Data..."].tap()
        }
    }
    
    func confirmClearData() {
        let clearButton = app.buttons["Clear"]
        if clearButton.waitForExistence(timeout: 2) {
            clearButton.tap()
        }
    }
    
    func cancelClearData() {
        let sheetCancel = app.sheets.buttons["Cancel"]
        let alertCancel = app.dialogs.buttons["Cancel"]
        if sheetCancel.waitForExistence(timeout: 2) {
            sheetCancel.tap()
        } else if alertCancel.waitForExistence(timeout: 2) {
            alertCancel.tap()
        } else {
            // Fallback: use firstMatch to avoid TouchBar ambiguity
            app.buttons["Cancel"].firstMatch.tap()
        }
    }
    
    // MARK: - Verification
    
    var allTabsVisible: Bool {
        generalTabText.exists &&
        monitoringTabText.exists &&
        notificationsTabText.exists &&
        networkTabText.exists &&
        dataTabText.exists &&
        appearanceTabText.exists &&
        companionTabText.exists
    }
}
