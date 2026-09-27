//
//  TurnGuideView.swift
//  Ordir
//
//  Pass-and-play turn guide on one phone lying flat between two players. The screen splits in two:
//  the far half is turned 180° to face the player across the table. The acting side's half shows
//  the step (instruction, component pictures, sources, "Done"); the other half shows who is acting,
//  on which step, and for how long. Steps for both players show on both halves; either "Done"
//  advances. The mascot speaks each new instruction.
//

import SwiftUI

struct TurnGuideView: View {
    let script: TurnScript
    @State private var session: TurnGuideSession?

    /// `startAt` and `expansions` skip the expansion picker (CI screenshots use them).
    init(script: TurnScript, startAt stepID: String? = nil, expansions: Set<String>? = nil) {
        self.script = script
        if stepID != nil || script.expansions.isEmpty {
            let session = TurnGuideSession(script: script, expansions: expansions ?? [], startAt: stepID)
            _session = State(initialValue: session)
        }
    }

    var body: some View {
        if let session {
            TurnGuideRunner(session: session)
        } else {
            ExpansionPicker(script: script) { chosen in
                session = TurnGuideSession(script: script, expansions: chosen)
            }
        }
    }
}

// MARK: - Expansion picker

/// Asked once before the guide starts: which expansions are on the table.
private struct ExpansionPicker: View {
    let script: TurnScript
    let start: (Set<String>) -> Void
    @State private var chosen: Set<String> = []

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                HStack(spacing: 14) {
                    OrdirMascotView()
                        .frame(width: 48, height: 48)
                    Text("Which expansions are you playing with?")
                        .font(.title3.weight(.semibold))
                        .fixedSize(horizontal: false, vertical: true)
                }
                VStack(spacing: 12) {
                    ForEach(script.expansions) { expansion in
                        Toggle(isOn: binding(for: expansion.id)) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(expansion.title)
                                    .font(.headline)
                                Text(expansion.summary)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        .padding(16)
                        .background(Color(white: 0.11), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                }
                Text("Leave them all off to play the base game.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .padding(20)
        }
        .safeAreaInset(edge: .bottom) {
            Button {
                start(chosen)
            } label: {
                Text("Start guide")
                    .font(.headline)
                    .frame(maxWidth: .infinity, minHeight: 54)
            }
            .buttonStyle(PrimaryButtonStyle())
            .padding(.horizontal, 20)
            .padding(.bottom, 8)
        }
        .navigationTitle(script.title)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func binding(for id: String) -> Binding<Bool> {
        Binding(
            get: { chosen.contains(id) },
            set: { isOn in
                if isOn { chosen.insert(id) } else { chosen.remove(id) }
            }
        )
    }
}

// MARK: - Guide

private struct TurnGuideRunner: View {
    let session: TurnGuideSession
    @State private var isSpeaking = false
    /// Which faction sits at the bottom edge of the phone; the other half faces the far player.
    @State private var nearSeat: TurnScript.Side = .atreides
    @State private var enlarged: EnlargedImage?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Group {
            if session.isFinished {
                finished
            } else {
                splitScreen
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .task(id: stepKey) { await speak() }
        .sheet(item: $enlarged) { item in
            EnlargedImageView(script: session.script, item: item)
        }
    }

    // MARK: Split screen

    private var farSeat: TurnScript.Side { nearSeat == .atreides ? .harkonnen : .atreides }

    private var splitScreen: some View {
        VStack(spacing: 0) {
            panel(for: farSeat, isFar: true)
                .rotationEffect(.degrees(180))
            centerBar
            panel(for: nearSeat, isFar: false)
        }
    }

    private func panel(for seat: TurnScript.Side, isFar: Bool) -> some View {
        SeatPanel(
            seat: seat,
            script: session.script,
            phase: session.phase,
            step: session.step,
            additions: session.additions,
            stepTitle: stepTitle,
            stepKey: stepKey,
            startedAt: session.stepStartedAt,
            isSpeaking: isSpeaking,
            stepTransition: stepTransition,
            done: { withAnimation(stepAnimation) { session.advance() } },
            endLoop: { withAnimation(stepAnimation) { session.endLoop() } },
            enlarge: { enlarged = EnlargedImage(image: $0, isFar: isFar) }
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    /// Shared controls between the two halves, read from the near side.
    private var centerBar: some View {
        HStack(spacing: 4) {
            barButton("Close guide", systemImage: "xmark") { dismiss() }
            Spacer(minLength: 8)
            VStack(spacing: 1) {
                Text(session.phase.title)
                    .font(.footnote.weight(.semibold))
                Text(progressText)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            .accessibilityElement(children: .combine)
            Spacer(minLength: 8)
            barButton("Previous step", systemImage: "arrow.uturn.backward") {
                withAnimation(stepAnimation) { session.goBack() }
            }
            .disabled(!session.canGoBack)
            barButton("Swap seats", systemImage: "arrow.up.arrow.down") {
                withAnimation(stepAnimation) { nearSeat = farSeat }
            }
        }
        .padding(.horizontal, 8)
        .frame(height: 52)
        .background(.bar)
        .overlay(alignment: .top) { Divider() }
        .overlay(alignment: .bottom) { Divider() }
    }

    private func barButton(_ title: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.body.weight(.medium))
                .frame(width: 44, height: 44)
        }
        .accessibilityLabel(title)
    }

    private var progressText: String {
        if session.phase.loop != nil {
            return "Turn \(session.turnNumber)"
        }
        return "\(session.position.step + 1) of \(session.phase.steps.count)"
    }

    // MARK: Finished

    private var finished: some View {
        VStack(spacing: 20) {
            OrdirMascotView()
                .frame(height: 96)
            Text("Round complete")
                .font(.title2.weight(.semibold))
            Text("Setup and one full round are done. Every new round starts the same way (rulebook, page 16).")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button {
                withAnimation(stepAnimation) { session.restart() }
            } label: {
                Text("Start over")
                    .font(.headline)
                    .frame(maxWidth: .infinity, minHeight: 54)
            }
            .buttonStyle(PrimaryButtonStyle())
            .padding(.top, 12)
            Button("Back to games") { dismiss() }
                .font(.subheadline.weight(.semibold))
                .frame(minHeight: 44)
        }
        .padding(32)
        .transition(stepTransition)
    }

    // MARK: Behaviour

    /// Inside a loop, number each side's turns: "Action turn 2".
    private var stepTitle: String {
        session.phase.loop == nil ? session.step.title : "\(session.step.title) \(session.position.pass)"
    }

    private var stepKey: String {
        let p = session.position
        return "\(p.phase)-\(p.step)-\(p.pass)-\(session.isFinished)"
    }

    private var stepAnimation: Animation {
        reduceMotion ? .easeInOut(duration: 0.2) : .smooth(duration: 0.4)
    }

    /// New step fades in with a short rise; a plain cross-fade with Reduce Motion on.
    private var stepTransition: AnyTransition {
        reduceMotion
            ? .opacity
            : .asymmetric(insertion: .opacity.combined(with: .offset(y: 16)), removal: .opacity)
    }

    /// The mascot "speaks" for roughly as long as the instruction takes to read aloud.
    private func speak() async {
        guard !session.isFinished else {
            isSpeaking = false
            return
        }
        let step = session.step
        let announcement: String = "\(step.side.displayName): \(stepTitle). \(step.instruction)"
        AccessibilityNotification.Announcement(announcement).post()
        isSpeaking = true
        let seconds = min(5, max(1.5, Double(step.instruction.count) / 18))
        try? await Task.sleep(for: .seconds(seconds))
        guard !Task.isCancelled else { return }
        isSpeaking = false
    }
}

// MARK: - Seat panel

/// One player's half of the screen: the step when they act, otherwise who they are waiting for.
private struct SeatPanel: View {
    let seat: TurnScript.Side
    let script: TurnScript
    let phase: TurnScript.Phase
    let step: TurnScript.Step
    let additions: [TurnScript.Addition]
    let stepTitle: String
    let stepKey: String
    let startedAt: Date
    let isSpeaking: Bool
    let stepTransition: AnyTransition
    let done: () -> Void
    let endLoop: () -> Void
    let enlarge: (TurnScript.SourceImage) -> Void

    private var isActing: Bool { step.side == seat || step.side == .both }

    var body: some View {
        VStack(spacing: 0) {
            seatLabel
            if isActing {
                ScrollView {
                    StepCard(
                        script: script,
                        phase: phase,
                        step: step,
                        additions: additions,
                        title: stepTitle,
                        isSpeaking: isSpeaking,
                        enlarge: enlarge
                    )
                    .padding(.horizontal, 20)
                    .padding(.bottom, 16)
                    .id(stepKey)
                    .transition(stepTransition)
                }
                .scrollIndicators(.hidden)
                actions
            } else {
                WaitingView(side: step.side, stepTitle: stepTitle, startedAt: startedAt)
                    .id(stepKey)
                    .transition(stepTransition)
            }
        }
    }

    private var seatLabel: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(seat.color)
                .frame(width: 8, height: 8)
            Text(seat.displayName)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(seat.color)
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 8)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(seat.displayName) side")
    }

    private var actions: some View {
        HStack(spacing: 12) {
            if let loop = phase.loop {
                Button(loop.endLabel, action: endLoop)
                    .font(.subheadline.weight(.semibold))
                    .multilineTextAlignment(.center)
                    .frame(minHeight: 44)
            }
            Button(action: done) {
                Text("Done")
                    .font(.headline)
                    .frame(maxWidth: .infinity, minHeight: 50)
            }
            .buttonStyle(PrimaryButtonStyle())
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
    }
}

// MARK: - Step card

private struct StepCard: View {
    let script: TurnScript
    let phase: TurnScript.Phase
    let step: TurnScript.Step
    let additions: [TurnScript.Addition]
    let title: String
    let isSpeaking: Bool
    let enlarge: (TurnScript.SourceImage) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(spacing: 14) {
                OrdirMascotView(isSpeaking: isSpeaking)
                    .frame(width: 48, height: 48)
                VStack(alignment: .leading, spacing: 2) {
                    if let context {
                        Text(context)
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                    Text(title)
                        .font(.title3.weight(.semibold))
                }
                .accessibilityElement(children: .combine)
                .accessibilityAddTraits(.isHeader)
            }

            Text(step.instruction)
                .font(.body)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)

            section("You’ll need") {
                PictureStrip(script: script, pictures: script.pictures(step.images), enlarge: enlarge)
                Text(step.components.joined(separator: ", "))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            section("Source") {
                CitationList(script: script, citations: step.citations)
            }

            ForEach(Array(additions.enumerated()), id: \.offset) { _, addition in
                section(script.expansionTitle(addition.expansion)) {
                    Text(addition.text)
                        .font(.body)
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)
                    PictureStrip(script: script, pictures: script.pictures(addition.images), enlarge: enlarge)
                    CitationList(script: script, citations: addition.citations)
                }
            }

            if let loop = phase.loop {
                section("When to stop") {
                    Text(loop.note)
                        .font(.subheadline)
                        .fixedSize(horizontal: false, vertical: true)
                    CitationList(script: script, citations: loop.citations)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// "Both players" and/or the expansion a step belongs to.
    private var context: String? {
        let parts = [step.side == .both ? "Both players" : nil, step.expansion.map(script.expansionTitle)]
            .compactMap { $0 }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
                .accessibilityAddTraits(.isHeader)
            content()
        }
    }
}

/// Component pictures cropped from the rulebook, each labelled with its page. Tap to enlarge.
private struct PictureStrip: View {
    let script: TurnScript
    let pictures: [TurnScript.SourceImage]
    let enlarge: (TurnScript.SourceImage) -> Void

    var body: some View {
        ScrollView(.horizontal) {
            HStack(alignment: .top, spacing: 12) {
                ForEach(pictures) { picture in
                    Button { enlarge(picture) } label: {
                        VStack(alignment: .leading, spacing: 6) {
                            Image(script.assetName(for: picture))
                                .resizable()
                                .scaledToFit()
                                .frame(width: 176, height: 112)
                                .background(Color(white: 0.12))
                                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                            Text(picture.caption)
                                .font(.caption)
                                .foregroundStyle(.primary)
                                .lineLimit(2)
                            Text(script.label(for: picture))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        .frame(width: 176, alignment: .leading)
                    }
                    .buttonStyle(.plain)
                    .accessibilityElement(children: .combine)
                    .accessibilityHint("Shows the picture larger")
                }
            }
        }
        .scrollIndicators(.hidden)
    }
}

/// One tappable row per cited page; opens the official PDF at that page.
private struct CitationList: View {
    let script: TurnScript
    let citations: [TurnScript.Citation]

    private struct Row: Identifiable {
        let id: String
        let label: String
        let entry: String?
        let url: URL?
    }

    /// Several excerpts can come from the same page; show that page once.
    private var rows: [Row] {
        var seen = Set<String>()
        return citations.compactMap { citation in
            guard let source = script.source(for: citation) else { return nil }
            let id = "\(citation.source)-\(citation.page)-\(citation.entry ?? "")"
            guard seen.insert(id).inserted else { return nil }
            return Row(
                id: id,
                label: "\(source.shortTitle), page \(citation.page)",
                entry: citation.entry,
                url: URL(string: "\(source.url.absoluteString)#page=\(citation.page)")
            )
        }
    }

    var body: some View {
        ForEach(rows) { row in
            if let url = row.url {
                Link(destination: url) {
                    HStack(alignment: .firstTextBaseline) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(row.label)
                            if let entry = row.entry {
                                Text(entry)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Spacer(minLength: 8)
                        Image(systemName: "arrow.up.right")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                            .accessibilityHidden(true)
                    }
                    .font(.subheadline)
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
                }
                .accessibilityHint("Opens the PDF at this page")
            }
        }
    }
}

// MARK: - Waiting

/// What the waiting player sees: who is acting, on which step, and for how long.
private struct WaitingView: View {
    let side: TurnScript.Side
    let stepTitle: String
    let startedAt: Date

    var body: some View {
        VStack(spacing: 14) {
            Spacer(minLength: 0)
            OrdirMascotView(isThinking: true)
                .frame(height: 64)
            line
                .font(.title3)
                .multilineTextAlignment(.center)
            Text(startedAt, style: .timer)
                .font(.title2.monospacedDigit())
                .foregroundStyle(.secondary)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
    }

    private var line: Text {
        let step = Text(stepTitle).fontWeight(.semibold)
        return Text("The \(side.displayName) is on \(step)")
    }
}

// MARK: - Enlarged picture

private struct EnlargedImage: Identifiable {
    let image: TurnScript.SourceImage
    /// Opened from the far half, so it is shown turned to face that player.
    let isFar: Bool
    var id: String { image.id }
}

private struct EnlargedImageView: View {
    let script: TurnScript
    let item: EnlargedImage
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(script.assetName(for: item.image))
                .resizable()
                .scaledToFit()
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .accessibilityLabel(item.image.caption)
            Text(item.image.caption)
                .font(.headline)
            Text(script.label(for: item.image))
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Button {
                dismiss()
            } label: {
                Text("Close")
                    .font(.headline)
                    .frame(maxWidth: .infinity, minHeight: 50)
            }
            .buttonStyle(PrimaryButtonStyle())
            .padding(.top, 8)
        }
        .padding(20)
        .frame(maxHeight: .infinity)
        .rotationEffect(.degrees(item.isFar ? 180 : 0))
        .presentationDetents([.medium, .large])
    }
}

// MARK: - Styling

private struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(.background)
            .background(
                Color.primary.opacity(configuration.isPressed ? 0.7 : 1),
                in: RoundedRectangle(cornerRadius: 16, style: .continuous)
            )
    }
}

extension TurnScript.Side {
    var displayName: String {
        switch self {
        case .atreides: "Atreides"
        case .harkonnen: "Harkonnen"
        case .both: "Both players"
        }
    }

    var color: Color {
        switch self {
        case .atreides: Color("SideAtreides")
        case .harkonnen: Color("SideHarkonnen")
        case .both: .secondary
        }
    }
}

#Preview {
    NavigationStack {
        if let script = TurnScript.bundled(for: .duneWarForArrakis) {
            TurnGuideView(script: script)
        }
    }
}
