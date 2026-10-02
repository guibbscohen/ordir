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
                    Text(tr("How are you playing?"))
                        .font(.ordir(.title3).weight(.semibold))
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityAddTraits(.isHeader)
                }
                VStack(spacing: 12) {
                    modeRow(.table, title: tr("One phone on the table"), detail: tr("Split screen: the top half faces the player across the table."))
                    modeRow(.pass, title: tr("Pass the phone"), detail: tr("Full screen: hand the phone to whoever acts next."))
                }
                Text(tr("Which expansions are you playing with?"))
                    .font(.ordir(.title3).weight(.semibold))
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)
                VStack(spacing: 12) {
                    ForEach(script.expansions) { expansion in
                        Toggle(isOn: binding(for: expansion.id)) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(expansion.title)
                                    .font(.ordir(.headline))
                                Text(expansion.summary)
                                    .font(.ordir(.subheadline))
                                    .foregroundStyle(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        .accessibilityIdentifier("expansion-\(expansion.id)")
                        .padding(16)
                        .background(Color(white: 0.11), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                }
                Text(tr("Leave them all off to play the base game."))
                    .font(.ordir(.footnote))
                    .foregroundStyle(.secondary)
            }
            .padding(20)
        }
        .safeAreaInset(edge: .bottom) {
            Button {
                start(mode, chosen)
            } label: {
                Text(tr("Start guide"))
                    .font(.ordir(.headline))
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
                        .font(.ordir(.headline))
                    Text(detail)
                        .font(.ordir(.subheadline))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 8)
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.ordir(.title3))
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

    init(session: TurnGuideSession, mode: PlayMode, isBattle: Bool = false, nearSeat: TurnScript.Side? = nil) {
        self.session = session
        self.mode = mode
        self.isBattle = isBattle
        _nearSeat = State(initialValue: nearSeat ?? session.script.sides[0].id)
    }
    @State private var enlarged: EnlargedImage?
    @State private var showsGameMenu = false
    /// The last move was "Previous step", so steps change in the opposite direction.
    @State private var goingBack = false
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
        .sensoryFeedback(.impact(weight: .light), trigger: session.position)
        .sensoryFeedback(.success, trigger: session.isFinished) { _, finished in finished }
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

    private var farSeat: TurnScript.Side { session.script.opponent(of: nearSeat) }

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
            done: {
                goingBack = false
                withAnimation(stepAnimation) { session.advance() }
            },
            endLoop: {
                goingBack = false
                withAnimation(stepAnimation) { session.endLoop() }
            },
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
                HandoffView(script: session.script, side: side, stepTitle: stepTitle) {
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
            barButton(tr("Previous step"), systemImage: "arrow.uturn.backward") {
                goingBack = true
                withAnimation(stepAnimation) { session.goBack() }
            }
            .disabled(!session.canGoBack)
            Text(session.stepStartedAt, style: .timer)
                .font(.ordir(.footnote).monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(minWidth: 44)
                .accessibilityLabel(Text(tr("Time on this step: ")) + Text(session.stepStartedAt, style: .timer))
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
            .layoutPriority(1)
            Spacer(minLength: 8)
            barButton(tr("Previous step"), systemImage: "arrow.uturn.backward") {
                goingBack = true
                withAnimation(stepAnimation) { session.goBack() }
            }
            .disabled(!session.canGoBack)
            barButton(tr("Swap seats"), systemImage: "arrow.up.arrow.down") {
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
            barButton(tr("Leave battle"), systemImage: "xmark") { dismiss() }
        } else {
            barButton(tr("Game menu"), systemImage: "flag.checkered") { showsGameMenu = true }
        }
    }

    private func barButton(_ title: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.ordir(.body).weight(.medium))
                .frame(minWidth: 44, minHeight: 44)
        }
        .accessibilityLabel(title)
    }

    /// Phase over progress, wrapping rather than clipping at large text sizes. The progress uses the
    /// primary colour: secondary text falls below 4.5:1 on the bar's translucent background.
    private var phaseLabel: some View {
        VStack(spacing: 1) {
            Text(session.phase.title)
                .font(.ordir(.footnote).weight(.semibold))
                .id(session.phase.title)
                .transition(reduceMotion ? .opacity : .push(from: .bottom))
            Text(progressText)
                .font(.ordir(.caption).monospacedDigit())
        }
        .multilineTextAlignment(.center)
        .fixedSize(horizontal: false, vertical: true)
        .layoutPriority(1)
        .accessibilityElement(children: .combine)
    }

    private var progressText: String {
        let steps = tr("{0} of {1}", session.stepNumber, session.applicableSteps.count)
        if isBattle {
            // Combat rounds repeat: "Round 2 · 3 of 6".
            return session.phase.loop != nil ? "\(tr("Round {0}", session.position.pass)) · \(steps)" : steps
        }
        let inPhase = session.phase.loop != nil ? tr("Turn {0}", session.turnNumber) : steps
        return session.isInSetup ? inPhase : "\(tr("Round {0}", session.round)) · \(inPhase)"
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
            Text(tr("Battle over"))
                .font(.ordir(.title2).weight(.semibold))
                .accessibilityAddTraits(.isHeader)
            Text(tr("Back to the turn: finish your Action, then tap Done."))
                .font(.ordir(.body))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button {
                dismiss()
            } label: {
                Text(tr("Back to the turn"))
                    .font(.ordir(.headline))
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
            Text(tr("Game over"))
                .font(.ordir(.title2).weight(.semibold))
                .accessibilityAddTraits(.isHeader)
            if let winner = session.winner {
                Text(tr: "The {0} win", Text(session.script.name(of: winner)).foregroundColor(session.script.color(of: winner)))
                    .font(.ordir(.title3).weight(.semibold))
            }
            Text(session.round == 1 ? tr("Played in 1 round.") : tr("Played in {0} rounds.", session.round))
                .font(.ordir(.body))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button {
                withAnimation(stepAnimation) { session.restart() }
            } label: {
                Text(tr("Start over"))
                    .font(.ordir(.headline))
                    .frame(maxWidth: .infinity, minHeight: 54)
            }
            .buttonStyle(PrimaryButtonStyle())
            .padding(.top, 12)
            Button(tr("Back to games")) { dismiss() }
                .buttonStyle(TextButtonStyle())
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

    /// Forward, the new step rises in as the old one lifts away; going back, the step comes in from above
    /// and the old one sinks. A plain cross-fade with Reduce Motion on.
    private var stepTransition: AnyTransition {
        reduceMotion
            ? .opacity
            : .asymmetric(insertion: .opacity.combined(with: .offset(y: goingBack ? -16 : 16)),
                          removal: .opacity.combined(with: .offset(y: goingBack ? 12 : -12)))
    }

    /// The mascot "speaks" for roughly as long as the instruction takes to read aloud.
    private func speak() async {
        guard !session.isFinished, session.handoffTo == nil else {
            isSpeaking = false
            return
        }
        let step = session.step
        let announcement: String = "\(session.script.name(of: step.side)): \(stepTitle). \(step.instruction)"
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
                    Text(session.isInSetup ? tr("Setup") : tr("Round {0}", session.round))
                }
                if !session.availableStates.isEmpty {
                    Section(tr("Happened this game")) {
                        ForEach(session.availableStates) { state in
                            Toggle(isOn: Binding(
                                get: { session.activeStates.contains(state.id) },
                                set: { session.setState(state.id, $0) }
                            )) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(state.title)
                                    Text(state.trigger)
                                        .font(.ordir(.footnote))
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
                Section {
                    ForEach(session.script.sides) { side in
                        Button(tr("The {0} won", side.name)) { endGame(side.id) }
                            .foregroundStyle(session.script.color(of: side.id))
                    }
                } header: {
                    Text(tr("End the game"))
                } footer: {
                    Text("\(session.script.victory.note) (\(session.script.citeText(session.script.victory.citations)))")
                }
                Section {
                    Button(tr("Leave the guide"), action: leave)
                }
            }
            .navigationTitle(tr("Game"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(tr("Close")) { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

// MARK: - Handoff

/// Pass-the-phone play: shown when the next step belongs to the other player.
private struct HandoffView: View {
    let script: TurnScript
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
                Text(tr: "Pass the phone to the {0}", Text(script.name(of: side)).foregroundColor(script.color(of: side)))
                    .font(.ordir(.title2).weight(.semibold))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)
                Text(tr("Next: {0}", stepTitle))
                    .font(.ordir(.body))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
            Button(action: ready) {
                Text(tr("I’m the {0}", script.name(of: side)))
                    .font(.ordir(.headline))
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
                WaitingView(sideName: script.name(of: step.side), stepTitle: stepTitle, startedAt: startedAt)
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
                .fill(script.color(of: seat))
                .frame(width: 8, height: 8)
            Text(script.name(of: seat))
                .font(.ordir(.subheadline).weight(.semibold))
                .foregroundStyle(script.color(of: seat))
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 8)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(tr("{0} side", script.name(of: seat)))
        .accessibilityAddTraits(.isHeader)
    }

    private var actions: some View {
        ActionRow {
            if let loop = phase.loop {
                Button(loop.endLabel) { passTurn(then: endLoop) }
                    .buttonStyle(TextButtonStyle())
            }
        } primary: {
            Button { passTurn(then: done) } label: {
                Text(tr("Done"))
                    .font(.ordir(.headline))
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
                            .font(.ordir(.footnote).weight(.semibold))
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Text(title)
                        .font(.ordir(.title3).weight(.semibold))
                        .fixedSize(horizontal: false, vertical: true)
                }
                .accessibilityElement(children: .combine)
                .accessibilityAddTraits(.isHeader)
            }

            VStack(alignment: .leading, spacing: 10) {
                Text(step.instruction)
                    .font(.ordir(.body).weight(.medium))
                    .fixedSize(horizontal: false, vertical: true)
                BulletList(items: step.bullets ?? [])
                if step.opensBattle == true, script.battle != nil {
                    Button(action: startBattle) {
                        Label(tr("Start a battle"), systemImage: "shield.lefthalf.filled")
                            .font(.ordir(.subheadline).weight(.semibold))
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(minHeight: 44)
                            .contentShape(Rectangle())
                    }
                    .accessibilityHint(tr("Walks both players through the battle, then returns to this turn"))
                }
            }

            ForEach(Array(additions.enumerated()), id: \.offset) { _, addition in
                section(script.expansionTitle(addition.expansion)) {
                    Text(addition.text)
                        .font(.ordir(.body))
                        .fixedSize(horizontal: false, vertical: true)
                    BulletList(items: addition.bullets ?? [])
                    PictureStrip(script: script, pictures: script.pictures(addition.images), enlarge: enlarge)
                    CitationList(script: script, citations: addition.citations)
                    if let id = addition.sets, let state = script.state(id) {
                        Button(state.markLabel) { markState(id) }
                            .buttonStyle(TextButtonStyle())
                    }
                }
            }

            section(tr("You’ll need")) {
                PictureStrip(script: script, pictures: script.pictures(step.images), enlarge: enlarge)
                Text(step.components.joined(separator: ", "))
                    .font(.ordir(.subheadline))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            section(tr("Source")) {
                CitationList(script: script, citations: step.citations)
            }

            if let loop = phase.loop {
                section(tr("When to stop")) {
                    Text(loop.note)
                        .font(.ordir(.subheadline))
                        .fixedSize(horizontal: false, vertical: true)
                    CitationList(script: script, citations: loop.citations)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// "Both players" and/or the expansion a step belongs to.
    private var context: String? {
        let parts = [step.side == .both && showsBothPlayers ? tr("Both players") : nil, step.expansion.map(script.expansionTitle)]
            .compactMap { $0 }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.ordir(.footnote).weight(.semibold))
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
                .font(.ordir(.body))
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
                    .font(.ordir(.title3).weight(.semibold))
                    .fixedSize(horizontal: false, vertical: true)
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
                Text(tr("Done"))
                    .font(.ordir(.headline))
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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var glowing = false
    /// How far the sheet has been pulled down by its top; far enough, and it closes ("Not yet").
    @State private var pull: CGFloat = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Capsule()
                .fill(Color(white: 0.3))
                .frame(width: 36, height: 5)
                .frame(maxWidth: .infinity)
                .accessibilityHidden(true)
            HStack(spacing: 12) {
                OrdirMascotView(isSpeaking: true)
                    .frame(width: 40, height: 40)
                    .accessibilityHidden(true)
                Text(tr("Before you pass the turn"))
                    .font(.ordir(.title3).weight(.semibold))
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)
                    .accessibilityFocused($headingFocused)
            }
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    ReminderChecklist(reminders: reminders) { count in
                        guard count == reminders.count, !reduceMotion else { return }
                        withAnimation(.easeOut(duration: 0.3)) { glowing = true }
                        withAnimation(.easeIn(duration: 0.6).delay(0.35)) { glowing = false }
                    }
                    CitationList(script: script, citations: reminders.flatMap(\.citations))
                }
            }
            .scrollIndicators(.hidden)
            ActionRow {
                Button(tr("Not yet"), action: cancel)
                    .buttonStyle(TextButtonStyle())
            } primary: {
                Button(action: pass) {
                    Text(tr("Pass the turn"))
                        .font(.ordir(.headline))
                        .frame(maxWidth: .infinity, minHeight: 50)
                }
                .buttonStyle(PrimaryButtonStyle())
                .shadow(color: Color.ordirSparkle.opacity(glowing ? 0.7 : 0), radius: glowing ? 16 : 0)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(.background)
        .offset(y: pull)
        // Swipe down from the top (the handle and heading) to close it, like "Not yet". The list keeps
        // its own scrolling; the buttons stay for anyone who doesn't swipe.
        .simultaneousGesture(
            DragGesture(minimumDistance: 12)
                .onChanged { drag in
                    if drag.startLocation.y < 90 { pull = max(0, drag.translation.height) }
                }
                .onEnded { drag in
                    if drag.startLocation.y < 90 && drag.translation.height > 100 { cancel() }
                    withAnimation(reduceMotion ? nil : .spring(duration: 0.3)) { pull = 0 }
                }
        )
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
    /// Called with how many items are ticked, after each tap.
    var onChange: (Int) -> Void = { _ in }
    @State private var checked: Set<Int> = []

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            ForEach(Array(reminders.enumerated()), id: \.offset) { index, reminder in
                let isChecked = checked.contains(index)
                Button {
                    if isChecked { checked.remove(index) } else { checked.insert(index) }
                    onChange(checked.count)
                } label: {
                    HStack(alignment: .firstTextBaseline, spacing: 12) {
                        Image(systemName: isChecked ? "checkmark.circle.fill" : "circle")
                            .contentTransition(.symbolEffect(.replace))
                            .foregroundStyle(isChecked ? Color.primary : Color.secondary)
                        Text(reminder.text)
                            .foregroundStyle(isChecked ? Color.secondary : Color.primary)
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 0)
                    }
                    .font(.ordir(.body))
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(isChecked ? [.isToggle, .isSelected] : [.isToggle])
            }
        }
        .sensoryFeedback(.selection, trigger: checked)
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
                                .font(.ordir(.caption))
                                .foregroundStyle(.primary)
                                .fixedSize(horizontal: false, vertical: true)
                            Text(script.label(for: picture))
                                .font(.ordir(.caption2))
                                .foregroundStyle(.secondary)
                        }
                        .frame(width: 176, alignment: .leading)
                    }
                    .buttonStyle(.plain)
                    .accessibilityElement(children: .combine)
                    .accessibilityHint(tr("Shows the picture larger"))
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
                label: tr("{0}, page {1}", source.shortTitle, citation.page),
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
                            .font(.ordir(.caption))
                            .foregroundStyle(.tertiary)
                            .accessibilityHidden(true)
                    }
                    .font(.ordir(.subheadline))
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
                }
                .accessibilityHint(tr("Opens the PDF at this page"))
            }
        }
    }
}

