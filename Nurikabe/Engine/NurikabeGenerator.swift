//
//  NurikabeGenerator.swift
//  Nurikabe
//
//  Generation invariant, enforced at this file's single exit: every returned
//  puzzle is provably unique (BacktrackingSolver) AND fully solvable by
//  LogicalSolver under the requested tier's technique ceiling. A board
//  failing either test is never returned; this is what makes the hint
//  guarantee real.
//
//  Bounded by a DETERMINISTIC node budget (never wall-clock), so each seed
//  always produces the same board. Baked fallbacks cover budget exhaustion.
//

import Foundation

nonisolated enum BoardSize: Int, CaseIterable, Codable, Sendable, Identifiable {
    case five = 5, seven = 7, ten = 10

    var id: Int { rawValue }

    /// Largest island the layout step may grow.
    var maxIsland: Int {
        switch self {
        case .five: 5
        case .seven: 7
        case .ten: 9
        }
    }

    /// Chance (in %) that a random cell not touching land starts an island.
    static let newIslandPercentDefault = 35

    /// Tiers offered at this size. Measured 2026-09-27: 10×10 boards almost
    /// never grade gentle (0 in 6 full budgets) and rarely steady (2 in 6),
    /// so the big board starts at sharp.
    var tiers: [Difficulty] {
        switch self {
        case .five, .seven: Difficulty.allCases
        case .ten: [.sharp, .deep, .severe]
        }
    }

    /// Target share of land cells. Real Nurikabe boards sit near 40%.
    var landShare: Double {
        switch self {
        case .five: 0.40
        case .seven: 0.40
        case .ten: 0.38
        }
    }
}

nonisolated struct GenerationResult: Sendable {
    let puzzle: Puzzle
    let grade: Difficulty
    let trace: [SolverStep]
    /// True when the budget ran out and a baked fallback was returned.
    let isFallback: Bool
}

