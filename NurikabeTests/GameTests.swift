import Foundation
import Testing
@testable import Nurikabe

@Suite("Game") @MainActor
struct GameTests {

    private func game() -> NurikabeGame {
        NurikabeGame(puzzle: BakedPuzzles.puzzle(size: .five), kind: .random(size: .five, tier: .steady),
                     grade: .steady)
    }

    private func firstBlank(_ g: NurikabeGame) -> Int { g.marks.firstIndex(of: .unknown)! }

    @Test func tapCyclesBlankSeaDotBlank() {
        let g = game()
        let i = firstBlank(g)
        for expected in [Mark.sea, .land, .unknown] {
            g.beginStroke(at: i); g.endStroke()
            #expect(g.marks[i] == expected)
        }
    }

    @Test func clueCellsIgnoreInput() {
        let g = game()
        let clue = g.grid.index(g.puzzle.clues[0].cell)
        g.beginStroke(at: clue); g.endStroke()
        #expect(g.marks[clue] == .land)
        #expect(!g.canUndo)
    }

    @Test func aStrokePaintsItsFirstMarkAndIsOneUndoStep() {
        let g = game()
        let blanks = g.marks.indices.filter { g.marks[$0] == .unknown }.prefix(3)
        g.beginStroke(at: blanks.first!)
        for i in blanks.dropFirst() { g.extendStroke(to: i) }
        g.endStroke()
        #expect(blanks.allSatisfy { g.marks[$0] == .sea })
        g.undo()
        #expect(blanks.allSatisfy { g.marks[$0] == .unknown })
        #expect(!g.canUndo)
        g.redo()
        #expect(blanks.allSatisfy { g.marks[$0] == .sea })
    }

    @Test func solvingDetectsTheWinAndStopsInput() {
        let g = game()
        for i in g.marks.indices where g.marks[i] == .unknown {
            g.set(i, to: g.puzzle.solution[i] ? .land : .sea)
        }
        #expect(g.isSolved)
        #expect(!g.canUndo)
        let before = g.marks
        g.beginStroke(at: 0); g.endStroke()
        #expect(g.marks == before)
    }

    @Test func wrongCellsCompareWithTheSolution() {
        let g = game()
        let i = firstBlank(g)
        g.set(i, to: g.puzzle.solution[i] ? .sea : .land)
        #expect(g.wrongCells == [i])
        g.clearWrongCells()
        #expect(g.wrongCells.isEmpty)
    }

    @Test func restartClearsMarksButKeepsClues() {
        let g = game()
        g.set(firstBlank(g), to: .sea)
        g.restart()
        #expect(g.marks == g.puzzle.initialMarks)
        #expect(g.canUndo)
    }

    @Test func clockAccumulatesOnlyWhileRunning() {
        let g = game()
        let t0 = Date(timeIntervalSince1970: 1000)
        g.resumeClock(at: t0)
        g.pauseClock(at: t0.addingTimeInterval(30))
        #expect(g.elapsed(at: t0.addingTimeInterval(500)) == 30)
    }

    @Test func snapshotRoundTrips() {
        let g = game()
        g.set(firstBlank(g), to: .sea)
        let restored = NurikabeGame(saved: g.snapshot)
        #expect(restored.marks == g.marks)
        #expect(restored.puzzle == g.puzzle)
        #expect(restored.kind == g.kind)
    }
}

@Suite("Hint ladder") @MainActor
struct HintTests {

    private func game() -> NurikabeGame {
        NurikabeGame(puzzle: BakedPuzzles.puzzle(size: .five), kind: .random(size: .five, tier: .steady),
                     grade: .steady)
    }

    @Test func climbsNudgeTechniqueArgumentThenApplies() {
        let g = game()
        g.advanceHint(policy: .full)
        guard case .nudge(let step)? = g.hint else { Issue.record("expected nudge"); return }
        g.advanceHint(policy: .full)
        #expect(g.hint == .technique(step))
        g.advanceHint(policy: .full)
        #expect(g.hint == .argument(step))
        let before = g.marks
        g.advanceHint(policy: .full)
        #expect(g.hint == nil)
        #expect(g.marks != before)
        #expect(g.wrongCells.isEmpty, "an applied hint must never be wrong")
        #expect(g.hintsUsed == 1, "climbing one step's ladder counts once")
    }

    @Test func mistakesComeFirstAndCount() {
        let g = game()
        let i = g.marks.firstIndex(of: .unknown)!
        g.set(i, to: g.puzzle.solution[i] ? .sea : .land)
        g.advanceHint(policy: .full)
        #expect(g.hint == .mistakes([i]))
        #expect(g.hintsUsed == 1)
    }

    @Test func freeTierStopsAtTheMistakesCheck() {
        let g = game()
        g.advanceHint(policy: .errorsOnly)
        #expect(g.hint == .noMistakes)
        #expect(g.marks == g.puzzle.initialMarks)
    }

    @Test func anyMarkResetsTheLadder() {
        let g = game()
        g.advanceHint(policy: .full)
        #expect(g.hint != nil)
        g.beginStroke(at: g.marks.firstIndex(of: .unknown)!); g.endStroke()
        #expect(g.hint == nil)
    }

    @Test func hintsAloneSolveTheBoard() {
        let g = game()
        var presses = 0
        while !g.isSolved && presses < 500 {
            g.advanceHint(policy: .full)
            presses += 1
        }
        #expect(g.isSolved)
    }
}
