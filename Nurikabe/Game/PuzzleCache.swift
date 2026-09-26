import Foundation
import Observation

/// Generates boards off the main thread and keeps one ready per (size, tier),
/// so "New board" is usually instant. A service, not a ViewModel.
@Observable @MainActor
final class PuzzleCache {

    private var ready: [String: GenerationResult] = [:]
    private var inFlight: Set<String> = []

    private static func key(_ size: BoardSize, _ tier: Difficulty) -> String {
        "\(size.rawValue)-\(tier.rawValue)"
    }

    /// A board for (size, tier): the prefetched one if present, else a fresh
    /// generation. Refills the slot in the background either way.
    func board(size: BoardSize, tier: Difficulty) async -> GenerationResult {
        let key = Self.key(size, tier)
        if let hit = ready.removeValue(forKey: key) {
            prefetch(size: size, tier: tier)
            return hit
        }
        let result = await Self.generate(size: size, tier: tier, seed: UInt64.random(in: .min ... .max))
        prefetch(size: size, tier: tier)
        return result
    }

    func prefetch(size: BoardSize, tier: Difficulty) {
        let key = Self.key(size, tier)
        guard ready[key] == nil, !inFlight.contains(key) else { return }
        inFlight.insert(key)
        Task {
            let result = await Self.generate(size: size, tier: tier, seed: UInt64.random(in: .min ... .max))
            ready[key] = result
            inFlight.remove(key)
        }
    }

    // MARK: Off-main generation

    nonisolated static func generate(size: BoardSize, tier: Difficulty, seed: UInt64) async -> GenerationResult {
        await Task.detached(priority: .userInitiated) {
            NurikabeGenerator.generate(size: size, tier: tier, seed: seed)
        }.value
    }

    nonisolated static func daily(_ day: DayKey) async -> GenerationResult {
        await Task.detached(priority: .userInitiated) { DailySeed.generate(for: day) }.value
    }

    /// A board whose solve uses `technique`, at its lesson tier.
    nonisolated static func practice(_ technique: Technique, seed: UInt64) async -> GenerationResult {
        await Task.detached(priority: .userInitiated) {
            let size: BoardSize = technique >= .commonGround ? .seven : .five
            return NurikabeGenerator.generate(featuring: technique, size: size,
                                              tier: max(technique.lessonTier, .gentle),
                                              seed: seed).result
        }.value
    }
}
