//
//  OrdirLanguage.swift
//  Ordir
//
//  Ordir speaks English, Brazilian Portuguese and Latin American Spanish. It follows the phone's language
//  until the player picks one in Settings. Screen text is looked up by its English wording in strings.json,
//  which the browser preview shares; each game's turn guide has its own translation files
//  (TurnScript.bundled).
//

import SwiftUI

enum OrdirLanguage: String, CaseIterable, Identifiable {
    case english = "en"
    case portuguese = "pt-BR"
    case spanish = "es-419"

    var id: String { rawValue }

    /// The language's own name, as the picker shows it.
    var name: String {
        switch self {
        case .english: "English"
        case .portuguese: "Português (Brasil)"
        case .spanish: "Español (Latinoamérica)"
        }
    }

    /// Where the player's choice is kept (`@AppStorage` in the app).
    static let storageKey = "OrdirLanguage"

    /// The chosen language, or else the phone's (English if it's none of Ordir's).
    static var current: OrdirLanguage {
        if let saved = UserDefaults.standard.string(forKey: storageKey), let language = OrdirLanguage(rawValue: saved) {
            return language
        }
        for tag in Locale.preferredLanguages.map({ $0.lowercased() }) {
            if tag.hasPrefix("pt") { return .portuguese }
            if tag.hasPrefix("es") { return .spanish }
            if tag.hasPrefix("en") { return .english }
        }
        return .english
    }
}

/// Every translation, by language and then by English wording.
private let translations: [String: [String: String]] = {
    guard let url = Bundle.main.url(forResource: "strings", withExtension: "json"),
          let data = try? Data(contentsOf: url),
          let table = try? JSONDecoder().decode([String: [String: String]].self, from: data) else { return [:] }
    return table
}()

/// Screen text in the current language; {0}, {1}… take the arguments. A missing translation stays English.
func tr(_ english: String, _ arguments: CustomStringConvertible...) -> String {
    var text = translations[OrdirLanguage.current.rawValue]?[english] ?? english
    for (index, argument) in arguments.enumerated() {
        text = text.replacingOccurrences(of: "{\(index)}", with: argument.description)
    }
    return text
}

extension Text {
    /// A translated sentence with styled parts in it, e.g. the side's name in its colour:
    /// `Text(tr: "Pass the phone to the {0}", Text(name).foregroundColor(color))`.
    init(tr english: String, _ parts: Text...) {
        var result = Text(verbatim: "")
        var rest = Substring(tr(english))
        while let open = rest.firstIndex(of: "{"),
              let close = rest[open...].firstIndex(of: "}"),
              let index = Int(rest[rest.index(after: open)..<close]),
              index < parts.count {
            result = result + Text(verbatim: String(rest[..<open])) + parts[index]
            rest = rest[rest.index(after: close)...]
        }
        self = result + Text(verbatim: String(rest))
    }
}
