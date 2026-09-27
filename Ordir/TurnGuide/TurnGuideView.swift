//
//  TurnGuideView.swift
//  Ordir
//
//  Pass-and-play turn guide on one phone: who acts, what to do, what you need, where the rule is.
//  "Done" advances; the mascot speaks each new instruction; the top strip tells the waiting
//  player where the other side is and for how long.
//

import SwiftUI

struct TurnGuideView: View {
    @State private var session: TurnGuideSession
    @State private var isSpeaking = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(script: TurnScript) {
        _session = State(initialValue: TurnGuideSession(script: script))
    }

    var body: some View {
        Group {
            if session.isFinished {
                finished
            } else {
                guide
            }
        }
        .navigationTitle(session.script.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    withAnimation(stepAnimation) { session.goBack() }
                } label: {
                    Label("Previous step", systemImage: "arrow.uturn.backward")
                }
                .disabled(!session.canGoBack)
            }
        }
        .task(id: stepKey) { await speak() }
    }

    // MARK: Guide

    private var guide: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                progressHeader
                StepCard(
                    script: session.script,
                    phase: session.phase,
                    step: session.step,
                    title: stepTitle,
                    isSpeaking: isSpeaking
                )
                .id(stepKey)
                .transition(stepTransition)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 20)
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            WaitingStrip(side: session.step.side, stepTitle: stepTitle, startedAt: session.stepStartedAt)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            actionBar
        }
    }

    private var progressHeader: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(session.phase.title)
                .font(.subheadline.weight(.semibold))
            Spacer()
            Text(progressText)
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
    }

    private var progressText: String {
        if session.phase.loop != nil {
            return "Turn \(session.turnNumber)"
        }
        return "\(session.position.step + 1) of \(session.phase.steps.count)"
    }

    private var actionBar: some View {
        VStack(spacing: 4) {
            if let loop = session.phase.loop {
                Button(loop.endLabel) {
                    withAnimation(stepAnimation) { session.endLoop() }
                }
                .font(.subheadline.weight(.semibold))
                .frame(minHeight: 44)
            }
            Button {
                withAnimation(stepAnimation) { session.advance() }
            } label: {
                Text("Done")
                    .font(.headline)
                    .frame(maxWidth: .infinity, minHeight: 54)
            }
            .buttonStyle(PrimaryButtonStyle())
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, 8)
        .background(.bar)
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

// MARK: - Step card

private struct StepCard: View {
    let script: TurnScript
    let phase: TurnScript.Phase
    let step: TurnScript.Step
    let title: String
    let isSpeaking: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            HStack(spacing: 14) {
                OrdirMascotView(isSpeaking: isSpeaking)
                    .frame(width: 52, height: 52)
                VStack(alignment: .leading, spacing: 2) {
                    Text(step.side.displayName)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(step.side.color)
                    Text(title)
                        .font(.title2.weight(.semibold))
                }
                .accessibilityElement(children: .combine)
                .accessibilityAddTraits(.isHeader)
            }

            Text(step.instruction)
                .font(.body)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)

            section("You’ll need") {
                ForEach(step.components, id: \.self) { component in
                    Text(component)
                        .font(.subheadline)
                }
            }

            section("Source") {
                CitationList(script: script, citations: step.citations)
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

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
                .accessibilityAddTraits(.isHeader)
            content()
        }
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
                    .foregroundStyle(.primary)
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
                }
                .accessibilityHint("Opens the PDF at this page")
            }
        }
    }
}

// MARK: - Waiting strip

/// What the waiting player glances at: who is acting, on which step, and for how long.
private struct WaitingStrip: View {
    let side: TurnScript.Side
    let stepTitle: String
    let startedAt: Date

    var body: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(side.color)
                .frame(width: 8, height: 8)
                .accessibilityHidden(true)
            Text(line)
                .font(.footnote)
                .lineLimit(2)
            Spacer(minLength: 8)
            Text(startedAt, style: .timer)
                .font(.footnote.monospacedDigit())
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity)
        .background(.bar)
        .accessibilityElement(children: .combine)
    }

    private var line: Text {
        let step = Text(stepTitle).fontWeight(.semibold)
        switch side {
        case .both: return Text("Both players are on \(step)")
        case .atreides, .harkonnen: return Text("The \(side.displayName) is on \(step)")
        }
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
