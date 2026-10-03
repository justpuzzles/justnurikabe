import SwiftUI

/// Everything VoiceOver says about the chart beyond the cell labels: what a
/// move did, and where a hint points. Hint text says "the highlighted
/// island"; speech has to name it.
enum BoardSpeech {

    static func position(_ cell: Cell) -> String {
        "row \(cell.row + 1), column \(cell.col + 1)"
    }

    static func position(_ index: Int, size: Int) -> String {
        position(Cell(row: index / size, col: index % size))
    }

    static func markName(_ mark: Mark) -> String {
        switch mark {
        case .sea: "sea"
        case .land: "dot"
        case .unknown: "blank"
        }
    }

    /// "Row 2, column 3: sea. The 4 is complete." Newly finished islands and
    /// newly broken rules are the consequences sight would catch.
    static func moveResult(index: Int, mark: Mark, puzzle: Puzzle,
                           newlySatisfied: Set<Int>, newBreak: String?) -> String {
        var parts = ["\(position(index, size: puzzle.size).capitalizedFirst): \(markName(mark))"]
        parts += newlySatisfied.sorted().map { "The \(puzzle.clues[$0].value) is complete" }
        if let newBreak { parts.append(newBreak) }
        return parts.joined(separator: ". ")
    }

    /// Cells, listed when few, summarised as a span when many.
    static func cells(_ cells: [Cell]) -> String {
        let sorted = cells.sorted()
        if sorted.count <= 5 { return sorted.map(position).joined(separator: "; ") }
        guard let rows = sorted.map(\.row).minMax, let cols = sorted.map(\.col).minMax else { return "" }
        return "\(sorted.count) cells, rows \(rows.0 + 1) to \(rows.1 + 1), columns \(cols.0 + 1) to \(cols.1 + 1)"
    }

    /// The hint card's words plus where they point.
    static func spokenHint(_ hint: HintState, text: String) -> String {
        switch hint {
        case .mistakes:
            return text
        case .nudge(let step), .technique(let step):
            let region = step.explanation.region
            return region.isEmpty ? text : "\(text) Highlighted: \(cells(region))."
        case .argument(let step):
            var parts = [text]
            if !step.sea.isEmpty { parts.append("Sea: \(cells(step.sea)).") }
            if !step.land.isEmpty { parts.append("Dots: \(cells(step.land)).") }
            return parts.joined(separator: " ")
        default:
            return text
        }
    }

    static func announce(_ text: String) {
        AccessibilityNotification.Announcement(text).post()
    }
}

private extension Array where Element == Int {
    var minMax: (Int, Int)? {
        guard let lo = self.min(), let hi = self.max() else { return nil }
        return (lo, hi)
    }
}

extension String {
    var capitalizedFirst: String { prefix(1).uppercased() + dropFirst() }
}
