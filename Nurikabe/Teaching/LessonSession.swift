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
    /// target cell → the mark it must end up with.
    let answers: [Int: Mark]
    private(set) var marks: [Mark]
    private(set) var feedback: Feedback = .none
    /// Set when the player asked to be shown the answer.
    private(set) var revealed = false

    init(position: LessonPosition) {
        self.position = position
        marks = position.marks
        var answers: [Int: Mark] = [:]
        if let step = position.step {
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
        let next = NurikabeGame.cycled(marks[index])
        marks[index] = next
        evaluate(changed: index, answer: answer)
    }

    /// Paint a target directly (drag strokes).
    func paint(_ index: Int, _ mark: Mark) {
        guard !isDone, let answer = answers[index], marks[index] != mark else { return }
        marks[index] = mark
        evaluate(changed: index, answer: answer)
    }

    private func evaluate(changed index: Int, answer: Mark) {
        let mark = marks[index]
        if mark != .unknown && mark != answer {
            feedback = .wrong(TechniqueContent.wrongTarget(position.technique, markedSea: mark == .sea))
            return
        }
        if answers.allSatisfy({ marks[$0.key] == $0.value }) {
            feedback = .done
        } else if case .wrong = feedback, mark == answer {
            feedback = .none
        } else if feedback == .offTarget {
            feedback = .none
        }
    }

    /// Fill in the answer (the "Show me" button). Still counts as done, so
    /// the lesson can move on; the path records the lesson either way.
    func reveal() {
        for (i, m) in answers { marks[i] = m }
        revealed = true
        feedback = .done
    }
}
