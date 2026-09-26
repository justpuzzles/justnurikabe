//
//  LessonPositions.swift
//  Nurikabe
//
//  Real board positions for the learning path, mined from generated boards
//  and baked into LessonBoards.swift (regenerate with NURIKABE_LESSONS=1).
//  A position is a puzzle plus the player's marks at the moment a chosen
//  technique is the LOWEST one that applies — so the lesson's move is exactly
//  the argument being taught, and no easier argument competes with it.
//

import Foundation

nonisolated struct LessonPosition: Sendable, Equatable {
    let puzzle: Puzzle
    let marks: [Mark]
    /// The argument this position teaches.
    let technique: Technique

    /// The step the lesson asks for: this technique's deduction from here.
    /// (For technique lessons it is also the lowest one that applies —
    /// LessonTests pins that; rule positions only need the rule to apply.)
    var step: SolverStep? {
        let context = SolverContext(puzzle: puzzle)
        let groups = Groups(marks: marks, grid: context.grid, clueIndexAt: context.clueAt)
        return LogicalSolver.detect(technique, context: context, marks: marks, groups: groups)
    }

    /// Is `technique` the lowest applicable technique here?
    var isLowest: Bool {
        LogicalSolver.nextStep(puzzle: puzzle, marks: marks)?.technique == technique
    }

    /// Every blank cell, as flat indices — what the player must fill.
    var blanks: [Int] { marks.indices.filter { marks[$0] == .unknown } }

    /// Cells the player must decide, as flat indices.
    var targets: [Int] {
        guard let step else { return [] }
        let g = puzzle.grid
        return (step.sea + step.land).map { g.index($0) }.sorted()
    }

    // MARK: Encoding

    /// Two row arrays: the puzzle (`BakedPuzzles` format) and the marks
    /// (`#` sea, `o` land dot, `_` blank; clue cells written as `o`).
    static func decode(_ technique: Technique, puzzle rows: [String],
                       marks markRows: [String]) -> LessonPosition {
        let puzzle = BakedPuzzles.decode(rows)
        var marks: [Mark] = []
        for row in markRows {
            for ch in row {
                switch ch {
                case "#": marks.append(.sea)
                case "o": marks.append(.land)
                default: marks.append(.unknown)
                }
            }
        }
        return LessonPosition(puzzle: puzzle, marks: marks, technique: technique)
    }

    var encodedMarks: [String] {
        (0..<puzzle.size).map { r in
            String((0..<puzzle.size).map { c -> Character in
                switch marks[r * puzzle.size + c] {
                case .sea: "#"
                case .land: "o"
                case .unknown: "_"
                }
            })
        }
    }
}

/// The rules chapter, in teaching order. Prose lives in the app's
/// TechniqueContent; the engine only knows which technique each rule's
/// position exercises.
nonisolated enum RuleStep: String, CaseIterable, Codable, Sendable, Identifiable {
    /// Tap to shade; a number is an island of that size.
    case islands
    /// Two numbers never share an island.
    case oneNumber
    /// No 2×2 block of sea.
    case noPools
    /// All the sea is one connected piece.
    case oneSea
    /// A whole small board.
    case firstPuzzle

    var id: String { rawValue }

    /// The technique whose argument the rule's position calls for.
    var technique: Technique? {
        switch self {
        case .islands: .completeIsland
        case .oneNumber: .twoClues
        case .noPools: .noPool
        case .oneSea: .seaEscape
        case .firstPuzzle: nil
        }
    }
}

extension Technique {
    /// The easiest tier whose boards use this technique, for lesson mining
    /// and practice boards.
    nonisolated var lessonTier: Difficulty {
        for tier in Difficulty.allCases where self <= tier.techniqueCeiling { return tier }
        return .severe
    }
}

nonisolated enum LessonMiner {

    /// How the position is cut from a board.
    nonisolated enum Style: Sendable {
        /// Everything solved except the cells the step decides — for the
        /// rules chapter, where the player should need only the one rule.
        case almostSolved
        /// The solver's own state just before the step — for technique
        /// lessons, a real mid-solve moment.
        case midSolve
    }

    /// The first qualifying position in boards generated from `seed`
    /// onwards, or nil within `boards` attempts.
    static func mine(_ technique: Technique, style: Style, size: BoardSize, tier: Difficulty,
                     seed: UInt64, boards: Int = 40,
                     maxTargets: Int = 4) -> LessonPosition? {
        var rng = SeededRandomNumberGenerator(seed: seed)
        for _ in 0..<boards {
            let result = NurikabeGenerator.generate(size: size, tier: tier, seed: rng.next())
            guard !result.isFallback else { continue }
            let puzzle = result.puzzle
            let grid = puzzle.grid
            var marks = puzzle.initialMarks
            for step in result.trace {
                if step.technique == technique, step.decidedCount <= maxTargets {
                    let candidate: [Mark]
                    switch style {
                    case .midSolve:
                        candidate = marks
                    case .almostSolved:
                        var solved = puzzle.solution.map { $0 ? Mark.land : Mark.sea }
                        for cell in step.sea + step.land { solved[grid.index(cell)] = .unknown }
                        candidate = solved
                    }
                    let position = LessonPosition(puzzle: puzzle, marks: candidate, technique: technique)
                    let ok: Bool
                    switch style {
                    case .midSolve:
                        ok = position.isLowest && position.targets.count <= maxTargets
                    case .almostSolved:
                        // The rule must decide exactly the blanks.
                        ok = position.step != nil && position.targets == position.blanks
                    }
                    if ok { return position }
                }
                LogicalSolver.apply(step, to: &marks, grid: grid)
            }
        }
        return nil
    }
}
