//
//  TurnScript.swift
//  Ordir
//
//  Authored, versioned turn guide for one game: phases → steps, each citing the rulebook or FAQ.
//  Scripts live next to their game as `<game>.turnscript.json`; tools/validate_turn_scripts.py
//  checks every excerpt against the official PDFs in Sources/.
//

import Foundation

struct TurnScript: Decodable {
    let game: OrdirGame
    let title: String
    let version: Int
    /// The two sides (factions) the game is played between; steps name one of them, or both. Games without
    /// fixed sides (everyone does the same things in turn) have one: the player on turn (`takesTurns`).
    let sides: [SideInfo]
    /// How each side wins, shown when the players end the game.
    let victory: Victory
    let sources: [Source]
    /// Optional modules players can switch on before starting; steps and additions name one by id.
    let expansions: [Expansion]
    /// Things that happen mid-game and change which steps apply, e.g. the Smugglers allying.
    let states: [GameState]?
    /// Component pictures cropped from the sources by tools/crop_source_images.py.
    let images: [SourceImage]
    let phases: [Phase]
    /// Battle walkthrough opened from an Action turn; its steps name the attacker and defender.
    let battle: Battle?

    struct Source: Decodable {
        let id: String
        let title: String
        let shortTitle: String
        let url: URL
    }

    struct Expansion: Decodable, Identifiable {
        let id: String
        let title: String
        let summary: String
    }

    struct SourceImage: Decodable, Identifiable {
        let id: String
        let caption: String
        let source: String
        let page: Int
    }

    struct Phase: Decodable {
        let id: String
        /// Setup phases run once; round phases repeat until the players end the game.
        let part: Part
        let title: String
        let steps: [Step]
        /// Set when the phase's steps repeat (e.g. alternating Action turns) until the players end it.
        let loop: Loop?
    }

    struct Battle: Decodable {
        let title: String
        let phases: [Phase]
    }

    enum Part: String, Decodable {
        case setup, round
    }

    struct GameState: Decodable, Identifiable {
        let id: String
        /// The expansion it belongs to; none for the base game's (e.g. Brass's Rail Era).
        let expansion: String?
        let title: String
        /// Button label for marking that it happened, e.g. "The Smugglers have joined us".
        let markLabel: String
        let trigger: String
        let citations: [Citation]
        /// What to do at the moment it happens.
        let event: StateEvent
    }

    struct StateEvent: Decodable {
        let title: String
        let side: Side
        let bullets: [String]
        let images: [String]
        let citations: [Citation]
    }

    /// Shows a step or addition only while a state is on (or off).
    struct Condition: Decodable {
        let state: String
        let `is`: Bool
    }

    struct Loop: Decodable {
        let endLabel: String
        let note: String
        let citations: [Citation]
    }

    struct Step: Decodable {
        let id: String
        /// Set when the whole step only applies with that expansion.
        let expansion: String?
        let when: Condition?
        let side: Side
        let title: String
        /// Lead line; options and sub-steps go in `bullets` rather than a long paragraph.
        let instruction: String
        let bullets: [String]?
        let components: [String]
        let images: [String]
        let citations: [Citation]
        /// Extra rules an expansion adds to this step.
        let additions: [Addition]?
        /// Checklist for the moment the turn passes, e.g. moving the Regeneration Tank.
        let reminders: [Reminder]?
        /// Offers "Start a battle" on this step.
        let opensBattle: Bool?

        /// The same step for another side, e.g. a battle's "attacker" resolved to the Atreides.
        func with(side newSide: Side) -> Step {
            Step(
                id: id, expansion: expansion, when: when, side: newSide, title: title,
                instruction: instruction, bullets: bullets, components: components, images: images,
                citations: citations, additions: additions, reminders: reminders, opensBattle: opensBattle
            )
        }
    }

