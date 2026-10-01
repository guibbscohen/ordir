//
//  TurnGuideView.swift
//  Ordir
//
//  Turn guide on one phone, played two ways:
//  - On the table: the screen splits in two and the far half is turned 180° to face the player
//    across the table. The acting side's half shows the step (instruction, component pictures,
//    sources, "Done"); the other half shows who is acting, on which step, and for how long. Steps
//    for both players show on both halves; either "Done" advances.
//  - Pass the phone: one full-screen step at a time; when the turn moves to the other player, a
//    handoff screen asks for the phone to be passed first.
//  The mascot speaks each new instruction.
//

import SwiftUI

/// How the players share the phone.
enum PlayMode {
    /// Lying flat between the players, split in two halves.
    case table
    /// Handed to whoever acts next, one full-screen step at a time.
    case pass
}

struct TurnGuideView: View {
    let script: TurnScript
    @State private var session: TurnGuideSession?
    @State private var mode: PlayMode

    /// `startAt` and `expansions` skip the setup picker (CI screenshots use them).
    init(script: TurnScript, mode: PlayMode = .table, startAt stepID: String? = nil, expansions: Set<String>? = nil) {
        self.script = script
        _mode = State(initialValue: mode)
        if stepID != nil {
            let session = TurnGuideSession(
                script: script,
                expansions: expansions ?? [],
                passesPhone: mode == .pass,
                startAt: stepID
            )
            _session = State(initialValue: session)
        }
    }

    var body: some View {
        if let session {
            TurnGuideRunner(session: session, mode: mode)
        } else {
            SetupPicker(script: script, mode: mode) { chosenMode, chosen in
                mode = chosenMode
                session = TurnGuideSession(script: script, expansions: chosen, passesPhone: chosenMode == .pass)
            }
        }
    }
}

// MARK: - Setup picker

/// Asked once before the guide starts: how the phone is shared, and which expansions are on the table.
private struct SetupPicker: View {
    let script: TurnScript
    let start: (PlayMode, Set<String>) -> Void
    @State private var mode: PlayMode
    @State private var chosen: Set<String> = []

    init(script: TurnScript, mode: PlayMode, start: @escaping (PlayMode, Set<String>) -> Void) {
        self.script = script
        self.start = start
        _mode = State(initialValue: mode)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                HStack(spacing: 14) {
                    OrdirMascotView()
                        .frame(width: 48, height: 48)
                        .accessibilityHidden(true)
                    Text("How are you playing?")
                        .font(.title3.weight(.semibold))
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityAddTraits(.isHeader)
                }
                VStack(spacing: 12) {
                    modeRow(.table, title: "One phone on the table", detail: "Split screen: the top half faces the player across the table.")
                    modeRow(.pass, title: "Pass the phone", detail: "Full screen: hand the phone to whoever acts next.")
                }
                Text("Which expansions are you playing with?")
                    .font(.title3.weight(.semibold))
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)
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
                        .accessibilityIdentifier("expansion-\(expansion.id)")
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
                start(mode, chosen)
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

