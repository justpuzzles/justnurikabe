import SwiftUI

/// What to draw over the chart. Everything is flat cell indices.
struct BoardOverlay: Equatable {
    /// Ochre wash: the region an argument is about.
    var region: Set<Int> = []
    /// Ochre outline: the cells the player should decide.
    var targets: Set<Int> = []
    /// Vermilion outline: wrong marks, or cells of a contradiction.
    var errors: Set<Int> = []
    /// Vermilion wash: cells of a broken rule (pools, merged islands).
    var broken: Set<Int> = []
    /// whatIf: the cell being supposed, drawn with a question ring.
    var trial: Int? = nil

    static let none = BoardOverlay()
}

enum StrokeEvent: Equatable {
    case begin(Int)
    case extend(Int)
    case end
}

/// The chart. One Canvas for the drawing, one gesture for input; the parent
/// decides what a stroke means.
struct BoardView: View {
    let puzzle: Puzzle
    let marks: [Mark]
    var overlay: BoardOverlay = .none
    /// Clue indices whose island is complete and correct (numeral relaxes).
    var satisfiedClues: Set<Int> = []
    var interactive: Bool = true
    /// The solved board's sea flooding in, then its islands lifting (nil
    /// while playing, and on every lesson board).
    var flood: SeaFlood? = nil
    var onStroke: (StrokeEvent) -> Void = { _ in }
    /// VoiceOver, Switch Control and Voice Control: "Sea", "Dot", "Clear" on a
    /// cell, without cycling. Nil (lesson boards) offers none, so a lesson's
    /// own input handling can't be walked around.
    var onSet: ((Int, Mark) -> Void)? = nil

    @State private var lastIndex: Int?