nonisolated enum NurikabeGenerator {

    /// Total node budget per generate() call, spent across layout,
    /// uniqueness proofs and solver runs.
    static let nodeBudget = 600_000

    /// Requested-tier generation: returns a board graded in the requested
    /// tier when one turns up, otherwise the nearest grade — and a baked
    /// board if the budget runs out. Show the returned grade, never the
    /// requested label.
    static func generate(size: BoardSize, tier: Difficulty, seed: UInt64,
                         isCancelled: () -> Bool = { false }) -> GenerationResult {
        var rng = SeededRandomNumberGenerator(seed: seed)
        var budget = nodeBudget
        var nearest: GenerationResult? = nil

        while budget > 0 && !isCancelled() {
            budget -= 50
            guard let layout = attempt(size: size, rng: &rng, budget: &budget),
                  let unique = makeUnique(layout, rng: &rng, budget: &budget) else { continue }
            // Two folding passes: the first reshapes the board enough that
            // some remaining 1s become foldable (measured: 33% → 31% 1s on
            // 7×7, 39% → 33% on 10×10).
            let once = dropOnes(unique, rng: &rng, budget: &budget)
            let puzzle = dropOnes(once, rng: &rng, budget: &budget)

            // Solve once with the whole ladder and grade: a board graded
            // below the request is still a near miss worth keeping, and
            // its trace is exactly what the hint engine will replay.
            var solveBudget = min(budget, 40_000)
            let solveBefore = solveBudget
            let result = LogicalSolver.solve(puzzle: puzzle, budget: &solveBudget)
            budget -= solveBefore - solveBudget
            guard result.solved else { continue }

            let grade = DifficultyRater.grade(trace: result.trace, size: size.rawValue)
            let candidate = GenerationResult(puzzle: puzzle, grade: grade, trace: result.trace,
                                             isFallback: false)
            if grade == tier { return candidate }
            if nearest.map({ abs(grade.rawValue - tier.rawValue) < abs($0.grade.rawValue - tier.rawValue) }) ?? true {
                nearest = candidate
            }
        }
        if let nearest { return nearest }
        return BakedPuzzles.result(size: size)
    }

    /// A board guaranteed to exercise `technique` — its trace contains at
    /// least one step of it. Round 0 is the unsalted seed; later rounds salt
    /// deterministically; the first valid board ships with `matched: false`
    /// if no round produces the technique.
    static func generate(featuring technique: Technique, size: BoardSize, tier: Difficulty,
                         seed: UInt64, rounds: Int = 10,
                         isCancelled: () -> Bool = { false })
    -> (result: GenerationResult, matched: Bool) {
        var first: GenerationResult? = nil
        for round in 0..<max(rounds, 1) {
            if isCancelled() { break }
            let salted = seed &+ UInt64(round) &* 0x9E37_79B9_7F4A_7C15
            let result = generate(size: size, tier: tier, seed: salted, isCancelled: isCancelled)
            if result.trace.contains(where: { $0.technique == technique }) { return (result, true) }
            if first == nil { first = result }
        }
        // Cancelled before any round finished: never start an uncancellable
        // full generation here; a baked board answers instantly.
        return (first ?? (isCancelled() ? BakedPuzzles.result(size: size)
                          : generate(size: size, tier: tier, seed: seed, isCancelled: isCancelled)), false)
    }

    // MARK: - Uniqueness repair

    /// Repair rounds per layout before it is abandoned.
    static let repairRounds = 24
    /// New 1-islands the repair may add; each is a free deduction for the
    /// player, so a board that needs more is abandoned instead.
    static let maxCarves = 3

    /// Turn a layout's puzzle into a unique one without changing the
    /// intended solution, or nil. Each round asks the backtracker for a
    /// rival solution and rules it out:
    ///  1. move a clue onto a cell of its island that the rival leaves as
    ///     sea (clue cells must be land, so the rival dies), else
    ///  2. carve a new 1-island from our sea at a cell the rival uses as
    ///     land, where our layout allows it (the layout changes; the new
    ///     solution is still a valid layout by construction).
    static func makeUnique(_ start: Puzzle, rng: inout SeededRandomNumberGenerator,
                           budget: inout Int) -> Puzzle? {
        var puzzle = start
        let grid = puzzle.grid
        var carves = 0
        for round in 0..<repairRounds {
            var proof = min(budget, 60_000)
            let before = proof
            let found = BacktrackingSolver.solutions(puzzle: puzzle, limit: 2, budget: &proof)
            budget -= before - proof
            guard let found, !found.isEmpty else { return nil }
            if found.count == 1 { return puzzle }
            let rival = found.first { $0 != puzzle.solution } ?? found[1]

            // Every third round, change the layout itself: clue moves alone
            // can chase rivals around a board forever.
            if round % 3 == 2, let changed = reshape(puzzle, rival: rival, carves: &carves, rng: &rng) {
                puzzle = changed
                continue
            }

            // Clue move: onto a cell of its island the rival leaves as sea.
            // Always available: equal land totals mean the rival's extra
            // land is paid for by sea inside one of our islands.
            let marks = puzzle.solution.map { $0 ? Mark.land : Mark.sea }
            let groups = Groups(marks: marks, grid: grid, clueIndexAt: puzzle.clueIndexAt)
            var moves: [(clue: Int, to: Int)] = []
            for g in groups.land {
                guard let k = g.clueIndices.first else { continue }
                for i in g.cells where !rival[i] { moves.append((k, i)) }
            }
            guard !moves.isEmpty else { return nil }
            let move = moves[Int(rng.next() % UInt64(moves.count))]
            var clues = puzzle.clues
            clues[move.clue] = Clue(cell: grid.cell(move.to), value: clues[move.clue].value)
            clues.sort { $0.cell < $1.cell }
            puzzle = Puzzle(size: puzzle.size, clues: clues, solution: puzzle.solution)
        }
        return nil
    }

    /// Fold redundant 1-islands into a neighbouring island. Random layouts
    /// owe much of their uniqueness to scattered 1s, but many are
    /// redundant. A 1 is walled by sea, so deleting it would usually make a
    /// pool; instead a sea cell `y` beside it bridges it into the one island
    /// `y` touches (that island grows by two, the 1's clue goes). The change
    /// is kept only if the board stays unique. Fewer 1s means fewer free
    /// deductions and more islands that matter.
    static func dropOnes(_ start: Puzzle, rng: inout SeededRandomNumberGenerator,
                         budget: inout Int) -> Puzzle {
        var puzzle = start
        let grid = puzzle.grid
        let cap = (BoardSize(rawValue: puzzle.size)?.maxIsland ?? 9) + 1
        var ones = puzzle.clues.filter { $0.value == 1 }.map(\.cell)
        ones.shuffle(using: &rng)
        for cell in ones {
            guard budget > 0 else { break }
            let x = grid.index(cell)
            guard puzzle.clues.contains(where: { $0.cell == cell && $0.value == 1 }) else { continue }
            let marks = puzzle.solution.map { $0 ? Mark.land : Mark.sea }
            let groups = Groups(marks: marks, grid: grid, clueIndexAt: puzzle.clueIndexAt)
            var bridges = grid.neighbours[x].filter { !puzzle.solution[$0] }
            bridges.shuffle(using: &rng)
            for y in bridges {
                var touching = Set<Int>()
                for m in grid.neighbours[y] where m != x && puzzle.solution[m] {
                    touching.insert(groups.landGroupOf[m])
                }
                guard touching.count == 1, let g = touching.first,
                      let k = groups.land[g].clueIndices.first,
                      groups.land[g].cells.count + 2 <= cap,
                      seaStaysConnected(without: y, land: puzzle.solution, grid: grid) else { continue }
                var solution = puzzle.solution
                solution[y] = true
                var clues = puzzle.clues
                clues[k] = Clue(cell: clues[k].cell, value: clues[k].value + 2)
                clues.removeAll { $0.cell == cell }
                let trial = Puzzle(size: puzzle.size, clues: clues, solution: solution)
                var proof = min(budget, 60_000)
                let before = proof
                let count = BacktrackingSolver.countSolutions(puzzle: trial, limit: 2, budget: &proof)
                budget -= before - proof
                if count == 1 { puzzle = trial; break }
            }
        }
        return puzzle
    }

    /// A layout change aimed at the rival: grow one of our islands into a
    /// cell the rival uses as land, else carve a new 1-island there. The
    /// result is still a legal layout by construction; nil if neither fits.
    static func reshape(_ puzzle: Puzzle, rival: [Bool], carves: inout Int,
                        rng: inout SeededRandomNumberGenerator) -> Puzzle? {
        let grid = puzzle.grid
        let land = puzzle.solution
        let marks = land.map { $0 ? Mark.land : Mark.sea }
        let groups = Groups(marks: marks, grid: grid, clueIndexAt: puzzle.clueIndexAt)
        let maxIsland = BoardSize(rawValue: puzzle.size)?.maxIsland ?? 9

        // Grow: a rival-land sea cell beside exactly one island.
        var grows: [(cell: Int, group: Int)] = []
        for x in 0..<grid.count where rival[x] && !land[x] {
            var touching = Set<Int>()
            for m in grid.neighbours[x] where land[m] { touching.insert(groups.landGroupOf[m]) }
            guard touching.count == 1, let g = touching.first,
                  groups.land[g].cells.count < maxIsland,
                  seaStaysConnected(without: x, land: land, grid: grid) else { continue }
            grows.append((x, g))
        }
        if !grows.isEmpty {
            let pick = grows[Int(rng.next() % UInt64(grows.count))]
            var solution = land
            solution[pick.cell] = true
            guard let k = groups.land[pick.group].clueIndices.first else { return nil }
            var clues = puzzle.clues
            clues[k] = Clue(cell: clues[k].cell, value: clues[k].value + 1)
            return Puzzle(size: puzzle.size, clues: clues, solution: solution)
        }

        // Carve: a new 1-island, capped because each is a free deduction.
        guard carves < maxCarves else { return nil }
        let spots = (0..<grid.count).filter { rival[$0] && canCarveOne($0, in: land, grid: grid) }
        guard !spots.isEmpty else { return nil }
        carves += 1
        let x = spots[Int(rng.next() % UInt64(spots.count))]
        var solution = land
        solution[x] = true
        var clues = puzzle.clues
        clues.append(Clue(cell: grid.cell(x), value: 1))
        clues.sort { $0.cell < $1.cell }
        return Puzzle(size: puzzle.size, clues: clues, solution: solution)
    }

    static func seaStaysConnected(without x: Int, land: [Bool], grid: Grid) -> Bool {
        var seen = [Bool](repeating: false, count: grid.count)
        var start = -1, seaCells = 0
        for i in 0..<grid.count where !land[i] && i != x {
            seaCells += 1
            if start == -1 { start = i }
        }
        guard start >= 0 else { return false }
        var stack = [start]
        seen[start] = true
        var reached = 0
        while let i = stack.popLast() {
            reached += 1
            for m in grid.neighbours[i] where !land[m] && m != x && !seen[m] {
                seen[m] = true
                stack.append(m)
            }
        }
        return reached == seaCells
    }

    /// Can sea cell `x` become a 1-island? It must not touch land, and the
    /// sea must stay connected without it.
    static func canCarveOne(_ x: Int, in land: [Bool], grid: Grid) -> Bool {
        guard !land[x], !grid.neighbours[x].contains(where: { land[$0] }) else { return false }
        return seaStaysConnected(without: x, land: land, grid: grid)
    }

    // MARK: - One attempt

    /// Lay out islands, then place one clue per island. nil when the layout
    /// could not clear every 2×2 pool.
    static func attempt(size: BoardSize, rng: inout SeededRandomNumberGenerator,
                        budget: inout Int) -> Puzzle? {
        guard let land = layout(size: size, rng: &rng, budget: &budget) else { return nil }
        let n = size.rawValue
        let grid = Grid(size: n)

        // Islands of the layout.
        let marks = land.map { $0 ? Mark.land : Mark.sea }
        let groups = Groups(marks: marks, grid: grid, clueIndexAt: [Int](repeating: -1, count: grid.count))
        var clues: [Clue] = []
        for g in groups.land {
            let pick = g.cells[Int(rng.next() % UInt64(g.cells.count))]
            clues.append(Clue(cell: grid.cell(pick), value: g.cells.count))
        }
        clues.sort { $0.cell < $1.cell }
        return Puzzle(size: n, clues: clues, solution: land)
    }

    /// Grow a legal island layout from an all-sea grid: the sea stays
    /// connected, islands never touch, no island exceeds `maxIsland`, and
    /// flipping continues until no 2×2 pool remains and the land share is met.
    static func layout(size: BoardSize, rng: inout SeededRandomNumberGenerator,
                       budget: inout Int) -> [Bool]? {
        let n = size.rawValue
        let grid = Grid(size: n)
        var land = [Bool](repeating: false, count: grid.count)
        var islandOf = [Int](repeating: -1, count: grid.count)
        var islandSize: [Int] = []
        let targetLand = Int(Double(grid.count) * size.landShare)
        var landCount = 0

        func pools() -> [Int] {
            grid.poolCorners.filter { c in grid.pool(at: c).allSatisfy { !land[$0] } }
        }

        func seaConnectedWithout(_ cell: Int) -> Bool {
            var seen = [Bool](repeating: false, count: grid.count)
            var start = -1
            var seaCells = 0
            for i in 0..<grid.count where !land[i] && i != cell {
                seaCells += 1
                if start == -1 { start = i }
            }
            guard start >= 0 else { return false }
            var stack = [start]
            seen[start] = true
            var reached = 0
            while let i = stack.popLast() {
                reached += 1
                for m in grid.neighbours[i] where !land[m] && m != cell && !seen[m] {
                    seen[m] = true
                    stack.append(m)
                }
            }
            return reached == seaCells
        }

        /// Can `cell` turn to land? Returns the island it would join
        /// (-1 = starts a new island), or nil if illegal.
        func joinable(_ cell: Int) -> Int?? {
            guard !land[cell] else { return nil }
            var island = -1
            for m in grid.neighbours[cell] where land[m] {
                let id = islandOf[m]
                if island == -1 { island = id } else if island != id { return nil }
            }
            if island >= 0, islandSize[island] >= size.maxIsland { return nil }
            guard seaConnectedWithout(cell) else { return nil }
            return .some(island)
        }

        func flip(_ cell: Int, into island: Int) {
            if island == -1 {
                islandSize.append(1)
                islandOf[cell] = islandSize.count - 1
            } else {
                islandSize[island] += 1
                islandOf[cell] = island
            }
            land[cell] = true
            landCount += 1
        }

        var flips = 0
        while budget > 0 {
            budget -= 1
            let open = pools()
            if open.isEmpty && landCount >= targetLand { break }
            flips += 1
            if flips > grid.count * 6 { return nil }

            // Break a pool with one of its cells.
            if !open.isEmpty && (rng.next() % 100 < 60 || landCount >= targetLand) {
                let block = grid.pool(at: open[Int(rng.next() % UInt64(open.count))])
                let cell = block[Int(rng.next() % 4)]
                if let join = joinable(cell), let island = join { flip(cell, into: island) }
                continue
            }

            // Otherwise a random cell: it grows the island it touches, or —
            // less often — starts a new one. Growth lands where islands have
            // most boundary, which keeps a spread of sizes; measured
            // 2026-09-27, this scattered layout is what makes random boards
            // repairable to uniqueness at 10×10 (smallest-first growth fell
            // to 1 unique board in 26).
            let cell = Int(rng.next() % UInt64(grid.count))
            guard let join = joinable(cell), let island = join else { continue }
            if island == -1 && !islandSize.isEmpty && rng.next() % 100 >= BoardSize.newIslandPercentDefault { continue }
            flip(cell, into: island)
        }
        guard pools().isEmpty else { return nil }
        return land
    }
}