    private func modeRow(_ option: PlayMode, title: String, detail: String) -> some View {
        let isSelected = mode == option
        return Button {
            mode = option
        } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                    Text(detail)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 8)
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isSelected ? Color.primary : Color.secondary)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(white: 0.11), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(option == .table ? "mode-table" : "mode-pass")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
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
    let mode: PlayMode
    /// A battle walkthrough runs in its own runner, opened over the turn it started from.
    let isBattle: Bool
    @State private var isSpeaking = false
    /// Which faction sits at the bottom edge of the phone; the other half faces the far player.
    @State private var nearSeat: TurnScript.Side
    @State private var battle: TurnGuideSession?

    init(session: TurnGuideSession, mode: PlayMode, isBattle: Bool = false, nearSeat: TurnScript.Side = .atreides) {
        self.session = session
        self.mode = mode
        self.isBattle = isBattle
        _nearSeat = State(initialValue: nearSeat)
    }
    @State private var enlarged: EnlargedImage?
    @State private var showsGameMenu = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Group {
            if session.isFinished {
                finished
            } else if mode == .pass {
                passScreen
            } else {
                splitScreen
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .task(id: stepKey) { await speak() }
        .sheet(item: $enlarged) { item in
            EnlargedImageView(script: session.script, item: item)
        }
        .fullScreenCover(item: $battle) { battle in
            TurnGuideRunner(session: battle, mode: mode, isBattle: true, nearSeat: nearSeat)
        }
        .sheet(isPresented: $showsGameMenu) {
            GameMenu(
                session: session,
                endGame: { winner in
                    showsGameMenu = false
                    withAnimation(stepAnimation) { session.endGame(winner: winner) }
                },
                leave: {
                    showsGameMenu = false
                    dismiss()
                }
            )
        }
    }

    // MARK: Split screen

    private var farSeat: TurnScript.Side { nearSeat == .atreides ? .harkonnen : .atreides }

    /// VoiceOver starts with the near half, then the bar, then the far half; when a step is for both
    /// players, the far half's identical copy is skipped (unless it holds an event checklist).
    private var splitScreen: some View {
        VStack(spacing: 0) {
            panel(for: farSeat, isFar: true)
                .rotationEffect(.degrees(180))
                .accessibilityHidden(session.step.side == .both && session.pendingEvent == nil)
                .accessibilitySortPriority(0)
            centerBar
                .accessibilitySortPriority(1)
            panel(for: nearSeat, isFar: false)
                .accessibilitySortPriority(2)
        }
        .accessibilityElement(children: .contain)
    }

    private func panel(for seat: TurnScript.Side, isFar: Bool) -> some View {
        SeatPanel(
            seat: seat,
            script: session.script,
            phase: session.phase,
            step: session.step,
            additions: session.additions,
            reminders: session.reminders,
            stepTitle: stepTitle,
            stepKey: stepKey,
            startedAt: session.stepStartedAt,
            isSpeaking: isSpeaking,
            stepTransition: stepTransition,
            done: { withAnimation(stepAnimation) { session.advance() } },
            endLoop: { withAnimation(stepAnimation) { session.endLoop() } },
            enlarge: { enlarged = EnlargedImage(image: $0, isFar: isFar) },
            event: session.pendingEvent,
            dismissEvent: { withAnimation(stepAnimation) { session.dismissEvent() } },
            markState: { id in withAnimation(stepAnimation) { session.setState(id, true) } },
            startBattle: { battle = session.makeBattle() }
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: Pass the phone

    private var passScreen: some View {
        VStack(spacing: 0) {
            passBar
            if let side = session.handoffTo {
                HandoffView(side: side, stepTitle: stepTitle) {
                    withAnimation(stepAnimation) { session.confirmHandoff() }
                }
                .transition(stepTransition)
            } else {
                panel(for: session.step.side, isFar: false)
            }
        }
    }

    /// Top bar for pass-the-phone play: nothing needs mirroring, so it shows the step timer instead.
    private var passBar: some View {
        HStack(spacing: 4) {
            menuOrLeaveButton
            Spacer(minLength: 8)
            phaseLabel
                .accessibilityIdentifier("guide-progress")
            Spacer(minLength: 8)
            barButton("Previous step", systemImage: "arrow.uturn.backward") {
                withAnimation(stepAnimation) { session.goBack() }
            }
            .disabled(!session.canGoBack)
            Text(session.stepStartedAt, style: .timer)
                .font(.footnote.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(minWidth: 44)
                .accessibilityLabel(Text("Time on this step: ") + Text(session.stepStartedAt, style: .timer))
        }
        .padding(.horizontal, 8)
        .frame(minHeight: 52)
        .background(.bar)
        .overlay(alignment: .bottom) { Divider() }
    }

    /// Shared controls between the two halves, read from the near side.
    private var centerBar: some View {
        HStack(spacing: 4) {
            menuOrLeaveButton
            Spacer(minLength: 8)
            // The phase reads both ways: the upper copy is turned to face the far player.
            VStack(spacing: 2) {
                phaseLabel
                    .rotationEffect(.degrees(180))
                    .accessibilityHidden(true)
                phaseLabel
                    .accessibilityIdentifier("guide-progress")
            }
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
        .frame(minHeight: 60)
        .background(.bar)
        .overlay(alignment: .top) { Divider() }
        .overlay(alignment: .bottom) { Divider() }
    }

    /// The game's menu; in a battle, a way back to the turn instead.
    @ViewBuilder private var menuOrLeaveButton: some View {
        if isBattle {
            barButton("Leave battle", systemImage: "xmark") { dismiss() }
        } else {
            barButton("Game menu", systemImage: "flag.checkered") { showsGameMenu = true }
        }
    }

    private func barButton(_ title: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.body.weight(.medium))
                .frame(minWidth: 44, minHeight: 44)
        }
        .accessibilityLabel(title)
    }

    private var phaseLabel: some View {
        HStack(spacing: 6) {
            Text(session.phase.title)
                .font(.footnote.weight(.semibold))
            Text(progressText)
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
        }
        .lineLimit(2)
        .multilineTextAlignment(.center)
        .accessibilityElement(children: .combine)
    }

    private var progressText: String {
        let steps = "\(session.stepNumber) of \(session.applicableSteps.count)"
        if isBattle {
            // Combat rounds repeat: "Round 2 · 3 of 6".
            return session.phase.loop != nil ? "Round \(session.position.pass) · \(steps)" : steps
        }
        let inPhase = session.phase.loop != nil ? "Turn \(session.turnNumber)" : steps
        return session.isInSetup ? inPhase : "Round \(session.round) · \(inPhase)"
    }

    // MARK: Finished

    @ViewBuilder private var finished: some View {
        if isBattle {
            battleOver
        } else {
            gameOver
        }
    }

    private var battleOver: some View {
        VStack(spacing: 20) {
            OrdirMascotView()
                .frame(height: 96)
                .accessibilityHidden(true)
            Text("Battle over")
                .font(.title2.weight(.semibold))
                .accessibilityAddTraits(.isHeader)
            Text("Back to the turn: finish your Action, then tap Done.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button {
                dismiss()
            } label: {
                Text("Back to the turn")
                    .font(.headline)
                    .frame(maxWidth: .infinity, minHeight: 54)
            }
            .buttonStyle(PrimaryButtonStyle())
            .padding(.top, 12)
        }
        .padding(32)
        .transition(stepTransition)
    }

    private var gameOver: some View {
        VStack(spacing: 20) {
            OrdirMascotView()
                .frame(height: 96)
                .accessibilityHidden(true)
            Text("Game over")
                .font(.title2.weight(.semibold))
                .accessibilityAddTraits(.isHeader)
            if let winner = session.winner {
                Text("The \(Text(winner.displayName).foregroundColor(winner.color)) win")
                    .font(.title3.weight(.semibold))
            }
            Text(session.round == 1 ? "Played in 1 round." : "Played in \(session.round) rounds.")
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

    /// Inside a loop, number each side's turns: "Action turn 2". Battles show the round in the bar instead.
    private var stepTitle: String {
        session.phase.loop == nil || isBattle ? session.step.title : "\(session.step.title) \(session.position.pass)"
    }

    private var stepKey: String {
        let p = session.position
        return "\(p.round)-\(p.phase)-\(p.step)-\(p.pass)-\(session.isFinished)-\(session.handoffTo == nil)"
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
        guard !session.isFinished, session.handoffTo == nil else {
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

// MARK: - Game menu

/// Round, game states (to mark or correct) and ending the game.
private struct GameMenu: View {
    let session: TurnGuideSession
    let endGame: (TurnScript.Side?) -> Void
    let leave: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text(session.isInSetup ? "Setup" : "Round \(session.round)")
                }
                if !session.availableStates.isEmpty {
                    Section("Happened this game") {
                        ForEach(session.availableStates) { state in
                            Toggle(isOn: Binding(
                                get: { session.activeStates.contains(state.id) },
                                set: { session.setState(state.id, $0) }
                            )) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(state.title)
                                    Text(state.trigger)
                                        .font(.footnote)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
                Section {
                    Button("The Atreides won") { endGame(.atreides) }
                        .foregroundStyle(TurnScript.Side.atreides.color)
                    Button("The Harkonnen won") { endGame(.harkonnen) }
                        .foregroundStyle(TurnScript.Side.harkonnen.color)
                } header: {
                    Text("End the game")
                } footer: {
                    Text("The Harkonnen win at 10 Supremacy points; the Atreides when every Prescience marker reaches their Secret Objective (rulebook, pages 7 and 27).")
                }
                Section {
                    Button("Leave the guide", action: leave)
                }
            }
            .navigationTitle("Game")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

// MARK: - Handoff

/// Pass-the-phone play: shown when the next step belongs to the other player.
private struct HandoffView: View {
    let side: TurnScript.Side
    let stepTitle: String
    let ready: () -> Void

    var body: some View {
        VStack(spacing: 18) {
            Spacer(minLength: 0)
            OrdirMascotView(isThinking: true)
                .frame(height: 80)
                .accessibilityHidden(true)
            VStack(spacing: 6) {
                Text("Pass the phone to the \(Text(side.displayName).foregroundColor(side.color))")
                    .font(.title2.weight(.semibold))
                    .multilineTextAlignment(.center)
                    .accessibilityAddTraits(.isHeader)
                Text("Next: \(stepTitle)")
                    .font(.body)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            Button(action: ready) {
                Text("I’m the \(side.displayName)")
                    .font(.headline)
                    .frame(maxWidth: .infinity, minHeight: 54)
            }
            .buttonStyle(PrimaryButtonStyle())
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 12)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
    let reminders: [TurnScript.Reminder]
    let stepTitle: String
    let stepKey: String
    let startedAt: Date
    let isSpeaking: Bool
    let stepTransition: AnyTransition
    let done: () -> Void
    let endLoop: () -> Void
    let enlarge: (TurnScript.SourceImage) -> Void
    /// A game state that just happened; its one-off steps cover the half of the side it belongs to.
    let event: TurnScript.GameState?
    let dismissEvent: () -> Void
    let markState: (String) -> Void
    let startBattle: () -> Void

    /// Set while the turn-change checklist is up; holds what "Pass the turn" will do.
    @State private var pendingPass: (() -> Void)?

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
                        // In pass-the-phone play the seat label already says "Both players".
                        showsBothPlayers: seat != .both,
                        isSpeaking: isSpeaking,
                        enlarge: enlarge,
                        markState: markState,
                        startBattle: startBattle
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
        .overlay {
            if let event, seat == event.event.side || seat == .both {
                EventChecklist(script: script, state: event, enlarge: enlarge, done: dismissEvent)
                    .transition(stepTransition)
            } else if let pass = pendingPass {
                PassTurnChecklist(
                    script: script,
                    reminders: reminders,
                    pass: {
                        pendingPass = nil
                        pass()
                    },
                    cancel: { withAnimation { pendingPass = nil } }
                )
                .transition(stepTransition)
            }
        }
    }

    /// Turns with reminders stop at the checklist first; everything else moves on at once.
    private func passTurn(then action: @escaping () -> Void) {
        if reminders.isEmpty {
            action()
        } else {
            withAnimation { pendingPass = action }
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
        .accessibilityAddTraits(.isHeader)
    }

    private var actions: some View {
        HStack(spacing: 12) {
            if let loop = phase.loop {
                Button(loop.endLabel) { passTurn(then: endLoop) }
                    .font(.subheadline.weight(.semibold))
                    .multilineTextAlignment(.center)
                    .frame(minHeight: 44)
            }
            Button { passTurn(then: done) } label: {
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
    let showsBothPlayers: Bool
    let isSpeaking: Bool
    let enlarge: (TurnScript.SourceImage) -> Void
    let markState: (String) -> Void
    let startBattle: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(spacing: 14) {
                OrdirMascotView(isSpeaking: isSpeaking)
                    .frame(width: 48, height: 48)
                    .accessibilityHidden(true)
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

            VStack(alignment: .leading, spacing: 10) {
                Text(step.instruction)
                    .font(.body.weight(.medium))
                    .fixedSize(horizontal: false, vertical: true)
                BulletList(items: step.bullets ?? [])
                if step.opensBattle == true, script.battle != nil {
                    Button(action: startBattle) {
                        Label("Start a battle", systemImage: "shield.lefthalf.filled")
                            .font(.subheadline.weight(.semibold))
                            .frame(minHeight: 44)
                    }
                    .accessibilityHint("Walks both players through the battle, then returns to this turn")
                }
            }

            ForEach(Array(additions.enumerated()), id: \.offset) { _, addition in
                section(script.expansionTitle(addition.expansion)) {
                    Text(addition.text)
                        .font(.body)
                        .fixedSize(horizontal: false, vertical: true)
                    BulletList(items: addition.bullets ?? [])
                    PictureStrip(script: script, pictures: script.pictures(addition.images), enlarge: enlarge)
                    CitationList(script: script, citations: addition.citations)
                    if let id = addition.sets, let state = script.state(id) {
                        Button(state.markLabel) { markState(id) }
                            .font(.subheadline.weight(.semibold))
                            .frame(minHeight: 44)
                    }
                }
            }

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
        let parts = [step.side == .both && showsBothPlayers ? "Both players" : nil, step.expansion.map(script.expansionTitle)]
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

/// Options and sub-steps as a short list instead of a paragraph.
private struct BulletList: View {
    let items: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Text("•")
                        .foregroundStyle(.secondary)
                        .accessibilityHidden(true)
                    Text(item)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .font(.body)
            }
        }
    }
}

/// Covers a half when a game state happens, e.g. the Smugglers allying: its one-off steps.
private struct EventChecklist: View {
    let script: TurnScript
    let state: TurnScript.GameState
    let enlarge: (TurnScript.SourceImage) -> Void
    let done: () -> Void
    @AccessibilityFocusState private var headingFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                OrdirMascotView(isSpeaking: true)
                    .frame(width: 40, height: 40)
                    .accessibilityHidden(true)
                Text(state.event.title)
                    .font(.title3.weight(.semibold))
                    .accessibilityAddTraits(.isHeader)
                    .accessibilityFocused($headingFocused)
            }
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    ReminderChecklist(reminders: state.event.bullets.map {
                        TurnScript.Reminder(expansion: nil, text: $0, citations: [])
                    })
                    PictureStrip(script: script, pictures: script.pictures(state.event.images), enlarge: enlarge)
                    CitationList(script: script, citations: state.event.citations)
                }
            }
            .scrollIndicators(.hidden)
            Button(action: done) {
                Text("Done")
                    .font(.headline)
                    .frame(maxWidth: .infinity, minHeight: 50)
            }
            .buttonStyle(PrimaryButtonStyle())
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(.background)
        .task {
            // Let the overlay settle before VoiceOver focus moves onto it.
            try? await Task.sleep(for: .milliseconds(300))
            headingFocused = true
        }
    }
}

/// Covers the acting half when the player taps Done on a turn with reminders.
private struct PassTurnChecklist: View {
    let script: TurnScript
    let reminders: [TurnScript.Reminder]
    let pass: () -> Void
    let cancel: () -> Void
    @AccessibilityFocusState private var headingFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                OrdirMascotView(isSpeaking: true)
                    .frame(width: 40, height: 40)
                    .accessibilityHidden(true)
                Text("Before you pass the turn")
                    .font(.title3.weight(.semibold))
                    .accessibilityAddTraits(.isHeader)
                    .accessibilityFocused($headingFocused)
            }
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    ReminderChecklist(reminders: reminders)
                    CitationList(script: script, citations: reminders.flatMap(\.citations))
                }
            }
            .scrollIndicators(.hidden)
            HStack(spacing: 12) {
                Button("Not yet", action: cancel)
                    .font(.subheadline.weight(.semibold))
                    .frame(minHeight: 44)
                Button(action: pass) {
                    Text("Pass the turn")
                        .font(.headline)
                        .frame(maxWidth: .infinity, minHeight: 50)
                }
                .buttonStyle(PrimaryButtonStyle())
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(.background)
        .task {
            // Let the overlay settle before VoiceOver focus moves onto it.
            try? await Task.sleep(for: .milliseconds(300))
            headingFocused = true
        }
    }
}

/// Tick-off list for the moment the turn passes. Resets with every new step.
private struct ReminderChecklist: View {
    let reminders: [TurnScript.Reminder]
    @State private var checked: Set<Int> = []

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            ForEach(Array(reminders.enumerated()), id: \.offset) { index, reminder in
                let isChecked = checked.contains(index)
                Button {
                    if isChecked { checked.remove(index) } else { checked.insert(index) }
                } label: {
                    HStack(alignment: .firstTextBaseline, spacing: 12) {
                        Image(systemName: isChecked ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(isChecked ? Color.primary : Color.secondary)
                        Text(reminder.text)
                            .foregroundStyle(isChecked ? Color.secondary : Color.primary)
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 0)
                    }
                    .font(.body)
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(isChecked ? [.isToggle, .isSelected] : [.isToggle])
            }
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
                                .accessibilityHidden(true)
                            Text(picture.caption)
                                .font(.caption)
                                .foregroundStyle(.primary)
                                .fixedSize(horizontal: false, vertical: true)
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
                .accessibilityHidden(true)
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
        case .attacker: "Attacker"
        case .defender: "Defender"
        }
    }

    var color: Color {
        switch self {
        case .atreides: Color("SideAtreides")
        case .harkonnen: Color("SideHarkonnen")
        case .both, .attacker, .defender: .secondary
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
