//
//  TutorialView.swift
//  Ordir
//
//  A short tour after the opening on a first launch (and from Settings later): what Ordir does, one idea a
//  card. Back, Skip and Next on every card; a sideways swipe turns the page too. The preview's tour (TOUR in
//  Preview/index.html) has the same cards, plus rules questions and own-phone tables, which the app gets later.
//

import SwiftUI

struct TutorialView: View {
    /// The tour was finished or skipped.
    let done: () -> Void
    @State private var page = 0
    @AccessibilityFocusState private var focusedPage: Int?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private enum Art { case welcome, games, phone, step, checklist, settings }

    private struct Card {
        let art: Art
        let title: String
        let text: String
    }

    private static let cards = [
        Card(art: .welcome, title: "Welcome to Ordir",
             text: "I walk you through every turn, step by step, with the rulebook page behind each one."),
        Card(art: .games, title: "Pick a game",
             text: "Choose a game, then how you’re playing and which expansions are on the table."),
        Card(art: .phone, title: "One phone, two players",
             text: "On the table, the screen splits: the top half faces the player across from you. Or pass the phone between you."),
        Card(art: .step, title: "Follow each step",
             text: "Each step says who acts and what to do, with pictures and the rulebook page. Tap Done to move on; the arrow goes back a step."),
        Card(art: .checklist, title: "Before you pass the turn",
             text: "When your turn ends, a short checklist reminds you what to tidy up. Tick it off, then pass the turn."),
        Card(art: .settings, title: "Make it yours",
             text: "Tap the gear on Home to change the language or replay this tour."),
    ]

    private var isLast: Bool { page == Self.cards.count - 1 }

    var body: some View {
        VStack(spacing: 20) {
            TabView(selection: $page) {
                ForEach(Self.cards.indices, id: \.self) { index in
                    card(index).tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            HStack(spacing: 8) {
                ForEach(Self.cards.indices, id: \.self) { index in
                    Circle()
                        .fill(index == page ? Color.ordirSparkle : Color(white: 0.17))
                        .frame(width: 7, height: 7)
                }
            }
            .accessibilityHidden(true)
            HStack(spacing: 16) {
                Button(tr("Back")) { turn(by: -1) }
                    .buttonStyle(TextButtonStyle())
                    .disabled(page == 0)
                    .opacity(page == 0 ? 0.4 : 1)
                if !isLast {
                    Button(tr("Skip"), action: done)
                        .buttonStyle(TextButtonStyle())
                        .accessibilityIdentifier("tutorial-skip")
                }
                Spacer(minLength: 8)
                Button { isLast ? done() : turn(by: 1) } label: {
                    Text(isLast ? tr("Let’s play") : tr("Next"))
                        .font(.ordir(.headline))
                        .padding(.horizontal, 28)
                        .frame(minHeight: 50)
                }
                .buttonStyle(PrimaryButtonStyle())
                .accessibilityIdentifier("tutorial-next")
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
        .background(Color.black.ignoresSafeArea())
        .onChange(of: page) { _, new in focusedPage = new }
    }

    private func turn(by step: Int) {
        let next = page + step
        guard Self.cards.indices.contains(next) else { return }
        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.3)) { page = next }
    }

    private func card(_ index: Int) -> some View {
        let card = Self.cards[index]
        return VStack(spacing: 14) {
            Spacer(minLength: 0)
            art(card.art)
                .frame(height: 132)
                .accessibilityHidden(true)
            Text(tr("Step {0} of {1}", index + 1, Self.cards.count))
                .font(.ordir(.subheadline))
                .foregroundStyle(.secondary)
            Text(tr(card.title))
                .font(.ordir(.title2).weight(.semibold))
                .multilineTextAlignment(.center)
                .accessibilityAddTraits(.isHeader)
                .accessibilityFocused($focusedPage, equals: index)
            Text(tr(card.text))
                .font(.ordir(.body))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: 340)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 8)
    }

    @ViewBuilder private func art(_ art: Art) -> some View {
        switch art {
        case .welcome:
            OrdirMascotView(isSpeaking: true).frame(width: 108)
        case .games:
            Image(systemName: "square.grid.2x2.fill").font(.system(size: 64)).foregroundStyle(Color.ordirSparkle)
        case .settings:
            Image(systemName: "gearshape").font(.system(size: 64)).foregroundStyle(Color.ordirSparkle)
        case .phone:
            // A phone lying between two players: the top half is turned to face the far one.
            VStack(spacing: 0) {
                Text(tr("Your turn"))
                    .foregroundStyle(Color.ordirSparkle)
                    .rotationEffect(.degrees(180))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                Divider()
                Text(tr("Waiting…"))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .font(.ordir(.caption2))
            .frame(width: 92, height: 124)
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(Color(white: 0.17), lineWidth: 2))
        case .step:
            VStack(alignment: .leading, spacing: 8) {
                ForEach([1.0, 0.8, 0.6], id: \.self) { width in
                    Capsule().fill(Color(white: 0.17)).frame(width: 128 * width, height: 8)
                }
                Text(tr("Done"))
                    .font(.ordir(.caption).weight(.semibold))
                    .foregroundStyle(.black)
                    .frame(width: 128, height: 26)
                    .background(Color.white, in: Capsule())
                    .padding(.top, 6)
            }
            .padding(14)
            .background(Color(white: 0.12), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        case .checklist:
            VStack(spacing: 10) {
                ForEach(0..<3, id: \.self) { _ in
                    HStack(spacing: 8) {
                        RoundedRectangle(cornerRadius: 4).strokeBorder(Color.green, lineWidth: 2).frame(width: 14, height: 14)
                        Capsule().fill(Color(white: 0.17)).frame(height: 8)
                    }
                    .frame(width: 150)
                }
            }
        }
    }
}

#Preview {
    TutorialView {}
}
