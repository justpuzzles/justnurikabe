//
//  LogicalSolver.swift
//  Nurikabe
//
//  The human-technique solver. `nextStep` powers hints; `solve` powers the
//  generation gate. Applies the LOWEST-TIER applicable technique, never the
//  first found — otherwise difficulty ratings inflate and hints skip the
//  argument the player could actually make.
//
//  Never a uniqueness proof; that is BacktrackingSolver's only job.
//

import Foundation

/// Per-puzzle constants the detectors share, computed once.
nonisolated struct SolverContext: Sendable {
    let puzzle: Puzzle
    let grid: Grid
    let clueAt: [Int]
    let landTotal: Int
    let seaTotal: Int

    init(puzzle: Puzzle) {
        self.puzzle = puzzle
        grid = puzzle.grid
        clueAt = puzzle.clueIndexAt
        landTotal = puzzle.landTotal
        seaTotal = puzzle.seaTotal
    }

    func value(ofClue k: Int) -> Int { puzzle.clues[k].value }
}

nonisolated enum LogicalSolver {

    /// The lowest-tier applicable step, or nil when solved or stuck.
    static func nextStep(context: SolverContext, marks: [Mark],
                         maxTechnique: Technique = .whatIf) -> SolverStep? {
        let groups = Groups(marks: marks, grid: context.grid, clueIndexAt: context.clueAt)
        for technique in Technique.allCases where technique <= maxTechnique {
            if let step = detect(technique, context: context, marks: marks, groups: groups) {
                return step
            }
        }
        return nil
    }

    static func nextStep(puzzle: Puzzle, marks: [Mark],
                         maxTechnique: Technique = .whatIf) -> SolverStep? {
        nextStep(context: SolverContext(puzzle: puzzle), marks: marks, maxTechnique: maxTechnique)
    }

    nonisolated struct SolveResult: Sendable {
        let solved: Bool
        let trace: [SolverStep]
        let marks: [Mark]
    }

    /// Run to completion (or stuck) under a technique ceiling, spending one
    /// unit of `budget` per step (whatIf spends more inside).
    static func solve(puzzle: Puzzle, from start: [Mark]? = nil,
                      maxTechnique: Technique = .whatIf,
                      budget: inout Int) -> SolveResult {
        let context = SolverContext(puzzle: puzzle)
        var marks = start ?? puzzle.initialMarks
        var trace: [SolverStep] = []
        while marks.contains(.unknown) {
            guard budget > 0,
                  let step = nextStep(context: context, marks: marks, maxTechnique: maxTechnique,
                                      budget: &budget)
            else { break }
            budget -= 1
            apply(step, to: &marks, grid: context.grid)
            trace.append(step)
        }
        let solved = !marks.contains(.unknown) && Rules.isSolved(marks, puzzle: puzzle)
        return SolveResult(solved: solved, trace: trace, marks: marks)
    }

    /// The solver's own steps from `marks` up to and including the first
    /// step that decides `cell`, or nil if that takes more than `maxSteps`
    /// steps or the solver gets stuck. Mastery uses it to ask "what argument
    /// did the player just make?"
    static func chain(toDecide cell: Int, from start: [Mark], context: SolverContext,
                      maxSteps: Int = 6, budget: Int = 6_000) -> [SolverStep]? {
        var marks = start
        var steps: [SolverStep] = []
        var budget = budget
        let target = context.grid.cell(cell)
        while steps.count < maxSteps, marks[cell] == .unknown {
            guard budget > 0,
                  let step = nextStep(context: context, marks: marks, maxTechnique: .whatIf, budget: &budget)
            else { return nil }
            budget -= 1
            steps.append(step)
            if step.sea.contains(target) || step.land.contains(target) { return steps }
            apply(step, to: &marks, grid: context.grid)
        }
        return nil
    }

    static func apply(_ step: SolverStep, to marks: inout [Mark], grid: Grid) {
        for cell in step.sea { marks[grid.index(cell)] = .sea }
        for cell in step.land { marks[grid.index(cell)] = .land }
    }

    /// Budgeted variant used by `solve`: whatIf's look-ahead draws on the
    /// same budget so generation stays deterministic and bounded.
    private static func nextStep(context: SolverContext, marks: [Mark],
                                 maxTechnique: Technique, budget: inout Int) -> SolverStep? {
        let groups = Groups(marks: marks, grid: context.grid, clueIndexAt: context.clueAt)
        for technique in Technique.allCases where technique <= maxTechnique {
            if technique == .whatIf {
                if let step = detectWhatIf(context: context, marks: marks, budget: &budget) {
                    return step
                }
            } else if let step = detect(technique, context: context, marks: marks, groups: groups) {
                return step
            }
        }
        return nil
    }

    static func detect(_ technique: Technique, context: SolverContext,
                       marks: [Mark], groups: Groups) -> SolverStep? {
        switch technique {
        case .oneClue: return detectOneClue(context, marks)
        case .twoClues: return detectTwoClues(context, marks, groups)
        case .completeIsland: return detectCompleteIsland(context, groups)
        case .noPool: return detectNoPool(context, marks)
        case .unreachable: return detectUnreachable(context, marks, groups)
        case .islandEscape: return detectIslandEscape(context, groups)
        case .seaEscape: return detectSeaEscape(context, groups)
        case .commonGround: return detectCommonGround(context, marks, groups)
        case .whatIf:
            var budget = 4_000
            return detectWhatIf(context: context, marks: marks, budget: &budget)
        }
    }

    // MARK: - T1 oneClue

    private static func detectOneClue(_ ctx: SolverContext, _ marks: [Mark]) -> SolverStep? {
        for (k, clue) in ctx.puzzle.clues.enumerated() where clue.value == 1 {
            let i = ctx.grid.index(clue.cell)
            let open = ctx.grid.neighbours[i].filter { marks[$0] == .unknown }
            guard !open.isEmpty else { continue }
            return step(.oneClue, ctx, sea: open,
                        explanation: ExplanationData(clueIndices: [k], region: [clue.cell]))
        }
        return nil
    }

    // MARK: - T2 twoClues

    private static func detectTwoClues(_ ctx: SolverContext, _ marks: [Mark],
                                       _ groups: Groups) -> SolverStep? {
        for i in 0..<ctx.grid.count where marks[i] == .unknown {
            var clueGroups: [Int] = []
            var clues: [Int] = []
            for n in ctx.grid.neighbours[i] {
                let g = groups.landGroupOf[n]
                guard g >= 0, let k = groups.land[g].clueIndices.first,
                      !clues.contains(k) else { continue }
                clues.append(k)
                clueGroups.append(g)
            }
            guard clues.count >= 2 else { continue }
            let region = clueGroups.prefix(2).flatMap { groups.land[$0].cells }
            return step(.twoClues, ctx, sea: [i],
                        explanation: ExplanationData(clueIndices: Array(clues.prefix(2)),
                                                     region: cells(region, ctx)))
        }
        return nil
    }

    // MARK: - T3 completeIsland

    private static func detectCompleteIsland(_ ctx: SolverContext, _ groups: Groups) -> SolverStep? {
        for g in groups.land where g.clueIndices.count == 1 && !g.liberties.isEmpty {
            let k = g.clueIndices[0]
            guard g.cells.count == ctx.value(ofClue: k) else { continue }
            return step(.completeIsland, ctx, sea: g.liberties,
                        explanation: ExplanationData(clueIndices: [k], region: cells(g.cells, ctx),
                                                     numbers: [ctx.value(ofClue: k)]))
        }
        return nil
    }

    // MARK: - T4 noPool

    private static func detectNoPool(_ ctx: SolverContext, _ marks: [Mark]) -> SolverStep? {
        for corner in ctx.grid.poolCorners {
            let block = ctx.grid.pool(at: corner)
            var seaCount = 0
            var open = -1
            for i in block {
                switch marks[i] {
                case .sea: seaCount += 1
                case .unknown: open = i
                case .land: break
                }
            }
            guard seaCount == 3, open >= 0 else { continue }
            return step(.noPool, ctx, land: [open],
                        explanation: ExplanationData(region: cells(block, ctx)))
        }
        return nil
    }

    // MARK: - T5 unreachable

    /// reach[i] = true when some unfinished numbered island could still
    /// grow to cell i. Shared with whatIf's contradiction check.
    static func reachable(_ ctx: SolverContext, _ marks: [Mark], _ groups: Groups) -> [Bool] {
        var reach = [Bool](repeating: false, count: ctx.grid.count)
        var dist = [Int](repeating: Int.max, count: ctx.grid.count)
        var queue: [Int] = []
        for (gi, g) in groups.land.enumerated() where g.clueIndices.count == 1 {
            let k = g.clueIndices[0]
            let remaining = ctx.value(ofClue: k) - g.cells.count
            for i in g.cells { reach[i] = true }
            guard remaining > 0 else { continue }
            for i in 0..<ctx.grid.count { dist[i] = Int.max }
            queue.removeAll(keepingCapacity: true)
            for i in g.cells { dist[i] = 0; queue.append(i) }
            var head = 0
            while head < queue.count {
                let cur = queue[head]; head += 1
                let d = dist[cur] + 1
                guard d <= remaining else { continue }
                for n in ctx.grid.neighbours[cur] where dist[n] == Int.max {
                    guard marks[n] != .sea,
                          !touchesOtherClue(n, clue: k, ownGroup: gi, marks: marks, groups: groups, ctx)
                    else { continue }
                    dist[n] = d
                    reach[n] = true
                    queue.append(n)
                }
            }
        }
        return reach
    }

    /// Would cell n, as part of the island of clue k, sit in or beside a
    /// different numbered island?
    private static func touchesOtherClue(_ n: Int, clue k: Int, ownGroup: Int, marks: [Mark],
                                         groups: Groups, _ ctx: SolverContext) -> Bool {
        let own = groups.landGroupOf[n]
        if own >= 0, own != ownGroup, !groups.land[own].clueIndices.isEmpty { return true }
        for m in ctx.grid.neighbours[n] {
            let g = groups.landGroupOf[m]
            guard g >= 0, g != ownGroup else { continue }
            if groups.land[g].clueIndices.contains(where: { $0 != k }) { return true }
        }
        return false
    }

    private static func detectUnreachable(_ ctx: SolverContext, _ marks: [Mark],
                                          _ groups: Groups) -> SolverStep? {
        let reach = reachable(ctx, marks, groups)
        let out = (0..<ctx.grid.count).filter { marks[$0] == .unknown && !reach[$0] }
        guard !out.isEmpty else { return nil }
        return step(.unreachable, ctx, sea: out,
                    explanation: ExplanationData(region: cells(out, ctx)))
    }

    // MARK: - T6 islandEscape

    private static func detectIslandEscape(_ ctx: SolverContext, _ groups: Groups) -> SolverStep? {
        for g in groups.land where g.liberties.count == 1 && g.clueIndices.count <= 1 {
            if let k = g.clueIndices.first {
                guard g.cells.count < ctx.value(ofClue: k) else { continue }
                return step(.islandEscape, ctx, land: g.liberties,
                            explanation: ExplanationData(clueIndices: [k], region: cells(g.cells, ctx),
                                                         numbers: [ctx.value(ofClue: k), g.cells.count]))
            }
            return step(.islandEscape, ctx, land: g.liberties,
                        explanation: ExplanationData(region: cells(g.cells, ctx)))
        }
        return nil
    }

    // MARK: - T7 seaEscape

    private static func detectSeaEscape(_ ctx: SolverContext, _ groups: Groups) -> SolverStep? {
        for g in groups.sea where g.liberties.count == 1 && g.cells.count < ctx.seaTotal {
            return step(.seaEscape, ctx, sea: g.liberties,
                        explanation: ExplanationData(region: cells(g.cells, ctx),
                                                     numbers: [g.cells.count, ctx.seaTotal]))
        }
        return nil
    }

    // MARK: - T8 commonGround

    /// Islands needing more than this many cells are not enumerated.
    static let commonGroundMaxRemaining = 7
    /// Abandon an island's enumeration past this many partial shapes.
    static let commonGroundMaxShapes = 4_000

    private static func detectCommonGround(_ ctx: SolverContext, _ marks: [Mark],
                                           _ groups: Groups) -> SolverStep? {
        for (gi, g) in groups.land.enumerated() where g.clueIndices.count == 1 {
            let k = g.clueIndices[0]
            let value = ctx.value(ofClue: k)
            let remaining = value - g.cells.count
            guard remaining > 0, remaining <= commonGroundMaxRemaining,
                  let completions = completions(of: gi, clue: k, value: value, ctx, marks, groups),
                  !completions.isEmpty
            else { continue }

            // Land: blank cells every completion uses.
            var shared = completions[0]
            for c in completions.dropFirst() { shared = shared.intersection(c) }
            let land = shared.indices.filter { marks[$0] == .unknown }

            // Sea: blank cells every completion borders but none uses.
            var used = Bits()
            for c in completions { used = used.union(c) }
            var bordered: Bits? = nil
            for c in completions {
                var border = Bits()
                for i in c.indices {
                    for n in ctx.grid.neighbours[i] where marks[n] == .unknown && !c.contains(n) {
                        border.insert(n)
                    }
                }
                bordered = bordered.map { $0.intersection(border) } ?? border
            }
            let sea = (bordered ?? Bits()).indices.filter { !used.contains($0) }

            guard !land.isEmpty || !sea.isEmpty else { continue }
            return step(.commonGround, ctx, sea: sea, land: land,
                        explanation: ExplanationData(clueIndices: [k],
                                                     region: cells(g.cells, ctx),
                                                     numbers: [value, completions.count]))
        }
        return nil
    }

    /// Every way the island in land group `gi` could reach exactly `value`
    /// cells. nil when enumeration exceeds its cap.
    static func completions(of gi: Int, clue k: Int, value: Int, _ ctx: SolverContext,
                            _ marks: [Mark], _ groups: Groups) -> [Bits]? {
        var start = Bits()
        for i in groups.land[gi].cells { start.insert(i) }
        var level: Set<Bits> = [start]
        var complete: [Bits] = []
        var explored = 0

        while !level.isEmpty {
            var next: Set<Bits> = []
            for shape in level {
                let size = shape.count
                if size == value {
                    if isValidCompletion(shape, ctx, marks) { complete.append(shape) }
                    continue
                }
                for i in shape.indices {
                    for n in ctx.grid.neighbours[i] where !shape.contains(n) && marks[n] != .sea {
                        guard !touchesOtherClue(n, clue: k, ownGroup: gi, marks: marks,
                                                groups: groups, ctx) else { continue }
                        var grown = shape
                        // Unnumbered land joins whole: an island is a maximal group.
                        let lg = groups.landGroupOf[n]
                        if lg >= 0 { for c in groups.land[lg].cells { grown.insert(c) } }
                        else { grown.insert(n) }
                        guard grown.count <= value else { continue }
                        next.insert(grown)
                    }
                }
                explored += 1
                if explored > commonGroundMaxShapes { return nil }
            }
            level = next
        }
        return complete
    }

    /// A finished island may not leave land touching it from outside.
    private static func isValidCompletion(_ shape: Bits, _ ctx: SolverContext, _ marks: [Mark]) -> Bool {
        for i in shape.indices {
            for n in ctx.grid.neighbours[i] where !shape.contains(n) && marks[n] == .land {
                return false
            }
        }
        return true
    }

    // MARK: - T9 whatIf

    /// Cells are tried in index order, land before sea, with propagation
    /// capped below whatIf (no recursion).
    private static func detectWhatIf(context ctx: SolverContext, marks: [Mark],
                                     budget: inout Int) -> SolverStep? {
        for i in 0..<ctx.grid.count where marks[i] == .unknown {
            for tryLand in [true, false] {
                guard budget > 0 else { return nil }
                var trial = marks
                trial[i] = tryLand ? .land : .sea
                if let contradiction = propagateToContradiction(ctx, &trial, budget: &budget) {
                    let cell = ctx.grid.cell(i)
                    let explanation = ExplanationData(region: [cell], trialCell: cell,
                                                      trialWasLand: tryLand,
                                                      contradiction: cells(contradiction, ctx))
                    return tryLand
                        ? step(.whatIf, ctx, sea: [i], explanation: explanation)
                        : step(.whatIf, ctx, land: [i], explanation: explanation)
                }
            }
        }
        return nil
    }

    /// Apply techniques below whatIf until stuck; return the cells of the
    /// first contradiction found, or nil if none arises.
    static func propagateToContradiction(_ ctx: SolverContext, _ marks: inout [Mark],
                                         budget: inout Int) -> [Int]? {
        while budget > 0 {
            budget -= 1
            let groups = Groups(marks: marks, grid: ctx.grid, clueIndexAt: ctx.clueAt)
            if let bad = Contradiction.find(ctx, marks, groups) { return bad }
            var progressed = false
            for technique in Technique.allCases where technique < .whatIf {
                if let s = detect(technique, context: ctx, marks: marks, groups: groups) {
                    apply(s, to: &marks, grid: ctx.grid)
                    progressed = true
                    break
                }
            }
            if !progressed { return nil }
        }
        return nil
    }

    // MARK: - Helpers

    private static func step(_ technique: Technique, _ ctx: SolverContext,
                             sea: [Int] = [], land: [Int] = [],
                             explanation: ExplanationData) -> SolverStep {
        SolverStep(technique: technique, sea: cells(sea, ctx), land: cells(land, ctx),
                   explanation: explanation)
    }

    private static func cells(_ indices: [Int], _ ctx: SolverContext) -> [Cell] {
        indices.sorted().map { ctx.grid.cell($0) }
    }
}

