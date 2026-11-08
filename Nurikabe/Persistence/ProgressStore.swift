import Foundation
import Observation

/// What kind of board a game is, for saving, stats and the finish screen.
nonisolated enum GameKind: Codable, Hashable, Sendable {
    case random(size: BoardSize, tier: Difficulty)
    case daily(DayKey)
    /// A board generated so one technique appears in its solve.
    case practice(Technique)
}

/// An in-progress board, saved on every change.
nonisolated struct SavedGame: Codable, Equatable, Sendable {
    var kind: GameKind
    var puzzle: Puzzle
    var grade: Difficulty
    var marks: [Mark]
    var elapsed: TimeInterval
    var hintsUsed: Int
    /// Cells that can no longer earn mastery (already credited, or filled by
    /// a hint). Optional so saves from before mastery still decode.
    var creditedCells: [Int]? = nil
}

nonisolated struct Settings: Codable, Equatable, Sendable {
    var hapticsEnabled = true
    /// Mark broken rules (pools, merged islands, cut-off sea) as they appear.
    var showRuleBreaks = true
    var showTimer = true
}

/// Per (size, tier) record.
nonisolated struct StatEntry: Codable, Equatable, Sendable {
    var solved = 0
    var solvedWithoutHints = 0
    var bestSeconds: TimeInterval? = nil
}

/// Everything the app remembers. UserDefaults + Codable under versioned keys;
/// `init(userDefaults:)` is the test seam. Every mutation persists
/// immediately — saving only on scene-phase changes is how progress gets lost.
@Observable @MainActor
final class ProgressStore {

    private enum Key {
        static let settings = "nurikabe.settings.v1"
        static let savedGame = "nurikabe.savedGame.v1"
        static let savedDaily = "nurikabe.savedDaily.v1"
        static let savedPractice = "nurikabe.savedPractice.v1"
        static let rules = "nurikabe.rulesDone.v1"
        static let lessons = "nurikabe.lessonsDone.v1"
        static let stats = "nurikabe.stats.v1"
        static let dailies = "nurikabe.dailies.v1"
        static let mastery = "nurikabe.mastery.v1"
    }

    private let defaults: UserDefaults

    var settings: Settings { didSet { save(settings, Key.settings) } }
    /// The main game in progress (random boards) — what Continue resumes.
    private(set) var savedGame: SavedGame?
    /// A daily in progress. Its own slot, so opening the daily never throws
    /// away the main game (and vice versa).
    private(set) var savedDaily: SavedGame?
    /// A practice board in progress, likewise separate.
    private(set) var savedPractice: SavedGame?
    private(set) var completedRules: Set<RuleStep>
    private(set) var completedLessons: Set<Technique>
    private(set) var stats: [String: StatEntry]
    /// Day → solve time.
    private(set) var dailies: [String: TimeInterval]
    /// Technique → credited unaided deductions (see MasteryRules).
    private(set) var mastery: [Technique: Int]

    init(userDefaults: UserDefaults = .standard) {
        defaults = userDefaults
        settings = Self.load(Settings.self, Key.settings, userDefaults) ?? Settings()
        savedGame = Self.load(SavedGame.self, Key.savedGame, userDefaults)
        savedDaily = Self.load(SavedGame.self, Key.savedDaily, userDefaults)
        savedPractice = Self.load(SavedGame.self, Key.savedPractice, userDefaults)
        completedRules = Self.load(Set<RuleStep>.self, Key.rules, userDefaults) ?? []
        completedLessons = Self.load(Set<Technique>.self, Key.lessons, userDefaults) ?? []
        stats = Self.load([String: StatEntry].self, Key.stats, userDefaults) ?? [:]
        dailies = Self.load([String: TimeInterval].self, Key.dailies, userDefaults) ?? [:]
        mastery = Self.load([Technique: Int].self, Key.mastery, userDefaults) ?? [:]
    }

    // MARK: Games

    /// Save a game into the slot its kind belongs to.
    func saveGame(_ game: SavedGame) {
        switch game.kind {
        case .random: savedGame = game; save(game, Key.savedGame)
        case .daily: savedDaily = game; save(game, Key.savedDaily)
        case .practice: savedPractice = game; save(game, Key.savedPractice)
        }
    }

    /// Clear the slot a kind of game uses.
    func clearGame(kind: GameKind) {
        switch kind {
        case .random: savedGame = nil; defaults.removeObject(forKey: Key.savedGame)
        case .daily: savedDaily = nil; defaults.removeObject(forKey: Key.savedDaily)
        case .practice: savedPractice = nil; defaults.removeObject(forKey: Key.savedPractice)
        }
    }

    /// What a finished board meant for the records.
    nonisolated struct SolveRecord: Equatable, Sendable {
        /// The first solve at this size and grade.
        let isFirst: Bool
        /// Faster than every earlier solve at this size and grade.
        let isNewBest: Bool
    }

