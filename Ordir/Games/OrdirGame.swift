//
//  OrdirGame.swift
//  Ordir
//

import Foundation

/// Games Ordir can guide. Launch set; each case gets an authored turn script later.
enum OrdirGame: String, CaseIterable, Identifiable, Codable {
    case duneWarForArrakis
    case starWarsRebellion
    case warOfTheRing2E

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .duneWarForArrakis: "Dune: War for Arrakis"
        case .starWarsRebellion: "Star Wars: Rebellion"
        case .warOfTheRing2E: "War of the Ring (2nd Edition)"
        }
    }
}
