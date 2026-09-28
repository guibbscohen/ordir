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
        script.phases.flatMap(\.steps)
            .filter { step in step.expansion.map { expansions.contains($0) } ?? true }
            .map(\.id)
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
        let steps = script.phases.flatMap(\.steps)
        let citations = steps.flatMap(\.citations)
            + steps.flatMap { $0.additions ?? [] }.flatMap(\.citations)
            + steps.flatMap { $0.reminders ?? [] }.flatMap(\.citations)
        for citation in citations {
            XCTAssertNotNil(script.source(for: citation), "unknown source \(citation.source)")
        }
    }
}
