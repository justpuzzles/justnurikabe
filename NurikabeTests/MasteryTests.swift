import Foundation
import Testing
@testable import Nurikabe

private func step(_ t: Technique) -> SolverStep {
    SolverStep(technique: t, sea: [], land: [], explanation: ExplanationData())
}

@Suite("Mastery rules")
struct MasteryRulesTests {

    @Test func noChainNoCredit() {
        #expect(MasteryRules.credit(for: nil) == nil)
        #expect(MasteryRules.credit(for: []) == nil)
    }

    @Test func aLeapEarnsNothing() {
        let long = Array(repeating: step(.oneClue), count: MasteryRules.maxChain + 1)
        #expect(MasteryRules.credit(for: long) == nil)
    }

    @Test func theHardestLinkIsCredited() {
        #expect(MasteryRules.credit(for: [step(.oneClue), step(.seaEscape), step(.noPool)]) == .seaEscape)
    }

    /// On every technique lesson position the chain to a target is one step
    /// of exactly that technique: the argument the lesson teaches.
    @Test(arguments: Technique.allCases)
    func chainToALessonTargetIsItsTechnique(technique: Technique) throws {
        let pos = try #require(LessonBoards.techniques[technique]?.first)
        let target = try #require(pos.targets.first)
        let chain = LogicalSolver.chain(toDecide: target, from: pos.marks,
                                        context: SolverContext(puzzle: pos.puzzle))
        #expect(chain?.count == 1)
        #expect(MasteryRules.credit(for: chain) == technique)
    }
}

@Suite("Mastery in a game") @MainActor
struct MasteryGameTests {

    /// A game on a lesson position, so the next deduction is known.
    private func game(_ t: Technique = .oneClue) -> (NurikabeGame, LessonPosition) {
        let pos = LessonBoards.techniques[t]![0]
        let g = NurikabeGame(puzzle: pos.puzzle, kind: .practice(t), grade: .gentle, marks: pos.marks)
        return (g, pos)
    }

    private func settle(_ g: NurikabeGame, until: () -> Bool) async {
        for _ in 0..<100 where !until() { try? await Task.sleep(for: .milliseconds(20)) }
    }

    @Test func anUnaidedCorrectMarkIsCredited() async {
        let (g, pos) = game()
        var credited: [Technique] = []
        g.onCredit = { credited.append($0) }
        let target = pos.targets[0]
        g.set(target, to: pos.puzzle.solution[target] ? .land : .sea)
        await settle(g) { !credited.isEmpty }
        #expect(credited == [.oneClue])
        #expect(g.creditsThisGame[.oneClue] == 1)
    }

    @Test func hintCellsNeverEarnCredit() async {
        let (g, _) = game()
        var credited: [Technique] = []
        g.onCredit = { credited.append($0) }
        for _ in 0..<4 { g.advanceHint(policy: .full) }     // nudge → apply
        #expect(!g.creditedCells.isEmpty)
        // Undo the hint and place the same cells by hand: still no credit.
        let cells = g.creditedCells
        g.undo()
        for i in cells { g.set(i, to: g.puzzle.solution[i] ? .land : .sea) }
        try? await Task.sleep(for: .milliseconds(400))
        #expect(credited.isEmpty)
    }

    @Test func undoAndRedoCannotFarmCredit() async {
        let (g, pos) = game()
        var credited: [Technique] = []
        g.onCredit = { credited.append($0) }
        let target = pos.targets[0]
        let mark: Mark = pos.puzzle.solution[target] ? .land : .sea
        g.set(target, to: mark)
        await settle(g) { credited.count == 1 }
        g.undo()
        g.set(target, to: mark)
        g.undo()
        g.redo()
        try? await Task.sleep(for: .milliseconds(400))
        #expect(credited.count == 1)
    }

    @Test func aWrongMarkEarnsNothing() async {
        let (g, pos) = game()
        var credited: [Technique] = []
        g.onCredit = { credited.append($0) }
        let target = pos.targets[0]
        g.set(target, to: pos.puzzle.solution[target] ? .sea : .land)
        try? await Task.sleep(for: .milliseconds(400))
        #expect(credited.isEmpty)
        #expect(!g.creditedCells.contains(target))
    }

    @Test func creditedCellsSurviveSaveAndRestore() {
        let (g, pos) = game()
        let target = pos.targets[0]
        g.set(target, to: pos.puzzle.solution[target] ? .land : .sea)
        let restored = NurikabeGame(saved: g.snapshot)
        #expect(restored.creditedCells.contains(target))
    }
}

@Suite("Records and saves") @MainActor
struct RecordTests {

    private func store() -> ProgressStore {
        let suite = "NurikabeTests.records.\(UUID().uuidString)"
        let d = UserDefaults(suiteName: suite)!
        d.removePersistentDomain(forName: suite)
        return ProgressStore(userDefaults: d)
    }

    @Test func firstSolveThenNewBestThenNeither() {
        let s = store()
        let kind = GameKind.random(size: .seven, tier: .sharp)
        let first = s.recordSolve(kind: kind, grade: .sharp, size: .seven, seconds: 300, hintsUsed: 0)
        #expect(first == .init(isFirst: true, isNewBest: false))
        let faster = s.recordSolve(kind: kind, grade: .sharp, size: .seven, seconds: 200, hintsUsed: 0)
        #expect(faster == .init(isFirst: false, isNewBest: true))
        let slower = s.recordSolve(kind: kind, grade: .sharp, size: .seven, seconds: 250, hintsUsed: 0)
        #expect(slower == .init(isFirst: false, isNewBest: false))
    }

    @Test func masteryCountsPersistAndCrossTheThreshold() {
        let s = store()
        for _ in 0..<MasteryRules.threshold - 1 { s.credit(.noPool) }
        #expect(!s.isMastered(.noPool))
        s.credit(.noPool)
        #expect(s.isMastered(.noPool))
    }

    /// Saves written before mastery existed have no creditedCells key.
    @Test func oldSavesStillDecode() throws {
        let p = BakedPuzzles.puzzle(size: .five)
        let saved = SavedGame(kind: .random(size: .five, tier: .gentle), puzzle: p, grade: .gentle,
                              marks: p.initialMarks, elapsed: 3, hintsUsed: 0, creditedCells: [1, 2])
        var json = try JSONSerialization.jsonObject(with: JSONEncoder().encode(saved)) as! [String: Any]
        json.removeValue(forKey: "creditedCells")
        let old = try JSONDecoder().decode(SavedGame.self, from: JSONSerialization.data(withJSONObject: json))
        #expect(old.creditedCells == nil)
        #expect(NurikabeGame(saved: old).creditedCells.isEmpty)
    }
}