// MARK: - Contradictions

nonisolated enum Contradiction {

    /// Cells of the first impossibility on the board, or nil if none is
    /// visible. Every condition here is necessary for a solution, which is
    /// what makes whatIf (and the uniqueness solver's pruning) sound.
    static func find(_ ctx: SolverContext, _ marks: [Mark], _ groups: Groups) -> [Int]? {
        var landCount = 0, seaCount = 0
        for m in marks {
            if m == .land { landCount += 1 } else if m == .sea { seaCount += 1 }
        }
        if landCount > ctx.landTotal || seaCount > ctx.seaTotal {
            return []
        }
        for g in groups.land {
            if g.clueIndices.count > 1 { return g.cells }
            if let k = g.clueIndices.first {
                let value = ctx.value(ofClue: k)
                if g.cells.count > value { return g.cells }
                if g.cells.count < value && g.liberties.isEmpty { return g.cells }
            } else if g.liberties.isEmpty {
                return g.cells
            }
        }
        for g in groups.sea where g.liberties.isEmpty && g.cells.count < ctx.seaTotal {
            return g.cells
        }
        for corner in ctx.grid.poolCorners {
            let block = ctx.grid.pool(at: corner)
            if block.allSatisfy({ marks[$0] == .sea }) { return block }
        }
        // Unnumbered land that no numbered island can reach.
        let reach = LogicalSolver.reachable(ctx, marks, groups)
        for g in groups.land where g.clueIndices.isEmpty {
            if !g.cells.contains(where: { reach[$0] }) { return g.cells }
        }
        return nil
    }
}

