//
//  ToolsUITests.swift
//  NetMonitorUITests
//
//  Comprehensive UI tests for the Tools view and individual tools.
//

import XCTest

final class ToolsUITests: BaseUITests {
    
    var sidebar: SidebarScreen!
    var tools: ToolsScreen!
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        
        sidebar = SidebarScreen(app: app)
        tools = ToolsScreen(app: app)
        
        XCTAssertTrue(sidebar.waitForScreen(timeout: 15), "App should launch")
    }
    
    // MARK: - Tools View Loading
    
    func testToolsViewLoads() throws {
        sidebar.navigateToTools()
        
        XCTAssertTrue(tools.waitForScreen(timeout: 5), "Tools view should load")
        
        let screenshot = tools.takeScreenshot(name: "Tools-View")
        add(screenshot)
    }
    
    func testAllToolCardsVisible() throws {
        sidebar.navigateToTools()
        _ = tools.waitForScreen(timeout: 5)
        
        // Verify all 8 tools are visible
        XCTAssertTrue(tools.pingText.exists, "Ping tool should be visible")
        XCTAssertTrue(tools.tracerouteText.exists, "Traceroute tool should be visible")
        XCTAssertTrue(tools.portScannerText.exists, "Port Scanner tool should be visible")
        XCTAssertTrue(tools.dnsLookupText.exists, "DNS Lookup tool should be visible")
        XCTAssertTrue(tools.whoisText.exists, "WHOIS tool should be visible")
        XCTAssertTrue(tools.speedTestText.exists, "Speed Test tool should be visible")
        XCTAssertTrue(tools.bonjourBrowserText.exists, "Bonjour Browser tool should be visible")
        XCTAssertTrue(tools.wakeOnLanText.exists, "Wake on LAN tool should be visible")
    }
    
    // MARK: - Ping Tool Tests
    
    func testPingToolOpens() throws {
        sidebar.navigateToTools()
        _ = tools.waitForScreen(timeout: 5)
        
        let pingScreen = tools.openPingTool()
        
        XCTAssertTrue(pingScreen.waitForScreen(timeout: 5), "Ping tool should open")
        
        let screenshot = pingScreen.takeScreenshot(name: "Ping-Tool")
        add(screenshot)
        
        pingScreen.close()
    }
    
    func testPingToolHasHostField() throws {
        sidebar.navigateToTools()
        _ = tools.waitForScreen(timeout: 5)
        
        let pingScreen = tools.openPingTool()
        _ = pingScreen.waitForScreen(timeout: 5)
        
        let hasHostField = pingScreen.hostTextField.exists || app.textFields.firstMatch.exists
        XCTAssertTrue(hasHostField, "Ping tool should have host input field")
        
        pingScreen.close()
    }
    
    func testPingToolRunButton() throws {
        sidebar.navigateToTools()
        _ = tools.waitForScreen(timeout: 5)
        
        let pingScreen = tools.openPingTool()
        _ = pingScreen.waitForScreen(timeout: 5)
        
        let hasRunButton = pingScreen.runButton.exists || app.buttons["Run"].exists
        XCTAssertTrue(hasRunButton, "Ping tool should have Run button")
        
        pingScreen.close()
    }
    
    func testPingToolExecutes() throws {
        sidebar.navigateToTools()
        _ = tools.waitForScreen(timeout: 5)
        
        let pingScreen = tools.openPingTool()
        _ = pingScreen.waitForScreen(timeout: 5)
        
        // Run ping against localhost (should always work)
        pingScreen.runPing(host: "127.0.0.1")
        
        // Wait for some output
        sleep(3)
        
        let screenshot = pingScreen.takeScreenshot(name: "Ping-Executing")
        add(screenshot)
        
        pingScreen.close()
    }
    
    // MARK: - Traceroute Tool Tests
    
    func testTracerouteToolOpens() throws {
        sidebar.navigateToTools()
        _ = tools.waitForScreen(timeout: 5)
        
        let tracerouteScreen = tools.openTracerouteTool()
        
        XCTAssertTrue(tracerouteScreen.waitForScreen(timeout: 5), "Traceroute tool should open")
        
        let screenshot = tracerouteScreen.takeScreenshot(name: "Traceroute-Tool")
        add(screenshot)
        
        tracerouteScreen.close()
    }

    func testTracerouteToolExecutes() throws {
        sidebar.navigateToTools()
        _ = tools.waitForScreen(timeout: 5)
        
        let tracerouteScreen = tools.openTracerouteTool()
        _ = tracerouteScreen.waitForScreen(timeout: 5)
        
        if tracerouteScreen.hostTextField.exists {
            tracerouteScreen.hostTextField.tap()
            tracerouteScreen.hostTextField.typeText("127.0.0.1")
        }
        
        if tracerouteScreen.runButton.exists {
            tracerouteScreen.runButton.tap()
        } else {
            app.buttons["Run"].tap()
        }
        
        sleep(2)
        
        let screenshot = tracerouteScreen.takeScreenshot(name: "Traceroute-Running")
        add(screenshot)
        
        tracerouteScreen.close()
    }
    
    // MARK: - Port Scanner Tool Tests
    
    func testPortScannerToolOpens() throws {
        sidebar.navigateToTools()
        _ = tools.waitForScreen(timeout: 5)
        
        let portScannerScreen = tools.openPortScannerTool()
        
        XCTAssertTrue(portScannerScreen.waitForScreen(timeout: 5), "Port Scanner tool should open")
        
        let screenshot = portScannerScreen.takeScreenshot(name: "PortScanner-Tool")
        add(screenshot)
        
        portScannerScreen.close()
    }

    func testPortScannerToolExecutes() throws {
        sidebar.navigateToTools()
        _ = tools.waitForScreen(timeout: 5)
        
        let portScannerScreen = tools.openPortScannerTool()
        _ = portScannerScreen.waitForScreen(timeout: 5)
        
        if portScannerScreen.hostTextField.exists {
            portScannerScreen.hostTextField.tap()
            portScannerScreen.hostTextField.typeText("127.0.0.1")
        }
        
        if portScannerScreen.scanButton.exists {
            portScannerScreen.scanButton.tap()
        } else {
            app.buttons["Scan"].tap()
        }
        
        sleep(2)
        
        let screenshot = portScannerScreen.takeScreenshot(name: "PortScanner-Running")
        add(screenshot)
        
        if portScannerScreen.scanButton.exists && portScannerScreen.scanButton.label == "Stop" {
            portScannerScreen.scanButton.tap()
        }
        
        portScannerScreen.close()
    }
    
    // MARK: - DNS Lookup Tool Tests
    
    func testDNSLookupToolOpens() throws {
        sidebar.navigateToTools()
        _ = tools.waitForScreen(timeout: 5)
        
        let dnsScreen = tools.openDNSLookupTool()
        
        XCTAssertTrue(dnsScreen.waitForScreen(timeout: 5), "DNS Lookup tool should open")
        
        let screenshot = dnsScreen.takeScreenshot(name: "DNSLookup-Tool")
        add(screenshot)
        
        dnsScreen.close()
    }

    func testDNSLookupToolExecutes() throws {
        sidebar.navigateToTools()
        _ = tools.waitForScreen(timeout: 5)
        
        let dnsScreen = tools.openDNSLookupTool()
        _ = dnsScreen.waitForScreen(timeout: 5)
        
        if dnsScreen.domainTextField.exists {
            dnsScreen.domainTextField.tap()
            dnsScreen.domainTextField.typeText("example.com")
        }
        
        if dnsScreen.lookupButton.exists {
            dnsScreen.lookupButton.tap()
        } else {
            app.buttons["Lookup"].tap()
        }
        
        sleep(2)
        
        let screenshot = dnsScreen.takeScreenshot(name: "DNSLookup-Running")
        add(screenshot)
        
        dnsScreen.close()
    }
    
    // MARK: - WHOIS Tool Tests
    
    func testWhoisToolOpens() throws {
        sidebar.navigateToTools()
        _ = tools.waitForScreen(timeout: 5)
        
        let whoisScreen = tools.openWhoisTool()
        
        XCTAssertTrue(whoisScreen.waitForScreen(timeout: 5), "WHOIS tool should open")
        
        let screenshot = whoisScreen.takeScreenshot(name: "WHOIS-Tool")
        add(screenshot)
        
        whoisScreen.close()
    }

    func testWhoisToolExecutes() throws {
        sidebar.navigateToTools()
        _ = tools.waitForScreen(timeout: 5)
        
        let whoisScreen = tools.openWhoisTool()
        _ = whoisScreen.waitForScreen(timeout: 5)
        
        if whoisScreen.domainTextField.exists {
            whoisScreen.domainTextField.tap()
            whoisScreen.domainTextField.typeText("example.com")
        }
        
        if whoisScreen.lookupButton.exists {
            whoisScreen.lookupButton.tap()
        } else {
            app.buttons["Lookup"].tap()
        }
        
        sleep(2)
        
        let screenshot = whoisScreen.takeScreenshot(name: "WHOIS-Running")
        add(screenshot)
        
        whoisScreen.close()
    }
    
    // MARK: - Speed Test Tool Tests
    
    func testSpeedTestToolOpens() throws {
        sidebar.navigateToTools()
        _ = tools.waitForScreen(timeout: 5)
        
        let speedTestScreen = tools.openSpeedTestTool()
        
        XCTAssertTrue(speedTestScreen.waitForScreen(timeout: 5), "Speed Test tool should open")
        
        let screenshot = speedTestScreen.takeScreenshot(name: "SpeedTest-Tool")
        add(screenshot)
        
        speedTestScreen.close()
    }

    func testSpeedTestToolStartStop() throws {
        sidebar.navigateToTools()
        _ = tools.waitForScreen(timeout: 5)
        
        let speedTestScreen = tools.openSpeedTestTool()
        _ = speedTestScreen.waitForScreen(timeout: 5)
        
        if speedTestScreen.startButton.exists {
            speedTestScreen.startButton.tap()
        } else if app.buttons["Start"].exists {
            app.buttons["Start"].tap()
        }
        
        sleep(3)
        
        if speedTestScreen.stopButton.exists {
            speedTestScreen.stopButton.tap()
        }
        
        let screenshot = speedTestScreen.takeScreenshot(name: "SpeedTest-Started")
        add(screenshot)
        
        speedTestScreen.close()
    }
    
    // MARK: - Bonjour Browser Tool Tests
    
    func testBonjourBrowserToolOpens() throws {
        sidebar.navigateToTools()
        _ = tools.waitForScreen(timeout: 5)
        
        let bonjourScreen = tools.openBonjourBrowserTool()
        
        XCTAssertTrue(bonjourScreen.waitForScreen(timeout: 5), "Bonjour Browser tool should open")
        
        let screenshot = bonjourScreen.takeScreenshot(name: "BonjourBrowser-Tool")
        add(screenshot)
        
        bonjourScreen.close()
    }

    func testBonjourBrowserRefresh() throws {
        sidebar.navigateToTools()
        _ = tools.waitForScreen(timeout: 5)
        
        let bonjourScreen = tools.openBonjourBrowserTool()
        _ = bonjourScreen.waitForScreen(timeout: 5)
        
        if bonjourScreen.refreshButton.exists {
            bonjourScreen.refreshButton.tap()
        }
        
        sleep(2)
        
        let screenshot = bonjourScreen.takeScreenshot(name: "BonjourBrowser-Refreshed")
        add(screenshot)
        
        bonjourScreen.close()
    }
    
    // MARK: - Wake on LAN Tool Tests
    
    func testWakeOnLanToolOpens() throws {
        sidebar.navigateToTools()
        _ = tools.waitForScreen(timeout: 5)
        
        let wolScreen = tools.openWakeOnLanTool()
        
        XCTAssertTrue(wolScreen.waitForScreen(timeout: 5), "Wake on LAN tool should open")
        
        let screenshot = wolScreen.takeScreenshot(name: "WakeOnLAN-Tool")
        add(screenshot)
        
        wolScreen.close()
    }

    func testWakeOnLanToolFields() throws {
        sidebar.navigateToTools()
        _ = tools.waitForScreen(timeout: 5)
        
        let wolScreen = tools.openWakeOnLanTool()
        _ = wolScreen.waitForScreen(timeout: 5)
        
        XCTAssertTrue(wolScreen.macAddressTextField.exists || app.textFields.firstMatch.exists,
                      "Wake on LAN should have a MAC address field")
        
        if wolScreen.macAddressTextField.exists {
            wolScreen.macAddressTextField.tap()
            wolScreen.macAddressTextField.typeText("AA:BB:CC:DD:EE:FF")
        }
        
        if wolScreen.wakeButton.exists {
            wolScreen.wakeButton.tap()
        }
        
        let screenshot = wolScreen.takeScreenshot(name: "WakeOnLAN-Fields")
        add(screenshot)
        
        wolScreen.close()
    }
    
    // MARK: - Close Tool Tests
    
    func testCloseToolWithEscape() throws {
        sidebar.navigateToTools()
        _ = tools.waitForScreen(timeout: 5)
        
        let pingScreen = tools.openPingTool()
        _ = pingScreen.waitForScreen(timeout: 5)
        
        // Close with Escape key
        app.typeKey(.escape, modifierFlags: [])
        
        // Verify tool closed
        sleep(1)
        XCTAssertTrue(tools.pingText.exists, "Should return to tools view after closing")
    }
    
    // MARK: - Navigation Tests
    
    func testNavigateToToolsFromDashboard() throws {
        sidebar.navigateToDashboard()
        sleep(1)
        
        sidebar.navigateToTools()
        
        XCTAssertTrue(tools.waitForScreen(timeout: 5), "Should navigate to Tools from Dashboard")
    }
    
    func testOpenAndCloseMultipleTools() throws {
        sidebar.navigateToTools()
        _ = tools.waitForScreen(timeout: 5)
        
        // Open and close each tool in sequence
        let pingScreen = tools.openPingTool()
        _ = pingScreen.waitForScreen(timeout: 3)
        pingScreen.close()
        _ = tools.waitForScreen(timeout: 3)
        
        let tracerouteScreen = tools.openTracerouteTool()
        _ = tracerouteScreen.waitForScreen(timeout: 3)
        tracerouteScreen.close()
        _ = tools.waitForScreen(timeout: 3)
        
        let dnsScreen = tools.openDNSLookupTool()
        _ = dnsScreen.waitForScreen(timeout: 3)
        dnsScreen.close()
        
        XCTAssertTrue(tools.waitForScreen(timeout: 5), "Should be back at tools view")
    }
}
