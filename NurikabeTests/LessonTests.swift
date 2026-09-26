import Foundation
import Testing
@testable import Nurikabe

@Suite("Baked lesson positions")
struct LessonPositionTests {

    @Test(arguments: RuleStep.allCases.filter { $0.technique != nil })
    func rulePositionDecidesExactlyItsBlanks(rule: RuleStep) throws {
        let pos = try #require(LessonBoards.rules[rule])
        #expect(pos.technique == rule.technique)
        #expect(pos.step != nil)
        #expect(pos.targets == pos.blanks)
        #expect(!pos.blanks.isEmpty)
    }

    @Test(arguments: Technique.allCases)
    func techniqueHasThreeLowestFirstPositions(technique: Technique) throws {
        let positions = try #require(LessonBoards.techniques[technique])
        #expect(positions.count == 3)
        for pos in positions {
            #expect(pos.isLowest, "a lower technique applies first in a \(technique) lesson")
            #expect(!pos.targets.isEmpty)
            // Given marks agree with the solution, and the step's cells are blank.
            for i in pos.marks.indices where pos.marks[i] != .unknown {
                #expect((pos.marks[i] == .land) == pos.puzzle.solution[i])
            }
            #expect(pos.targets.allSatisfy { pos.marks[$0] == .unknown })
        }
    }

    @Test func firstPuzzleIsAGentleUniqueBoard() {
        var budget = 1_000_000
        #expect(BacktrackingSolver.countSolutions(puzzle: LessonBoards.firstPuzzle, limit: 2, budget: &budget) == 1)
        var solveBudget = 100_000
        #expect(LogicalSolver.solve(puzzle: LessonBoards.firstPuzzle,
                                    maxTechnique: Difficulty.gentle.techniqueCeiling,
                                    budget: &solveBudget).solved)
    }

    @Test func everyTechniqueHasProse() {
        for t in Technique.allCases {
            #expect(!TechniqueContent.name(t).isEmpty)
            #expect(!TechniqueContent.rule(t).isEmpty)
            #expect(TechniqueContent.explanation(t).count >= 2)
        }
        for r in RuleStep.allCases {
            #expect(!TechniqueContent.cards(r).isEmpty)
            #expect(!TechniqueContent.task(r).isEmpty)
        }
    }

    @Test(arguments: Technique.allCases)
    func argumentTextMentionsTheDecision(technique: Technique) throws {
        let pos = try #require(LessonBoards.techniques[technique]?.first)
        let step = try #require(pos.step)
        let text = TechniqueContent.argument(step, puzzle: pos.puzzle)
        #expect(text.contains("highlighted"))
    }
}

@Suite("Lesson session") @MainActor
struct LessonSessionTests {

    private func session(_ t: Technique = .oneClue) -> LessonSession {
        LessonSession(position: LessonBoards.techniques[t]![0])
    }

    @Test func targetsAreTheStepCellsOnly() throws {
        let s = session()
        let step = try #require(s.position.step)
        #expect(s.targets.count == step.decidedCount)
        #expect(s.targets.count < s.position.blanks.count)
    }

    @Test func correctMarksFinishTheLesson() {
        let s = session()
        for (i, mark) in s.answers {
            s.paint(i, mark)
        }
        #expect(s.isDone)
        #expect(!s.revealed)
    }

    @Test func wrongColourExplainsTheRule() throws {
        let s = session()
        let (i, answer) = try #require(s.answers.first)
        s.paint(i, answer == .sea ? .land : .sea)
        guard case .wrong(let text) = s.feedback else {
            Issue.record("expected wrong feedback, got \(s.feedback)"); return
        }
        #expect(text.contains(TechniqueContent.rule(.oneClue)))
        // Correcting it clears the complaint.
        s.paint(i, answer)
        #expect(s.feedback != .wrong(text))
    }

    @Test func tapOutsideTargetsIsRefusedWithoutChange() throws {
        let s = session()
        let outside = try #require(s.position.blanks.first { !s.targets.contains($0) })
        let before = s.marks
        s.tap(outside)
        #expect(s.feedback == .offTarget)
        #expect(s.marks == before)
    }

    @Test func tapCyclesSeaThenDotThenBlank() throws {
        let s = session()
        let i = try #require(s.targets.first)
        s.tap(i); #expect(s.marks[i] == .sea)
        s.tap(i); #expect(s.marks[i] == .land)
        s.tap(i); #expect(s.marks[i] == .unknown)
    }

    /// Review finding: taps cycle blank → sea → dot, so heading for a land
    /// answer passes through sea. That sea must not be called wrong unless
    /// it stays.
    @Test func passingThroughSeaToALandAnswerIsNotWrong() throws {
        let s = LessonSession(position: LessonBoards.techniques[.noPool]![0])
        let (i, answer) = try #require(s.answers.first { $0.value == .land })
        #expect(answer == .land)
        s.tap(i)                       // sea, on the way
        #expect(s.pending == i)
        #expect(s.feedback == .none)
        s.tap(i)                       // dot: the answer
        #expect(s.pending == nil)
        #expect(s.feedback == .done || s.feedback == .none)
        if case .wrong = s.feedback { Issue.record("a correct dot was called wrong") }
    }

    @Test func seaLeftOnALandAnswerIsWrongOnceSettled() throws {
        let s = LessonSession(position: LessonBoards.techniques[.noPool]![0])
        let (i, _) = try #require(s.answers.first { $0.value == .land })
        s.tap(i)
        s.settle()
        guard case .wrong = s.feedback else { Issue.record("expected wrong after settling"); return }
    }

    /// Review finding: fixing one target must not hide another wrong one.
    @Test func feedbackKeepsReportingAnyWrongTarget() throws {
        let pos = try #require(Technique.allCases.lazy
            .flatMap { LessonBoards.techniques[$0] ?? [] }
            .first { LessonSession(position: $0).answers.count >= 2 })
        let s = LessonSession(position: pos)
        let cells = s.answers.keys.sorted()
        let a = cells[0], b = cells[1]
        s.paint(a, s.answers[a] == .sea ? .land : .sea)
        s.paint(b, s.answers[b]!)
        guard case .wrong = s.feedback else { Issue.record("wrong verdict about \(a) was cleared"); return }
    }

    @Test func revealFillsTheAnswer() {
        let s = session(.seaEscape)
        s.reveal()
        #expect(s.isDone && s.revealed)
        #expect(s.answers.allSatisfy { s.marks[$0.key] == $0.value })
    }

    @Test(arguments: RuleStep.allCases.filter { $0.technique != nil })
    func rulePositionsAreSolvableByTheirAnswers(rule: RuleStep) {
        let s = LessonSession(position: LessonBoards.rules[rule]!)
        #expect(Set(s.answers.keys) == Set(s.position.blanks))
        for (i, m) in s.answers { s.paint(i, m) }
        #expect(s.isDone)
    }
}
