//
//  ToolsScreen.swift
//  NetMonitorUITests
//
//  Page object for the Tools view.
//

import XCTest

final class ToolsScreen: BaseScreen {
    let app: XCUIApplication
    
    // MARK: - Tool Card Elements
    
    var pingCard: XCUIElement {
        app.otherElements["tools_card_ping"]
    }
    
    var tracerouteCard: XCUIElement {
        app.otherElements["tools_card_traceroute"]
    }
    
    var portScannerCard: XCUIElement {
        app.otherElements["tools_card_port_scanner"]
    }
    
    var dnsLookupCard: XCUIElement {
        app.otherElements["tools_card_dns_lookup"]
    }
    
    var whoisCard: XCUIElement {
        app.otherElements["tools_card_whois"]
    }
    
    var speedTestCard: XCUIElement {
        app.otherElements["tools_card_speed_test"]
    }
    
    var bonjourBrowserCard: XCUIElement {
        app.otherElements["tools_card_bonjour_browser"]
    }
    
    var wakeOnLanCard: XCUIElement {
        app.otherElements["tools_card_wake_on_lan"]
    }
    
    // Fallback text-based elements
    var pingText: XCUIElement {
        app.staticTexts["Ping"].firstMatch
    }
    
    var tracerouteText: XCUIElement {
        app.staticTexts["Traceroute"].firstMatch
    }
    
    var portScannerText: XCUIElement {
        app.staticTexts["Port Scanner"].firstMatch
    }
    
    var dnsLookupText: XCUIElement {
        app.staticTexts["DNS Lookup"].firstMatch
    }
    
    var whoisText: XCUIElement {
        app.staticTexts["WHOIS"].firstMatch
    }
    
    var speedTestText: XCUIElement {
        app.staticTexts["Speed Test"].firstMatch
    }
    
    var bonjourBrowserText: XCUIElement {
        app.staticTexts["Bonjour Browser"].firstMatch
    }
    
    var wakeOnLanText: XCUIElement {
        app.staticTexts["Wake on LAN"].firstMatch
    }
    
    // MARK: - Init
    
    init(app: XCUIApplication) {
        self.app = app
    }
    
    // MARK: - BaseScreen
    
    func waitForScreen(timeout: TimeInterval = 5) -> Bool {
        pingText.waitForExistence(timeout: timeout)
    }
    
    // MARK: - Navigation Actions
    
    @discardableResult
    func openPingTool() -> PingToolScreen {
        if pingCard.exists {
            pingCard.tap()
        } else {
            pingText.tap()
        }
        return PingToolScreen(app: app)
    }
    
    @discardableResult
    func openTracerouteTool() -> TracerouteToolScreen {
        if tracerouteCard.exists {
            tracerouteCard.tap()
        } else {
            tracerouteText.tap()
        }
        return TracerouteToolScreen(app: app)
    }
    
    @discardableResult
    func openPortScannerTool() -> PortScannerToolScreen {
        if portScannerCard.exists {
            portScannerCard.tap()
        } else {
            portScannerText.tap()
        }
        return PortScannerToolScreen(app: app)
    }
    
    @discardableResult
    func openDNSLookupTool() -> DNSLookupToolScreen {
        if dnsLookupCard.exists {
            dnsLookupCard.tap()
        } else {
            dnsLookupText.tap()
        }
        return DNSLookupToolScreen(app: app)
    }
    
    @discardableResult
    func openWhoisTool() -> WhoisToolScreen {
        if whoisCard.exists {
            whoisCard.tap()
        } else {
            whoisText.tap()
        }
        return WhoisToolScreen(app: app)
    }
    
    @discardableResult
    func openSpeedTestTool() -> SpeedTestToolScreen {
        if speedTestCard.exists {
            speedTestCard.tap()
        } else {
            speedTestText.tap()
        }
        return SpeedTestToolScreen(app: app)
    }
    
    @discardableResult
    func openBonjourBrowserTool() -> BonjourBrowserToolScreen {
        if bonjourBrowserCard.exists {
            bonjourBrowserCard.tap()
        } else {
            bonjourBrowserText.tap()
        }
        return BonjourBrowserToolScreen(app: app)
    }
    
    @discardableResult
    func openWakeOnLanTool() -> WakeOnLanToolScreen {
        if wakeOnLanCard.exists {
            wakeOnLanCard.tap()
        } else {
            wakeOnLanText.tap()
        }
        return WakeOnLanToolScreen(app: app)
    }
    
