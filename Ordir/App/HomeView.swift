//
//  HomeView.swift
//  Ordir
//
//  First screen after the opening: the mascot and the games, unfinished ones marked "Coming soon".
//

import SwiftUI

struct HomeView: View {
    // `-OrdirOpenGame <game>` at launch opens that game directly; `-OrdirStartStep <step id>` and
    // `-OrdirExpansions <id,id>` also skip the setup picker, and `-OrdirPlayMode pass` picks
    // pass-the-phone play. Used by CI screenshots.
    @State private var path: [OrdirGame] = UserDefaults.standard.string(forKey: "OrdirOpenGame")
        .flatMap(OrdirGame.init(rawValue:))
        .map { [$0] } ?? []

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(spacing: 40) {
                    header
                    gameList
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 32)
            }
            .navigationDestination(for: OrdirGame.self) { game in
                if let script = TurnScript.bundled(for: game) {
                    TurnGuideView(
                        script: script,
                        mode: UserDefaults.standard.string(forKey: "OrdirPlayMode") == "pass" ? .pass : .table,
                        startAt: UserDefaults.standard.string(forKey: "OrdirStartStep"),
                        expansions: UserDefaults.standard.string(forKey: "OrdirExpansions")
                            .map { Set($0.split(separator: ",").map(String.init)) }
                    )
                } else {
                    GamePlaceholderView(game: game)
                }
            }
        }
    }

    private var header: some View {
        VStack(spacing: 12) {
            OrdirMascotView()
                .frame(height: 120)
                .padding(.top, 48)
            Text("Ordir")
                .font(.largeTitle.weight(.semibold))
                .accessibilityAddTraits(.isHeader)
            Text("Learn any turn, step by step.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var gameList: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Choose a game")
                .font(.headline)
                .accessibilityAddTraits(.isHeader)
            ForEach(OrdirGame.allCases) { game in
                if game.hasTurnGuide {
                    NavigationLink(value: game) {
                        GameRow(game: game)
                    }
                    .buttonStyle(.plain)
                } else {
                    ComingSoonRow(game: game)
                }
            }
        }
    }
}

private struct GameRow: View {
    let game: OrdirGame

    var body: some View {
        HStack {
            Text(game.displayName)
                .font(.body)
            Spacer()
            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.tertiary)
                .accessibilityHidden(true)
        }
        .padding(.horizontal, 16)
        .frame(minHeight: 56)
        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .contentShape(Rectangle())
    }
}

/// A game whose turn guide isn't written yet: greyed, with a "Coming soon" badge, not tappable.
private struct ComingSoonRow: View {
    let game: OrdirGame
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        // At accessibility text sizes the badge goes under the name instead of squeezing it.
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8))
            : AnyLayout(HStackLayout(spacing: 12))
        layout {
            Text(game.displayName)
                .font(.body)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text("Coming soon")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 3)
                .overlay(Capsule().strokeBorder(.quaternary))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(minHeight: 56)
        .background(.quaternary.opacity(0.25), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}

/// Stand-in until turn guides exist; shows the game's thinking indicator.
private struct GamePlaceholderView: View {
    let game: OrdirGame

    var body: some View {
        VStack(spacing: 24) {
            OrdirThinkingIndicator(game: game)
            Text("Turn guides for \(game.displayName) are on the way.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(32)
        .navigationTitle(game.displayName)
        .navigationBarTitleDisplayMode(.inline)
    }
}

private extension OrdirGame {
    /// Whether the app bundles this game's turn script.
    var hasTurnGuide: Bool {
        Bundle.main.url(forResource: "\(rawValue).turnscript", withExtension: "json") != nil
    }
}

#Preview {
    HomeView()
}
