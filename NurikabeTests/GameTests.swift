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

    /// Review finding: the solving tap removes the gesture, so endStroke may
    /// never run. The clock must stop on the solve itself.
    @Test func clockStopsWhenTheBoardIsSolvedMidStroke() {
        let g = game()
        let t0 = Date()
        g.resumeClock(at: t0)
        let blanks = g.marks.indices.filter { g.marks[$0] == .unknown }
        for i in blanks.dropLast() { g.set(i, to: g.puzzle.solution[i] ? .land : .sea) }
        let last = blanks.last!
        // Cycle the last cell to its answer with begin only, no end.
        while g.marks[last] != (g.puzzle.solution[last] ? .land : .sea) {
            g.beginStroke(at: last)
        }
        #expect(g.isSolved)
        let frozen = g.elapsed(at: Date())
        #expect(g.elapsed(at: Date().addingTimeInterval(60)) == frozen)
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

    /// Review finding: pressing Hint again on the same mistakes is not new help.
    @Test func repeatedMistakesCheckCountsOnce() {
        let g = game()
        let i = g.marks.firstIndex(of: .unknown)!
        g.set(i, to: g.puzzle.solution[i] ? .sea : .land)
        for _ in 0..<4 { g.advanceHint(policy: .errorsOnly) }
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

@Suite("Sea flood")
struct SeaFloodTests {

    private func marks(_ rows: [String]) -> [Mark] {
        rows.joined().map { $0 == "#" ? Mark.sea : .land }
    }

    @Test func floodStepsThroughTheSeaFromTheBorder() {
        // A sea ring around one island; the inner arm is two steps in.
        let m = marks(["####",
                       "#..#",
                       "#.##",
                       "####"])
        let d = SeaFlood.distances(marks: m, size: 4)
        #expect(d[0] == 0 && d[3] == 0 && d[15] == 0)
        #expect(d[5] == -1 && d[9] == -1)
        #expect(d[10] == 1)     // (2,2) touches border sea at (2,3) and (3,2)
    }

    @Test func aSeaOffTheBorderStartsNearestTheEdge() {
        let m = marks(["....",
                       ".##.",
                       ".#..",
                       "...."])
        let d = SeaFlood.distances(marks: m, size: 4)
        #expect(d[5] == 0 && d[6] == 0 && d[9] == 0)
        #expect(d.filter { $0 >= 0 }.count == 3)
    }

    @Test func cellsFillInBorderOrderAndTheLiftComesLast() {
        let m = marks(["####",
                       "#..#",
                       "#.##",
                       "####"])
        let start = Date(timeIntervalSinceReferenceDate: 0)
        let f = SeaFlood(marks: m, size: 4, start: start, reduceMotion: false)
        let early = start.addingTimeInterval(0.1)
        #expect(f.fill(0, at: early) > f.fill(10, at: early))
        #expect(f.lift(at: start.addingTimeInterval(SeaFlood.stagger + SeaFlood.cellFill)) == 0)
        let end = start.addingTimeInterval(f.duration)
        #expect(f.isFinished(at: end))
        #expect(m.indices.allSatisfy { f.fill($0, at: end) == 1 })
        #expect(f.lift(at: end) == 1)
        #expect(f.duration <= 1.2)
    }

    @Test func reduceMotionIsOneCrossfadeWithNoStagger() {
        let m = marks(["####", "#..#", "#.##", "####"])
        let start = Date(timeIntervalSinceReferenceDate: 0)
        let f = SeaFlood(marks: m, size: 4, start: start, reduceMotion: true)
        let mid = start.addingTimeInterval(SeaFlood.crossfade / 2)
        #expect(f.fill(0, at: mid) == f.fill(10, at: mid))
        #expect(f.lift(at: mid) == f.fill(0, at: mid))
        #expect(SeaFlood.settled(marks: m, size: 4).isFinished(at: .now))
    }
}
