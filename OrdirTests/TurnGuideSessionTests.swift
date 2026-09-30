//
//  TurnGuideSessionTests.swift
//  OrdirTests
//
//  Walks the bundled Dune script through TurnGuideSession for the base game, each expansion
//  alone and all of them together.
//

import UIKit
import XCTest
@testable import Ordir

final class TurnGuideSessionTests: XCTestCase {
    private var script: TurnScript!

    override func setUpWithError() throws {
        script = try XCTUnwrap(TurnScript.bundled(for: .duneWarForArrakis), "Dune turn script missing or invalid")
    }

    private var allExpansions: Set<String> { Set(script.expansions.map(\.id)) }

    /// Every expansion combination worth checking: none, each alone, all.
    private var expansionSets: [Set<String>] {
        [[]] + allExpansions.sorted().map { [$0] } + [allExpansions]
    }

    /// Step ids in script order, keeping only those that apply with `expansions`.
    private func expectedSteps(with expansions: Set<String>) -> [String] {
        let steps: [TurnScript.Step] = script.phases.flatMap(\.steps)
        let applicable = steps.filter { step in
            guard let expansion = step.expansion else { return true }
            return expansions.contains(expansion)
        }
        return applicable.map(\.id)
    }

    /// Taps "Done" through the whole guide; each loop runs one pass of its turns, then ends.
    private func walk(_ session: TurnGuideSession, check: (TurnGuideSession) -> Void = { _ in }) -> [String] {
        var visited: [String] = []
        while !session.isFinished, visited.count < 500 {
            visited.append(session.step.id)
            check(session)
            if session.phase.loop != nil, session.position.step == session.phase.steps.count - 1 {
                session.endLoop()
            } else {
                session.advance()
            }
        }
        return visited
    }

    func testEveryExpansionCombinationVisitsExactlyItsSteps() {
        for expansions in expansionSets {
            let visited = walk(TurnGuideSession(script: script, expansions: expansions))
            XCTAssertEqual(visited, expectedSteps(with: expansions), "expansions: \(expansions.sorted())")
        }
    }

    func testAdditionsAndRemindersOnlyForChosenExpansions() {
        for expansions in expansionSets {
            _ = walk(TurnGuideSession(script: script, expansions: expansions)) { session in
                for addition in session.additions {
                    XCTAssertTrue(expansions.contains(addition.expansion), "\(session.step.id): \(addition.expansion)")
                }
                for reminder in session.reminders {
                    if let expansion = reminder.expansion {
                        XCTAssertTrue(expansions.contains(expansion), "\(session.step.id): \(expansion)")
                    }
                }
            }
        }
    }

    func testEveryActionTurnEndsWithReminders() {
        let session = TurnGuideSession(script: script, expansions: [])
        let loop = session.phases.first { $0.loop != nil }
        XCTAssertNotNil(loop)
        for step in loop?.steps ?? [] {
            XCTAssertFalse(step.reminders?.isEmpty ?? true, "\(step.id) has no turn-change reminders")
        }
    }

    func testLoopWrapsUntilEnded() throws {
        let session = TurnGuideSession(script: script, expansions: [], startAt: "turn-atreides")
        XCTAssertEqual(session.step.id, "turn-atreides")
        session.advance()
        XCTAssertEqual(session.step.id, "turn-harkonnen")
        session.advance()
        XCTAssertEqual(session.step.id, "turn-atreides")
        XCTAssertEqual(session.position.pass, 2)
        XCTAssertEqual(session.turnNumber, 3)
        session.endLoop()
        XCTAssertNil(session.phase.loop)
        XCTAssertEqual(session.position.step, 0)
    }

    func testGoBackReturnsToThePreviousStep() {
        let session = TurnGuideSession(script: script, expansions: [])
        XCTAssertFalse(session.canGoBack)
        let first = session.step.id
        session.advance()
        XCTAssertNotEqual(session.step.id, first)
        session.goBack()
        XCTAssertEqual(session.step.id, first)
        XCTAssertFalse(session.canGoBack)
    }

    func testFinishingAndGoingBack() {
        let session = TurnGuideSession(script: script, expansions: [])
        let visited = walk(session)
        XCTAssertTrue(session.isFinished)
        session.goBack()
        XCTAssertFalse(session.isFinished)
        XCTAssertEqual(session.step.id, visited.last)
        session.restart()
        XCTAssertEqual(session.step.id, visited.first)
    }

    func testTablePlayNeverAsksForAHandoff() {
        _ = walk(TurnGuideSession(script: script, expansions: allExpansions)) { session in
            XCTAssertNil(session.handoffTo, "\(session.step.id)")
        }
    }

    func testPassingThePhoneAsksForAHandoffWhenTheSideChanges() {
        for expansions in expansionSets {
            let session = TurnGuideSession(script: script, expansions: expansions, passesPhone: true)
            var previousSide = session.step.side
            var handoffs = 0
            while !session.isFinished {
                let side = session.step.side
                let expected: TurnScript.Side? = side != .both && side != previousSide ? side : nil
                XCTAssertEqual(session.handoffTo, expected, "\(session.step.id), expansions \(expansions.sorted())")
                if session.handoffTo != nil {
                    handoffs += 1
                    session.confirmHandoff()
                    XCTAssertNil(session.handoffTo)
                }
                previousSide = side
                if session.phase.loop != nil, session.position.step == session.phase.steps.count - 1 {
                    session.endLoop()
                } else {
                    session.advance()
                }
            }
            XCTAssertGreaterThan(handoffs, 5, "expansions \(expansions.sorted())")
        }
    }

    func testGoingBackClearsAHandoff() {
        let session = TurnGuideSession(script: script, expansions: [], passesPhone: true, startAt: "turn-atreides")
        session.advance()
        XCTAssertEqual(session.handoffTo, .harkonnen)
        session.goBack()
        XCTAssertNil(session.handoffTo)
        XCTAssertEqual(session.step.id, "turn-atreides")
    }

    func testUnknownStartStepStartsAtTheBeginning() {
        let session = TurnGuideSession(script: script, expansions: [], startAt: "no-such-step")
        XCTAssertEqual(session.step.id, expectedSteps(with: []).first)
    }

    func testEveryPictureHasItsAsset() {
        for image in script.images {
            XCTAssertNotNil(UIImage(named: script.assetName(for: image)), "missing asset for \(image.id)")
        }
    }

    func testEveryCitationNamesAKnownSource() {
        let steps: [TurnScript.Step] = script.phases.flatMap(\.steps)
        let additions: [TurnScript.Addition] = steps.flatMap { $0.additions ?? [] }
        let reminders: [TurnScript.Reminder] = steps.flatMap { $0.reminders ?? [] }
        var citations: [TurnScript.Citation] = steps.flatMap(\.citations)
        citations += additions.flatMap(\.citations)
        citations += reminders.flatMap(\.citations)
        for citation in citations {
            XCTAssertNotNil(script.source(for: citation), "unknown source \(citation.source)")
        }
    }
}
