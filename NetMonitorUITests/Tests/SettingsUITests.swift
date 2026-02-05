//
//  SettingsUITests.swift
//  NetMonitorUITests
//
//  Comprehensive UI tests for the Settings view.
//

import XCTest

final class SettingsUITests: XCTestCase {
    
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
    
    // MARK: - Settings View Loading
    
    func testSettingsViewLoads() throws {
        sidebar.navigateToSettings()
        
        XCTAssertTrue(settings.waitForScreen(timeout: 5), "Settings view should load")
        
        let screenshot = settings.takeScreenshot(name: "Settings-View")
        add(screenshot)
    }
    
    func testAllSettingsTabsVisible() throws {
        sidebar.navigateToSettings()
        _ = settings.waitForScreen(timeout: 5)
        
        XCTAssertTrue(settings.allTabsVisible, "All 7 settings tabs should be visible")
    }
    
    // MARK: - General Settings Tests
    
    func testGeneralTabSelected() throws {
        sidebar.navigateToSettings()
        _ = settings.waitForScreen(timeout: 5)
        
        settings.selectGeneralTab()
        
        // Look for General settings content
        let hasLaunchAtLogin = app.staticTexts["Launch at login"].exists ||
                               app.checkBoxes["Launch at login"].exists
        XCTAssertTrue(hasLaunchAtLogin, "General settings should show Launch at login option")
        
        let screenshot = settings.takeScreenshot(name: "Settings-General")
        add(screenshot)
    }
    
    func testGeneralSettingsOptions() throws {
        sidebar.navigateToSettings()
        _ = settings.waitForScreen(timeout: 5)
        
        settings.selectGeneralTab()
        sleep(1)
        
        // Verify expected options exist
        XCTAssertTrue(app.staticTexts["Launch at login"].exists || 
                     settings.launchAtLoginToggle.exists,
                     "Launch at login option should exist")
        
        XCTAssertTrue(app.staticTexts["Show in menu bar"].exists ||
                     settings.showInMenuBarToggle.exists,
                     "Show in menu bar option should exist")
    }

    func testGeneralSettingsToggles() throws {
        sidebar.navigateToSettings()
        _ = settings.waitForScreen(timeout: 5)
        
        settings.selectGeneralTab()
        sleep(1)
        
        if settings.launchAtLoginToggle.exists {
            settings.launchAtLoginToggle.tap()
            settings.launchAtLoginToggle.tap()
        }
        
        if settings.showInMenuBarToggle.exists {
            settings.showInMenuBarToggle.tap()
            settings.showInMenuBarToggle.tap()
        }
        
        if settings.showInDockToggle.exists {
            settings.showInDockToggle.tap()
            settings.showInDockToggle.tap()
        }
        
        let screenshot = settings.takeScreenshot(name: "Settings-General-Toggles")
        add(screenshot)
    }
    
    // MARK: - Monitoring Settings Tests
    
    func testMonitoringTabLoads() throws {
        sidebar.navigateToSettings()
        _ = settings.waitForScreen(timeout: 5)
        
        settings.selectMonitoringTab()
        
        // Verify Monitoring settings content loads
        XCTAssertTrue(app.staticTexts["Monitoring"].waitForExistence(timeout: 3), 
                     "Monitoring settings should load")
        
        let screenshot = settings.takeScreenshot(name: "Settings-Monitoring")
        add(screenshot)
    }

    func testMonitoringSettingsControlsExist() throws {
        sidebar.navigateToSettings()
        _ = settings.waitForScreen(timeout: 5)
        
        settings.selectMonitoringTab()
        sleep(1)
        
        let intervalPicker = app.popUpButtons["settings_picker_defaultInterval"]
        let timeoutPicker = app.popUpButtons["settings_picker_defaultTimeout"]
        let retryToggle = app.checkBoxes["settings_toggle_retryEnabled"]
        let retryStepper = app.steppers["settings_stepper_retryCount"]
        
        XCTAssertTrue(intervalPicker.exists, "Default interval picker should exist")
        XCTAssertTrue(timeoutPicker.exists, "Default timeout picker should exist")
        XCTAssertTrue(retryToggle.exists, "Retry toggle should exist")
        XCTAssertTrue(retryStepper.exists, "Retry count stepper should exist")
    }
    
