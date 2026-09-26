import Foundation

/// What the one-time unlock buys. Used to give the paywall contextual copy.
nonisolated enum PaidFeature: String, CaseIterable, Sendable, Identifiable {
    case advancedLessons
    case largeBoards
    case teachingHints

    var id: String { rawValue }

    // Every sentence here is Nurikabe's own. The siblings share this type;
    // they must never share a sentence (Shikaku's 4.3(a) rejection was fed
    // by paywalls that read alike).
    var headline: String {
        switch self {
        case .advancedLessons: "The deep water"
        case .largeBoards: "Ten by ten"
        case .teachingHints: "Hints that explain"
        }
    }

    var pitch: String {
        switch self {
        case .advancedLessons:
            "The last four lessons: Only Way Out, The Sea Must Connect, Common Ground and What If. They are the arguments hard boards are built on."
        case .largeBoards:
            "The 10×10 chart, with more islands in play at once and long chains of reasoning across the sea."
        case .teachingHints:
            "During a game, the hint names the argument and draws it on your board, instead of only pointing out a mistake."
        }
    }
}

/// What the hint button may do in a game. Lessons always explain in full.
nonisolated enum HintPolicy: Sendable, Equatable {
    /// Free tier: points out wrong cells, nothing more.
    case errorsOnly
    /// The whole ladder: nudge, technique, argument, apply.
    case full
}

/// Every gating decision, as pure functions taking `unlocked:` explicitly —
/// never read a store from a view. Pinned by FeatureGateTests without
/// touching StoreKit.
nonisolated enum FeatureGate {

    /// Free: the rules chapter and the first five technique lessons — enough
    /// to solve every gentle board without help.
    static let freeLessonCeiling: Technique = .unreachable

    static func isLessonAvailable(_ technique: Technique, unlocked: Bool) -> Bool {
        unlocked || technique <= freeLessonCeiling
    }

    /// The rules chapter is never gated: nobody should pay to learn the game.
    static func isRuleAvailable(_ rule: RuleStep, unlocked: Bool) -> Bool { true }

    static func isBoardSizeAvailable(_ size: BoardSize, unlocked: Bool) -> Bool {
        unlocked || size != .ten
    }

    /// Difficulty is never gated: gating it punishes the players most likely
    /// to buy (the family's rule since Kakuro).
    static func isDifficultyAvailable(_ difficulty: Difficulty, unlocked: Bool) -> Bool { true }

    /// Practice boards follow their lesson.
    static func isPracticeAvailable(_ technique: Technique, unlocked: Bool) -> Bool {
        isLessonAvailable(technique, unlocked: unlocked)
    }

    static func hintPolicy(unlocked: Bool) -> HintPolicy {
        unlocked ? .full : .errorsOnly
    }
}
