//
//  NetMonitorUITests.swift
//  NetMonitorUITests
//
//  Created on 2026-01-10.
//

import XCTest

final class NetMonitorUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        // In UI tests it is usually best to stop immediately when a failure occurs.
        continueAfterFailure = false

        // Create and configure the app
        app = XCUIApplication()

        // Add launch argument to indicate test mode
        app.launchArguments = ["--uitesting"]
    }

    override func tearDownWithError() throws {
        // Ensure app is terminated after each test
        app?.terminate()
        app = nil
    }

    @MainActor
    func testExample() throws {
        // Launch the application with test arguments
        app.launch()

        // Verify the app launched successfully by checking for main window
        let windowExists = app.windows.firstMatch.waitForExistence(timeout: 5)
        XCTAssertTrue(windowExists, "App should have at least one window")

        // Terminate the app (best effort - may fail due to stuck processes)
        app.terminate()
    }

    @MainActor
    func testLaunchPerformance() throws {
        if #available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 7.0, *) {
            // This measures how long it takes to launch your application.
            measure(metrics: [XCTApplicationLaunchMetric()]) {
                app.launch()
                app.terminate()
            }
        }
    }
}