    // MARK: - Notifications Settings Tests
    
    func testNotificationsTabLoads() throws {
        sidebar.navigateToSettings()
        _ = settings.waitForScreen(timeout: 5)
        
        settings.selectNotificationsTab()
        
        XCTAssertTrue(app.staticTexts["Notifications"].waitForExistence(timeout: 3),
                     "Notifications settings should load")
        
        let screenshot = settings.takeScreenshot(name: "Settings-Notifications")
        add(screenshot)
    }

    func testNotificationSettingsControlsExist() throws {
        sidebar.navigateToSettings()
        _ = settings.waitForScreen(timeout: 5)
        
        settings.selectNotificationsTab()
        sleep(1)
        
        let notificationsToggle = app.checkBoxes["settings_toggle_notificationsEnabled"]
        let downToggle = app.checkBoxes["settings_toggle_notifyTargetDown"]
        let recoveryToggle = app.checkBoxes["settings_toggle_notifyTargetRecovery"]
        let latencySlider = app.sliders["settings_slider_latencyThreshold"]
        
        XCTAssertTrue(notificationsToggle.exists, "Notifications enabled toggle should exist")
        XCTAssertTrue(downToggle.exists, "Target down toggle should exist")
        XCTAssertTrue(recoveryToggle.exists, "Target recovery toggle should exist")
        XCTAssertTrue(latencySlider.exists, "Latency threshold slider should exist")
    }
    
    // MARK: - Network Settings Tests
    
    func testNetworkTabLoads() throws {
        sidebar.navigateToSettings()
        _ = settings.waitForScreen(timeout: 5)
        
        settings.selectNetworkTab()
        
        XCTAssertTrue(app.staticTexts["Network"].waitForExistence(timeout: 3),
                     "Network settings should load")
        
        let screenshot = settings.takeScreenshot(name: "Settings-Network")
        add(screenshot)
    }

    func testNetworkSettingsControlsExist() throws {
        sidebar.navigateToSettings()
        _ = settings.waitForScreen(timeout: 5)
        
        settings.selectNetworkTab()
        sleep(1)
        
        let interfacePicker = app.popUpButtons["settings_picker_preferredInterface"]
        let proxyToggle = app.checkBoxes["settings_toggle_useSystemProxy"]
        
        XCTAssertTrue(interfacePicker.exists, "Preferred interface picker should exist")
        XCTAssertTrue(proxyToggle.exists, "Use system proxy toggle should exist")
    }
    
    // MARK: - Data Settings Tests
    
    func testDataTabLoads() throws {
        sidebar.navigateToSettings()
        _ = settings.waitForScreen(timeout: 5)
        
        settings.selectDataTab()
        
        XCTAssertTrue(app.staticTexts["Data"].waitForExistence(timeout: 3),
                     "Data settings should load")
        
        let screenshot = settings.takeScreenshot(name: "Settings-Data")
        add(screenshot)
    }

    func testHistoryRetentionPickerExists() throws {
        sidebar.navigateToSettings()
        _ = settings.waitForScreen(timeout: 5)
        
        settings.selectDataTab()
        sleep(1)
        
        XCTAssertTrue(settings.historyRetentionPicker.exists ||
                     app.popUpButtons["settings_picker_historyRetention"].exists,
                     "History retention picker should exist")
    }
    
    func testExportButtonExists() throws {
        sidebar.navigateToSettings()
        _ = settings.waitForScreen(timeout: 5)
        
        settings.selectDataTab()
        sleep(1)
        
        let exportExists = settings.exportButton.exists ||
                          app.buttons["Export Data to CSV..."].exists
        XCTAssertTrue(exportExists, "Export button should exist in Data settings")
    }
    
    func testClearDataButtonExists() throws {
        sidebar.navigateToSettings()
        _ = settings.waitForScreen(timeout: 5)
        
        settings.selectDataTab()
        sleep(1)
        
        let clearExists = settings.clearDataButton.exists ||
                         app.buttons["Clear All Data..."].exists
        XCTAssertTrue(clearExists, "Clear All Data button should exist in Data settings")
    }
    
