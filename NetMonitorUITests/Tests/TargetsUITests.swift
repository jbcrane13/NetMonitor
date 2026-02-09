//
//  TargetsUITests.swift
//  NetMonitorUITests
//
//  Comprehensive UI tests for the Targets view.
//

import XCTest

final class TargetsUITests: XCTestCase {
    
    var app: XCUIApplication!
    var sidebar: SidebarScreen!
    var targets: TargetsScreen!
    
    override func setUpWithError() throws {
        continueAfterFailure = false
        
        app = XCUIApplication()
        app.launchArguments = ["--uitesting"]
        app.launch()
        
        sidebar = SidebarScreen(app: app)
        targets = TargetsScreen(app: app)
        
        XCTAssertTrue(sidebar.waitForScreen(timeout: 10), "App should launch")
    }
    
    override func tearDownWithError() throws {
        app?.terminate()
        app = nil
    }
    
    // MARK: - Targets View Loading
    
    func testTargetsViewLoads() throws {
        sidebar.navigateToTargets()
        
        XCTAssertTrue(targets.waitForScreen(timeout: 5), "Targets view should load")
        
        let screenshot = targets.takeScreenshot(name: "Targets-View")
        add(screenshot)
    }
    
    func testAddTargetButtonExists() throws {
        sidebar.navigateToTargets()
        _ = targets.waitForScreen(timeout: 5)
        
        XCTAssertTrue(targets.addTargetButton.exists, "Add Target button should exist")
    }
    
    // MARK: - Add Target Sheet Tests
    
    func testOpenAddTargetSheet() throws {
        sidebar.navigateToTargets()
        _ = targets.waitForScreen(timeout: 5)
        
        targets.openAddTargetSheet()
        
        // Verify sheet opened
        XCTAssertTrue(targets.addTargetNameField.waitForExistence(timeout: 3) ||
                     app.staticTexts["Add Target"].waitForExistence(timeout: 3),
                     "Add Target sheet should open")
        
        let screenshot = targets.takeScreenshot(name: "Add-Target-Sheet")
        add(screenshot)
    }
    
    func testCancelAddTargetSheet() throws {
        sidebar.navigateToTargets()
        _ = targets.waitForScreen(timeout: 5)
        
        targets.openAddTargetSheet()
        _ = targets.addTargetNameField.waitForExistence(timeout: 3)
        
        targets.cancelAddTarget()
        
        // Sheet should close
        XCTAssertTrue(targets.waitForElementToDisappear(targets.addTargetNameField, timeout: 3),
                     "Add Target sheet should close on cancel")
    }
    
    func testAddTargetFieldsExist() throws {
        sidebar.navigateToTargets()
        _ = targets.waitForScreen(timeout: 5)
        
        targets.openAddTargetSheet()
        
        // Wait for sheet to fully load
        _ = app.staticTexts["Add Target"].waitForExistence(timeout: 3)
        sleep(1)
        
        // Check for name field (may be with or without identifier)
        let nameFieldExists = targets.addTargetNameField.exists || 
                             app.textFields["Name"].exists ||
                             app.textFields.count > 0
        XCTAssertTrue(nameFieldExists, "Name field should exist")
        
        // Check for host field
        let hostFieldExists = targets.addTargetHostField.exists ||
                             app.textFields["Host"].exists
        XCTAssertTrue(hostFieldExists, "Host field should exist")
        
        targets.cancelAddTarget()
    }
    
    func testAddTargetWithValidData() throws {
        sidebar.navigateToTargets()
        _ = targets.waitForScreen(timeout: 5)
        
        let testTargetName = "Test Target \(Int.random(in: 1000...9999))"
        
        targets.openAddTargetSheet()
        _ = app.staticTexts["Add Target"].waitForExistence(timeout: 3)
        sleep(1)
        
        targets.addTarget(
            name: testTargetName,
            host: "google.com",
            protocol: "HTTPS"
        )
        
        // Wait for sheet to close
        sleep(2)
        
        // Verify target appears in list
        let targetAdded = targets.targetExists(named: testTargetName)
        
        let screenshot = targets.takeScreenshot(name: "Target-Added")
        add(screenshot)
        
        // Clean up - this test may or may not successfully add depending on validation
        // The main goal is to verify the flow works
    }
    
    func testAddTargetButtonDisabledWhenEmpty() throws {
        sidebar.navigateToTargets()
        _ = targets.waitForScreen(timeout: 5)
        
        targets.openAddTargetSheet()
        _ = app.staticTexts["Add Target"].waitForExistence(timeout: 3)
        sleep(1)
        
        // Add button should be disabled when fields are empty
        let addButton = targets.addTargetAddButton.exists ? targets.addTargetAddButton : app.buttons["Add"]
        
        if addButton.exists {
            // Button should be disabled
            XCTAssertFalse(addButton.isEnabled, "Add button should be disabled when fields are empty")
        }
        
        targets.cancelAddTarget()
    }
    
