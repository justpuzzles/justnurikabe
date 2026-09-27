import Foundation
import Observation

/// One board being played. A service the views observe, not a ViewModel:
/// it owns the marks, undo history, timer and hint ladder, and knows nothing
/// about layout.
@Observable @MainActor
final class NurikabeGame {

    let puzzle: Puzzle
    let kind: GameKind
    let grade: Difficulty
    let context: SolverContext

    private(set) var marks: [Mark]
    private(set) var hintsUsed: Int
    private(set) var isSolved = false
    /// Rule breaks no further marking can repair (pools, two numbers in one
    /// island, a cut-off sea, an island too big or boxed in).
    private(set) var ruleBreaks: [Rules.Violation] = []
    /// Clue indices whose island is complete and exactly its size, computed
    /// once per change (the board re-renders far more often than it changes).
    private(set) var satisfiedClues: Set<Int> = []
    private(set) var hint: HintState?

    private var undoStack: [[Mark]] = []
    private var redoStack: [[Mark]] = []
    private var strokeMark: Mark?
    private var strokeStart: [Mark]?

    // MARK: Mastery state

    /// Cells that can no longer earn mastery: credited once, or filled by a
    /// hint. Survives undo, so place → undo → place cannot farm credit.
    private(set) var creditedCells: Set<Int>
    /// Techniques credited during this game, for the finish card.
    private(set) var creditsThisGame: [Technique: Int] = [:]
    /// Called on the main actor for each credited deduction; the view wires
    /// it to ProgressStore.
    var onCredit: ((Technique) -> Void)?

    /// Elapsed time is accumulated while the board is on screen.
    private var accumulated: TimeInterval
    private var resumedAt: Date?

    init(puzzle: Puzzle, kind: GameKind, grade: Difficulty,
         marks: [Mark]? = nil, elapsed: TimeInterval = 0, hintsUsed: Int = 0,
         creditedCells: Set<Int> = []) {
        self.creditedCells = creditedCells
        self.puzzle = puzzle
        self.kind = kind
        self.grade = grade
        context = SolverContext(puzzle: puzzle)
        self.marks = marks ?? puzzle.initialMarks
        accumulated = elapsed
        self.hintsUsed = hintsUsed
        refresh()
    }

    convenience init(saved: SavedGame) {
        self.init(puzzle: saved.puzzle, kind: saved.kind, grade: saved.grade,
                  marks: saved.marks, elapsed: saved.elapsed, hintsUsed: saved.hintsUsed,
                  creditedCells: Set(saved.creditedCells ?? []))
    }

    var size: BoardSize { BoardSize(rawValue: puzzle.size) ?? .seven }
    var grid: Grid { context.grid }

    var snapshot: SavedGame {
        SavedGame(kind: kind, puzzle: puzzle, grade: grade, marks: marks,
                  elapsed: elapsed(at: Date()), hintsUsed: hintsUsed,
                  creditedCells: creditedCells.sorted())
    }

    // MARK: Timer

    func resumeClock(at now: Date = Date()) {
        guard !isSolved, resumedAt == nil else { return }
        resumedAt = now
    }

    func pauseClock(at now: Date = Date()) {
        if let resumedAt { accumulated += now.timeIntervalSince(resumedAt) }
        resumedAt = nil
    }

    func elapsed(at now: Date) -> TimeInterval {
        accumulated + (resumedAt.map { now.timeIntervalSince($0) } ?? 0)
    }

    // MARK: Input

    func isClue(_ index: Int) -> Bool { context.clueAt[index] >= 0 }

    /// What a tap does to a mark: blank → sea → dot → blank.
    static func cycled(_ mark: Mark) -> Mark {
        switch mark {
        case .unknown: .sea
        case .sea: .land
        case .land: .unknown
        }
    }

    /// A stroke begins: the first cell cycles, and the stroke then paints
    /// that same mark onto every cell it crosses. One stroke = one undo step.
    func beginStroke(at index: Int) {
        guard !isSolved, index >= 0, index < marks.count, !isClue(index) else { return }
        strokeStart = marks
        let mark = Self.cycled(marks[index])
        strokeMark = mark
        marks[index] = mark
        changed()
    }

    func extendStroke(to index: Int) {
        guard let mark = strokeMark, index >= 0, index < marks.count,
              !isClue(index), marks[index] != mark else { return }
        marks[index] = mark
        changed()
    }

    func endStroke() {
        settleStroke()
        if isSolved { pauseClock() }
    }

    /// Close the open stroke: record undo and judge its marks for mastery.
    /// Also runs when a stroke solves the board, because the gesture that
    /// would have sent the end event is gone by then.
    private func settleStroke() {
        guard let start = strokeStart else { return }
        strokeStart = nil
        strokeMark = nil
        guard start != marks else { return }
        undoStack.append(start)
        redoStack.removeAll()
        judge(from: start)
    }

