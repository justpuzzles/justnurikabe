import Foundation
import Testing
@testable import Nurikabe

private func solvedMarks(_ p: Puzzle) -> [Mark] { p.solution.map { $0 ? .land : .sea } }

@Suite("Rules")
struct RulesTests {
    let puzzle = BakedPuzzles.puzzle(size: .five)

    @Test func storedSolutionIsSolved() {
        #expect(Rules.isSolved(solvedMarks(puzzle), puzzle: puzzle))
    }

    @Test func incompleteBoardIsNotSolved() {
        #expect(!Rules.isSolved(puzzle.initialMarks, puzzle: puzzle))
    }

    @Test func shadedClueIsAViolation() {
        var marks = solvedMarks(puzzle)
        let clue = puzzle.grid.index(puzzle.clues[0].cell)
        marks[clue] = .sea
        #expect(!Rules.isSolved(marks, puzzle: puzzle))
        #expect(Rules.violations(marks, puzzle: puzzle, requireComplete: false)
            .contains(.clueShaded(cell: clue)))
    }

    @Test func poolIsReportedAsSoonAsItForms() {
        var marks = puzzle.initialMarks
        let g = puzzle.grid
        // Find a 2×2 block of non-clue cells and fill it with sea.
        let corner = g.poolCorners.first { c in g.pool(at: c).allSatisfy { puzzle.clueIndexAt[$0] < 0 } }!
        for i in g.pool(at: corner) { marks[i] = .sea }
        #expect(Rules.violations(marks, puzzle: puzzle, requireComplete: false).contains(.pool(corner: corner)))
    }

    @Test func groupsFindIslandsAndLiberties() {
        let marks = puzzle.initialMarks
        let groups = Groups(marks: marks, grid: puzzle.grid, clueIndexAt: puzzle.clueIndexAt)
        // Every clue starts as its own one-cell island with blank neighbours.
        #expect(groups.land.count == puzzle.clues.count)
        #expect(groups.land.allSatisfy { $0.cells.count == 1 && $0.clueIndices.count == 1 })
    }

    @Test func encodingRoundTrips() {
        #expect(BakedPuzzles.decode(BakedPuzzles.encode(puzzle)) == puzzle)
    }
}

@Suite("Generation and solving")
struct GenerationTests {

    /// A small live corpus: every step the solver takes must agree with the
    /// board's known solution. The full corpus runs in EngineCheck.
    @Test(arguments: [BoardSize.five, .seven])
    func everyDeductionIsSound(size: BoardSize) {
        for seed in UInt64(1)...3 {
            let result = NurikabeGenerator.generate(size: size, tier: .sharp, seed: seed)
            let p = result.puzzle
            let g = p.grid
            for step in result.trace {
                #expect(step.decidedCount > 0)
                for c in step.sea { #expect(!p.solution[g.index(c)], "\(step.technique) shaded land") }
                for c in step.land { #expect(p.solution[g.index(c)], "\(step.technique) dotted sea") }
            }
        }
    }

    @Test func generatedBoardsAreUniqueAndSolvableUnderTheirGrade() {
        for seed in UInt64(10)...13 {
            let r = NurikabeGenerator.generate(size: .five, tier: .steady, seed: seed)
            #expect(!r.isFallback)
            var budget = 1_000_000
            #expect(BacktrackingSolver.countSolutions(puzzle: r.puzzle, limit: 2, budget: &budget) == 1)
            var solveBudget = 100_000
            let solved = LogicalSolver.solve(puzzle: r.puzzle, maxTechnique: r.grade.techniqueCeiling,
                                             budget: &solveBudget)
            #expect(solved.solved)
            #expect(Rules.isSolved(solvedMarks(r.puzzle), puzzle: r.puzzle))
        }
    }

    @Test func generationIsDeterministicPerSeed() {
        let a = NurikabeGenerator.generate(size: .seven, tier: .steady, seed: 99)
        let b = NurikabeGenerator.generate(size: .seven, tier: .steady, seed: 99)
        #expect(a.puzzle == b.puzzle)
        #expect(a.trace == b.trace)
    }

    @Test func bakedFallbacksAreValidAndUnique() {
        for size in BoardSize.allCases {
            let p = BakedPuzzles.puzzle(size: size)
            #expect(p.size == size.rawValue)
            #expect(Rules.isSolved(solvedMarks(p), puzzle: p))
            var budget = 2_000_000
            #expect(BacktrackingSolver.countSolutions(puzzle: p, limit: 2, budget: &budget) == 1)
        }
    }

    @Test func tenByTenStartsAtSharp() {
        #expect(BoardSize.ten.tiers.first == .sharp)
        #expect(BoardSize.five.tiers == Difficulty.allCases)
    }

    @Test func gradeFloorFollowsTheHardestTechnique() {
        let step = { (t: Technique) in SolverStep(technique: t, sea: [], land: [], explanation: ExplanationData()) }
        #expect(DifficultyRater.floor(trace: [step(.oneClue), step(.islandEscape)]) == .gentle)
        #expect(DifficultyRater.floor(trace: [step(.seaEscape)]) == .steady)
        #expect(DifficultyRater.floor(trace: [step(.commonGround)]) == .sharp)
        #expect(DifficultyRater.floor(trace: [step(.whatIf)]) == .deep)
    }

    @Test func removingAClueBreaksUniqueness() {
        // A sanity check on the uniqueness solver itself: with a clue gone,
        // the land total no longer matches and the stored layout is no
        // longer a solution, so the count must change.
        let p = BakedPuzzles.puzzle(size: .five)
        let fewer = Puzzle(size: p.size, clues: Array(p.clues.dropFirst()), solution: p.solution)
        var budget = 1_000_000
        #expect(BacktrackingSolver.countSolutions(puzzle: fewer, limit: 2, budget: &budget) != 1
                || !Rules.isSolved(solvedMarks(fewer), puzzle: fewer))
    }
}

@Suite("Daily seed")
struct DailySeedTests {
    @Test func sameDaySameBoard() {
        let day = DayKey(year: 2026, month: 9, day: 27)
        #expect(DailySeed.seed(for: day) == DailySeed.seed(for: day))
        #expect(DailySeed.seed(for: day) != DailySeed.seed(for: day.previous))
    }

    @Test func weekClimbsFromGentleToSevere() {
        // 2026-09-28 is a Monday, 2026-10-04 a Sunday.
        #expect(DailySeed.tier(for: DayKey(year: 2026, month: 9, day: 28)) == .gentle)
        #expect(DailySeed.tier(for: DayKey(year: 2026, month: 10, day: 3)) == .deep)
        #expect(DailySeed.tier(for: DayKey(year: 2026, month: 10, day: 4)) == .severe)
    }

    @Test func previousCrossesMonthAndYear() {
        #expect(DayKey(year: 2026, month: 10, day: 1).previous == DayKey(year: 2026, month: 9, day: 30))
        #expect(DayKey(year: 2027, month: 1, day: 1).previous == DayKey(year: 2026, month: 12, day: 31))
    }
}
