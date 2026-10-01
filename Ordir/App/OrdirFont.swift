//
//  OrdirFont.swift
//  Ordir
//
//  Ordir's typeface: Google Sans Flex (SIL OFL 1.1, see Fonts/OFL.txt), bundled and registered at
//  launch. `Font.ordir(_:)` keeps each text style's Dynamic Type scaling.
//

import CoreText
import SwiftUI

enum OrdirFont {
    static let family = "Google Sans Flex"

    /// Registers the bundled font for this process; call once at launch.
    static func register() {
        guard let url = Bundle.main.url(forResource: "GoogleSansFlex", withExtension: "ttf") else {
            assertionFailure("GoogleSansFlex.ttf is missing from the app bundle")
            return
        }
        CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
    }
}

extension Font {
    /// Google Sans Flex at `style`'s size, scaled with Dynamic Type like the system style.
    static func ordir(_ style: TextStyle) -> Font {
        let font = Font.custom(OrdirFont.family, size: style.defaultSize, relativeTo: style)
        return style == .headline ? font.weight(.semibold) : font
    }
}

private extension Font.TextStyle {
    /// Point sizes at the default text size (Apple's Human Interface Guidelines).
    var defaultSize: CGFloat {
        switch self {
        case .largeTitle: 34
        case .title: 28
        case .title2: 22
        case .title3: 20
        case .headline, .body: 17
        case .callout: 16
        case .subheadline: 15
        case .footnote: 13
        case .caption: 12
        case .caption2: 11
        @unknown default: 17
        }
    }
}
