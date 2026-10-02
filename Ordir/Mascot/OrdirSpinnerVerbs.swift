//
//  OrdirSpinnerVerbs.swift
//  Ordir
//
//  Playful status verbs shown while Ordir is thinking ("Rolling for initiative…").
//

import Foundation

enum OrdirSpinnerVerbs {
    /// Board game and nerd culture verbs, usable in any game.
    static let general: [String] = [
        "Rolling for initiative",
        "Shuffling the deck",
        "Consulting the rulebook",
        "Checking the errata",
        "Reading the fine print",
        "Summoning the rules lawyer",
        "Counting victory points",
        "Herding meeples",
        "Punching out tokens",
        "Sleeving the cards",
        "Sorting the bits",
        "Untapping, upkeeping, drawing",
        "Resolving the stack",
        "Rerolling the ones",
        "Taking a mulligan",
        "Placing workers",
        "Building the engine",
        "Counting hexes",
        "Checking line of sight",
        "Tallying resources",
        "Passing the first-player token",
        "Flipping the sand timer",
        "Min-maxing",
        "Theorycrafting",
        "Metagaming",
        "Calculating THAC0",
        "Rolling a saving throw",
        "Asking the Game Master",
        "Scrying",
        "Taking a long rest",
        "Grinding XP",
        "Leveling up",
        "Respawning",
        "Loading the save file",
        "Speedrunning the rulebook",
        "Rolling a natural 20",
    ]

    /// Verbs themed to a specific game, mixed in while that game is being played.
    static func themed(for game: OrdirGame) -> [String] {
        switch game {
        case .duneWarForArrakis:
            [
                "Following the spice",
                "Calling the carryall",
                "Walking without rhythm",
                "Folding space",
                "Summoning a sandworm",
                "Consulting prescience",
            ]
        case .starWarsRebellion:
            [
                "Hiding the Rebel base",
                "Launching probe droids",
                "Recruiting leaders",
                "Plotting a hyperspace jump",
                "Scanning the Outer Rim",
                "Making the Kessel Run",
            ]
        case .warOfTheRing2E:
            [
                "Hunting the Ring",
                "Rolling action dice",
                "Mustering the Free Peoples",
                "Consulting the Council",
                "Counting corruption",
                "Guiding the Fellowship",
            ]
        case .knarr:
            [
                "Recruiting Vikings",
                "Setting sail",
                "Trading silver bracelets",
                "Exploring new lands",
                "Raising our reputation",
                "Loading the knarr",
            ]
        case .brassBirmingham:
            [
                "Building a cotton mill",
                "Digging the canals",
                "Laying the rail",
                "Selling to the merchants",
                "Taking a loan",
                "Flipping industry tiles",
            ]
        case .duneImperium:
            [
                "Sending an Agent",
                "Revealing the hand",
                "Gathering spice",
                "Courting the Emperor",
                "Deploying troops",
                "Buying from the Imperium Row",
            ]
        case .terraformingMars:
            [
                "Raising the temperature",
                "Placing an ocean",
                "Planting greenery",
                "Funding an award",
                "Claiming a milestone",
                "Researching projects",
            ]
        }
    }
}

/// Deals verbs like a shuffled deck: every verb appears once per pass, never twice in a row.
struct SpinnerVerbDeck {
    private let verbs: [String]
    private var pile: [String] = []
    private var last: String?

    /// With a game, its themed verbs make up about a third of the deck.
    init(game: OrdirGame? = nil) {
        guard let game else {
            verbs = OrdirSpinnerVerbs.general
            return
        }
        let themed = OrdirSpinnerVerbs.themed(for: game)
        verbs = themed + OrdirSpinnerVerbs.general.shuffled().prefix(themed.count * 2)
    }

    mutating func next() -> String {
        if pile.isEmpty {
            pile = verbs.shuffled()
            // The next card is dealt from the end; don't repeat the previous pass's final verb.
            if pile.count > 1, pile.last == last {
                pile.swapAt(0, pile.count - 1)
            }
        }
        let verb = pile.removeLast()
        last = verb
        return verb
    }
}