    var body: some View {
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height)
            let cell = side / CGFloat(puzzle.size)
            // The clock runs only while the flood is moving.
            TimelineView(.animation(paused: flood.map { $0.isFinished(at: .now) } ?? true)) { timeline in
                Canvas { context, _ in
                    draw(in: &context, cell: cell, now: timeline.date)
                }
            }
            .frame(width: side, height: side)
            .contentShape(Rectangle())
            .gesture(interactive ? strokeGesture(cell: cell) : nil)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(accessibilitySummary)
        .accessibilityIdentifier("board")
        // The Canvas is one opaque drawing; VoiceOver gets a synthetic grid
        // of cells instead, each activatable like a tap.
        .accessibilityChildren {
            SwiftUI.Grid(horizontalSpacing: 0, verticalSpacing: 0) {
                ForEach(0..<puzzle.size, id: \.self) { r in
                    GridRow {
                        ForEach(0..<puzzle.size, id: \.self) { c in
                            cellElement(r * puzzle.size + c)
                        }
                    }
                }
            }
        }
    }

    private func cellElement(_ i: Int) -> some View {
        let clue = puzzle.clueIndexAt[i]
        let state: String
        if clue >= 0 {
            state = "number \(puzzle.clues[clue].value)" + (satisfiedClues.contains(clue) ? ", island complete" : "")
        } else {
            switch marks[i] {
            case .sea: state = "sea"
            case .land: state = "land, dotted"
            case .unknown: state = "blank"
            }
        }
        var extra: [String] = []
        if overlay.targets.contains(i) { extra.append("outlined") }
        if overlay.errors.contains(i) { extra.append("marked wrong") }
        if overlay.region.contains(i) { extra.append("highlighted") }
        let label = "Row \(i / puzzle.size + 1), column \(i % puzzle.size + 1), \(state)"
            + (extra.isEmpty ? "" : ", " + extra.joined(separator: ", "))
        return Rectangle()
            .fill(.clear)
            .accessibilityLabel(label)
            .accessibilityAddTraits(clue < 0 && interactive ? .isButton : [])
            .accessibilityHint(clue < 0 && interactive ? "Double-tap to cycle blank, sea, dot." : "")
            .accessibilityAction {
                guard interactive, clue < 0 else { return }
                onStroke(.begin(i))
                onStroke(.end)
            }
            .accessibilityActions {
                if interactive, clue < 0, let onSet {
                    if marks[i] != .sea { Button("Sea") { onSet(i, .sea) } }
                    if marks[i] != .land { Button("Dot") { onSet(i, .land) } }
                    if marks[i] != .unknown { Button("Clear") { onSet(i, .unknown) } }
                }
            }
    }

    // MARK: Input

    private func strokeGesture(cell: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .local)
            .onChanged { value in
                guard let index = index(at: value.location, cell: cell) else { return }
                if lastIndex == nil {
                    lastIndex = index
                    onStroke(.begin(index))
                } else if index != lastIndex {
                    lastIndex = index
                    onStroke(.extend(index))
                }
            }
            .onEnded { _ in
                if lastIndex != nil { onStroke(.end) }
                lastIndex = nil
            }
    }

    private func index(at point: CGPoint, cell: CGFloat) -> Int? {
        let c = Int(point.x / cell), r = Int(point.y / cell)
        guard r >= 0, c >= 0, r < puzzle.size, c < puzzle.size else { return nil }
        return r * puzzle.size + c
    }

    // MARK: Drawing

    private func draw(in context: inout GraphicsContext, cell: CGFloat, now: Date) {
        let n = puzzle.size
        let clueAt = puzzle.clueIndexAt
        func rect(_ i: Int) -> CGRect {
            CGRect(x: CGFloat(i % n) * cell, y: CGFloat(i / n) * cell, width: cell, height: cell)
        }
        let full = CGRect(x: 0, y: 0, width: cell * CGFloat(n), height: cell * CGFloat(n))

        // Paper, then sea.
        context.fill(Path(full), with: .color(Theme.land))
        for i in marks.indices where marks[i] == .sea {
            context.fill(Path(rect(i)), with: .color(Theme.sea))
        }

        // Washes: broken rules, then the argument's region.
        for i in overlay.broken {
            context.fill(Path(rect(i)), with: .color(Theme.errorWash))
        }
        for i in overlay.region {
            context.fill(Path(rect(i)), with: .color(Theme.ochreWash))
        }

        // Grid.
        var lines = Path()
        for k in 1..<n {
            let p = CGFloat(k) * cell
            lines.move(to: CGPoint(x: p, y: 0)); lines.addLine(to: CGPoint(x: p, y: full.maxY))
            lines.move(to: CGPoint(x: 0, y: p)); lines.addLine(to: CGPoint(x: full.maxX, y: p))
        }
        context.stroke(lines, with: .color(Theme.grid), lineWidth: 1)

        if let flood { drawFlood(flood, in: &context, cell: cell, now: now, lines: lines, rect: rect) }

        // Dots and numerals.
        let dotRadius = max(2.5, cell * 0.08)
        for i in marks.indices {
            let r = rect(i)
            if clueAt[i] >= 0 {
                let k = clueAt[i]
                let text = Text("\(puzzle.clues[k].value)")
                    .font(Theme.clueFont(size: cell * 0.52))
                    .foregroundStyle(satisfiedClues.contains(k) ? Theme.numeralDone : Theme.numeral)
                context.draw(text, at: CGPoint(x: r.midX, y: r.midY))
            } else if marks[i] == .land {
                let dot = CGRect(x: r.midX - dotRadius, y: r.midY - dotRadius,
                                 width: dotRadius * 2, height: dotRadius * 2)
                context.fill(Path(ellipseIn: dot), with: .color(Theme.numeral))
            }
        }

        // Outlines: targets in ochre, errors in vermilion, the trial cell ringed.
        let inset = max(1.5, cell * 0.06)
        for i in overlay.targets {
            let r = rect(i).insetBy(dx: inset, dy: inset)
            context.stroke(Path(roundedRect: r, cornerRadius: cell * 0.12),
                           with: .color(Theme.ochreRing), lineWidth: max(2, cell * 0.07))
        }
        for i in overlay.errors {
            let r = rect(i).insetBy(dx: inset, dy: inset)
            context.stroke(Path(roundedRect: r, cornerRadius: cell * 0.12),
                           with: .color(Theme.error), lineWidth: max(2, cell * 0.07))
            // A land-coloured inner ring: vermilion alone is 2.3–2.6:1 on sea.
            let inner = r.insetBy(dx: max(2, cell * 0.07), dy: max(2, cell * 0.07))
            context.stroke(Path(roundedRect: inner, cornerRadius: cell * 0.08),
                           with: .color(Theme.land), lineWidth: max(1, cell * 0.03))
        }
        if let t = overlay.trial {
            let r = rect(t).insetBy(dx: cell * 0.22, dy: cell * 0.22)
            context.stroke(Path(ellipseIn: r), with: .color(Theme.ochreRing),
                           style: StrokeStyle(lineWidth: max(2, cell * 0.06), dash: [cell * 0.08, cell * 0.06]))
        }

        // Frame.
        context.stroke(Path(full.insetBy(dx: 1, dy: 1)), with: .color(Theme.sea), lineWidth: 2)
    }

    /// The win: each sea cell fills in its turn (a pale crest growing from
    /// its centre, then the sea washing over the grid lines so the whole sea
    /// reads as one body of water); then the islands lift on a soft shadow.
    /// Reduce Motion: the same end state, crossfaded, with no crest.
    private func drawFlood(_ flood: SeaFlood, in context: inout GraphicsContext, cell: CGFloat,
                           now: Date, lines: Path, rect: (Int) -> CGRect) {
        for i in marks.indices where marks[i] == .sea {
            let p = flood.fill(i, at: now)
            guard p > 0 else { continue }
            let r = rect(i)
            context.fill(Path(r.insetBy(dx: -0.5, dy: -0.5)), with: .color(Theme.sea.opacity(p)))
            if !flood.reduceMotion, p < 1 {
                let crest = r.insetBy(dx: r.width * (1 - p) / 2, dy: r.height * (1 - p) / 2)
                context.fill(Path(roundedRect: crest, cornerRadius: crest.width * 0.3),
                             with: .color(Theme.land.opacity(0.35 * sin(.pi * p))))
            }
        }
        let lift = flood.lift(at: now)
        guard lift > 0 else { return }
        var land = Path()
        for i in marks.indices where marks[i] != .sea {
            land.addRect(rect(i).insetBy(dx: -0.5, dy: -0.5))
        }
        context.drawLayer { layer in
            layer.addFilter(.shadow(color: .black.opacity(0.4 * lift),
                                    radius: max(2, cell * 0.08) * lift, x: 0, y: max(1, cell * 0.04) * lift))
            layer.fill(land, with: .color(Theme.land))
        }
        // The islands keep their own grid.
        context.drawLayer { layer in
            layer.clip(to: land)
            layer.stroke(lines, with: .color(Theme.grid), lineWidth: 1)
        }
    }

    private var accessibilitySummary: String {
        let clueAt = puzzle.clueIndexAt
        let sea = marks.filter { $0 == .sea }.count
        let dots = marks.indices.filter { marks[$0] == .land && clueAt[$0] < 0 }.count
        let blank = marks.filter { $0 == .unknown }.count
        return "\(puzzle.size) by \(puzzle.size) board: \(puzzle.clues.count) numbers, \(sea) sea, \(dots) dots, \(blank) blank."
    }
}
