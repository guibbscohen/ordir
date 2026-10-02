//
//  TurnsAroundTheTableTests.swift
//  OrdirTests
//
//  Games without fixed sides (Knarr, Brass: Birmingham, Dune: Imperium): play and the phone pass round the
//  table, base-game states (Brass's Rail Era) and their notes, and every picture these guides show.
//

import UIKit
import XCTest
@testable import Ordir

final class TurnsAroundTheTableTests: XCTestCase {
    private let player = TurnScript.Side(rawValue: "player")

    private func script(_ game: OrdirGame) throws -> TurnScript {
        try XCTUnwrap(TurnScript.bundled(for: game, language: .english), "\(game) turn script missing or invalid")
    }

    func testTheyTakeTurnsWithoutSides() throws {
        for game in [OrdirGame.knarr, .brassBirmingham, .duneImperium] {
            let script = try script(game)
            XCTAssertTrue(script.takesTurns, "\(game)")
            XCTAssertNil(script.battle, "\(game)")
        }
        XCTAssertFalse(try script(.duneWarForArrakis).takesTurns)
    }

    func testEachTurnPassesThePhoneOnce() throws {
        let session = TurnGuideSession(script: try script(.knarr), expansions: [], passesPhone: true, startAt: "turn-reputation")
        XCTAssertEqual(session.turnNumber, 1)
        session.advance()  // Recruit or Explore: the same player's turn
        XCTAssertNil(session.handoffTo)
        session.advance()  // Trade
        XCTAssertNil(session.handoffTo)
        session.advance()  // round the loop: the next player's turn
        XCTAssertEqual(session.step.id, "turn-reputation")
        XCTAssertEqual(session.handoffTo, player)
        XCTAssertEqual(session.turnNumber, 2)
        session.confirmHandoff()
        session.goBack()
        XCTAssertNil(session.handoffTo)
        XCTAssertEqual(session.step.id, "turn-trade")
    }

    func testTablePlayStillNeverAsksForAHandoff() throws {
        let session = TurnGuideSession(script: try script(.duneImperium), expansions: [], startAt: "turn")
        session.advance()
        XCTAssertEqual(session.position.pass, 2)
        XCTAssertNil(session.handoffTo)
    }

    func testTheRailEraIsABaseGameState() throws {
        let session = TurnGuideSession(script: try script(.brassBirmingham), expansions: [], startAt: "round-income")
        XCTAssertEqual(session.availableStates.map(\.id), ["railEra"])
        XCTAssertEqual(session.additions.map(\.sets), ["railEra"], "the Canal Era's end can be marked from the step")
        session.setState("railEra", true)
        XCTAssertEqual(session.pendingEvent?.id, "railEra")
        XCTAssertEqual(session.additions.compactMap(\.title), ["End of the game?"])
    }

    func testDuneImperiumExpansionsAddToSetup() throws {
        let script = try script(.duneImperium)
        XCTAssertTrue(TurnGuideSession(script: script, expansions: []).additions.isEmpty)
        let all = Set(script.expansions.map(\.id))
        XCTAssertEqual(TurnGuideSession(script: script, expansions: all).additions.count, 3)
    }

    func testEveryPictureHasItsAsset() throws {
        for game in [OrdirGame.knarr, .brassBirmingham, .duneImperium] {
            let script = try script(game)
            for image in script.images {
                XCTAssertNotNil(UIImage(named: script.assetName(for: image)), "\(game): missing asset for \(image.id)")
            }
        }
    }
}
