import Foundation

/// Every sentence the teaching layer shows. The engine never holds English;
/// it hands over `Technique`, `RuleStep` and `ExplanationData`, and this file
/// turns them into words. Keep the voice plain: short sentences, no jargon
/// without a definition, and the board's own vocabulary (island, sea, pool).
nonisolated enum TechniqueContent {

    // MARK: - The rules chapter

    static func title(_ rule: RuleStep) -> String {
        switch rule {
        case .islands: "Numbers are islands"
        case .oneNumber: "One number per island"
        case .noPools: "No pools"
        case .oneSea: "One sea"
        case .firstPuzzle: "Your first chart"
        }
    }

    /// The explanation cards shown before the board, in order.
    static func cards(_ rule: RuleStep) -> [String] {
        switch rule {
        case .islands:
            [
                "Every cell is either land or sea. You paint the sea; the land is what's left.",
                "Each number sits on an island: a group of land cells joined side by side. The number is the island's size, counting the number's own cell.",
                "Tap a cell once to paint it sea. Tap again to leave a dot, meaning \u{201C}this is land, I'm sure.\u{201D} A third tap clears it. You can also drag to paint several cells.",
            ]
        case .oneNumber:
            [
                "Every island holds exactly one number. There are no islands without a number, and no island with two.",
                "Land cells that touch side by side are always the same island. So two different numbers must never touch through land.",
            ]
        case .noPools:
            [
                "The sea may never form a pool: no 2×2 square can be all sea.",
                "Look for three sea cells in a square. The fourth has to be land.",
            ]
        case .oneSea:
            [
                "All the sea is one piece. Every sea cell connects to every other through sea cells side by side (corners don't count).",
                "So a patch of sea can never be walled in. If it has only one way out, the sea must continue through it.",
            ]
        case .firstPuzzle:
            [
                "That's every rule. Numbers are island sizes, one number per island, no pools, one sea.",
                "Now a whole board. Start with what is certain, and dot the land you're sure of so you can see the islands grow.",
            ]
        }
    }

    /// The instruction above the board.
    static func task(_ rule: RuleStep) -> String {
        switch rule {
        case .islands: "The highlighted island already has all its cells. Paint the outlined cells around it as sea."
        case .oneNumber: "The outlined cell touches two different islands. Decide what it must be."
        case .noPools: "The outlined cell completes a square with three sea cells. Decide what it must be."
        case .oneSea: "A patch of sea has a single way out. Decide what the outlined cell must be."
        case .firstPuzzle: "Solve the whole board."
        }
    }

    static func success(_ rule: RuleStep) -> String {
        switch rule {
        case .islands: "Right. The island has all its cells, so everything beside it is sea."
        case .oneNumber: "Right. As land it would join two numbers into one island, so it is sea."
        case .noPools: "Right. As sea it would finish a pool, so it is land."
        case .oneSea: "Right. Without it that sea patch would be cut off, so it is sea."
        case .firstPuzzle: "Solved. You know the whole game now; the lessons show how to think faster."
        }
    }

    // MARK: - Techniques

    static func name(_ t: Technique) -> String {
        switch t {
        case .oneClue: "Ones"
        case .twoClues: "Between Two Islands"
        case .completeIsland: "Finished Island"
        case .noPool: "No Pools"
        case .unreachable: "Out of Reach"
        case .islandEscape: "Only Way Out"
        case .seaEscape: "The Sea Must Connect"
        case .commonGround: "Common Ground"
        case .whatIf: "What If"
        }
    }

    /// The rule in one sentence: the hint's second rung and the path's subtitle.
    static func rule(_ t: Technique) -> String {
        switch t {
        case .oneClue: "A 1 is a whole island, so every cell beside it is sea."
        case .twoClues: "A blank cell touching two different islands is sea."
        case .completeIsland: "When an island has all its cells, every blank beside it is sea."
        case .noPool: "Three sea cells in a 2×2 square make the fourth land."
        case .unreachable: "A cell no island can reach in time is sea."
        case .islandEscape: "An island that needs more cells, with one blank neighbour, grows there."
        case .seaEscape: "A patch of sea with one way out must flow through it."
        case .commonGround: "A cell that every possible shape of an island uses is land."
        case .whatIf: "If one colour for a cell breaks a rule, it is the other colour."
        }
    }

    /// The lesson's explanation, a few short paragraphs.
    static func explanation(_ t: Technique) -> [String] {
        switch t {
        case .oneClue:
            [
                "An island of size 1 is just the numbered cell itself.",
                "Its neighbours can't be land, because that land would join the island and make it bigger than 1. So every cell beside a 1 is sea.",
                "Start every board by painting around the 1s.",
            ]
        case .twoClues:
            [
                "Land cells that touch are one island, and an island can hold only one number.",
                "So a blank cell that touches land from two different numbered islands would glue them into one island with two numbers. It has to be sea.",
                "Look between numbers that sit two cells apart, in a line or diagonally.",
            ]
        case .completeIsland:
            [
                "Count an island's cells. When the count reaches its number, the island is finished.",
                "Any more land beside it would make it too big, so every blank cell touching it is sea.",
                "Ones are the smallest case of this. Dotting land as you find it makes finished islands easy to spot.",
            ]
        case .noPool:
            [
                "The sea can never fill a 2×2 square.",
                "So wherever three sea cells share a square, the fourth cell must be land. It then has to belong to some island, which often tells you more.",
            ]
        case .unreachable:
            [
                "An island with number n that already has k cells can grow only n − k more.",
                "It can't reach a cell farther away than that, and it can't pass through cells that would make it touch another island.",
                "A blank cell that no island can reach is sea. On a fresh board, these are often whole corners.",
            ]
        case .islandEscape:
            [
                "An island that still needs cells has to grow somewhere.",
                "If only one blank cell touches it, that cell is the only way out, so it is land. The same is true for a dotted patch of land that has no number yet: it must reach one.",
            ]
        case .seaEscape:
            [
                "All the sea is one piece. A patch of sea that isn't all of it must connect to the rest.",
                "If that patch has only one blank neighbour, the connection has to go through it, so it is sea.",
                "Watch the edges and corners, where sea patches get boxed in easily.",
            ]
        case .commonGround:
            [
                "Sometimes an island can finish in several shapes. Picture every way it could still grow to its size.",
                "A cell that every shape uses must be land. A blank cell that every shape touches but none uses must be sea, because it borders the island whichever way it grows.",
                "This works best on islands that need just one or two more cells.",
            ]
        case .whatIf:
            [
                "When nothing simpler applies, try a cell. Suppose it is land, and follow the other arguments from there.",
                "If that leads to a broken rule, such as a pool, a sea patch cut off or an island that can't be finished, the supposition was wrong and the cell is sea. The same works the other way round.",
                "This isn't guessing: you only keep a colour when the other one is impossible.",
            ]
        }
    }

    /// The instruction for a lesson position.
    static func lessonTask(_ t: Technique, count: Int) -> String {
        let cells = count == 1 ? "the outlined cell" : "the \(count) outlined cells"
        return "Use \(name(t)) to decide \(cells)."
    }

    static func lessonSuccess(_ t: Technique) -> String {
        switch t {
        case .oneClue: "Right. Nothing can join a 1."
        case .twoClues: "Right. That cell would have merged two islands."
        case .completeIsland: "Right. The island was full, so its border is sea."
        case .noPool: "Right. That cell prevents a pool."
        case .unreachable: "Right. No island could get there."
        case .islandEscape: "Right. It was the only way out."
        case .seaEscape: "Right. The sea had to flow through there."
        case .commonGround: "Right. Every way the island can finish agrees."
        case .whatIf: "Right. The other colour led to a broken rule."
        }
    }

    // MARK: - Hints and arguments

    /// The hint's first rung: where to look, not why.
    static let nudge = "Look at the highlighted area. Something there is certain."

    /// The hint's third rung and the lesson's worked example: the argument
    /// about this step's actual cells.
    static func argument(_ step: SolverStep, puzzle: Puzzle) -> String {
        let seaCount = step.sea.count, landCount = step.land.count
        let decided = describe(sea: seaCount, land: landCount)
        let e = step.explanation
        switch step.technique {
        case .oneClue:
            return "This 1 is a complete island, so \(decided)."
        case .twoClues:
            let values = e.clueIndices.map { String(puzzle.clues[$0].value) }
            let pair = values.count == 2 ? "the \(values[0]) and the \(values[1])" : "two numbered islands"
            return "This cell touches \(pair). As land it would join them, so \(decided)."
        case .completeIsland:
            let n = e.numbers.first ?? e.region.count
            return "This island already has all \(n) of its cells, so \(decided)."
        case .noPool:
            return "Three cells of this square are sea. As sea, the last one would make a pool, so \(decided)."
        case .unreachable:
            let one = seaCount == 1
            return "No island has enough cells left to reach \(one ? "this cell" : "these cells"), so \(decided)."
        case .islandEscape:
            if e.numbers.count == 2 {
                return "This island of \(e.numbers[0]) has only \(e.numbers[1]) cell\(e.numbers[1] == 1 ? "" : "s") and one blank neighbour. It has to grow there, so \(decided)."
            }
            return "This land has no number yet and only one blank neighbour. It must reach a number through it, so \(decided)."
        case .seaEscape:
            return "This sea patch has only one blank neighbour, and the sea must connect to the rest. So \(decided)."
        case .commonGround:
            let n = e.numbers.first ?? 0
            let ways = e.numbers.count > 1 ? e.numbers[1] : 0
            let shapes = ways == 1 ? "only one shape" : "\(ways) possible shapes"
            return "This island of \(n) can finish in \(shapes). All of them agree here, so \(decided)."
        case .whatIf:
            let tried = e.trialWasLand ? "land" : "sea"
            return "Suppose this cell were \(tried). Following the rules from there breaks one (the red cells show where), so \(decided)."
        }
    }

    private static func describe(sea: Int, land: Int) -> String {
        switch (sea, land) {
        case (1, 0): "the highlighted cell is sea"
        case (_, 0): "the highlighted cells are sea"
        case (0, 1): "the highlighted cell is land"
        case (0, _): "the highlighted cells are land"
        default: "the highlighted cells are decided"
        }
    }

    // MARK: - Mistakes and rule breaks

    static func mistakes(_ count: Int) -> String {
        count == 1
            ? "One cell is marked wrong. It's outlined in red."
            : "\(count) cells are marked wrong. They're outlined in red."
    }

    static let noMistakes = "No mistakes so far. Hints that name the next argument come with the full game."

    static let stuck = "No certain move found here. Try undoing your last few marks."

    static func ruleBreak(_ v: Rules.Violation) -> String {
        switch v {
        case .twoClues: "Two numbers are in the same island."
        case .oversized: "An island is bigger than its number."
        case .undersized: "An island is boxed in before reaching its size."
        case .unnumbered: "Some land is walled off from every number."
        case .pool: "Four sea cells make a pool."
        case .seaSplit: "Part of the sea is cut off from the rest."
        case .clueShaded: "A number is painted over."
        }
    }

    /// Lesson feedback for a wrong mark on a target cell.
    static func wrongTarget(_ t: Technique, markedSea: Bool) -> String {
        let colour = markedSea ? "sea" : "land"
        return "Not \(colour). " + rule(t)
    }

    static let offTarget = "That cell isn't part of this lesson. Work on the outlined cells."

    // MARK: - Difficulty and sizes

    static func name(_ d: Difficulty) -> String {
        switch d {
        case .gentle: "Gentle"
        case .steady: "Steady"
        case .sharp: "Sharp"
        case .deep: "Deep"
        case .severe: "Severe"
        }
    }

    static func blurb(_ d: Difficulty) -> String {
        switch d {
        case .gentle: "Ones, finished islands, pools and reach."
        case .steady: "Adds the sea that must connect."
        case .sharp: "Adds Common Ground."
        case .deep: "Needs What If, now and then."
        case .severe: "Long chains of What If."
        }
    }

    static func name(_ s: BoardSize) -> String { "\(s.rawValue)×\(s.rawValue)" }
}