    /// Record a finished board and clear the save.
    ///
    /// Only fresh boards feed the records. A daily solved again keeps its
    /// first time and is not another solve (the streak and best times would
    /// otherwise be farmable), and a practice board, generated to show one
    /// technique at whatever grade it lands, never sets a size-and-grade best.
    @discardableResult
    func recordSolve(kind: GameKind, grade: Difficulty, size: BoardSize,
                     seconds: TimeInterval, hintsUsed: Int) -> SolveRecord {
        let counts: Bool
        switch kind {
        case .random: counts = true
        case .daily(let day): counts = !isDailySolved(day)
        case .practice: counts = false
        }
        guard counts else {
            clearGame(kind: kind)
            return SolveRecord(isFirst: false, isNewBest: false)
        }
        let key = Self.statKey(size, grade)
        var entry = stats[key] ?? StatEntry()
        let previousBest = entry.bestSeconds
        let record = SolveRecord(isFirst: entry.solved == 0,
                                 isNewBest: previousBest.map { seconds < $0 } ?? false)
        entry.solved += 1
        if hintsUsed == 0 { entry.solvedWithoutHints += 1 }
        if previousBest.map({ seconds < $0 }) ?? true { entry.bestSeconds = seconds }
        stats[key] = entry
        save(stats, Key.stats)
        if case .daily(let day) = kind {
            dailies[day.description] = seconds
            save(dailies, Key.dailies)
        }
        clearGame(kind: kind)
        return record
    }

    // MARK: Mastery

    func credit(_ technique: Technique) {
        mastery[technique, default: 0] += 1
        save(mastery, Key.mastery)
    }

    func masteryCount(_ technique: Technique) -> Int { mastery[technique] ?? 0 }

    func isMastered(_ technique: Technique) -> Bool {
        masteryCount(technique) >= MasteryRules.threshold
    }

    func entry(size: BoardSize, grade: Difficulty) -> StatEntry {
        stats[Self.statKey(size, grade)] ?? StatEntry()
    }

    var totalSolved: Int { stats.values.reduce(0) { $0 + $1.solved } }

    static func statKey(_ size: BoardSize, _ grade: Difficulty) -> String {
        "\(size.rawValue)-\(grade.rawValue)"
    }

    // MARK: Dailies

    func isDailySolved(_ day: DayKey) -> Bool { dailies[day.description] != nil }

    /// Consecutive solved days ending today (or yesterday, so a streak is not
    /// shown as broken before today's board is done).
    func dailyStreak(today: DayKey = .today()) -> Int {
        var day = isDailySolved(today) ? today : today.previous
        var count = 0
        while isDailySolved(day) {
            count += 1
            day = day.previous
        }
        return count
    }

    // MARK: Learning path

    func completeRule(_ rule: RuleStep) {
        guard !completedRules.contains(rule) else { return }
        completedRules.insert(rule)
        save(completedRules, Key.rules)
    }

    func completeLesson(_ technique: Technique) {
        guard !completedLessons.contains(technique) else { return }
        completedLessons.insert(technique)
        save(completedLessons, Key.lessons)
    }

    var rulesFinished: Bool { completedRules.isSuperset(of: RuleStep.allCases) }

    /// The path unlocks in order: every rule step, then each technique once
    /// the one before it is done.
    func isRuleUnlocked(_ rule: RuleStep) -> Bool {
        guard let index = RuleStep.allCases.firstIndex(of: rule), index > 0 else { return true }
        return completedRules.contains(RuleStep.allCases[index - 1])
    }

    func isLessonUnlocked(_ technique: Technique) -> Bool {
        guard rulesFinished else { return false }
        guard technique.rawValue > 0,
              let previous = Technique(rawValue: technique.rawValue - 1) else { return true }
        return completedLessons.contains(previous)
    }

    /// The first unfinished step of the path, for Home's "continue learning".
    var nextPathStep: PathStep? {
        if let rule = RuleStep.allCases.first(where: { !completedRules.contains($0) }) {
            return .rule(rule)
        }
        if let technique = Technique.allCases.first(where: { !completedLessons.contains($0) }) {
            return .lesson(technique)
        }
        return nil
    }

    // MARK: Plumbing

    private func save<T: Encodable>(_ value: T, _ key: String) {
        if let data = try? JSONEncoder().encode(value) { defaults.set(data, forKey: key) }
    }

    private static func load<T: Decodable>(_ type: T.Type, _ key: String, _ defaults: UserDefaults) -> T? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }
}

/// One stop on the learning path.
nonisolated enum PathStep: Hashable, Sendable {
    case rule(RuleStep)
    case lesson(Technique)
}
