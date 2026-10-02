//
//  OrdirGame.swift
//  Ordir
//

import Foundation

/// Games Ordir can guide, in the order they were added (Home's "Most recently added" reverses it). Each has an
/// authored turn script; one without its script yet shows as "Coming soon".
enum OrdirGame: String, CaseIterable, Identifiable, Codable {
    case duneWarForArrakis
    case starWarsRebellion
    case warOfTheRing2E
    case knarr
    case brassBirmingham
    case duneImperium
    case terraformingMars

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .duneWarForArrakis: "Dune: War for Arrakis"
        case .starWarsRebellion: "Star Wars: Rebellion"
        case .warOfTheRing2E: "War of the Ring (2nd Edition)"
        case .knarr: "Knarr"
        case .brassBirmingham: "Brass: Birmingham"
        case .duneImperium: "Dune: Imperium"
        case .terraformingMars: "Terraforming Mars"
        }
    }

    /// How many can play with Ordir's guide, e.g. "2–4".
    var players: String {
        switch self {
        case .duneWarForArrakis, .starWarsRebellion, .warOfTheRing2E: "2"
        case .knarr, .brassBirmingham: "2–4"
        case .duneImperium: "3–4"
        case .terraformingMars: "2–5"
        }
    }

    /// Ordi's current favourites, shown first on Home.
    static let favorites: [OrdirGame] = [.duneWarForArrakis, .starWarsRebellion, .warOfTheRing2E]

    /// Ordi's newest meeples, highlighted at the top of Home.
    static let newest: [OrdirGame] = [.terraformingMars]
}
