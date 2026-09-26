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
        static let rules = "nurikabe.rulesDone.v1"
        static let lessons = "nurikabe.lessonsDone.v1"
        static let stats = "nurikabe.stats.v1"
        static let dailies = "nurikabe.dailies.v1"
    }

    private let defaults: UserDefaults

    var settings: Settings { didSet { save(settings, Key.settings) } }
    private(set) var savedGame: SavedGame?
    private(set) var completedRules: Set<RuleStep>
    private(set) var completedLessons: Set<Technique>
    private(set) var stats: [String: StatEntry]
    /// Day → solve time.
    private(set) var dailies: [String: TimeInterval]

    init(userDefaults: UserDefaults = .standard) {
        defaults = userDefaults
        settings = Self.load(Settings.self, Key.settings, userDefaults) ?? Settings()
        savedGame = Self.load(SavedGame.self, Key.savedGame, userDefaults)
        completedRules = Self.load(Set<RuleStep>.self, Key.rules, userDefaults) ?? []
        completedLessons = Self.load(Set<Technique>.self, Key.lessons, userDefaults) ?? []
        stats = Self.load([String: StatEntry].self, Key.stats, userDefaults) ?? [:]
        dailies = Self.load([String: TimeInterval].self, Key.dailies, userDefaults) ?? [:]
    }

    // MARK: Games

    func saveGame(_ game: SavedGame?) {
        savedGame = game
        if let game { save(game, Key.savedGame) } else { defaults.removeObject(forKey: Key.savedGame) }
    }

    /// Record a finished board and clear the save.
    func recordSolve(kind: GameKind, grade: Difficulty, size: BoardSize,
                     seconds: TimeInterval, hintsUsed: Int) {
        let key = Self.statKey(size, grade)
        var entry = stats[key] ?? StatEntry()
        entry.solved += 1
        if hintsUsed == 0 { entry.solvedWithoutHints += 1 }
        if entry.bestSeconds.map({ seconds < $0 }) ?? true { entry.bestSeconds = seconds }
        stats[key] = entry
        save(stats, Key.stats)
        if case .daily(let day) = kind {
            dailies[day.description] = min(dailies[day.description] ?? .infinity, seconds)
            save(dailies, Key.dailies)
        }
        saveGame(nil)
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
