//
//  TurnGuideSession.swift
//  Ordir
//
//  Walks a TurnScript one step at a time on a single phone (pass-and-play).
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
    }

    let script: TurnScript
    private(set) var position = Position()
    private(set) var isFinished = false
    /// When the current step began; drives the running timer.
    private(set) var stepStartedAt = Date.now
    private var history: [Position] = []

    /// `startAt` jumps to a step by id (CI screenshots use it); unknown ids start at the beginning.
    init(script: TurnScript, startAt stepID: String? = nil) {
        self.script = script
        for (phaseIndex, phase) in script.phases.enumerated() {
            if let stepIndex = phase.steps.firstIndex(where: { $0.id == stepID }) {
                position = Position(phase: phaseIndex, step: stepIndex)
            }
        }
    }

    var phase: TurnScript.Phase { script.phases[position.phase] }
    var step: TurnScript.Step { phase.steps[position.step] }
    var canGoBack: Bool { !history.isEmpty || isFinished }

    /// Turn number inside a looping phase, e.g. the 5th alternating Action turn.
    var turnNumber: Int { (position.pass - 1) * phase.steps.count + position.step + 1 }

    /// "Done": next step, wrapping inside a looping phase.
    func advance() {
        var next = position
        if next.step + 1 < phase.steps.count {
            next.step += 1
        } else if phase.loop != nil {
            next.step = 0
            next.pass += 1
        } else {
            moveToNextPhase(from: next)
            return
        }
        move(to: next)
    }

    /// Leaves a looping phase, e.g. once every Action die is used.
    func endLoop() {
        moveToNextPhase(from: position)
    }

    func goBack() {
        if isFinished {
            isFinished = false
        } else if let previous = history.popLast() {
            position = previous
        }
        stepStartedAt = .now
    }

    func restart() {
        history = []
        position = Position()
        isFinished = false
        stepStartedAt = .now
    }

    private func moveToNextPhase(from current: Position) {
        guard current.phase + 1 < script.phases.count else {
            isFinished = true
            return
        }
        move(to: Position(phase: current.phase + 1))
    }

    private func move(to next: Position) {
        history.append(position)
        position = next
        stepStartedAt = .now
    }
}
