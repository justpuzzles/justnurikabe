//
//  Mastery.swift
//  Nurikabe
//
//  What earns mastery, as pure rules (MasteryTests pins them). The family's
//  rule: a technique is credited only for a deduction the player made
//  unaided, checked against the solver's own reasoning, never for a hint and
//  never twice for the same cell (undo and redo cannot farm credit).
//

import Foundation

nonisolated enum MasteryRules {

    /// Credited deductions that master a technique.
    static let threshold = 5

    /// A move the solver needs more steps than this to justify was a leap
    /// (or a guess), not an argument, and earns nothing.
    static let maxChain = 4

    /// The technique a correct, unaided mark earns: the hardest link of the
    /// solver's chain to that cell (by weight, ties to the later technique).
    static func credit(for chain: [SolverStep]?) -> Technique? {
        guard let chain, !chain.isEmpty, chain.count <= maxChain else { return nil }
        return chain.map(\.technique).max { a, b in
            a.weight != b.weight ? a.weight < b.weight : a < b
        }
    }

    /// The credit for each newly marked cell of a stroke. `before` is the
    /// board as it stood before the stroke with wrong marks cleared (the
    /// player's real knowledge); `cells` are the cells the stroke marked
    /// correctly for the first time.
    static func credits(for cells: [Int], before: [Mark], context: SolverContext) -> [Technique] {
        cells.prefix(12).compactMap { cell in
            credit(for: LogicalSolver.chain(toDecide: cell, from: before, context: context))
        }
    }
}
