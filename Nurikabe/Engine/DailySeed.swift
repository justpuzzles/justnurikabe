//
//  DailySeed.swift
//  Nurikabe
//
//  One board per calendar day, the same for everyone: the seed is a hash of
//  the date, never of the device or the clock time. Size and tier follow the
//  weekday so the week climbs from gentle to severe.
//

import Foundation

#if canImport(PuzzleKit)
// Absent under a bare `swiftc` harness, which compiles PuzzleKit's sources
// into the same module instead (docs/ENGINEERING.md).
import PuzzleKit
#endif

// `DayKey` lives in PuzzleKit since 1.2 (Gregorian, local midnight, Julian-day
// weekday and arithmetic). The seed prefix and the weekly tiers are
// Nurikabe's. **Never change either once shipped.**

nonisolated enum DailySeed {

    /// FNV-1a over the date string, salted with the game's name so the
    /// family's dailies never share a seed.
    /// The same bytes 1.1 hashed: `"nurikabe-daily-"` + `YYYY-MM-DD` (1.1
    /// interpolated its own `DayKey.description`, which is `isoString`).
    static func seed(for day: DayKey) -> UInt64 {
        DaySeed.seed(prefix: "nurikabe-daily-", day: day)
    }

    /// Mon gentle → Sun severe, all on 7×7 (free size, so the daily is for
    /// everyone).
    static func tier(for day: DayKey) -> Difficulty {
        switch day.weekday {
        case 2: .gentle      // Monday
        case 3: .steady
        case 4: .steady
        case 5: .sharp
        case 6: .sharp
        case 7: .deep        // Saturday
        default: .severe     // Sunday
        }
    }

    static let size: BoardSize = .seven

    static func generate(for day: DayKey, isCancelled: () -> Bool = { false }) -> GenerationResult {
        NurikabeGenerator.generate(size: size, tier: tier(for: day), seed: seed(for: day),
                                   isCancelled: isCancelled)
    }
}