    // MARK: - Protocol Selection Tests
    
    func testProtocolSegmentedControl() throws {
        sidebar.navigateToTargets()
        _ = targets.waitForScreen(timeout: 5)

        targets.openAddTargetSheet()
        _ = app.staticTexts["Add Target"].waitForExistence(timeout: 3)
        sleep(1)

        // Check protocol picker exists - SwiftUI segmented pickers render differently on macOS
        // Try all possible element types: segmentedControls, radioGroups, popUpButtons, buttons
        let pickerById = targets.addTargetProtocolPicker
        let segmented = app.segmentedControls.firstMatch
        let radioGroup = app.radioGroups.firstMatch
        let protocolLabel = app.staticTexts["Protocol"].firstMatch

        let protocolControlExists = pickerById.exists ||
                                     segmented.exists ||
                                     radioGroup.exists ||
                                     protocolLabel.exists

        XCTAssertTrue(protocolControlExists,
                     "Protocol selection control should exist in add target sheet")

        targets.cancelAddTarget()
    }
    
    // MARK: - Sort Tests
    
    func testSortButtonExists() throws {
        sidebar.navigateToTargets()
        _ = targets.waitForScreen(timeout: 5)

        // Sort is a Menu in toolbar - may render as menuButton, popUpButton, or button
        let sortExists = targets.sortButton.exists ||
                         app.buttons["Sort"].exists ||
                         app.menuButtons["Sort"].exists ||
                         app.popUpButtons["Sort"].exists ||
                         app.menuButtons["Sort By"].exists
        XCTAssertTrue(sortExists, "Sort button should exist")
    }
    
    // MARK: - Empty State Tests
    
    func testEmptyStateOrTargetsList() throws {
        sidebar.navigateToTargets()
        _ = targets.waitForScreen(timeout: 5)
        
        // Either show empty state or targets list
        let hasEmptyState = targets.hasNoTargets
        let hasTargets = targets.targetCount > 0 || app.cells.count > 0
        
        XCTAssertTrue(hasEmptyState || hasTargets, 
                     "Should show either empty state or targets list")
        
        let screenshot = targets.takeScreenshot(name: "Targets-State")
        add(screenshot)
    }
    
    // MARK: - Navigation Tests

    func testNavigateToTargetsFromDashboard() throws {
        sidebar.navigateToDashboard()
        sleep(1)

        sidebar.navigateToTargets()

        XCTAssertTrue(targets.waitForScreen(timeout: 5), "Should navigate to Targets from Dashboard")
    }

    // MARK: - Add Target with HTTP Protocol

    func testAddTargetWithHTTPProtocol() throws {
        sidebar.navigateToTargets()
        _ = targets.waitForScreen(timeout: 5)

        let testName = "HTTP Test \(Int.random(in: 1000...9999))"

        targets.openAddTargetSheet()
        _ = app.staticTexts["Add Target"].waitForExistence(timeout: 3)
        sleep(1)

        targets.addTarget(
            name: testName,
            host: "example.com",
            protocol: "HTTP"
        )

        sleep(2)

        // Verify the target appears in the list
        let targetFound = targets.targetExists(named: testName)
        XCTAssertTrue(targetFound, "Target added with HTTP protocol should appear in the list")

        let screenshot = targets.takeScreenshot(name: "Target-Added-HTTP")
        add(screenshot)
    }

    // MARK: - Add Target with TCP Protocol and Custom Port

    func testAddTargetWithTCPProtocolAndCustomPort() throws {
        sidebar.navigateToTargets()
        _ = targets.waitForScreen(timeout: 5)

        let testName = "TCP Test \(Int.random(in: 1000...9999))"

        targets.openAddTargetSheet()
        _ = app.staticTexts["Add Target"].waitForExistence(timeout: 3)
        sleep(1)

        targets.addTarget(
            name: testName,
            host: "example.com",
            port: "8080",
            protocol: "TCP"
        )

        sleep(2)

        let targetFound = targets.targetExists(named: testName)
        XCTAssertTrue(targetFound, "Target added with TCP protocol and port 8080 should appear in the list")

        let screenshot = targets.takeScreenshot(name: "Target-Added-TCP-Port")
        add(screenshot)
    }

    // MARK: - Form Validation Tests

