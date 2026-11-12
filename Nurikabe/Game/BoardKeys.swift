import SwiftUI
#if os(macOS)
import AppKit
#endif

/// What a key means on the chart (Mac). Built from key codes and characters,
/// so the mapping is testable without synthesising events.
nonisolated enum BoardKey: Equatable, Sendable {
    /// Arrows: move the cursor one cell.
    case move(dRow: Int, dCol: Int)
    /// Space or Return: what a click does (blank → sea → dot → blank).
    case cycle
    /// S, D (or .), Delete: set the cell outright, as VoiceOver's actions do.
    case set(Mark)

    static func from(keyCode: UInt16, characters: String, hasModifier: Bool) -> BoardKey? {
        guard !hasModifier else { return nil }   // ⌘Z, ⇧⌘H belong to the menu bar
        switch keyCode {
        case 126: return .move(dRow: -1, dCol: 0)
        case 125: return .move(dRow: 1, dCol: 0)
        case 123: return .move(dRow: 0, dCol: -1)
        case 124: return .move(dRow: 0, dCol: 1)
        case 49, 36, 76: return .cycle             // space, return, keypad enter
        // Backspace arrives as U+007F, not SwiftUI's U+0008 (Just Kakuro), so
        // both delete keys are matched by code.
        case 51, 117: return .set(.unknown)
        default: break
        }
        switch characters.lowercased() {
        case "s": return .set(.sea)
        case "d", ".": return .set(.land)
        default: return nil
        }
    }

    /// The cursor after a move on a `size`×`size` board, kept on the board.
    /// With no cursor yet, the first press puts it on the top-left cell.
    static func moved(_ cursor: Int?, dRow: Int, dCol: Int, size: Int) -> Int {
        guard let cursor else { return 0 }
        let row = min(max(cursor / size + dRow, 0), size - 1)
        let col = min(max(cursor % size + dCol, 0), size - 1)
        return row * size + col
    }
}

#if os(macOS)
extension View {
    /// Routes chart keys to `handle` while the board is on screen. Read from
    /// the window's event stream, not SwiftUI focus: focus set on appear lands
    /// before the window is key and clicks never restore it, so a focus-based
    /// board drops every key (Numeriqo's first Mac build).
    func macBoardKeys(_ handle: @escaping (BoardKey) -> Bool) -> some View {
        modifier(BoardKeyMonitor(handle: handle))
    }
}

private struct BoardKeyMonitor: ViewModifier {
    let handle: (BoardKey) -> Bool
    @State private var monitor: Any?

    func body(content: Content) -> some View {
        content
            .onAppear {
                guard monitor == nil else { return }
                monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
                    if event.window?.firstResponder is NSTextView { return event }
                    let flags = event.modifierFlags.intersection([.command, .control, .option])
                    guard let key = BoardKey.from(keyCode: event.keyCode,
                                                  characters: event.charactersIgnoringModifiers ?? "",
                                                  hasModifier: !flags.isEmpty)
                    else { return event }
                    return MainActor.assumeIsolated { handle(key) } ? nil : event
                }
            }
            .onDisappear {
                if let monitor { NSEvent.removeMonitor(monitor) }
                monitor = nil
            }
    }
}
#endif
