//
//  TurnGuideSession.swift
//  Ordir
//
//  Walks a TurnScript one step at a time on a single phone: setup once, then rounds that repeat
//  until the players end the game. Steps can depend on game states (e.g. the Smugglers allying).
//

import Foundation
import Observation

@Observable
final class TurnGuideSession {
    struct Position: Equatable {
        var phase = 0
        var step = 0
        /// How many times a looping phase has come round; 1 outside loops.
        var pass = 1
        /// Game round; setup counts as round 1.
        var round = 1
    }

    let script: TurnScript
    /// Expansion ids the players switched on.
    let expansions: Set<String>
    /// The script's phases with steps for switched-off expansions left out.
    let phases: [TurnScript.Phase]
    /// Whether moving between the two sides asks for the phone to be passed (pass-the-phone play).
    let passesPhone: Bool
    private(set) var position = Position()
    private(set) var isFinished = false
    /// Who won, once the players end the game.
    private(set) var winner: TurnScript.Side?
    /// When the current step began; drives the running timer.
    private(set) var stepStartedAt = Date.now
    /// Pass-the-phone play: set when the next step belongs to the other player, until they take the phone.
    private(set) var handoffTo: TurnScript.Side?
    /// Game states that have happened, e.g. "smugglersAllied".
    private(set) var activeStates: Set<String> = []
    /// A state that just happened: its one-off steps are shown until the players are done with them.
    private(set) var pendingEvent: TurnScript.GameState?
    private var history: [Position] = []

    /// `startAt` jumps to a step by id (CI screenshots use it); unknown ids start at the beginning.
    init(script: TurnScript, expansions: Set<String>, passesPhone: Bool = false, startAt stepID: String? = nil) {
        self.script = script
        self.expansions = expansions
        self.passesPhone = passesPhone
        self.phases = script.phases.compactMap { phase in
            let steps = phase.steps.filter { step in
                guard let expansion = step.expansion else { return true }
                return expansions.contains(expansion)
            }
            return steps.isEmpty ? nil : TurnScript.Phase(id: phase.id, part: phase.part, title: phase.title, steps: steps, loop: phase.loop)
        }
        for (phaseIndex, phase) in phases.enumerated() {
            if let stepIndex = phase.steps.firstIndex(where: { $0.id == stepID }) {
                position = Position(phase: phaseIndex, step: stepIndex)
            }
        }
    }

    var phase: TurnScript.Phase { phases[position.phase] }
    var step: TurnScript.Step { phase.steps[position.step] }
    var round: Int { position.round }
    var isInSetup: Bool { phase.part == .setup }

    /// Expansion additions that apply to the current step right now.
    var additions: [TurnScript.Addition] {
        (step.additions ?? []).filter { addition in
            (addition.expansion.map { expansions.contains($0) } ?? true) && applies(addition.when)
        }
    }
    /// Turn-change reminders for the current step, without those of switched-off expansions.
    var reminders: [TurnScript.Reminder] {
        (step.reminders ?? []).filter { reminder in
            guard let expansion = reminder.expansion else { return true }
            return expansions.contains(expansion)
        }
    }
    /// States the players can mark or correct: the base game’s and those of switched-on expansions.
    var availableStates: [TurnScript.GameState] {
        (script.states ?? []).filter { state in state.expansion.map { expansions.contains($0) } ?? true }
    }
    var canGoBack: Bool { !history.isEmpty || isFinished }

    /// Turn number inside a looping phase, e.g. the 5th alternating Action turn. Without fixed sides, each
    /// time round the loop is the next player's turn.
    var turnNumber: Int {
        script.takesTurns ? position.pass : (position.pass - 1) * phase.steps.count + position.step + 1
    }

    /// The current phase's steps that apply now, for "3 of 5".
    var applicableSteps: [TurnScript.Step] { phase.steps.filter { applies($0.when) } }
    var stepNumber: Int { (applicableSteps.firstIndex { $0.id == step.id } ?? 0) + 1 }

    func applies(_ condition: TurnScript.Condition?) -> Bool {
        guard let condition else { return true }
        return activeStates.contains(condition.state) == condition.`is`
    }

    // MARK: Moving through the game

    /// "Done": next step that applies, wrapping inside a looping phase, and from the end of a
    /// round to the start of the next.
    func advance() {
        var next = position
        if let index = firstApplicable(in: phase, after: position.step) {
            next.step = index
        } else if phase.loop != nil, let index = firstApplicable(in: phase, after: -1) {
            next.step = index
            next.pass += 1
        } else {
            moveToNextPhase(from: next)
            return
        }
        move(to: next)
    }

    /// Setup steps that apply, for the guide's intro ("Setup takes 15 steps").
    var setupStepCount: Int {
        phases.filter { $0.part == .setup }.reduce(0) { count, phase in
            count + phase.steps.filter { applies($0.when) }.count
        }
    }