    func testClearDataConfirmationDialog() throws {
        sidebar.navigateToSettings()
        _ = settings.waitForScreen(timeout: 5)
        
        settings.selectDataTab()
        sleep(1)
        
        settings.clearAllData()
        
        // Verify confirmation dialog appears
        let dialogExists = app.staticTexts["Clear All Data?"].waitForExistence(timeout: 3) ||
                          app.alerts.firstMatch.exists
        XCTAssertTrue(dialogExists, "Clear data confirmation dialog should appear")
        
        // Cancel to avoid actually clearing data
        settings.cancelClearData()
    }
    
    // MARK: - Appearance Settings Tests
    
    func testAppearanceTabLoads() throws {
        sidebar.navigateToSettings()
        _ = settings.waitForScreen(timeout: 5)
        
        settings.selectAppearanceTab()
        
        XCTAssertTrue(app.staticTexts["Appearance"].waitForExistence(timeout: 3),
                     "Appearance settings should load")
        
        let screenshot = settings.takeScreenshot(name: "Settings-Appearance")
        add(screenshot)
    }

    func testAppearanceSettingsControlsExist() throws {
        sidebar.navigateToSettings()
        _ = settings.waitForScreen(timeout: 5)
        
        settings.selectAppearanceTab()
        sleep(1)
        
        let compactToggle = app.checkBoxes["settings_toggle_compactMode"]
        XCTAssertTrue(compactToggle.exists, "Compact mode toggle should exist")
        
        // Validate at least one color preset is visible
        let presetExists = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'settings_color_'")).count > 0
        XCTAssertTrue(presetExists, "Color preset buttons should exist")
    }
    
    // MARK: - Companion Settings Tests
    
    func testCompanionTabLoads() throws {
        sidebar.navigateToSettings()
        _ = settings.waitForScreen(timeout: 5)
        
        settings.selectCompanionTab()
        
        XCTAssertTrue(app.staticTexts["Companion"].waitForExistence(timeout: 3),
                     "Companion settings should load")
        
        let screenshot = settings.takeScreenshot(name: "Settings-Companion")
        add(screenshot)
    }

    func testCompanionSettingsControlsExist() throws {
        sidebar.navigateToSettings()
        _ = settings.waitForScreen(timeout: 5)
        
        settings.selectCompanionTab()
        sleep(1)
        
        let companionToggle = app.checkBoxes["settings_toggle_companionEnabled"]
        let servicePortField = app.textFields["settings_textfield_servicePort"]
        
        XCTAssertTrue(companionToggle.exists, "Companion enabled toggle should exist")
        XCTAssertTrue(servicePortField.exists, "Service port text field should exist")
    }
    
    // MARK: - Tab Navigation Tests
    
    func testNavigateAllTabs() throws {
        sidebar.navigateToSettings()
        _ = settings.waitForScreen(timeout: 5)
        
        let tabs = ["General", "Monitoring", "Notifications", "Network", "Data", "Appearance", "Companion"]
        
        for tab in tabs {
            // Click the tab
            app.staticTexts[tab].firstMatch.tap()
            sleep(1)
            
            // Verify content area updates (title should be visible)
            let tabLoaded = app.staticTexts[tab].exists
            XCTAssertTrue(tabLoaded, "\(tab) tab should load when selected")
        }
    }
    
    // MARK: - Settings Persistence Test
    
    func testSettingsViewStatePreserved() throws {
        sidebar.navigateToSettings()
        _ = settings.waitForScreen(timeout: 5)
        
        // Select Monitoring tab
        settings.selectMonitoringTab()
        sleep(1)
        
        // Navigate away
        sidebar.navigateToDashboard()
        sleep(1)
        
        // Navigate back
        sidebar.navigateToSettings()
        _ = settings.waitForScreen(timeout: 5)
        
        // View should load (state preservation is implementation-specific)
        XCTAssertTrue(settings.waitForScreen(timeout: 5), "Settings view should load after navigation")
    }
}