    /// Extra rules for a step: an expansion's, or the base game's for a moment (e.g. the end of an era), with its
    /// own heading.
    struct Addition: Decodable {
        let expansion: String?
        let title: String?
        let when: Condition?
        /// A state this addition lets the players mark as happened.
        let sets: String?
        let text: String
        let bullets: [String]?
        let images: [String]
        let citations: [Citation]
    }

    struct Reminder: Decodable {
        let expansion: String?
        let text: String
        let citations: [Citation]
    }

    struct Citation: Decodable, Hashable {
        let source: String
        let page: Int
        /// FAQ question or rule the citation points to.
        let entry: String?
        /// Verbatim text from the page; used by the validator, not shown in the app.
        let excerpt: String
    }

    /// Who a step is for: one of the script's `sides` (by id), or both players. Battle steps name the
    /// attacker and defender, resolved to a side when a battle starts.
    struct Side: RawRepresentable, Hashable, Decodable {
        let rawValue: String
        init(rawValue: String) { self.rawValue = rawValue }
        init(from decoder: Decoder) throws { rawValue = try decoder.singleValueContainer().decode(String.self) }

        static let both = Side(rawValue: "both")
        static let attacker = Side(rawValue: "attacker")
        static let defender = Side(rawValue: "defender")
    }

    struct SideInfo: Decodable, Identifiable {
        let id: Side
        let name: String
        /// "#rrggbb", the side's colour in the guide.
        let color: String
    }

    struct Victory: Decodable {
        let note: String
        let citations: [Citation]
    }

    /// No fixed sides: play passes round the table, and the phone with it in pass-the-phone play.
    var takesTurns: Bool { sides.count == 1 }

    func name(of side: Side) -> String {
        side == .both ? tr("Both players") : sides.first { $0.id == side }?.name ?? side.rawValue.capitalized
    }

    /// The other side; for "both" (or an unknown side), the first side.
    func opponent(of side: Side) -> Side {
        sides.first { $0.id != side }?.id ?? side
    }

    func isPlayer(_ side: Side) -> Bool {
        sides.contains { $0.id == side }
    }

    /// "Rulebook p. 7, p. 27; FAQ p. 2": citations as a short line of text.
    func citeText(_ citations: [Citation]) -> String {
        var order: [String] = []
        var pages: [String: [Int]] = [:]
        for citation in citations {
            let title = sources.first { $0.id == citation.source }?.shortTitle ?? citation.source
            if pages[title] == nil { order.append(title) }
            if !(pages[title] ?? []).contains(citation.page) { pages[title, default: []].append(citation.page) }
        }
        return order.map { title in "\(title) " + (pages[title] ?? []).map { tr("p. {0}", $0) }.joined(separator: ", ") }
            .joined(separator: "; ")
    }

    func source(for citation: Citation) -> Source? {
        sources.first { $0.id == citation.source }
    }

    func pictures(_ ids: [String]) -> [SourceImage] {
        ids.compactMap { id in images.first { $0.id == id } }
    }

    func state(_ id: String) -> GameState? {
        states?.first { $0.id == id }
    }

    func expansionTitle(_ id: String) -> String {
        expansions.first { $0.id == id }?.title ?? id
    }

    /// Asset catalog name written by tools/crop_source_images.py.
    func assetName(for image: SourceImage) -> String {
        "\(game.rawValue)-\(image.id)"
    }

    func label(for image: SourceImage) -> String {
        let source = sources.first { $0.id == image.source }?.shortTitle ?? image.source
        return tr("{0}, page {1}", source, image.page)
    }

