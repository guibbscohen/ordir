//
//  TurnGuideUITests.swift
//  OrdirUITests
//
//  Taps "Done" through the whole Dune guide in the simulator. With every expansion on, it also
//  screenshots each step at the top, part-way down and at the bottom of both halves, so sections
//  below the fold (expansion rules, turn-change checklists) are captured. Screenshots go to SCREENSHOT_DIR when
//  set (CI passes it as TEST_RUNNER_SCREENSHOT_DIR) and are always attached to the test result.
//

import XCTest

final class TurnGuideUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    func testBaseGameTapThrough() {
        tapThrough(expansionIDs: [], screenshots: false, fightsABattle: true)
    }

    func testAllExpansionsTapThroughWithScreenshots() {
        tapThrough(expansionIDs: ["desertWar", "smugglers", "spacingGuild"], screenshots: true)
    }

    func testPassThePhoneTapThrough() {
        tapThrough(expansionIDs: [], screenshots: false, passThePhone: true)
    }

    private func tapThrough(expansionIDs: [String], screenshots: Bool, passThePhone: Bool = false, fightsABattle: Bool = false) {
        let app = XCUIApplication()
        app.launchArguments = ["-OrdirOpenGame", "duneWarForArrakis"]
        app.launch()

        XCTAssertTrue(app.buttons["Start guide"].waitForExistence(timeout: 20), "setup picker not shown")
        if passThePhone {
            app.buttons["mode-pass"].tap()
        }
        for id in expansionIDs {
            let toggle = app.switches["expansion-\(id)"]
            XCTAssertTrue(toggle.waitForExistence(timeout: 5), "no switch for \(id)")
            toggle.tap()
            if !isOn(toggle) {
                // The switch element spans the row; tap the switch itself at the trailing edge.
                toggle.coordinate(withNormalizedOffset: CGVector(dx: 0.92, dy: 0.5)).tap()
            }
            XCTAssertTrue(isOn(toggle), "\(id) did not switch on")
        }
        app.buttons["Start guide"].tap()

        let progress = app.descendants(matching: .any)["guide-progress"]
        XCTAssertTrue(progress.waitForExistence(timeout: 10), "guide did not start")

        var steps = 0
        var turnsInLoop = 0
        var handoffs = 0
        var foughtBattle = false
        let handoff = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "I’m the")).firstMatch
        // Play setup and round 1; the guide then starts round 2 on its own.
        while !progress.label.contains("Round 2") {
            // Pass-the-phone play: the next player takes the phone before seeing their step.
            if handoff.exists {
                handoffs += 1
                XCTAssertLessThan(handoffs, 100, "handoff screen keeps coming back")
                handoff.tap()
                Thread.sleep(forTimeInterval: 0.6)
                continue
            }
            steps += 1
            XCTAssertLessThan(steps, 150, "guide never finished")
            let before = progress.label

            if screenshots {
                capture(app, name: String(format: "%03d-top", steps))
                scrollBothHalves(app)
                capture(app, name: String(format: "%03d-middle", steps))
                for _ in 0..<3 { scrollBothHalves(app) }
                capture(app, name: String(format: "%03d-bottom", steps))
            }

            // Action turns loop: play one Atreides and one Harkonnen turn, then end the phase.
            let endLoop = app.buttons["Harkonnen dice all used"]
            // Read before tapping: Done on the last step before the loop makes this button appear.
            let isActionTurn = endLoop.exists
            if fightsABattle, !foughtBattle, isActionTurn, app.buttons["Start a battle"].exists {
                foughtBattle = true
                fightBattle(app)
                continue
            }
            if isActionTurn, turnsInLoop >= 2 {
                endLoop.tap()
                turnsInLoop = 0
            } else {
                if isActionTurn { turnsInLoop += 1 }
                let done = app.buttons["Done"].firstMatch
                XCTAssertTrue(done.waitForExistence(timeout: 5), "no Done button on \(before)")
                done.tap()
            }
            // Action turns stop at the "Before you pass the turn" checklist.
            if isActionTurn {
                let pass = app.buttons["Pass the turn"]
                XCTAssertTrue(pass.waitForExistence(timeout: 5), "no turn-change checklist on \(before)")
                if screenshots { capture(app, name: String(format: "%03d-checklist", steps)) }
                pass.tap()
            }
            waitForStepChange(progress, from: before, app: app)
        }
        XCTAssertGreaterThan(steps, 20, "too few steps for setup plus a round")

        // End the game from the Game menu.
        app.buttons["Game menu"].tap()
        let atreidesWon = app.buttons["The Atreides won"]
        XCTAssertTrue(atreidesWon.waitForExistence(timeout: 5), "Game menu did not open")
        atreidesWon.tap()
        XCTAssertTrue(app.staticTexts["Game over"].waitForExistence(timeout: 5), "game did not end")
        if fightsABattle {
            XCTAssertTrue(foughtBattle, "never offered to start a battle")
        }
        if passThePhone {
            XCTAssertGreaterThan(handoffs, 5, "pass-the-phone play never asked to pass the phone")
        }
        if screenshots { capture(app, name: "999-finished") }
    }

    /// Starts a battle from the current Action turn, plays two combat rounds, and returns to the turn.
    private func fightBattle(_ app: XCUIApplication) {
        app.buttons["Start a battle"].firstMatch.tap()
        XCTAssertTrue(app.buttons["Leave battle"].waitForExistence(timeout: 5), "battle did not open")
        var combatTaps = 0
        for _ in 0..<60 {
            if app.buttons["Back to the turn"].exists {
                app.buttons["Back to the turn"].tap()
                XCTAssertTrue(app.buttons["Harkonnen dice all used"].waitForExistence(timeout: 5), "not back on the turn")
                return
            }
            let battleOver = app.buttons["Battle over"]
            if battleOver.exists {
                combatTaps += 1
                // Six steps per combat round: play two rounds, then end the battle.
                if combatTaps > 12 {
                    battleOver.tap()
                    Thread.sleep(forTimeInterval: 0.8)
                    continue
                }
            }
            let done = app.buttons["Done"].firstMatch
            XCTAssertTrue(done.waitForExistence(timeout: 5), "no Done button in the battle")
            done.tap()
            Thread.sleep(forTimeInterval: 0.8)
        }
        XCTFail("battle never finished")
    }

    private func isOn(_ toggle: XCUIElement) -> Bool {
        (toggle.value as? String) == "1"
    }

    /// Waits until the progress label changes (or the guide finishes), then lets the transition settle
    /// so the outgoing step's Done button is gone before the next tap.
    private func waitForStepChange(_ progress: XCUIElement, from before: String, app: XCUIApplication) {
        let deadline = Date().addingTimeInterval(8)
        while Date() < deadline {
            if app.staticTexts["Game over"].exists { return }
            if progress.exists, progress.label != before { break }
            Thread.sleep(forTimeInterval: 0.1)
        }
        XCTAssertTrue(
            app.staticTexts["Game over"].exists || progress.label != before,
            "Done did not advance past \(before)"
        )
        Thread.sleep(forTimeInterval: 0.6)
    }

    /// Drags each half toward the middle bar, which scrolls its content: the far half is upside down.
    private func scrollBothHalves(_ app: XCUIApplication) {
        let window = app.windows.firstMatch
        func drag(from start: CGFloat, to end: CGFloat) {
            window.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: start))
                .press(forDuration: 0.05, thenDragTo: window.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: end)))
        }
        drag(from: 0.85, to: 0.6)
        drag(from: 0.15, to: 0.4)
    }

    private func capture(_ app: XCUIApplication, name: String) {
        let screenshot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
        if let dir = ProcessInfo.processInfo.environment["SCREENSHOT_DIR"], !dir.isEmpty {
            let url = URL(fileURLWithPath: dir).appendingPathComponent("\(name).png")
            try? screenshot.pngRepresentation.write(to: url)
        }
    }
}
