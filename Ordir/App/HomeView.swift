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

    /// When the opening's line reaches the header's orb, which is then built (nil: shown as is).
    var orbBuildStart: Date?
    /// Reports where the header's orb is on screen (global coordinates): the opening's line ends there.
    var onOrbFrame: (CGRect) -> Void = { _ in }

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
            .background { ambience.ignoresSafeArea() }
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

    /// The opening's deep blue and violet glow, settled behind the header and fading to black before the
    /// game cards, plus a faint glow at the bottom (the preview matches).
    private var ambience: some View {
        GeometryReader { proxy in
            let w = proxy.size.width
            ZStack {
                Color.black
                RadialGradient(colors: [Color(red: 0.49, green: 0.36, blue: 1).opacity(0.30), .clear],
                               center: UnitPoint(x: 0.18, y: 0), startRadius: 0, endRadius: w * 0.75)
                RadialGradient(colors: [Color(red: 0.15, green: 0.33, blue: 0.84).opacity(0.32), .clear],
                               center: UnitPoint(x: 0.88, y: 0.06), startRadius: 0, endRadius: w * 0.72)
                RadialGradient(colors: [Color(red: 0.49, green: 0.36, blue: 1).opacity(0.22), .clear],
                               center: UnitPoint(x: 0.5, y: 1.04), startRadius: 0, endRadius: w * 0.6)
            }
        }
        .accessibilityHidden(true)
    }

    private var header: some View {
        VStack(spacing: 12) {
            OrdirMascotView(buildStart: orbBuildStart)
                .frame(height: 72)
                .background {
                    GeometryReader { proxy in
                        Color.clear
                            .onAppear { onOrbFrame(proxy.frame(in: .global)) }
                            .onChange(of: proxy.frame(in: .global)) { _, frame in onOrbFrame(frame) }
                    }
                }
                .padding(.top, 40)
            Text("Ordir")
                .font(.ordir(.title).weight(.semibold))
                .accessibilityAddTraits(.isHeader)
            Text(Self.phraseOfDay)
                .font(.ordir(.subheadline))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 18)
                .padding(.vertical, 12)
                .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(alignment: .top) {
                    BubbleTail()  // points up at the orb
                        .fill(.quaternary.opacity(0.5))
                        .frame(width: 16, height: 8)
                        .offset(y: -8)
                }
                .padding(.top, 8)
        }
    }

    /// What the orb says on Home, one a day (the preview uses the same list).
    private static let phrases = [
        "What shall we play today?",
        "Ready for your next turn?",
        "Set up the board, I’ll walk you through it.",
        "Got a rules question? I’m all ears.",
        "Who’s going first today?",
        "A new game, a fresh start.",
        "Let’s learn a turn together.",
        "Shuffle up. I’ll keep the rules straight.",
    ]
    private static var phraseOfDay: String {
        let day = Calendar.current.ordinality(of: .day, in: .era, for: .now) ?? 0
        return phrases[day % phrases.count]
    }

    private var gameList: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Choose a game")
                .font(.ordir(.headline))
                .accessibilityAddTraits(.isHeader)
            ForEach(OrdirGame.allCases.filter { Self.scripts[$0] != nil }) { game in
                NavigationLink(value: game) {
                    GameCard(game: game, script: Self.scripts[game]!)
                }
                .buttonStyle(PressableCardStyle())
            }
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                ForEach(OrdirGame.allCases.filter { Self.scripts[$0] == nil }) { game in
                    ComingSoonTile(game: game)
                }
            }
        }
    }

    /// Each game's bundled turn guide, loaded once; games without one show as "Coming soon".
    private static let scripts: [OrdirGame: TurnScript] = Dictionary(
        uniqueKeysWithValues: OrdirGame.allCases.compactMap { game in TurnScript.bundled(for: game).map { (game, $0) } }
    )
}

/// Cards shrink a little under the finger and spring back.
private struct PressableCardStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(duration: 0.25, bounce: 0.3), value: configuration.isPressed)
    }
}

/// The little triangle on top of the phrase bubble.
private struct BubbleTail: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

/// A playable game: its cover art (cropped from the rulebook cover) over the name.
private struct GameCard: View {
    let game: OrdirGame
    let script: TurnScript

    private var cover: TurnScript.SourceImage? { script.pictures(["cover"]).first }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let cover {
                Color.clear
                    .aspectRatio(5 / 4, contentMode: .fit)
                    .overlay {
                        Image(script.assetName(for: cover))
                            .resizable()
                            .scaledToFill()
                    }
                    .clipped()
                    .accessibilityHidden(true)
            }
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(game.displayName)
                        .font(.ordir(.headline))
                    Text("Turn guide, step by step")
                        .font(.ordir(.subheadline))
                        .foregroundStyle(.secondary)
                    if let cover {
                        Text("Cover art: \(script.label(for: cover))")
                            .font(.ordir(.caption))
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: "chevron.right")
                    .font(.ordir(.footnote).weight(.semibold))
                    .foregroundStyle(.tertiary)
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background(.quaternary.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}

/// A game whose turn guide isn't written yet: house-style art with a "Coming soon" badge, not tappable.
private struct ComingSoonTile: View {
    let game: OrdirGame

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Color.clear
                .aspectRatio(1, contentMode: .fit)
                .overlay {
                    RadialGradient(colors: [Color(white: 0.17), Color(white: 0.07), Color(white: 0.04)],
                                   center: UnitPoint(x: 0.3, y: 0.2), startRadius: 0, endRadius: 200)
                    OrdirMascotView()
                        .padding(44)
                        .opacity(0.35)
                }
                .overlay(alignment: .topLeading) {
                    Text("Coming soon")
                        .font(.ordir(.caption).weight(.semibold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 3)
                        .background(.black.opacity(0.55), in: Capsule())
                        .overlay(Capsule().strokeBorder(.white.opacity(0.14)))
                        .padding(10)
                }
                .clipped()
            Text(game.displayName)
                .font(.ordir(.subheadline).weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
        }
        .background(.quaternary.opacity(0.25))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(game.displayName), coming soon")
    }
}

/// Stand-in until turn guides exist; shows the game's thinking indicator.
private struct GamePlaceholderView: View {
    let game: OrdirGame

    var body: some View {
        VStack(spacing: 24) {
            OrdirThinkingIndicator(game: game)
            Text("Turn guides for \(game.displayName) are on the way.")
                .font(.ordir(.footnote))
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