    /// Credit the cells a move newly marked correctly. They are claimed at
    /// once (anti-farming); the solver chain behind each is found off the
    /// main actor, since a What If look-ahead can take a moment.
    private func judge(from before: [Mark]) {
        let fresh = marks.indices.filter { i in
            marks[i] != before[i] && marks[i] != .unknown
                && (marks[i] == .land) == puzzle.solution[i]
                && !isClue(i) && !creditedCells.contains(i)
        }
        guard !fresh.isEmpty else { return }
        creditedCells.formUnion(fresh)
        // What the player knew: the board before the move, wrong marks cleared.
        var known = before
        for i in known.indices where known[i] != .unknown && (known[i] == .land) != puzzle.solution[i] {
            known[i] = .unknown
        }
        let context = self.context
        let board = known       // a let: the detached closure may not capture a var
        Task { [weak self] in
            let credits = await Task.detached(priority: .utility) {
                MasteryRules.credits(for: fresh, before: board, context: context)
            }.value
            guard let self else { return }
            for t in credits {
                self.creditsThisGame[t, default: 0] += 1
                self.onCredit?(t)
            }
        }
    }

    /// Set one cell outright (lessons, applied hints). Records undo.
    func set(_ index: Int, to mark: Mark) {
        guard !isClue(index), marks[index] != mark else { return }
        let before = marks
        undoStack.append(marks)
        redoStack.removeAll()
        marks[index] = mark
        changed()
        judge(from: before)
        if isSolved { pauseClock() }
    }

    var canUndo: Bool { !undoStack.isEmpty && !isSolved }
    var canRedo: Bool { !redoStack.isEmpty && !isSolved }

    func undo() {
        guard canUndo, let previous = undoStack.popLast() else { return }
        redoStack.append(marks)
        marks = previous
        changed()
    }

    func redo() {
        guard canRedo, let next = redoStack.popLast() else { return }
        undoStack.append(marks)
        marks = next
        changed()
    }

    /// Clear every mark (clues stay). Undoable.
    func restart() {
        guard !isSolved else { return }
        let fresh = puzzle.initialMarks
        guard fresh != marks else { return }
        undoStack.append(marks)
        redoStack.removeAll()
        marks = fresh
        changed()
    }

    // MARK: Checking

    /// Marked cells that disagree with the solution.
    var wrongCells: [Int] {
        marks.indices.filter { i in
            marks[i] != .unknown && (marks[i] == .land) != puzzle.solution[i]
        }
    }

    func isClueSatisfied(_ clueIndex: Int) -> Bool { satisfiedClues.contains(clueIndex) }

    private func changed() {
        hint = nil
        refresh()
    }

    private func refresh() {
        isSolved = Rules.isSolved(marks, puzzle: puzzle)
        ruleBreaks = Rules.violations(marks, puzzle: puzzle, requireComplete: false)
        let groups = Groups(marks: marks, grid: grid, clueIndexAt: context.clueAt)
        satisfiedClues = Set(puzzle.clues.indices.filter { k in
            let g = groups.landGroupOf[grid.index(puzzle.clues[k].cell)]
            guard g >= 0 else { return false }
            let group = groups.land[g]
            return group.clueIndices == [k] && group.cells.count == puzzle.clues[k].value
                && group.liberties.isEmpty
        })
        // Stop the clock here, not in the input paths: the tap that solves
        // the board also removes its gesture, so the stroke's end event may
        // never arrive.
        if isSolved {
            pauseClock()
            settleStroke()
        }
    }

    // MARK: Hints

    /// One press of the hint button: start or climb the ladder.
    func advanceHint(policy: HintPolicy) {
        guard !isSolved else { return }
        let next = HintEngine.next(after: hint, marks: marks, context: context,
                                   wrong: wrongCells, policy: policy)
        if let next, next.countsAsHint(comparedTo: hint) { hintsUsed += 1 }
        if case .apply(let step)? = next {
            undoStack.append(marks)
            redoStack.removeAll()
            LogicalSolver.apply(step, to: &marks, grid: grid)
            // A hint's cells never earn mastery.
            creditedCells.formUnion((step.sea + step.land).map { grid.index($0) })
            hint = nil
            refresh()
            if isSolved { pauseClock() }
            return
        }
        hint = next
    }

    func dismissHint() { hint = nil }

    /// Clear the wrong cells the errors hint pointed at. Undoable.
    func clearWrongCells() {
        let wrong = wrongCells
        guard !wrong.isEmpty else { return }
        undoStack.append(marks)
        redoStack.removeAll()
        for i in wrong { marks[i] = .unknown }
        changed()
    }
}
