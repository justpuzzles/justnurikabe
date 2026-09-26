//
//  Technique.swift
//  Nurikabe
//
//  THE DECLARATION ORDER IS THE SOURCE OF TRUTH for five consumers: the
//  solver loop (lowest applicable technique first), difficulty weights, hint
//  escalation, the lesson sequence, and the practice menu. Reorder here and
//  everywhere follows; never introduce a second ordering.
//

import Foundation

nonisolated enum Technique: Int, CaseIterable, Codable, Sendable, Comparable, Identifiable {
    /// A 1 is a whole island: its neighbours are sea.
    case oneClue
    /// A blank touching two numbered islands is sea.
    case twoClues
    /// A finished island is walled off by sea.
    case completeIsland
    /// Three sea in a 2×2: the fourth is land.
    case noPool
    /// A blank no island can reach is sea.
    case unreachable
    /// Unfinished land with one blank neighbour grows into it.
    case islandEscape
    /// A sea patch with one blank neighbour, more sea to come, flows into it.
    case seaEscape
    /// Every completion of an island uses (land) or borders (sea) the cell.
    case commonGround
    /// One step of look-ahead: the opposite colour leads to a contradiction.
    case whatIf

    var id: Int { rawValue }

    static func < (a: Technique, b: Technique) -> Bool { a.rawValue < b.rawValue }

    /// Difficulty weight per applied step. Calibrated with
    /// NURIKABE_CALIBRATE=1; meaningless after any change to techniques,
    /// generation or weights until recalibrated.
    var weight: Int {
        switch self {
        case .oneClue: 1
        case .twoClues: 2
        case .completeIsland: 2
        case .noPool: 4
        case .unreachable: 5
        case .islandEscape: 6
        case .seaEscape: 8
        case .commonGround: 14
        case .whatIf: 24
        }
    }

    /// Techniques allowed to be absent from generated traces (their drills
    /// use hand-authored boards). Every other technique must appear in the
    /// EngineCheck generation corpus — pinned both ways by the harness.
    static let allowedAbsentFromGeneratedPuzzles: Set<Technique> = []
}

/// Structured facts for the teaching layer. The engine never holds a
/// string: TechniqueContent.swift is the only place this becomes English.
nonisolated struct ExplanationData: Codable, Sendable, Equatable {
    /// Clues the argument is about; first is the protagonist.
    var clueIndices: [Int] = []
    /// The cells the argument is built from (an island, a sea patch, a 2×2
    /// block, a completion's shared cells), drawn as the highlighted region.
    var region: [Cell] = []
    /// whatIf: the cell that was tried, and the colour tried.
    var trialCell: Cell? = nil
    var trialWasLand: Bool = false
    /// whatIf: cells involved in the contradiction the trial produced.
    var contradiction: [Cell] = []
    /// unreachable / island size facts: [clue value, cells so far] etc.
    var numbers: [Int] = []
}

/// One applied step of the logical solver.
nonisolated struct SolverStep: Codable, Sendable, Equatable {
    let technique: Technique
    /// Cells this step proves to be sea.
    let sea: [Cell]
    /// Cells this step proves to be land.
    let land: [Cell]
    let explanation: ExplanationData

    var decidedCount: Int { sea.count + land.count }
}
