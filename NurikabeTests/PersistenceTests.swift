import Foundation
import Testing
@testable import Nurikabe

@Suite("Progress store") @MainActor
struct PersistenceTests {
    private let defaults: UserDefaults

    init() {
        let suite = "NurikabeTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
    }

    private func store() -> ProgressStore { ProgressStore(userDefaults: defaults) }

    @Test func settingsPersist() {
        let s = store()
        s.settings.showTimer = false
        #expect(store().settings.showTimer == false)
    }

    @Test func savedGameRoundTripsAndClearsOnSolve() {
        let s = store()
        let p = BakedPuzzles.puzzle(size: .five)
        let saved = SavedGame(kind: .random(size: .five, tier: .gentle), puzzle: p, grade: .gentle,
                              marks: p.initialMarks, elapsed: 12, hintsUsed: 1)
        s.saveGame(saved)
        #expect(store().savedGame == saved)
        s.recordSolve(kind: saved.kind, grade: .gentle, size: .five, seconds: 40, hintsUsed: 0)
        #expect(store().savedGame == nil)
    }

    @Test func statsKeepTheBestTime() {
        let s = store()
        s.recordSolve(kind: .random(size: .seven, tier: .sharp), grade: .sharp, size: .seven, seconds: 90, hintsUsed: 2)
        s.recordSolve(kind: .random(size: .seven, tier: .sharp), grade: .sharp, size: .seven, seconds: 60, hintsUsed: 0)
        s.recordSolve(kind: .random(size: .seven, tier: .sharp), grade: .sharp, size: .seven, seconds: 75, hintsUsed: 0)
        let e = store().entry(size: .seven, grade: .sharp)
        #expect(e.solved == 3)
        #expect(e.solvedWithoutHints == 2)
        #expect(e.bestSeconds == 60)
    }

    @Test func dailyStreakCountsBackFromToday() {
        let s = store()
        let today = DayKey(year: 2026, month: 10, day: 2)
        for day in [today, today.previous, today.previous.previous] {
            s.recordSolve(kind: .daily(day), grade: .steady, size: .seven, seconds: 100, hintsUsed: 0)
        }
        #expect(s.dailyStreak(today: today) == 3)
        // Before today's board is done, yesterday's streak still shows.
        #expect(s.dailyStreak(today: DayKey(year: 2026, month: 10, day: 3)) == 3)
        #expect(s.dailyStreak(today: DayKey(year: 2026, month: 10, day: 5)) == 0)
    }

    @Test func pathUnlocksInOrder() {
        let s = store()
        #expect(s.isRuleUnlocked(.islands))
        #expect(!s.isRuleUnlocked(.oneNumber))
        #expect(!s.isLessonUnlocked(.oneClue))
        #expect(s.nextPathStep == .rule(.islands))
        for rule in RuleStep.allCases { s.completeRule(rule) }
        #expect(s.isLessonUnlocked(.oneClue))
        #expect(!s.isLessonUnlocked(.twoClues))
        s.completeLesson(.oneClue)
        #expect(s.isLessonUnlocked(.twoClues))
        #expect(store().nextPathStep == .lesson(.twoClues))
    }
}
