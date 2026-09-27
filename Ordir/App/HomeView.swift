//
//  HomeView.swift
//  Ordir
//
//  First screen: the mascot and the list of supported games.
//

import SwiftUI

struct HomeView: View {
    // `-OrdirOpenGame <game>` at launch opens that game directly (used by CI screenshots).
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
                    TurnGuideView(script: script)
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
            Text("Learn any turn, step by step.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var gameList: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Choose a game")
                .font(.headline)
            ForEach(OrdirGame.allCases) { game in
                NavigationLink(value: game) {
                    GameRow(game: game)
                }
                .buttonStyle(.plain)
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

#Preview {
    HomeView()
}
