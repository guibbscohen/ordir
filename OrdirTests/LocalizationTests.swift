//
//  LocalizationTests.swift
//  OrdirTests
//
//  Every bundled turn guide loads in Portuguese and Spanish with the same steps as in English, its
//  wording translated and its citations untouched; and screen text follows the chosen language.
//

import XCTest
@testable import Ordir

final class LocalizationTests: XCTestCase {
    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: OrdirLanguage.storageKey)
    }

    private func steps(_ script: TurnScript) -> [TurnScript.Step] {
        (script.phases + (script.battle?.phases ?? [])).flatMap(\.steps)
    }

    func testEveryGuideLoadsTranslated() throws {
        for game in OrdirGame.allCases {
            let english = try XCTUnwrap(TurnScript.bundled(for: game, language: .english), "\(game) has no guide")
            for language in [OrdirLanguage.portuguese, .spanish] {
                let translated = try XCTUnwrap(TurnScript.bundled(for: game, language: language), "\(game) in \(language) didn't load")
                let (before, after) = (steps(english), steps(translated))
                XCTAssertEqual(before.map(\.id), after.map(\.id), "\(game) in \(language): steps changed")
                XCTAssertEqual(before.map { $0.citations.map(\.excerpt) }, after.map { $0.citations.map(\.excerpt) },
                               "\(game) in \(language): citations must keep the rulebook's words")
                let changed = zip(before, after).filter { $0.instruction != $1.instruction }.count
                XCTAssertGreaterThan(changed, before.count / 2, "\(game) in \(language): most instructions should be translated")
            }
        }
    }

    func testScreenTextFollowsTheChosenLanguage() {
        UserDefaults.standard.set(OrdirLanguage.portuguese.rawValue, forKey: OrdirLanguage.storageKey)
        XCTAssertEqual(tr("Done"), "Feito")
        XCTAssertEqual(tr("Round {0}", 3), "Rodada 3")
        UserDefaults.standard.set(OrdirLanguage.spanish.rawValue, forKey: OrdirLanguage.storageKey)
        XCTAssertEqual(tr("Done"), "Listo")
        UserDefaults.standard.set(OrdirLanguage.english.rawValue, forKey: OrdirLanguage.storageKey)
        XCTAssertEqual(tr("Round {0}", 3), "Round 3")
        XCTAssertEqual(tr("Not a translated string"), "Not a translated string")
    }
}
