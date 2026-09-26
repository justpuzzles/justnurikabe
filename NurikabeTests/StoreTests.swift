import Foundation
import Testing
@testable import Nurikabe

@Suite("Feature gate")
struct FeatureGateTests {

    @Test func freeTierTeachesTheWholeGameAndFiveLessons() {
        for rule in RuleStep.allCases { #expect(FeatureGate.isRuleAvailable(rule, unlocked: false)) }
        let free = Technique.allCases.filter { FeatureGate.isLessonAvailable($0, unlocked: false) }
        #expect(free == [.oneClue, .twoClues, .completeIsland, .noPool, .unreachable])
    }

    @Test func unlockOpensEverything() {
        #expect(Technique.allCases.allSatisfy { FeatureGate.isLessonAvailable($0, unlocked: true) })
        #expect(BoardSize.allCases.allSatisfy { FeatureGate.isBoardSizeAvailable($0, unlocked: true) })
        #expect(FeatureGate.hintPolicy(unlocked: true) == .full)
    }

    @Test func freeBoardsAndHints() {
        #expect(FeatureGate.isBoardSizeAvailable(.five, unlocked: false))
        #expect(FeatureGate.isBoardSizeAvailable(.seven, unlocked: false))
        #expect(!FeatureGate.isBoardSizeAvailable(.ten, unlocked: false))
        #expect(Difficulty.allCases.allSatisfy { FeatureGate.isDifficultyAvailable($0, unlocked: false) })
        #expect(FeatureGate.hintPolicy(unlocked: false) == .errorsOnly)
    }

    @Test func dailyIsOnAFreeSize() {
        #expect(FeatureGate.isBoardSizeAvailable(DailySeed.size, unlocked: false))
    }
}

@Suite("Entitlements") @MainActor
struct EntitlementTests {

    private func defaults() -> UserDefaults {
        let suite = "NurikabeTests.store.\(UUID().uuidString)"
        let d = UserDefaults(suiteName: suite)!
        d.removePersistentDomain(forName: suite)
        return d
    }

    @Test func ownedUnlocks() async {
        let store = EntitlementStore(userDefaults: defaults(), source: PreviewEntitlementSource(owned: true))
        await store.refresh()
        #expect(store.isUnlocked)
    }

    @Test func indeterminateNeverDowngradesACachedUnlock() async {
        let d = defaults()
        d.set(true, forKey: "nurikabe.entitlement.v1")
        let store = EntitlementStore(userDefaults: d, source: PreviewEntitlementSource(owned: nil))
        await store.refresh()
        #expect(store.isUnlocked)
    }

    @Test func authoritativeFalseDowngrades() async {
        let d = defaults()
        d.set(true, forKey: "nurikabe.entitlement.v1")
        let store = EntitlementStore(userDefaults: d, source: PreviewEntitlementSource(owned: false))
        await store.refresh()
        #expect(!store.isUnlocked)
    }

    @Test func productionSourceCanReportIndeterminate() throws {
        // Without a nil path the never-downgrade contract is dead code on a
        // device (it shipped that way in Kakuro build 1).
        let text = try String(contentsOf: sourceFile("Store/EntitlementStore.swift"), encoding: .utf8)
        #expect(text.contains("return nil"))
    }

    @Test func screenshotUnlockExistsOnlyInDebug() throws {
        let text = try String(contentsOf: sourceFile("App/NurikabeApp.swift"), encoding: .utf8)
        let flagUse = try #require(text.range(of: "arguments.contains(Self.screenshotUnlockFlag)"))
        let before = text[..<flagUse.lowerBound]
        let lastIf = try #require(before.range(of: "#if DEBUG", options: .backwards))
        let lastEnd = before.range(of: "#endif", options: .backwards)
        #expect(lastEnd == nil || lastEnd!.lowerBound < lastIf.lowerBound,
                "the unlock flag must be read inside #if DEBUG")
    }

    private func sourceFile(_ path: String) -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()      // NurikabeTests
            .deletingLastPathComponent()      // repo root
            .appendingPathComponent("Nurikabe")
            .appendingPathComponent(path)
    }
}
