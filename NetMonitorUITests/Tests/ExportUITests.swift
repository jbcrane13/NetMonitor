//
//  ExportUITests.swift
//  NetMonitorUITests
//
//  UI tests for data export functionality.
//

import XCTest

final class ExportUITests: XCTestCase {
    
    var app: XCUIApplication!
    var sidebar: SidebarScreen!
    var settings: SettingsScreen!
    
    override func setUpWithError() throws {
        continueAfterFailure = false
        
        app = XCUIApplication()
        app.launchArguments = ["--uitesting"]
        app.launch()
        
        sidebar = SidebarScreen(app: app)
        settings = SettingsScreen(app: app)
        
        XCTAssertTrue(sidebar.waitForScreen(timeout: 10), "App should launch")
    }
    
    override func tearDownWithError() throws {
        app?.terminate()
        app = nil
    }
    
    // MARK: - Export Tests
    
    func testExportButtonAccessible() throws {
        sidebar.navigateToSettings()
        _ = settings.waitForScreen(timeout: 5)
        
        settings.selectDataTab()
        sleep(1)
        
        let exportButton = settings.exportButton.exists ? 
                          settings.exportButton : 
                          app.buttons["Export Data to CSV..."]
        
        XCTAssertTrue(exportButton.exists, "Export button should be accessible")
        XCTAssertTrue(exportButton.isEnabled, "Export button should be enabled")
    }
    
    func testExportInitiatesSaveDialog() throws {
        sidebar.navigateToSettings()
        _ = settings.waitForScreen(timeout: 5)
        
        settings.selectDataTab()
        sleep(1)
        
        // Click export
        settings.exportData()
        
        // Save dialog should appear (may be system dialog)
        sleep(2)
        
        let screenshot = settings.takeScreenshot(name: "Export-Dialog")
        add(screenshot)
        
        // Cancel the dialog if it appeared
        app.typeKey(.escape, modifierFlags: [])
    }

    func testExportDialogCanBeCancelled() throws {
        sidebar.navigateToSettings()
        _ = settings.waitForScreen(timeout: 5)
        
        settings.selectDataTab()
        sleep(1)
        
        settings.exportData()
        sleep(2)
        
        app.typeKey(.escape, modifierFlags: [])
        sleep(1)
        
        let dataTabVisible = app.staticTexts["Data"].exists ||
                             settings.exportButton.exists ||
                             app.buttons["Export Data to CSV..."].exists
        XCTAssertTrue(dataTabVisible, "Should return to Data settings after cancelling export")
    }
    
    // MARK: - Clear Data Tests
    
    func testClearDataShowsConfirmation() throws {
        sidebar.navigateToSettings()
        _ = settings.waitForScreen(timeout: 5)
        
        settings.selectDataTab()
        sleep(1)
        
        settings.clearAllData()
        
        // Confirmation should appear
        let confirmationShown = app.staticTexts["Clear All Data?"].waitForExistence(timeout: 3) ||
                               app.alerts.firstMatch.waitForExistence(timeout: 3) ||
                               app.sheets.firstMatch.waitForExistence(timeout: 3)
        
        XCTAssertTrue(confirmationShown, "Clear data confirmation should appear")
        
        let screenshot = settings.takeScreenshot(name: "ClearData-Confirmation")
        add(screenshot)
        
        // Cancel to preserve data
        settings.cancelClearData()
    }
    
    func testClearDataCanBeCancelled() throws {
        sidebar.navigateToSettings()
        _ = settings.waitForScreen(timeout: 5)
        
        settings.selectDataTab()
        sleep(1)
        
        settings.clearAllData()
        _ = app.staticTexts["Clear All Data?"].waitForExistence(timeout: 3)
        
        settings.cancelClearData()
        
        // Should be back at Data settings
        let dataSettingsVisible = app.staticTexts["Data"].exists ||
                                  settings.exportButton.exists
        XCTAssertTrue(dataSettingsVisible, "Should return to Data settings after cancel")
    }
    
    // MARK: - History Retention Tests
    
    func testHistoryRetentionPickerExists() throws {
        sidebar.navigateToSettings()
        _ = settings.waitForScreen(timeout: 5)
        
        settings.selectDataTab()
        sleep(1)
        
        let retentionExists = settings.historyRetentionPicker.exists ||
                             app.staticTexts["Keep measurement history"].exists ||
                             app.popUpButtons.firstMatch.exists
        
        XCTAssertTrue(retentionExists, "History retention setting should exist")
    }
}
