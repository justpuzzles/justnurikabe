import SwiftUI

/// The "Just Nurikabe" lockup, in paper on the sea band.
///
/// Family rule: every "Just …" app draws its puzzle into its name (Kakuro's
/// clue diagonal, Hashi's bridge, Shikaku's drag-line dash). Nurikabe's is the
/// island strip under the name: a row of sea with three small islands in it,
/// the puzzle in one line. See docs/DESIGN.md.
struct Wordmark: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(verbatim: "just")
                .font(.system(.title3, weight: .medium).width(.expanded))
                .foregroundStyle(Theme.bandSoft)
            Text(verbatim: "NURIKABE")
                .font(.system(.largeTitle, weight: .bold).width(.expanded))
                .tracking(3)
                .foregroundStyle(Theme.bandText)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            IslandStrip()
                .padding(.top, 6)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Just Nurikabe")
        .accessibilityAddTraits(.isHeader)
    }
}

/// One row of a Nurikabe board: sea cells drawn as open squares, islands as
/// paper cells, each island's first cell carrying its size.
struct IslandStrip: View {
    /// `#` sea, `.` land. Islands of 2, 1 and 3, never touching.
    var pattern = "##..#.##...##"
    @ScaledMetric(relativeTo: .title3) private var scaledCell: CGFloat = 17
    /// Decoration, not content: it grows a little with Dynamic Type but is
    /// capped, because a fixed-width strip wider than the screen would push
    /// the whole Home layout off the left edge (seen at AX sizes).
    private var cell: CGFloat { min(scaledCell, 22) }

    var body: some View {
        let cells = Array(pattern)
        Canvas { context, size in
            let gap: CGFloat = 3
            let side = cell - gap
            var i = 0
            while i < cells.count {
                let x = CGFloat(i) * cell
                let rect = CGRect(x: x, y: 0, width: side, height: side)
                if cells[i] == "#" {
                    context.stroke(Path(roundedRect: rect.insetBy(dx: 0.75, dy: 0.75), cornerRadius: side * 0.18),
                                   with: .color(Theme.bandSoft.opacity(0.45)), lineWidth: 1.5)
                    i += 1
                    continue
                }
                // An island: its length, drawn on its first cell.
                var length = 0
                while i + length < cells.count, cells[i + length] == "." { length += 1 }
                for k in 0..<length {
                    let r = CGRect(x: CGFloat(i + k) * cell, y: 0, width: side, height: side)
                    context.fill(Path(roundedRect: r, cornerRadius: side * 0.18), with: .color(Theme.bandText))
                }
                let label = Text("\(length)")
                    .font(.system(size: side * 0.68, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.band)
                context.draw(label, at: CGPoint(x: rect.midX, y: rect.midY))
                i += length
            }
        }
        .frame(width: CGFloat(cells.count) * cell, height: cell)
        .accessibilityHidden(true)
    }
}

/// The sea band behind Home's header: the chart's sea with a faint graticule,
/// opaque (the family never uses translucency).
struct SeaBand: View {
    var body: some View {
        Canvas { context, size in
            context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(Theme.band))
            var lines = Path()
            let step: CGFloat = 28
            var x: CGFloat = step
            while x < size.width { lines.move(to: CGPoint(x: x, y: 0)); lines.addLine(to: CGPoint(x: x, y: size.height)); x += step }
            var y: CGFloat = step
            while y < size.height { lines.move(to: CGPoint(x: 0, y: y)); lines.addLine(to: CGPoint(x: size.width, y: y)); y += step }
            context.stroke(lines, with: .color(Theme.bandText.opacity(0.06)), lineWidth: 1)
        }
        .accessibilityHidden(true)
    }
}

#Preview("Wordmark on the band") {
    Wordmark()
        .padding(28)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(SeaBand())
}