    // MARK: - Verification
    
    var allToolsVisible: Bool {
        pingText.exists &&
        tracerouteText.exists &&
        portScannerText.exists &&
        dnsLookupText.exists &&
        whoisText.exists &&
        speedTestText.exists &&
        bonjourBrowserText.exists &&
        wakeOnLanText.exists
    }
}

// MARK: - Individual Tool Screens

final class PingToolScreen: BaseScreen {
    let app: XCUIApplication
    
    var hostTextField: XCUIElement {
        app.textFields["ping_textfield_host"]
    }
    
    var runButton: XCUIElement {
        app.buttons["ping_button_run"]
    }
    
    var closeButton: XCUIElement {
        app.buttons["ping_button_close"]
    }
    
    var clearButton: XCUIElement {
        app.buttons["ping_button_clear"]
    }
    
    var countPicker: XCUIElement {
        app.popUpButtons["ping_picker_count"]
    }
    
    init(app: XCUIApplication) {
        self.app = app
    }
    
    func waitForScreen(timeout: TimeInterval = 5) -> Bool {
        hostTextField.waitForExistence(timeout: timeout) ||
        app.staticTexts["Ping"].waitForExistence(timeout: timeout)
    }
    
    func runPing(host: String) {
        if hostTextField.exists {
            hostTextField.tap()
            hostTextField.typeText(host)
        }
        if runButton.exists {
            runButton.tap()
        } else {
            app.buttons["Run"].tap()
        }
    }
    
    func close() {
        if closeButton.exists {
            closeButton.tap()
        } else {
            // Press Escape
            app.typeKey(.escape, modifierFlags: [])
        }
    }
    
    var isRunning: Bool {
        app.buttons["Stop"].exists ||
        (runButton.exists && runButton.label == "Stop")
    }
    
    var hasOutput: Bool {
        // Look for typical ping output
        app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'bytes from'")).count > 0 ||
        app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'PING'")).count > 0
    }
}

final class TracerouteToolScreen: BaseScreen {
    let app: XCUIApplication
    
    var hostTextField: XCUIElement {
        app.textFields["traceroute_textfield_host"]
    }
    
    var runButton: XCUIElement {
        app.buttons["traceroute_button_run"]
    }
    
    var closeButton: XCUIElement {
        app.buttons["traceroute_button_close"]
    }
    
    init(app: XCUIApplication) {
        self.app = app
    }
    
    func waitForScreen(timeout: TimeInterval = 5) -> Bool {
        app.staticTexts["Traceroute"].waitForExistence(timeout: timeout)
    }
    
    func runTraceroute(host: String) {
        if hostTextField.exists {
            hostTextField.tap()
            hostTextField.typeText(host)
        } else {
            // Try generic text field
            let textField = app.textFields.firstMatch
            textField.tap()
            textField.typeText(host)
        }
        if runButton.exists {
            runButton.tap()
        } else {
            app.buttons["Run"].tap()
        }
    }
    
    func close() {
        if closeButton.exists {
            closeButton.tap()
        } else {
            app.typeKey(.escape, modifierFlags: [])
        }
    }
}

final class PortScannerToolScreen: BaseScreen {
    let app: XCUIApplication
    
    var hostTextField: XCUIElement {
        app.textFields["portscan_textfield_host"]
    }
    
    var scanButton: XCUIElement {
        app.buttons["portscan_button_scan"]
    }
    
    var closeButton: XCUIElement {
        app.buttons["portscan_button_close"]
    }

    var presetPicker: XCUIElement {
        app.popUpButtons["portscan_picker_preset"]
    }

    var customPortsField: XCUIElement {
        app.textFields["portscan_textfield_custom"]
    }

    var clearButton: XCUIElement {
        app.buttons["portscan_button_clear"]
    }
    
    init(app: XCUIApplication) {
        self.app = app
    }
    
    func waitForScreen(timeout: TimeInterval = 5) -> Bool {
        app.staticTexts["Port Scanner"].waitForExistence(timeout: timeout)
    }
    
    func close() {
        if closeButton.exists {
            closeButton.tap()
        } else {
            app.typeKey(.escape, modifierFlags: [])
        }
    }
}

