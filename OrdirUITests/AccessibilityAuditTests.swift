//
//  AccessibilityAuditTests.swift
//  OrdirUITests
//
//  Runs Xcode's accessibility audit (labels, contrast, hit regions, Dynamic Type, clipped text,
//  traits) on each kind of guide screen, at the default text size and at the largest accessibility
//  size. Launch arguments jump straight to the screen, so each test takes seconds.
//

import XCTest

final class AccessibilityAuditTests: XCTestCase {
    override func setUp() {
        continueAfterFailure = true
    }

    func testHome() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-OrdirTourDone", "YES", "-OrdirLanguage", "en"]
        app.launch()
        // The opening plays first, then Home.
        XCTAssertTrue(app.staticTexts["Choose a game"].waitForExistence(timeout: 20))
        let comingSoon = app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS[c] %@", "coming soon"))
        XCTAssertEqual(comingSoon.count, 0, "Every game on Home has a turn guide now")
        try audit(app)
    }

    func testSetupPicker() throws {
        let app = launch()
        XCTAssertTrue(app.buttons["Start guide"].waitForExistence(timeout: 20))
        try audit(app)
    }

    func testStepForBothPlayers() throws {
        try auditStep("round-draw-planning")
    }

    func testStepForBothPlayersLargestText() throws {
        try auditStep("round-draw-planning", largestText: true)
    }

    func testActionTurnAndChecklist() throws {
        let app = try auditStep("turn-atreides")
        app.buttons["Done"].firstMatch.tap()
        XCTAssertTrue(app.buttons["Pass the turn"].waitForExistence(timeout: 5))
        try audit(app)
    }

    func testActionTurnLargestText() throws {
        try auditStep("turn-atreides", largestText: true)
    }

    func testBattle() throws {
        let app = try auditStep("turn-atreides")
        app.buttons["Start a battle"].firstMatch.tap()
        XCTAssertTrue(app.buttons["Leave battle"].waitForExistence(timeout: 5))
        try audit(app)
    }

    func testPassThePhoneHandoff() throws {
        let app = launch(step: "actions-roll", passThePhone: true)
        let done = app.buttons["Done"].firstMatch
        XCTAssertTrue(done.waitForExistence(timeout: 20))
        done.tap()
        let ready = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "I’m the")).firstMatch
        XCTAssertTrue(ready.waitForExistence(timeout: 5), "no handoff screen")
        try audit(app)
    }

    // MARK: Helpers

    @discardableResult
    private func auditStep(_ step: String, largestText: Bool = false) throws -> XCUIApplication {
        let app = launch(step: step, largestText: largestText)
        XCTAssertTrue(app.buttons["Done"].firstMatch.waitForExistence(timeout: 20), "step \(step) not shown")
        try audit(app)
        return app
    }

    private func launch(step: String? = nil, passThePhone: Bool = false, largestText: Bool = false) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-OrdirOpenGame", "duneWarForArrakis", "-OrdirLanguage", "en"]
        if let step { app.launchArguments += ["-OrdirStartStep", step] }
        if passThePhone { app.launchArguments += ["-OrdirPlayMode", "pass"] }
        if largestText {
            app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        }
        app.launch()
        return app
    }

    /// Fails the test with one message per issue the audit finds, naming the element.
    private func audit(_ app: XCUIApplication) throws {
        // Let step transitions and the mascot settle so the audit sees the resting screen.
        Thread.sleep(forTimeInterval: 1)
        try app.performAccessibilityAudit { issue in
            let element = issue.element
            let label = element?.label ?? "?"
            let frame = element.map { "\($0.frame.integral)" } ?? "?"
            XCTFail("\(issue.compactDescription): \"\(label)\" (\(element?.elementType.rawValue ?? 0)) at \(frame). \(issue.detailedDescription)")
            return true
        }
    }
}
