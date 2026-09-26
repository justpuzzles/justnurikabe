import Foundation

/// Where the hint ladder stands. Each rung shows more; the last applies.
nonisolated enum HintState: Equatable, Sendable {
    /// Some marks are wrong. Always the first thing a hint says: the solver
    /// cannot argue from a board that contradicts itself.
    case mistakes([Int])
    /// No mistakes, and the free tier stops here.
    case noMistakes
    /// Rung 1: look here (the argument's region, no words about why).
    case nudge(SolverStep)
    /// Rung 2: the technique's name and rule.
    case technique(SolverStep)
    /// Rung 3: the cells it decides, and the argument in full.
    case argument(SolverStep)
    /// Rung 4: do it. Transient — the game applies it and clears the hint.
    case apply(SolverStep)
    /// Nothing the ladder can find (should not happen on shipped boards).
    case stuck

    var step: SolverStep? {
        switch self {
        case .nudge(let s), .technique(let s), .argument(let s), .apply(let s): s
        default: nil
        }
    }

    /// A hint "counts" once per new piece of help: the first rung of a new
    /// step, and a mistakes check. Climbing the same step's ladder is free.
    func countsAsHint(comparedTo previous: HintState?) -> Bool {
        switch self {
        case .mistakes: return true
        case .nudge: return previous?.step != step
        default: return false
        }
    }
}

nonisolated enum HintEngine {

    static func next(after current: HintState?, marks: [Mark], context: SolverContext,
                     wrong: [Int], policy: HintPolicy) -> HintState? {
        if !wrong.isEmpty { return .mistakes(wrong) }
        guard policy == .full else { return .noMistakes }

        switch current {
        case .nudge(let s)?: return .technique(s)
        case .technique(let s)?: return .argument(s)
        case .argument(let s)?: return .apply(s)
        default:
            guard let step = LogicalSolver.nextStep(context: context, marks: marks) else { return .stuck }
            return .nudge(step)
        }
    }
}
