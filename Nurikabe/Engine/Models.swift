//
//  Models.swift
//  Nurikabe
//
//  Cells are addressed by flat row-major index everywhere inside the engine
//  (hot paths stay allocation-light); `Cell` exists for the API surface and
//  for Codable persistence.
//

import Foundation

nonisolated struct Cell: Hashable, Codable, Sendable, Comparable {
    let row: Int
    let col: Int

    static func < (a: Cell, b: Cell) -> Bool {
        a.row != b.row ? a.row < b.row : a.col < b.col
    }
}

nonisolated struct Clue: Hashable, Codable, Sendable {
    let cell: Cell
    let value: Int
}

/// What is known about a cell. The player's board and the solver share it.
nonisolated enum Mark: UInt8, Codable, Sendable {
    case unknown
    case sea
    case land
}

/// Square-grid geometry with a precomputed orthogonal neighbour table.
nonisolated struct Grid: Sendable, Equatable {
    let size: Int
    let count: Int
    /// neighbours[i] = orthogonal neighbours of cell i, row-major order.
    let neighbours: [[Int]]

    init(size: Int) {
        self.size = size
        count = size * size
        var table: [[Int]] = []
        table.reserveCapacity(size * size)
        for i in 0..<(size * size) {
            let r = i / size, c = i % size
            var n: [Int] = []
            if r > 0 { n.append(i - size) }
            if c > 0 { n.append(i - 1) }
            if c < size - 1 { n.append(i + 1) }
            if r < size - 1 { n.append(i + size) }
            table.append(n)
        }
        neighbours = table
    }

    func index(_ cell: Cell) -> Int { cell.row * size + cell.col }
    func cell(_ index: Int) -> Cell { Cell(row: index / size, col: index % size) }

    /// Top-left indices of every 2×2 window.
    var poolCorners: [Int] {
        var corners: [Int] = []
        for r in 0..<(size - 1) {
            for c in 0..<(size - 1) { corners.append(r * size + c) }
        }
        return corners
    }

    /// The four cells of the 2×2 window whose top-left is `corner`.
    func pool(at corner: Int) -> [Int] {
        [corner, corner + 1, corner + size, corner + size + 1]
    }
}

nonisolated struct Puzzle: Codable, Sendable, Equatable {
    let size: Int
    let clues: [Clue]
    /// The unique solution, row-major, true = land. Kept with the puzzle so
    /// the game can check a finished board and the harness can check every
    /// solver deduction against it.
    let solution: [Bool]

    var grid: Grid { Grid(size: size) }

    /// clueIndexAt[i] = index into `clues` for a clue cell, else -1.
    var clueIndexAt: [Int] {
        var map = [Int](repeating: -1, count: size * size)
        for (k, clue) in clues.enumerated() { map[clue.cell.row * size + clue.cell.col] = k }
        return map
    }

    var landTotal: Int { clues.reduce(0) { $0 + $1.value } }
    var seaTotal: Int { size * size - landTotal }

    /// The starting marks: clue cells are land, everything else unknown.
    var initialMarks: [Mark] {
        var marks = [Mark](repeating: .unknown, count: size * size)
        for clue in clues { marks[clue.cell.row * size + clue.cell.col] = .land }
        return marks
    }
}

// MARK: - CellGroup analysis

/// A connected group of same-coloured cells.
nonisolated struct CellGroup: Sendable {
    var cells: [Int] = []
    /// Unknown cells orthogonally adjacent to the group, deduplicated.
    var liberties: [Int] = []
    /// Clue indices inside the group (land groups only).
    var clueIndices: [Int] = []
}