    /// The script bundled for `game` in `language` (its translation laid over the English), or nil if
    /// the game has none yet.
    static func bundled(for game: OrdirGame, language: OrdirLanguage = .current) -> TurnScript? {
        guard let url = Bundle.main.url(forResource: "\(game.rawValue).turnscript", withExtension: "json") else {
            return nil
        }
        do {
            var data = try Data(contentsOf: url)
            if language != .english,
               let translation = Bundle.main.url(forResource: "\(game.rawValue).turnscript.\(language.rawValue)", withExtension: "json") {
                data = try localized(data, with: Data(contentsOf: translation))
            }
            return try JSONDecoder().decode(TurnScript.self, from: data)
        } catch {
            assertionFailure("Invalid turn script for \(game): \(error)")
            return nil
        }
    }

    /// A script's JSON with a translation's wording laid over it (<game>.turnscript.<lang>.json, checked
    /// complete by tools/validate_turn_scripts.py). Ids, pictures and citations, quoted from the English
    /// rulebook with their pages, stay as they are. The preview does the same (localize in index.html).
    static func localized(_ script: Data, with translation: Data) throws -> Data {
        guard var json = try JSONSerialization.jsonObject(with: script) as? [String: Any],
              let words = try JSONSerialization.jsonObject(with: translation) as? [String: Any] else { return script }
        func table(_ key: String) -> [String: Any] { words[key] as? [String: Any] ?? [:] }
        func put(_ object: inout [String: Any], _ from: Any?, _ keys: [String]) {
            guard let from = from as? [String: Any] else { return }
            for key in keys { if let value = from[key] { object[key] = value } }
        }
        func eachByID(_ key: String, in object: inout [String: Any], _ apply: (inout [String: Any], String) -> Void) {
            guard var list = object[key] as? [[String: Any]] else { return }
            for index in list.indices { if let id = list[index]["id"] as? String { apply(&list[index], id) } }
            object[key] = list
        }
        func phases(in object: inout [String: Any]) {
            eachByID("phases", in: &object) { phase, id in
                if let words = table("phases")[id] as? [String: Any] {
                    put(&phase, words, ["title"])
                    if var loop = phase["loop"] as? [String: Any] {
                        put(&loop, words["loop"], ["endLabel", "note"])
                        phase["loop"] = loop
                    }
                }
                eachByID("steps", in: &phase) { step, id in
                    guard let words = table("steps")[id] as? [String: Any] else { return }
                    put(&step, words, ["title", "instruction", "bullets", "components"])
                    if var additions = step["additions"] as? [[String: Any]], let texts = words["additions"] as? [Any] {
                        for index in additions.indices where index < texts.count { put(&additions[index], texts[index], ["title", "text", "bullets"]) }
                        step["additions"] = additions
                    }
                    if var reminders = step["reminders"] as? [[String: Any]], let texts = words["reminders"] as? [String] {
                        for index in reminders.indices where index < texts.count { reminders[index]["text"] = texts[index] }
                        step["reminders"] = reminders
                    }
                }
            }
        }

        put(&json, words, ["title"])
        eachByID("sides", in: &json) { side, id in if let name = table("sides")[id] { side["name"] = name } }
        if let note = words["victory"], var victory = json["victory"] as? [String: Any] {
            victory["note"] = note
            json["victory"] = victory
        }
        eachByID("sources", in: &json) { source, id in put(&source, table("sources")[id], ["title", "shortTitle"]) }
        eachByID("expansions", in: &json) { expansion, id in put(&expansion, table("expansions")[id], ["title", "summary"]) }
        eachByID("images", in: &json) { image, id in if let caption = table("images")[id] { image["caption"] = caption } }
        eachByID("states", in: &json) { state, id in
            guard let words = table("states")[id] as? [String: Any] else { return }
            put(&state, words, ["title", "markLabel", "trigger"])
            if var event = state["event"] as? [String: Any] {
                put(&event, words["event"], ["title", "bullets"])
                state["event"] = event
            }
        }
        phases(in: &json)
        if var battle = json["battle"] as? [String: Any] {
            if let title = words["battle"] { battle["title"] = title }
            phases(in: &battle)
            json["battle"] = battle
        }
        return try JSONSerialization.data(withJSONObject: json)
    }
}
