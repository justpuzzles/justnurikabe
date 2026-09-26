//
//  BacktrackingSolver.swift
//  Nurikabe
//
//  Uniqueness proof ONLY — `countSolutions(limit: 2)`. Never a hint source.
//  Kept apart from LogicalSolver: its propagation and contradiction checks
//  are its own, rules-level code. It shares exactly one function, the
//  reachability bound (`LogicalSolver.reachable`), without which 10×10
//  proofs cost ~8k nodes each. That function is covered twice: EngineCheck
//  cross-checks every 5×5 proof against a naive enumerator, and replays
//  every unreachable deduction against the known solution.
//

import Foundation

nonisolated enum BacktrackingSolver {

    /// Counts solutions up to `limit`, spending from `budget` (nodes).
    /// Returns nil if the budget ran out before the count was decided —
    /// callers must treat that as "unknown", never as a count.
    static func countSolutions(puzzle: Puzzle, limit: Int, budget: inout Int) -> Int? {
        solutions(puzzle: puzzle, limit: limit, budget: &budget)?.count
    }

    /// The solutions found, up to `limit` (row-major, true = land); nil when
    /// the budget ran out first. The generator's uniqueness repair uses the
    /// second solution to see where the ambiguity is.
    static func solutions(puzzle: Puzzle, limit: Int, budget: inout Int) -> [[Bool]]? {
        guard puzzle.landTotal <= puzzle.size * puzzle.size else { return [] }
        var search = Search(puzzle: puzzle, limit: limit)
        var marks = puzzle.initialMarks
        let finished = search.run(&marks, budget: &budget)
        return finished ? search.solutions : nil
    }

    private struct Search {
        let puzzle: Puzzle
        let grid: Grid
        let clueAt: [Int]
        let limit: Int
        let seaTotal: Int
        let landTotal: Int
        let context: SolverContext
        var solutions: [[Bool]] = []
        var found: Int { solutions.count }

        init(puzzle: Puzzle, limit: Int) {
            self.puzzle = puzzle
            grid = puzzle.grid
            clueAt = puzzle.clueIndexAt
            self.limit = limit
            seaTotal = puzzle.seaTotal
            landTotal = puzzle.landTotal
            context = SolverContext(puzzle: puzzle)
        }

        /// Returns false when the budget ran out (result unknown).
        mutating func run(_ marks: inout [Mark], budget: inout Int) -> Bool {
            if budget <= 0 { return false }
            budget -= 1
            var local = marks
            guard propagate(&local) else { return true }    // dead end
            guard let branch = chooseBranch(local) else {
                if Rules.isSolved(local, puzzle: puzzle) { solutions.append(local.map { $0 == .land }) }
                return true
            }
            for colour in [Mark.land, .sea] {
                var child = local
                child[branch] = colour
                if !run(&child, budget: &budget) { return false }
                if found >= limit { return true }
            }
            return true
        }

        /// Rules-level forcing to a fixpoint. False on contradiction.
        ///
        /// Each pass collects every forcing visible in one snapshot and
        /// applies them together — each is forced by facts that stay true —
        /// and a cell forced both ways is a contradiction.
        func propagate(_ marks: inout [Mark]) -> Bool {
            var forced = [Mark](repeating: .unknown, count: grid.count)
            var touched: [Int] = []
            while true {
                let groups = Groups(marks: marks, grid: grid, clueIndexAt: clueAt)
                guard consistent(marks, groups) else { return false }
                touched.removeAll(keepingCapacity: true)
                var conflict = false

                func force(_ i: Int, _ colour: Mark) {
                    if forced[i] == .unknown {
                        forced[i] = colour
                        touched.append(i)
                    } else if forced[i] != colour {
                        conflict = true
                    }
                }

                for g in groups.land where !g.liberties.isEmpty {
                    if let k = g.clueIndices.first {
                        let value = puzzle.clues[k].value
                        if g.cells.count == value {
                            for i in g.liberties { force(i, .sea) }
                        } else if g.liberties.count == 1 {
                            force(g.liberties[0], .land)
                        }
                    } else if g.liberties.count == 1 {
                        force(g.liberties[0], .land)
                    }
                }
                for g in groups.sea where g.liberties.count == 1 && g.cells.count < seaTotal {
                    force(g.liberties[0], .sea)
                }
                for i in 0..<grid.count where marks[i] == .unknown {
                    var clue = -1
                    for n in grid.neighbours[i] {
                        let g = groups.landGroupOf[n]
                        guard g >= 0, let k = groups.land[g].clueIndices.first else { continue }
                        if clue == -1 { clue = k } else if clue != k { force(i, .sea); break }
                    }
                }
                // No numbered island can reach it: sea. Unnumbered land no
                // island can reach: dead end.
                let reach = LogicalSolver.reachable(context, marks, groups)
                for g in groups.land where g.clueIndices.isEmpty && !g.cells.contains(where: { reach[$0] }) {
                    return false
                }
                for i in 0..<grid.count where marks[i] == .unknown && !reach[i] { force(i, .sea) }
                for corner in grid.poolCorners {
                    var seaCount = 0, open = -1
                    for i in grid.pool(at: corner) {
                        if marks[i] == .sea { seaCount += 1 } else if marks[i] == .unknown { open = i }
                    }
                    if seaCount == 3 && open >= 0 { force(open, .land) }
                }

                for i in touched {
                    marks[i] = forced[i]
                    forced[i] = .unknown
                }
                if conflict { return false }
                if touched.isEmpty { return true }
            }
        }

        func consistent(_ marks: [Mark], _ groups: Groups) -> Bool {
            var land = 0, sea = 0
            for m in marks { if m == .land { land += 1 } else if m == .sea { sea += 1 } }
            if land > landTotal || sea > seaTotal { return false }
            for g in groups.land {
                if g.clueIndices.count > 1 { return false }
                if let k = g.clueIndices.first {
                    let value = puzzle.clues[k].value
                    if g.cells.count > value { return false }
                    if g.cells.count < value && g.liberties.isEmpty { return false }
                } else if g.liberties.isEmpty {
                    return false
                }
            }
            for g in groups.sea where g.liberties.isEmpty && g.cells.count < seaTotal { return false }
            for corner in grid.poolCorners where grid.pool(at: corner).allSatisfy({ marks[$0] == .sea }) {
                return false
            }
            return true
        }

        /// Branch on a liberty of the unfinished island with the fewest
        /// liberties; else the first blank cell.
        func chooseBranch(_ marks: [Mark]) -> Int? {
            let groups = Groups(marks: marks, grid: grid, clueIndexAt: clueAt)
            var best: Int? = nil
            var bestCount = Int.max
            for g in groups.land where !g.liberties.isEmpty && g.liberties.count < bestCount {
                best = g.liberties[0]
                bestCount = g.liberties.count
            }
            return best ?? marks.firstIndex(of: .unknown)
        }
    }
}