// MARK: - Waiting

/// What the waiting player sees: who is acting, on which step, and for how long.
private struct WaitingView: View {
    let sideName: String
    let stepTitle: String
    let startedAt: Date

    /// Centred in the half, and scrollable when large text makes it taller than the half.
    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(spacing: 14) {
                    OrdirMascotView(isThinking: true)
                        .frame(height: 64)
                        .accessibilityHidden(true)
                    line
                        .font(.ordir(.title3))
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(startedAt, style: .timer)
                        .font(.ordir(.title2).monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 16)
                .frame(maxWidth: .infinity, minHeight: geometry.size.height)
                .accessibilityElement(children: .combine)
            }
            .scrollBounceBehavior(.basedOnSize)
            .scrollIndicators(.hidden)
        }
    }

    private var line: Text {
        let step = Text(stepTitle).fontWeight(.semibold)
        return Text(tr: "The {0} is on {1}", Text(sideName), step)
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
                .font(.ordir(.headline))
            Text(script.label(for: item.image))
                .font(.ordir(.subheadline))
                .foregroundStyle(.secondary)
            Button {
                dismiss()
            } label: {
                Text(tr("Close"))
                    .font(.ordir(.headline))
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

/// A secondary text button whose whole 44-point row is tappable, wrapping instead of truncating.
struct TextButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.ordir(.subheadline).weight(.semibold))
            .foregroundStyle(Color.accentColor)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .frame(minWidth: 44, minHeight: 44)
            .contentShape(Rectangle())
            .opacity(configuration.isPressed ? 0.6 : 1)
    }
}

/// A secondary button beside the primary one; stacked above it at accessibility text sizes.
private struct ActionRow<Secondary: View, Primary: View>: View {
    @ViewBuilder let secondary: Secondary
    @ViewBuilder let primary: Primary
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        let layout = typeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(spacing: 8))
            : AnyLayout(HStackLayout(spacing: 12))
        layout {
            secondary
            primary
        }
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .foregroundStyle(.background)
            .background(
                Color.primary.opacity(configuration.isPressed ? 0.7 : 1),
                in: RoundedRectangle(cornerRadius: 16, style: .continuous)
            )
    }
}

extension TurnScript {
    /// A side's colour from the script ("#rrggbb"); grey for both players.
    func color(of side: Side) -> Color {
        guard let hex = sides.first(where: { $0.id == side })?.color.dropFirst(), let value = UInt32(hex, radix: 16) else {
            return .secondary
        }
        return Color(red: Double(value >> 16 & 0xFF) / 255, green: Double(value >> 8 & 0xFF) / 255, blue: Double(value & 0xFF) / 255)
    }
}

#Preview {
    NavigationStack {
        if let script = TurnScript.bundled(for: .duneWarForArrakis) {
            TurnGuideView(script: script)
        }
    }
}
