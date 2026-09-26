//
//  BakedPuzzles.swift
//  Nurikabe
//
//  Budget-exhaustion fallbacks. Re-proven (unique + curriculum-solvable) on
//  every EngineCheck run; regenerate with NURIKABE_BAKE=1.
//

import Foundation

nonisolated enum BakedPuzzles {

    static func puzzle(size: BoardSize) -> Puzzle {
        let rows: [String]
        switch size {
        case .five: rows = five
        case .seven: rows = seven
        case .ten: rows = ten
        }
        return decode(rows)
    }

    static func result(size: BoardSize) -> GenerationResult {
        let puzzle = puzzle(size: size)
        var budget = 1_000_000
        let solved = LogicalSolver.solve(puzzle: puzzle, budget: &budget)
        return GenerationResult(puzzle: puzzle,
                                grade: DifficultyRater.grade(trace: solved.trace, size: size.rawValue),
                                trace: solved.trace, isFallback: true)
    }

    /// Row strings: `#` sea, `.` land, a digit (or `a`=10…) a clue on land.
    static func decode(_ rows: [String]) -> Puzzle {
        let n = rows.count
        var clues: [Clue] = []
        var solution: [Bool] = []
        for (r, row) in rows.enumerated() {
            for (c, ch) in row.enumerated() {
                solution.append(ch != "#")
                if let v = ch.hexDigitValue, ch != "." && ch != "#" {
                    clues.append(Clue(cell: Cell(row: r, col: c), value: v))
                }
            }
        }
        return Puzzle(size: n, clues: clues, solution: solution)
    }

    static func encode(_ puzzle: Puzzle) -> [String] {
        let clueAt = puzzle.clueIndexAt
        return (0..<puzzle.size).map { r in
            String((0..<puzzle.size).map { c -> Character in
                let i = r * puzzle.size + c
                if clueAt[i] >= 0 {
                    return Character(String(puzzle.clues[clueAt[i]].value, radix: 16))
                }
                return puzzle.solution[i] ? "." : "#"
            })
        }
    }

    // Baked 2026-09-27 with NURIKABE_BAKE=1 (steady request, seeds 0xBA4E0000 + size).
    static let five: [String] = [
        "1##.3",
        "#1##.",
        "###1#",
        "#1###",
        "1##.2",
    ]
    static let seven: [String] = [
        ".#2.#2.",
        "2######",
        "##2.#1#",
        "#3##1##",
        "#..##.#",
        "####.3#",
        ".2#1###",
    ]
    static let ten: [String] = [
        "####2#...6",
        "#..#.###..",
        "#3#1##1###",
        "#####.#.2#",
        "#..5#.####",
        "1#..#..#.#",
        "#####5##2#",
        "#.2#1##1##",
        "###1#.2##.",
        "2.#####1#2",
    ]
}
