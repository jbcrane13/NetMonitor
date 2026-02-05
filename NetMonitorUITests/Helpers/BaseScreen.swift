//
//  BaseScreen.swift
//  NetMonitorUITests
//
//  Base protocol for all screen objects with common utilities.
//

import XCTest

protocol BaseScreen {
    var app: XCUIApplication { get }
    
    /// Wait for the screen to be loaded
    func waitForScreen(timeout: TimeInterval) -> Bool
}

extension BaseScreen {
    /// Wait for an element to exist
    func waitForElement(_ element: XCUIElement, timeout: TimeInterval = 5) -> Bool {
        element.waitForExistence(timeout: timeout)
    }
    
    /// Tap an element if it exists
    func tapIfExists(_ element: XCUIElement, timeout: TimeInterval = 2) -> Bool {
        if element.waitForExistence(timeout: timeout) {
            element.tap()
            return true
        }
        return false
    }
    
    /// Type text into a text field
    func typeText(_ element: XCUIElement, text: String) {
        element.tap()
        element.typeText(text)
    }
    
    /// Clear and type text into a text field
    func clearAndTypeText(_ element: XCUIElement, text: String) {
        element.tap()
        element.tap() // Double tap to select all
        if element.value as? String != "" {
            element.typeText(XCUIKeyboardKey.delete.rawValue)
        }
        element.typeText(text)
    }
    
    /// Wait for element to disappear
    func waitForElementToDisappear(_ element: XCUIElement, timeout: TimeInterval = 5) -> Bool {
        let predicate = NSPredicate(format: "exists == false")
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: element)
        let result = XCTWaiter.wait(for: [expectation], timeout: timeout)
        return result == .completed
    }
    
    /// Take a screenshot with a name
    func takeScreenshot(name: String) -> XCTAttachment {
        let screenshot = app.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        return attachment
    }
}

// MARK: - XCUIElement Extensions

extension XCUIElement {
    /// Scroll to element if not visible
    func scrollToElement(in scrollView: XCUIElement) {
        var maxScrolls = 10
        while !isHittable && maxScrolls > 0 {
            scrollView.swipeUp()
            maxScrolls -= 1
        }
    }
    
    /// Wait for element to be hittable
    func waitUntilHittable(timeout: TimeInterval = 5) -> Bool {
        let predicate = NSPredicate(format: "isHittable == true")
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: self)
        let result = XCTWaiter.wait(for: [expectation], timeout: timeout)
        return result == .completed
    }
    
    /// Force tap using coordinate
    func forceTap() {
        coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
    }
}
