import Foundation
import Testing
@testable import Nurikabe

/// What VoiceOver hears beyond the cell labels (docs/ACCESSIBILITY.md).
@Suite("Board speech")
struct BoardSpeechTests {

    @Test func positionsAreOneBased() {
        #expect(BoardSpeech.position(Cell(row: 0, col: 4)) == "row 1, column 5")
        #expect(BoardSpeech.position(7, size: 5) == "row 2, column 3")
    }

    @Test func fewCellsAreListedManyAreSummarised() {
        let few = [Cell(row: 1, col: 1), Cell(row: 0, col: 2)]
        #expect(BoardSpeech.cells(few) == "row 1, column 3; row 2, column 2")
        let many = (0..<6).map { Cell(row: 2, col: $0) }
        #expect(BoardSpeech.cells(many) == "6 cells, rows 3 to 3, columns 1 to 6")
    }

    @Test func markNamesMatchTheTools() {
        #expect(BoardSpeech.markName(.sea) == "sea")
        #expect(BoardSpeech.markName(.land) == "dot")
        #expect(BoardSpeech.markName(.unknown) == "blank")
    }

    @Test func spokenTimeUsesWords() {
        #expect(GameView.spoken(247) == "4 minutes 7 seconds")
        #expect(GameView.spoken(3600) == "1 hour")
    }
}
