import Foundation

/// The win moment, "the sea floods in": the finished sea fills from the edge
/// of the chart inward, cell by cell in breadth-first order through the sea,
/// and then the islands lift off it. Pure timing; `BoardView` draws it from a
/// `TimelineView` clock, so nothing @Observable churns per frame.
nonisolated struct SeaFlood: Equatable, Sendable {
    /// When the flood began. `.distantPast` draws the settled end state.
    var start: Date
    /// Reduce Motion: no ripple, no lift travel; the solved look crossfades in.
    var reduceMotion: Bool
    /// Per cell: the flood's step count from the border (−1: not sea).
    var distance: [Int]

    static let stagger = Motion.winStagger
    static let cellFill = Motion.winCellFill
    static let lift = Motion.winLift
    static let crossfade = Motion.winCrossfade

    init(marks: [Mark], size: Int, start: Date, reduceMotion: Bool) {
        self.start = start
        self.reduceMotion = reduceMotion
        self.distance = Self.distances(marks: marks, size: size)
    }

    /// The solved look with no animation (a board resumed already solved).
    static func settled(marks: [Mark], size: Int) -> SeaFlood {
        SeaFlood(marks: marks, size: size, start: .distantPast, reduceMotion: true)
    }

    var duration: TimeInterval {
        reduceMotion ? Self.crossfade : Self.stagger + Self.cellFill + Self.lift
    }

    func isFinished(at date: Date) -> Bool { date.timeIntervalSince(start) >= duration }

    /// 0…1: how far cell `i` has filled (1 also for cells that aren't sea).
    func fill(_ i: Int, at date: Date) -> Double {
        let t = date.timeIntervalSince(start)
        if reduceMotion { return Self.clamp(t / Self.crossfade) }
        guard distance[i] >= 0 else { return 1 }
        let deepest = max(1, distance.max() ?? 1)
        let delay = Self.stagger * Double(distance[i]) / Double(deepest)
        return Self.clamp((t - delay) / Self.cellFill)
    }

    /// 0…1: how far the islands have lifted.
    func lift(at date: Date) -> Double {
        let t = date.timeIntervalSince(start)
        if reduceMotion { return Self.clamp(t / Self.crossfade) }
        let p = Self.clamp((t - Self.stagger - Self.cellFill) / Self.lift)
        return 1 - (1 - p) * (1 - p)   // ease out
    }

    private static func clamp(_ x: Double) -> Double { min(1, max(0, x)) }

    /// Breadth-first steps through the sea from the sea cells on the board's
    /// border. A sea with no border cell starts from the cells nearest the
    /// edge. Non-sea cells get −1.
    static func distances(marks: [Mark], size n: Int) -> [Int] {
        var dist = [Int](repeating: -1, count: marks.count)
        guard n > 0, marks.count == n * n else { return dist }
        func ring(_ i: Int) -> Int { min(i / n, i % n, n - 1 - i / n, n - 1 - i % n) }
        let sea = marks.indices.filter { marks[$0] == .sea }
        guard let nearest = sea.map(ring).min() else { return dist }
        var queue = sea.filter { ring($0) == nearest }
        for i in queue { dist[i] = 0 }
        var head = 0
        while head < queue.count {
            let i = queue[head]; head += 1
            let r = i / n, c = i % n
            for (dr, dc) in [(-1, 0), (1, 0), (0, -1), (0, 1)] {
                let rr = r + dr, cc = c + dc
                guard rr >= 0, cc >= 0, rr < n, cc < n else { continue }
                let j = rr * n + cc
                if marks[j] == .sea, dist[j] < 0 { dist[j] = dist[i] + 1; queue.append(j) }
            }
        }
        // A split sea (never in a solved board) floods its stragglers last.
        let last = (dist.max() ?? 0) + 1
        for i in sea where dist[i] < 0 { dist[i] = last }
        return dist
    }
}