/// Land and sea groups of a mark array, computed by flood fill.
nonisolated struct Groups: Sendable {
    let land: [CellGroup]
    let sea: [CellGroup]
    /// landGroupOf[i] = index into `land` for a land cell, else -1.
    let landGroupOf: [Int]
    /// seaGroupOf[i] = index into `sea` for a sea cell, else -1.
    let seaGroupOf: [Int]

    init(marks: [Mark], grid: Grid, clueIndexAt: [Int]) {
        var landGroups: [CellGroup] = []
        var seaGroups: [CellGroup] = []
        var landOf = [Int](repeating: -1, count: grid.count)
        var seaOf = [Int](repeating: -1, count: grid.count)
        var libertySeen = [Int](repeating: -1, count: grid.count)
        var stack: [Int] = []
        var stamp = 0

        for start in 0..<grid.count {
            let colour = marks[start]
            guard colour != .unknown else { continue }
            if colour == .land && landOf[start] != -1 { continue }
            if colour == .sea && seaOf[start] != -1 { continue }

            var group = CellGroup()
            let id = colour == .land ? landGroups.count : seaGroups.count
            stamp += 1
            stack.append(start)
            if colour == .land { landOf[start] = id } else { seaOf[start] = id }
            while let i = stack.popLast() {
                group.cells.append(i)
                if colour == .land, clueIndexAt[i] >= 0 { group.clueIndices.append(clueIndexAt[i]) }
                for n in grid.neighbours[i] {
                    switch marks[n] {
                    case .unknown:
                        if libertySeen[n] != stamp {
                            libertySeen[n] = stamp
                            group.liberties.append(n)
                        }
                    case colour:
                        if colour == .land, landOf[n] == -1 {
                            landOf[n] = id; stack.append(n)
                        } else if colour == .sea, seaOf[n] == -1 {
                            seaOf[n] = id; stack.append(n)
                        }
                    default:
                        break
                    }
                }
            }
            group.cells.sort()
            group.liberties.sort()
            group.clueIndices.sort()
            if colour == .land { landGroups.append(group) } else { seaGroups.append(group) }
        }
        land = landGroups
        sea = seaGroups
        landGroupOf = landOf
        seaGroupOf = seaOf
    }
}

// MARK: - Rules

nonisolated enum Rules {

    /// Is `marks` a complete, correct solution of `puzzle`? Judged on the
    /// rules alone, never by comparison with `puzzle.solution` — a player's
    /// correct board is correct even if (impossibly, for a unique puzzle) it
    /// differed.
    static func isSolved(_ marks: [Mark], puzzle: Puzzle) -> Bool {
        guard !marks.contains(.unknown) else { return false }
        return violations(marks, puzzle: puzzle, requireComplete: true).isEmpty
    }

    nonisolated enum Violation: Hashable, Sendable {
        case twoClues(group: [Int])
        case oversized(group: [Int])
        case undersized(group: [Int])
        case unnumbered(group: [Int])
        case pool(corner: Int)
        case seaSplit
        case clueShaded(cell: Int)
    }

    /// Rule breaks visible on a board. With `requireComplete: false`, only
    /// breaks that no further marking could repair are reported — the
    /// in-game error display uses that mode.
    static func violations(_ marks: [Mark], puzzle: Puzzle,
                           requireComplete: Bool) -> [Violation] {
        let grid = puzzle.grid
        let clueAt = puzzle.clueIndexAt
        let groups = Groups(marks: marks, grid: grid, clueIndexAt: clueAt)
        var found: [Violation] = []

        for clue in puzzle.clues where marks[grid.index(clue.cell)] == .sea {
            found.append(.clueShaded(cell: grid.index(clue.cell)))
        }
        for g in groups.land {
            if g.clueIndices.count > 1 { found.append(.twoClues(group: g.cells)); continue }
            if let k = g.clueIndices.first {
                let value = puzzle.clues[k].value
                if g.cells.count > value { found.append(.oversized(group: g.cells)) }
                else if g.cells.count < value && (requireComplete || g.liberties.isEmpty) {
                    found.append(.undersized(group: g.cells))
                }
            } else if requireComplete || g.liberties.isEmpty {
                found.append(.unnumbered(group: g.cells))
            }
        }
        for corner in grid.poolCorners where grid.pool(at: corner).allSatisfy({ marks[$0] == .sea }) {
            found.append(.pool(corner: corner))
        }
        if groups.sea.count > 1 {
            let split = requireComplete || groups.sea.contains { $0.liberties.isEmpty }
            if split { found.append(.seaSplit) }
        }
        return found
    }
}
