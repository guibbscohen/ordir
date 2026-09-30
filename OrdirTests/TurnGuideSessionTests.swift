//
//  TurnGuideSessionTests.swift
//  OrdirTests
//
//  Walks the bundled Dune script through TurnGuideSession for the base game, each expansion
//  alone and all of them together: setup and round 1, into round 2.
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

    /// Step ids of setup and one round in script order, keeping those that apply with `expansions`
    /// and no game states on (the Smugglers still neutral).
    private func expectedSteps(with expansions: Set<String>) -> [String] {
        let steps: [TurnScript.Step] = script.phases.flatMap(\.steps)
        let applicable = steps.filter { step in
            if let expansion = step.expansion, !expansions.contains(expansion) { return false }
            if let when = step.when, when.`is` { return false }
            return true
        }
        return applicable.map(\.id)
    }

    /// Taps "Done" through setup and round 1, stopping at the first step of round 2; each loop
    /// runs one pass of its turns, then ends.
    private func walk(_ session: TurnGuideSession, check: (TurnGuideSession) -> Void = { _ in }) -> [String] {
        var visited: [String] = []
        while session.round == 1, !session.isFinished, visited.count < 500 {
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

    func testRoundsRepeatWithoutSetup() {
        let session = TurnGuideSession(script: script, expansions: [])
        let roundOne = walk(session)
        XCTAssertFalse(session.isFinished)
        XCTAssertEqual(session.round, 2)
        XCTAssertEqual(session.step.id, "round-check-objective")
        // Round 2 visits the round steps again, and no setup step.
        let setupIDs = Set(script.phases.filter { $0.part == .setup }.flatMap(\.steps).map(\.id))
        var roundTwo: [String] = []
        while session.round == 2, roundTwo.count < 500 {
            roundTwo.append(session.step.id)
            if session.phase.loop != nil, session.position.step == session.phase.steps.count - 1 {
                session.endLoop()
            } else {
                session.advance()
            }
        }
        XCTAssertEqual(session.round, 3)
        XCTAssertTrue(Set(roundTwo).isDisjoint(with: setupIDs))
        XCTAssertEqual(roundTwo, roundOne.filter { !setupIDs.contains($0) })
    }

    func testEndingTheGameAndGoingBack() {
        let session = TurnGuideSession(script: script, expansions: [])
        _ = walk(session)
        let stepBefore = session.step.id
        session.endGame(winner: .atreides)
        XCTAssertTrue(session.isFinished)
        XCTAssertEqual(session.winner, .atreides)
        session.goBack()
        XCTAssertFalse(session.isFinished)
        XCTAssertNil(session.winner)
        XCTAssertEqual(session.step.id, stepBefore)
        session.restart()
        XCTAssertEqual(session.step.id, expectedSteps(with: []).first)
        XCTAssertEqual(session.round, 1)
    }

    func testSmugglersAllianceSwapsTheSmugglerSteps() {
        let session = TurnGuideSession(script: script, expansions: ["smugglers"], startAt: "turn-atreides")
        let neutralAddition = session.additions.first { $0.sets == "smugglersAllied" }
        XCTAssertNotNil(neutralAddition, "the Atreides turn should offer to mark the alliance")

        session.setState("smugglersAllied", true)
        XCTAssertEqual(session.pendingEvent?.id, "smugglersAllied")
        XCTAssertFalse(session.pendingEvent?.event.bullets.isEmpty ?? true)
        session.dismissEvent()
        XCTAssertNil(session.pendingEvent)
        XCTAssertNil(session.additions.first { $0.sets == "smugglersAllied" }, "marking twice makes no sense")
        XCTAssertTrue(session.additions.contains { $0.when?.state == "smugglersAllied" && $0.when?.`is` == true })

        // Play on into the next round: allied steps in, neutral-only steps out.
        var visited: [String] = []
        while session.round == 1 || session.phase.id != "desert-hazards", visited.count < 500 {
            visited.append(session.step.id)
            if session.phase.loop != nil, session.position.step == session.phase.steps.count - 1 {
                session.endLoop()
            } else {
                session.advance()
            }
        }
        XCTAssertTrue(visited.contains("sm-vehicles-allied"))
        XCTAssertFalse(visited.contains("sm-vehicles-neutral"))
        XCTAssertFalse(visited.contains("sm-round-regular"))

        // Marking it back (a correction) brings the neutral steps back.
        session.setState("smugglersAllied", false)
        XCTAssertFalse(session.activeStates.contains("smugglersAllied"))
    }

    func testProgressCountsOnlyStepsThatApply() {
        let session = TurnGuideSession(script: script, expansions: ["smugglers"], startAt: "vehicles-set-aside-dice")
        let neutralCount = session.applicableSteps.count
        session.setState("smugglersAllied", true)
        session.dismissEvent()
        XCTAssertEqual(session.applicableSteps.count, neutralCount, "one step swaps for another")
        XCTAssertEqual(session.stepNumber, 1)
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
            while session.round == 1 {
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

    func testBattleResolvesAttackerAndDefender() throws {
        let session = TurnGuideSession(script: script, expansions: [], startAt: "turn-harkonnen")
        let battle = try XCTUnwrap(session.makeBattle())
        XCTAssertEqual(battle.step.id, "battle-attack")
        XCTAssertEqual(battle.step.side, .harkonnen, "the acting side attacks")
        let steps = battle.phases.flatMap(\.steps)
        XCTAssertEqual(steps.first { $0.id == "battle-retreat" }?.side, .atreides, "the other side defends")
        XCTAssertFalse(steps.contains { $0.side == .attacker || $0.side == .defender })
    }

    func testBattleRunsItsRoundsThenFinishes() throws {
        let session = TurnGuideSession(script: script, expansions: [], passesPhone: true, startAt: "turn-atreides")
        let battle = try XCTUnwrap(session.makeBattle())
        var visited: [String] = []
        var combatRounds = 0
        while !battle.isFinished, visited.count < 100 {
            visited.append(battle.step.id)
            if battle.handoffTo != nil { battle.confirmHandoff() }
            if battle.phase.loop != nil, battle.position.step == battle.phase.steps.count - 1 {
                combatRounds += 1
                if combatRounds == 2 { battle.endLoop() } else { battle.advance() }
            } else {
                battle.advance()
            }
        }
        XCTAssertTrue(battle.isFinished)
        XCTAssertEqual(visited.first, "battle-attack")
        XCTAssertEqual(visited.last, "battle-advance")
        XCTAssertEqual(visited.filter { $0 == "battle-roll" }.count, 2, "two combat rounds")
        XCTAssertEqual(session.step.id, "turn-atreides", "the turn waits while the battle runs")
    }

    func testNoBattleFromAStepForBothPlayers() {
        let session = TurnGuideSession(script: script, expansions: [])
        XCTAssertEqual(session.step.side, .both)
        XCTAssertNil(session.makeBattle())
    }

    func testBattleKnowsTheSmugglersAlliance() throws {
        let session = TurnGuideSession(script: script, expansions: ["smugglers"], startAt: "turn-harkonnen")
        session.setState("smugglersAllied", true)
        session.dismissEvent()
        let battle = try XCTUnwrap(session.makeBattle())
        battle.advance()
        battle.advance()
        battle.advance()
        XCTAssertEqual(battle.step.id, "battle-roll")
        XCTAssertTrue(battle.additions.contains { $0.expansion == "smugglers" }, "Smugglers Base counts as a Settlement")
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
