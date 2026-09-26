import Foundation
import Observation

/// One lesson board: a position whose target cells the player must decide.
/// Pure interaction rules, no layout — LessonSessionTests drives it.
@Observable @MainActor
final class LessonSession {

    enum Feedback: Equatable {
        case none
        /// A target marked with the wrong colour.
        case wrong(String)
        /// A tap outside the targets.
        case offTarget
        case done
    }

    let position: LessonPosition
    /// The step this position teaches, computed once (for What If it runs a
    /// look-ahead, far too costly to repeat on every render).
    let step: SolverStep?
    /// target cell → the mark it must end up with.
    let answers: [Int: Mark]
    /// A land target currently showing sea from a tap. Taps cycle blank →
    /// sea → dot, so a player heading for the dot passes through sea; that
    /// sea is judged only if it is still there when `settle()` runs.
    private(set) var pending: Int?
    private(set) var marks: [Mark]
    private(set) var feedback: Feedback = .none
    /// Set when the player asked to be shown the answer.
    private(set) var revealed = false

    init(position: LessonPosition) {
        self.position = position
        marks = position.marks
        step = position.step
        var answers: [Int: Mark] = [:]
        if let step {
            let grid = position.puzzle.grid
            for c in step.sea { answers[grid.index(c)] = .sea }
            for c in step.land { answers[grid.index(c)] = .land }
        }
        // Targets are exactly the step's cells. For rule positions that is
        // every blank (EngineCheck proves it); technique positions are
        // mid-solve boards, where most blanks are not part of the lesson.
        self.answers = answers
    }

    var targets: Set<Int> { Set(answers.keys) }
    var isDone: Bool { feedback == .done }

    /// A tap: targets cycle blank → sea → dot → blank; anything else is
    /// refused with a pointer back to the targets.
    func tap(_ index: Int) {
        guard !isDone else { return }
        guard let answer = answers[index] else {
            feedback = .offTarget
            return
        }
        marks[index] = NurikabeGame.cycled(marks[index])
        pending = (answer == .land && marks[index] == .sea) ? index : nil
        evaluate()
    }

    /// Paint a target directly (drag strokes). Deliberate, so judged at once.
    func paint(_ index: Int, _ mark: Mark) {
        guard !isDone, answers[index] != nil, marks[index] != mark else { return }
        marks[index] = mark
        pending = nil
        evaluate()
    }

    /// Judge a sea left on a land target (called after a short pause).
    func settle() {
        guard pending != nil else { return }
        pending = nil
        evaluate()
    }

    /// Feedback always describes the whole board: the first wrong target,
    /// else done, else nothing — never a stale verdict about one cell.
    private func evaluate() {
        let wrong = answers.keys.sorted().first { i in
            i != pending && marks[i] != .unknown && marks[i] != answers[i]
        }
        if let wrong {
            feedback = .wrong(TechniqueContent.wrongTarget(position.technique, markedSea: marks[wrong] == .sea))
        } else if answers.allSatisfy({ marks[$0.key] == $0.value }) {
            feedback = .done
        } else {
            feedback = .none
        }
    }

    /// Fill in the answer (the "Show me" button). Still counts as done, so
    /// the lesson can move on; the path records the lesson either way.
    func reveal() {
        for (i, m) in answers { marks[i] = m }
        pending = nil
        revealed = true
        feedback = .done
    }
}
