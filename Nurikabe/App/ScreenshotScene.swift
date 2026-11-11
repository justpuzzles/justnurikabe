import Foundation

/// App Store screenshot scenes, reached with `-NurikabeScreenshotScene <name>`
/// so the capture script needs no tap chains. **DEBUG only**: in a release
/// build `current` is always nil (ReleaseBuildTests checks the argument is
/// read inside `#if DEBUG`).
enum ScreenshotScene: String, CaseIterable {
    /// A game with the hint ladder on its argument rung.
    case hint
    /// A technique lesson's worked example.
    case lesson
    /// The learning path, part done, with seals.
    case path
    /// Home.
    case home
    /// The finish card with the technique recap.
    case win

    static var current: ScreenshotScene? {
        #if DEBUG
        let args = ProcessInfo.processInfo.arguments
        guard let i = args.firstIndex(of: "-NurikabeScreenshotScene"), i + 1 < args.count else { return nil }
        return ScreenshotScene(rawValue: args[i + 1])
        #else
        return nil
        #endif
    }

    /// The navigation path the scene opens on.
    var initialPath: [Route] {
        switch self {
        case .hint, .win: [.play(.resume)]
        case .lesson: [.learn, .lesson(.islandEscape)]
        case .path: [.learn]
        case .home: []
        }
    }

    /// Prepare saved state for the scene: a player partway along the path,
    /// a few seals, and (for the game scenes) a board in progress.
    @MainActor
    func seed(_ progress: ProgressStore) {
        for rule in RuleStep.allCases { progress.completeRule(rule) }
        for t in [Technique.oneClue, .twoClues, .completeIsland, .noPool, .unreachable] {
            progress.completeLesson(t)
        }
        let counts: [Technique: Int] = [.oneClue: 5, .twoClues: 5, .completeIsland: 5, .noPool: 3, .unreachable: 2]
        for (t, n) in counts { for _ in 0..<n { progress.credit(t) } }
        // Oldest first: an older day solved after a newer one is a late
        // solve, which keeps its time but not the streak (PuzzleKit).
        let yesterday = DayKey(date: .now).previous()
        for back in (0..<4).reversed() {
            progress.recordSolve(kind: .daily(yesterday.adding(days: -back)), grade: .steady,
                                 size: .seven, seconds: 260, hintsUsed: 0)
        }
        guard self == .hint || self == .win || self == .home else { return }
        // The baked 7×7: instant even in an unoptimized Debug build, where
        // generating a fresh board during launch outlasted the capture wait.
        let result = BakedPuzzles.result(size: .seven)
        let puzzle = result.puzzle
        var marks = puzzle.initialMarks
        let grid = puzzle.grid
        switch self {
        case .win:
            // Everything but one cell; GameView fills it on appear.
            for i in marks.indices where marks[i] == .unknown {
                marks[i] = puzzle.solution[i] ? .land : .sea
            }
            if let last = marks.indices.last(where: { puzzle.clueIndexAt[$0] < 0 }) {
                marks[last] = .unknown
            }
        default:
            // Solve until the next step is a mid-ladder argument worth showing.
            for step in result.trace {
                if step.technique >= .islandEscape, marks.filter({ $0 != .unknown }).count > grid.count / 3 { break }
                LogicalSolver.apply(step, to: &marks, grid: grid)
            }
        }
        progress.saveGame(SavedGame(kind: .random(size: .seven, tier: result.grade), puzzle: puzzle,
                                    grade: result.grade, marks: marks, elapsed: 214, hintsUsed: 0))
    }
}