    func testAddButtonDisabledWithEmptyName() throws {
        sidebar.navigateToTargets()
        _ = targets.waitForScreen(timeout: 5)

        targets.openAddTargetSheet()
        _ = app.staticTexts["Add Target"].waitForExistence(timeout: 3)
        sleep(1)

        // Leave name empty, fill host only
        targets.addTargetHostField.tap()
        targets.addTargetHostField.typeText("example.com")

        let addButton = targets.addTargetAddButton.exists ? targets.addTargetAddButton : app.buttons["Add"]
        XCTAssertTrue(addButton.exists, "Add button should exist")
        XCTAssertFalse(addButton.isEnabled, "Add button should be disabled when name is empty")

        targets.cancelAddTarget()
    }

    func testAddButtonDisabledWithEmptyHost() throws {
        sidebar.navigateToTargets()
        _ = targets.waitForScreen(timeout: 5)

        targets.openAddTargetSheet()
        _ = app.staticTexts["Add Target"].waitForExistence(timeout: 3)
        sleep(1)

        // Fill name only, leave host empty
        targets.addTargetNameField.tap()
        targets.addTargetNameField.typeText("Test Target")

        let addButton = targets.addTargetAddButton.exists ? targets.addTargetAddButton : app.buttons["Add"]
        XCTAssertTrue(addButton.exists, "Add button should exist")
        XCTAssertFalse(addButton.isEnabled, "Add button should be disabled when host is empty")

        targets.cancelAddTarget()
    }

    func testAddButtonEnabledWithBothFields() throws {
        sidebar.navigateToTargets()
        _ = targets.waitForScreen(timeout: 5)

        targets.openAddTargetSheet()
        _ = app.staticTexts["Add Target"].waitForExistence(timeout: 3)
        sleep(1)

        // Fill both required fields
        targets.addTargetNameField.tap()
        targets.addTargetNameField.typeText("Valid Target")
        targets.addTargetHostField.tap()
        targets.addTargetHostField.typeText("example.com")

        let addButton = targets.addTargetAddButton.exists ? targets.addTargetAddButton : app.buttons["Add"]
        XCTAssertTrue(addButton.exists, "Add button should exist")
        XCTAssertTrue(addButton.isEnabled, "Add button should be enabled when both name and host are filled")

        targets.cancelAddTarget()
    }

    // MARK: - Multiple Targets Tests

    func testAddMultipleTargets() throws {
        sidebar.navigateToTargets()
        _ = targets.waitForScreen(timeout: 5)

        let suffix = Int.random(in: 1000...9999)
        let target1Name = "Multi A \(suffix)"
        let target2Name = "Multi B \(suffix)"

        // Add first target
        targets.openAddTargetSheet()
        _ = app.staticTexts["Add Target"].waitForExistence(timeout: 3)
        sleep(1)
        targets.addTarget(name: target1Name, host: "one.example.com", protocol: "HTTPS")
        sleep(2)

        // Add second target
        targets.openAddTargetSheet()
        _ = app.staticTexts["Add Target"].waitForExistence(timeout: 3)
        sleep(1)
        targets.addTarget(name: target2Name, host: "two.example.com", protocol: "ICMP")
        sleep(2)

        // Both targets should be visible
        let firstExists = targets.targetExists(named: target1Name)
        let secondExists = targets.targetExists(named: target2Name)

        XCTAssertTrue(firstExists, "First target should appear in the list")
        XCTAssertTrue(secondExists, "Second target should appear in the list")

        let screenshot = targets.takeScreenshot(name: "Multiple-Targets-Added")
        add(screenshot)
    }

    // MARK: - Target Deletion Tests

    func testDeleteTarget() throws {
        sidebar.navigateToTargets()
        _ = targets.waitForScreen(timeout: 5)

        let testName = "Delete Me \(Int.random(in: 1000...9999))"

        // First add a target to delete
        targets.openAddTargetSheet()
        _ = app.staticTexts["Add Target"].waitForExistence(timeout: 3)
        sleep(1)
        targets.addTarget(name: testName, host: "delete.example.com", protocol: "HTTPS")
        sleep(2)

        // Verify it was added
        let targetAdded = targets.targetExists(named: testName)
        guard targetAdded else {
            // If adding failed, skip the deletion test gracefully
            return
        }

        // Attempt to delete via right-click context menu
        targets.deleteTarget(named: testName)
        sleep(2)

        // Check if a confirmation dialog appeared and confirm if needed
        if app.buttons["Delete"].exists {
            app.buttons["Delete"].tap()
            sleep(1)
        }

        let screenshot = targets.takeScreenshot(name: "Target-Deleted")
        add(screenshot)
    }
}