final class DNSLookupToolScreen: BaseScreen {
    let app: XCUIApplication
    
    var domainTextField: XCUIElement {
        app.textFields["dns_textfield_hostname"]
    }
    
    var lookupButton: XCUIElement {
        app.buttons["dns_button_lookup"]
    }
    
    var closeButton: XCUIElement {
        app.buttons["dns_button_close"]
    }

    var typePicker: XCUIElement {
        app.popUpButtons["dns_picker_type"]
    }

    var clearButton: XCUIElement {
        app.buttons["dns_button_clear"]
    }
    
    init(app: XCUIApplication) {
        self.app = app
    }
    
    func waitForScreen(timeout: TimeInterval = 5) -> Bool {
        app.staticTexts["DNS Lookup"].waitForExistence(timeout: timeout)
    }
    
    func close() {
        if closeButton.exists {
            closeButton.tap()
        } else {
            app.typeKey(.escape, modifierFlags: [])
        }
    }
}

final class WhoisToolScreen: BaseScreen {
    let app: XCUIApplication
    
    var domainTextField: XCUIElement {
        app.textFields["whois_textfield_domain"]
    }
    
    var lookupButton: XCUIElement {
        app.buttons["whois_button_lookup"]
    }
    
    var closeButton: XCUIElement {
        app.buttons["whois_button_close"]
    }

    var clearButton: XCUIElement {
        app.buttons["whois_button_clear"]
    }
    
    init(app: XCUIApplication) {
        self.app = app
    }
    
    func waitForScreen(timeout: TimeInterval = 5) -> Bool {
        app.staticTexts["WHOIS"].waitForExistence(timeout: timeout)
    }
    
    func close() {
        if closeButton.exists {
            closeButton.tap()
        } else {
            app.typeKey(.escape, modifierFlags: [])
        }
    }
}

final class SpeedTestToolScreen: BaseScreen {
    let app: XCUIApplication
    
    var startButton: XCUIElement {
        app.buttons["speedtest_button_start"]
    }

    var stopButton: XCUIElement {
        app.buttons["speedtest_button_stop"]
    }

    var resetButton: XCUIElement {
        app.buttons["speedtest_button_reset"]
    }
    
    var closeButton: XCUIElement {
        app.buttons["speedtest_button_close"]
    }
    
    init(app: XCUIApplication) {
        self.app = app
    }
    
    func waitForScreen(timeout: TimeInterval = 5) -> Bool {
        app.staticTexts["Speed Test"].waitForExistence(timeout: timeout)
    }
    
    func close() {
        if closeButton.exists {
            closeButton.tap()
        } else {
            app.typeKey(.escape, modifierFlags: [])
        }
    }
}

final class BonjourBrowserToolScreen: BaseScreen {
    let app: XCUIApplication
    
    var refreshButton: XCUIElement {
        app.buttons["bonjour_button_refresh"]
    }

    var closeButton: XCUIElement {
        app.buttons["bonjour_button_close"]
    }
    
    init(app: XCUIApplication) {
        self.app = app
    }
    
    func waitForScreen(timeout: TimeInterval = 5) -> Bool {
        app.staticTexts["Bonjour Browser"].waitForExistence(timeout: timeout)
    }
    
    func close() {
        if closeButton.exists {
            closeButton.tap()
        } else {
            app.typeKey(.escape, modifierFlags: [])
        }
    }
}

final class WakeOnLanToolScreen: BaseScreen {
    let app: XCUIApplication
    
    var devicePicker: XCUIElement {
        app.popUpButtons["wol_picker_device"]
    }

    var macAddressTextField: XCUIElement {
        app.textFields["wol_textfield_mac"]
    }

    var broadcastTextField: XCUIElement {
        app.textFields["wol_textfield_broadcast"]
    }

    var wakeButton: XCUIElement {
        app.buttons["wol_button_send"]
    }
    
    var closeButton: XCUIElement {
        app.buttons["wol_button_close"]
    }
    
    init(app: XCUIApplication) {
        self.app = app
    }
    
    func waitForScreen(timeout: TimeInterval = 5) -> Bool {
        app.staticTexts["Wake on LAN"].waitForExistence(timeout: timeout)
    }
    
    func close() {
        if closeButton.exists {
            closeButton.tap()
        } else {
            app.typeKey(.escape, modifierFlags: [])
        }
    }
}