// MARK: - Bits

/// A 128-bit cell set — every supported grid (≤ 10×10) fits.
nonisolated struct Bits: Hashable, Sendable {
    private(set) var lo: UInt64 = 0
    private(set) var hi: UInt64 = 0

    mutating func insert(_ i: Int) {
        if i < 64 { lo |= 1 << UInt64(i) } else { hi |= 1 << UInt64(i - 64) }
    }

    func contains(_ i: Int) -> Bool {
        i < 64 ? (lo >> UInt64(i)) & 1 == 1 : (hi >> UInt64(i - 64)) & 1 == 1
    }

    var count: Int { lo.nonzeroBitCount + hi.nonzeroBitCount }

    func intersection(_ o: Bits) -> Bits { var b = Bits(); b.lo = lo & o.lo; b.hi = hi & o.hi; return b }
    func union(_ o: Bits) -> Bits { var b = Bits(); b.lo = lo | o.lo; b.hi = hi | o.hi; return b }

    var indices: [Int] {
        var out: [Int] = []
        var w = lo
        while w != 0 { let t = w.trailingZeroBitCount; out.append(t); w &= w - 1 }
        w = hi
        while w != 0 { let t = w.trailingZeroBitCount; out.append(64 + t); w &= w - 1 }
        return out
    }
}
