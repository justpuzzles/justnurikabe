import SwiftUI

/// Where a played board comes from.
nonisolated enum PlaySource: Hashable, Sendable {
    case random(BoardSize, Difficulty)
    case daily(DayKey)
    case practice(Technique)
    case resume
}

/// Loads a board of some kind (random, daily, practice, or the saved one) and
/// shows it. Owns the NurikabeGame for its lifetime.
struct PlayHostView: View {
    let source: PlaySource

    @Environment(ProgressStore.self) private var progress
    @Environment(PuzzleCache.self) private var cache
    @State private var game: NurikabeGame?
    @State private var generation = 0

    var body: some View {
        Group {
            if let game {
                GameView(game: game, title: title(for: game), onNext: nextAction)
                    .id(ObjectIdentifier(game))
            } else {
                VStack(spacing: 12) {
                    ProgressView()
                    Text("Drawing the chart…").font(.callout).foregroundStyle(Theme.textSoft)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Theme.ground.ignoresSafeArea())
            }
        }
        .task(id: generation) { await load() }
    }

    private var nextAction: (() -> Void)? {
        switch source {
        case .random, .practice, .resume:
            {
                if let game { nextShape = (game.size, game.grade) }
                game = nil
                generation += 1
            }
        case .daily: nil
        }
    }

    private func load() async {
        guard game == nil else { return }
        switch source {
        case .resume where generation == 0:
            if let saved = progress.savedGame { game = NurikabeGame(saved: saved); return }
            fallthrough
        case .resume:
            // "Next board" after finishing a resumed game: same size and tier.
            let (size, tier) = resumeShape
            let r = await cache.board(size: size, tier: tier)
            start(r, kind: .random(size: size, tier: tier))
        case .random(let size, let tier):
            let r = await cache.board(size: size, tier: tier)
            start(r, kind: .random(size: size, tier: tier))
        case .daily(let day):
            if let saved = progress.savedGame, saved.kind == .daily(day) {
                game = NurikabeGame(saved: saved); return
            }
            start(await PuzzleCache.daily(day), kind: .daily(day))
        case .practice(let technique):
            let r = await PuzzleCache.practice(technique, seed: UInt64.random(in: .min ... .max))
            start(r, kind: .practice(technique))
        }
    }

    /// After "Next board" on a resumed game: the same size and grade.
    @State private var nextShape: (BoardSize, Difficulty)? = nil

    private var resumeShape: (BoardSize, Difficulty) {
        let (size, grade) = nextShape ?? (.seven, .steady)
        // A 10×10 resumed game may have graded below the sizes' offered tiers.
        return (size, size.tiers.contains(grade) ? grade : size.tiers[0])
    }

    private func start(_ result: GenerationResult, kind: GameKind) {
        let g = NurikabeGame(puzzle: result.puzzle, kind: kind, grade: result.grade)
        progress.saveGame(g.snapshot)
        game = g
    }

    private func title(for game: NurikabeGame) -> String {
        switch game.kind {
        case .random(let size, _): TechniqueContent.name(size)
        case .daily(let day): "Daily · \(day.description)"
        case .practice(let t): "Practice · \(TechniqueContent.name(t))"
        }
    }
}
