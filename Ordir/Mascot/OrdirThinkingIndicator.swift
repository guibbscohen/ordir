//
//  OrdirThinkingIndicator.swift
//  Ordir
//
//  The thinking mascot with a rotating spinner verb beside it, e.g. while a rules answer loads.
//

import SwiftUI

struct OrdirThinkingIndicator: View {
    var game: OrdirGame?
    var interval: Duration = .seconds(2.4)

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var deck: SpinnerVerbDeck
    @State private var verb: String

    init(game: OrdirGame? = nil, interval: Duration = .seconds(2.4)) {
        self.game = game
        self.interval = interval
        var deck = SpinnerVerbDeck(game: game)
        _verb = State(initialValue: deck.next())
        _deck = State(initialValue: deck)
    }

    var body: some View {
        HStack(spacing: 12) {
            OrdirMascotView(isThinking: true)
                .frame(height: 40)

            Text(verb + "…")
                .font(.ordir(.subheadline))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .id(verb)
                .transition(verbTransition)
        }
        .clipped()
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(for: interval)
                guard !Task.isCancelled else { return }
                withAnimation(.easeInOut(duration: 0.35)) {
                    verb = deck.next()
                }
            }
        }
        // VoiceOver hears one steady label instead of every verb change.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Ordir is thinking")
    }

    /// New verb rises in as the old one rises out; a plain cross-fade with Reduce Motion on.
    private var verbTransition: AnyTransition {
        reduceMotion
            ? .opacity
            : .asymmetric(
                insertion: .move(edge: .bottom).combined(with: .opacity),
                removal: .move(edge: .top).combined(with: .opacity)
            )
    }
}

private struct OrdirThinkingIndicatorPreviewHarness: View {
    @State private var game: OrdirGame?

    var body: some View {
        VStack(spacing: 24) {
            Picker("Game", selection: $game) {
                Text("Any game").tag(OrdirGame?.none)
                ForEach(OrdirGame.allCases) { game in
                    Text(game.displayName).tag(Optional(game))
                }
            }
            // Recreate the indicator so its deck picks up the new game.
            OrdirThinkingIndicator(game: game)
                .id(game)
        }
        .padding()
    }
}

#Preview("Thinking indicator") {
    OrdirThinkingIndicatorPreviewHarness()
}
