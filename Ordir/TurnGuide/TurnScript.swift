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
    let sources: [Source]
    /// Optional modules players can switch on before starting; steps and additions name one by id.
    let expansions: [Expansion]
    /// Component pictures cropped from the sources by tools/crop_source_images.py.
    let images: [SourceImage]
    let phases: [Phase]

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
        let title: String
        let steps: [Step]
        /// Set when the phase's steps repeat (e.g. alternating Action turns) until the players end it.
        let loop: Loop?
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
        let side: Side
        let title: String
        let instruction: String
        let components: [String]
        let images: [String]
        let citations: [Citation]
        /// Extra rules an expansion adds to this step.
        let additions: [Addition]?
    }

    struct Addition: Decodable {
        let expansion: String
        let text: String
        let images: [String]
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

    enum Side: String, Decodable {
        case atreides, harkonnen, both
    }

    func source(for citation: Citation) -> Source? {
        sources.first { $0.id == citation.source }
    }

    func pictures(_ ids: [String]) -> [SourceImage] {
        ids.compactMap { id in images.first { $0.id == id } }
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
        return "\(source), page \(image.page)"
    }

    /// The script bundled for `game`, or nil if the game has none yet.
    static func bundled(for game: OrdirGame) -> TurnScript? {
        guard let url = Bundle.main.url(forResource: "\(game.rawValue).turnscript", withExtension: "json") else {
            return nil
        }
        do {
            return try JSONDecoder().decode(TurnScript.self, from: Data(contentsOf: url))
        } catch {
            assertionFailure("Invalid turn script for \(game): \(error)")
            return nil
        }
    }
}
