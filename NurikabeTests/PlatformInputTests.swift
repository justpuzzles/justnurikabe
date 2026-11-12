import Testing
@testable import Nurikabe

/// The Mac keyboard's mapping and cursor, without synthesising events.
@Suite struct PlatformInputTests {
    @Test func arrowsMoveTheCursor() {
        #expect(BoardKey.from(keyCode: 126, characters: "", hasModifier: false) == .move(dRow: -1, dCol: 0))
        #expect(BoardKey.from(keyCode: 125, characters: "", hasModifier: false) == .move(dRow: 1, dCol: 0))
        #expect(BoardKey.from(keyCode: 123, characters: "", hasModifier: false) == .move(dRow: 0, dCol: -1))
        #expect(BoardKey.from(keyCode: 124, characters: "", hasModifier: false) == .move(dRow: 0, dCol: 1))
    }

    @Test func spaceAndReturnCycle() {
        for code: UInt16 in [49, 36, 76] {
            #expect(BoardKey.from(keyCode: code, characters: " ", hasModifier: false) == .cycle)
        }
    }

    @Test func lettersAndDeleteSetTheCell() {
        #expect(BoardKey.from(keyCode: 1, characters: "s", hasModifier: false) == .set(.sea))
        #expect(BoardKey.from(keyCode: 1, characters: "S", hasModifier: false) == .set(.sea))
        #expect(BoardKey.from(keyCode: 2, characters: "d", hasModifier: false) == .set(.land))
        #expect(BoardKey.from(keyCode: 47, characters: ".", hasModifier: false) == .set(.land))
        // Backspace is a key code (its character is U+007F), forward delete too.
        #expect(BoardKey.from(keyCode: 51, characters: "\u{7F}", hasModifier: false) == .set(.unknown))
        #expect(BoardKey.from(keyCode: 117, characters: "", hasModifier: false) == .set(.unknown))
    }

    @Test func modifiedKeysBelongToTheMenuBar() {
        // ⌘Z (undo) and ⇧⌘H (hint) must reach the menu, not the board.
        #expect(BoardKey.from(keyCode: 6, characters: "z", hasModifier: true) == nil)
        #expect(BoardKey.from(keyCode: 1, characters: "s", hasModifier: true) == nil)
        #expect(BoardKey.from(keyCode: 0, characters: "a", hasModifier: false) == nil)
    }

    @Test func cursorStaysOnTheBoard() {
        // No cursor yet: the first press lands top-left.
        #expect(BoardKey.moved(nil, dRow: 1, dCol: 0, size: 7) == 0)
        #expect(BoardKey.moved(0, dRow: -1, dCol: 0, size: 7) == 0)
        #expect(BoardKey.moved(0, dRow: 0, dCol: -1, size: 7) == 0)
        #expect(BoardKey.moved(0, dRow: 1, dCol: 1, size: 7) == 8)
        #expect(BoardKey.moved(48, dRow: 1, dCol: 1, size: 7) == 48)
        #expect(BoardKey.moved(6, dRow: 0, dCol: 1, size: 7) == 6)
    }
}
