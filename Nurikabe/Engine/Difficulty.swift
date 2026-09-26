//
//  Difficulty.swift
//  Nurikabe
//
//  Technique-based grading, the family's replacement for machine-effort
//  rating: it can say "this board teaches seaEscape", which a node count
//  cannot.
//

import Foundation

nonisolated enum Difficulty: Int, CaseIterable, Codable, Sendable, Comparable, Identifiable {
    case gentle, steady, sharp, deep, severe

    var id: Int { rawValue }

    static func < (a: Difficulty, b: Difficulty) -> Bool { a.rawValue < b.rawValue }

    /// The hardest technique the tier's boards may require. Measured
    /// 2026-09-26: no generated board is solvable with T1–T4 alone, so the
    /// ladder's first four techniques share the gentle tier with T5–T6.
    /// Deep and severe share a ceiling and are told apart by score.
    var techniqueCeiling: Technique {
        switch self {
        case .gentle: .islandEscape
        case .steady: .seaEscape
        case .sharp: .commonGround
        case .deep: .whatIf
        case .severe: .whatIf
        }
    }
}

nonisolated enum DifficultyRater {

    /// Score = Σ technique weight over the trace, per cell, so one table
    /// serves every size.
    static func score(trace: [SolverStep], size: Int) -> Double {
        let raw = trace.reduce(0) { $0 + $1.technique.weight }
        return Double(raw) / Double(size * size)
    }

    /// Tier floor from the hardest technique in the trace.
    static func floor(trace: [SolverStep]) -> Difficulty {
        guard let hardest = trace.map(\.technique).max() else { return .gentle }
        for tier in Difficulty.allCases where hardest <= tier.techniqueCeiling { return tier }
        return .deep
    }

    /// Score thresholds that can lift a grade above its technique floor.
    /// Recalibrate with NURIKABE_CALIBRATE=1 whenever generation, techniques
    /// or weights change.
    static let thresholds: [(minScore: Double, tier: Difficulty)] = [
        (3.8, .severe),
        (2.6, .deep),
        (2.2, .sharp),
        (1.8, .steady),
    ]

    static func grade(trace: [SolverStep], size: Int) -> Difficulty {
        let base = floor(trace: trace)
        let s = score(trace: trace, size: size)
        for (minScore, tier) in thresholds where s >= minScore {
            return max(base, tier)
        }
        return base
    }
}