    /// "Skip setup": straight to round 1's first step. Back still returns to setup.
    func skipSetup() {
        guard isInSetup, let index = phases.firstIndex(where: { $0.part == .round }),
              let step = firstApplicable(in: phases[index], after: -1) else { return }
        move(to: Position(phase: index, step: step, pass: 1, round: 1))
    }

    /// Leaves a looping phase, e.g. once every Action die is used.
    func endLoop() {
        moveToNextPhase(from: position)
    }

    /// The phase that comes after this one (round phases follow on into the next round), for "Next: Desert hazards".
    var nextPhaseTitle: String? {
        let firstRound = phases.firstIndex { $0.part == .round }
        var index = position.phase
        for _ in 0..<phases.count {
            index += 1
            if index >= phases.count {
                guard let firstRound else { return nil }
                index = firstRound
            }
            if firstApplicable(in: phases[index], after: -1) != nil { return phases[index].title }
        }
        return nil
    }

    /// The player the phone was passed to has it now.
    func confirmHandoff() {
        handoffTo = nil
        stepStartedAt = .now
    }

    func goBack() {
        handoffTo = nil
        if isFinished {
            isFinished = false
            winner = nil
        } else if let previous = history.popLast() {
            position = previous
        }
        stepStartedAt = .now
    }

    func restart() {
        handoffTo = nil
        history = []
        activeStates = []
        pendingEvent = nil
        position = Position()
        isFinished = false
        winner = nil
        stepStartedAt = .now
    }

    /// Someone won; the guide shows the result.
    func endGame(winner: TurnScript.Side?) {
        handoffTo = nil
        pendingEvent = nil
        self.winner = winner
        isFinished = true
    }

    // MARK: Game states

    /// Marks a state as happened (showing its one-off steps) or corrects it back.
    func setState(_ id: String, _ isOn: Bool) {
        guard let state = script.state(id) else { return }
        if isOn {
            guard !activeStates.contains(id) else { return }
            activeStates.insert(id)
            pendingEvent = state
        } else {
            activeStates.remove(id)
            if pendingEvent?.id == id { pendingEvent = nil }
        }
    }

    func dismissEvent() {
        pendingEvent = nil
    }

    // MARK: Battles

    /// A battle walkthrough for the current turn: the acting side attacks. It shares this game's
    /// expansions, states and way of passing the phone, and finishes when the battle is over.
    func makeBattle() -> TurnGuideSession? {
        guard let battle = script.battle, script.isPlayer(step.side) else { return nil }
        let attacker = step.side
        let defender = script.opponent(of: attacker)
        func resolve(_ side: TurnScript.Side) -> TurnScript.Side {
            switch side {
            case .attacker: attacker
            case .defender: defender
            default: side
            }
        }
        let phases = battle.phases.map { phase in
            TurnScript.Phase(
                id: phase.id,
                part: .setup,
                title: phase.title,
                steps: phase.steps.map { $0.with(side: resolve($0.side)) },
                loop: phase.loop
            )
        }
        let battleScript = TurnScript(
            game: script.game, title: battle.title, version: script.version,
            sides: script.sides, victory: script.victory, sources: script.sources,
            expansions: script.expansions, states: script.states, images: script.images,
            phases: phases, battle: nil
        )
        let session = TurnGuideSession(script: battleScript, expansions: expansions, passesPhone: passesPhone)
        session.activeStates = activeStates
        return session
    }

    // MARK: Private

    private func firstApplicable(in phase: TurnScript.Phase, after index: Int) -> Int? {
        phase.steps.indices.first { $0 > index && applies(phase.steps[$0].when) }
    }

    /// Next phase with a step that applies; after the last phase of a round, the round's first phase.
    private func moveToNextPhase(from current: Position) {
        var index = current.phase
        var round = current.round
        for _ in 0...phases.count {
            index += 1
            if index >= phases.count {
                guard let first = phases.firstIndex(where: { $0.part == .round }) else {
                    isFinished = true
                    return
                }
                index = first
                round += 1
            }
            if let step = firstApplicable(in: phases[index], after: -1) {
                move(to: Position(phase: index, step: step, pass: 1, round: round))
                return
            }
        }
        isFinished = true
    }

    private func move(to next: Position) {
        let previousSide = step.side
        // Without fixed sides, going round the loop again (or into a new round) is another player's turn.
        let nextPlayer = script.takesTurns && (next.pass > position.pass || next.round > position.round)
        history.append(position)
        position = next
        stepStartedAt = .now
        // Steps for both players need no handoff; a switch to the other single side does.
        handoffTo = passesPhone && step.side != .both && (step.side != previousSide || nextPlayer) ? step.side : nil
    }
}

/// Lets a battle walkthrough be presented with `.fullScreenCover(item:)`.
extension TurnGuideSession: Identifiable {}
