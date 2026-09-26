import SwiftUI

/// One step of the rules chapter: explanation cards one at a time, then a
/// board where the rule is the move. The last step is a whole small board.
struct RuleLessonView: View {
    let rule: RuleStep
    @Binding var path: [Route]

    @Environment(ProgressStore.self) private var progress
    @State private var card = 0
    @State private var session: LessonSession?
    @State private var game: NurikabeGame?

    init(rule: RuleStep, path: Binding<[Route]>) {
        self.rule = rule
        _path = path
        _session = State(initialValue: LessonBoards.rules[rule].map { LessonSession(position: $0) })
        _game = State(initialValue: rule == .firstPuzzle
            ? NurikabeGame(puzzle: LessonBoards.firstPuzzle, kind: .random(size: .five, tier: .gentle),
                           grade: .gentle)
            : nil)
    }

    private var cards: [String] { TechniqueContent.cards(rule) }
    private var onBoard: Bool { card >= cards.count }

    var body: some View {
        ScrollViewReader { proxy in
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text(TechniqueContent.title(rule)).font(Theme.title).foregroundStyle(Theme.text)
                ForEach(0..<min(card + 1, cards.count), id: \.self) { i in
                    Text(cards[i])
                        .font(.body)
                        .foregroundStyle(i == card ? Theme.text : Theme.textSoft)
                        .fixedSize(horizontal: false, vertical: true)
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                }
                if onBoard {
                    boardSection
                } else {
                    Button(card == cards.count - 1 ? "Try it" : "Next") {
                        withAnimation(Motion.feedback) { card += 1 }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Theme.sea)
                    .accessibilityIdentifier("ruleNext")
                }
            }
            .padding(20)
        }
        .onChange(of: card) { _, _ in
            if onBoard { withAnimation(Motion.chrome) { proxy.scrollTo(LessonAnchor.board, anchor: .top) } }
        }
        .onChange(of: session?.feedback) { _, feedback in
            // Solved counts as done, whether or not Continue is tapped.
            if feedback == .done { progress.completeRule(rule) }
            withAnimation(Motion.chrome) { proxy.scrollTo(LessonAnchor.feedback, anchor: .bottom) }
        }
        .onChange(of: game?.isSolved) { _, solved in
            if solved == true { progress.completeRule(rule) }
            withAnimation(Motion.chrome) { proxy.scrollTo(LessonAnchor.feedback, anchor: .bottom) }
        }
        }
        .background(Theme.ground.ignoresSafeArea())
        .navigationTitle("The rules")
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private var boardSection: some View {
        if rule == .firstPuzzle {
            firstPuzzle
        } else if let session {
            LessonBoardView(session: session, task: TechniqueContent.task(rule),
                            showArgument: rule == .islands,
                            successText: TechniqueContent.success(rule)) {
                finish()
            }
        }
    }

    /// The first whole board, with the full hint ladder even for free
    /// players: this is where the game is learned.
    @ViewBuilder
    private var firstPuzzle: some View {
        if let game { firstPuzzleBoard(game) }
    }

    private func firstPuzzleBoard(_ game: NurikabeGame) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(TechniqueContent.task(rule)).font(.callout.weight(.medium)).foregroundStyle(Theme.text)
            BoardView(puzzle: game.puzzle, marks: game.marks,
                      overlay: firstPuzzleOverlay(game), interactive: !game.isSolved) { event in
                switch event {
                case .begin(let i): game.beginStroke(at: i); Haptics.mark()
                case .extend(let i): game.extendStroke(to: i)
                case .end: game.endStroke()
                }
            }
            .frame(maxWidth: 330)
            .frame(maxWidth: .infinity)
            .id(LessonAnchor.board)
            if game.isSolved {
                Label(TechniqueContent.success(rule), systemImage: "checkmark.circle.fill")
                    .foregroundStyle(Theme.text)
                Button("Continue") { finish() }
                    .buttonStyle(.borderedProminent)
                    .tint(Theme.sea)
                    .id(LessonAnchor.feedback)
                    .accessibilityIdentifier("lessonContinue")
            } else {
                if let hint = game.hint { hintText(hint, game: game) }
                HStack(spacing: 20) {
                    Button("Undo") { game.undo() }.disabled(!game.canUndo)
                    Button("Hint") { game.advanceHint(policy: .full) }
                }
                .tint(Theme.sea)
            }
        }
        .onChange(of: game.isSolved) { _, solved in if solved { Haptics.success() } }
    }

    private func hintText(_ hint: HintState, game: NurikabeGame) -> some View {
        Group {
            switch hint {
            case .mistakes(let cells): Text(TechniqueContent.mistakes(cells.count))
            case .nudge: Text(TechniqueContent.nudge)
            case .technique(let s): Text("\(TechniqueContent.name(s.technique)): \(TechniqueContent.rule(s.technique))")
            case .argument(let s): Text(TechniqueContent.argument(s, puzzle: game.puzzle))
            default: Text(TechniqueContent.stuck)
            }
        }
        .font(.callout)
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 10))
    }

    private func firstPuzzleOverlay(_ game: NurikabeGame) -> BoardOverlay {
        var o = BoardOverlay()
        let g = game.grid
        switch game.hint {
        case .mistakes(let cells)?: o.errors = Set(cells)
        case .nudge(let s)?, .technique(let s)?: o.region = Set(s.explanation.region.map { g.index($0) })
        case .argument(let s)?:
            o.region = Set(s.explanation.region.map { g.index($0) })
            o.targets = Set((s.sea + s.land).map { g.index($0) })
        default: break
        }
        return o
    }

    private func finish() {
        progress.completeRule(rule)
        path.removeLast()
        if let next = RuleStep.allCases.drop(while: { $0 != rule }).dropFirst().first {
            path.append(.rule(next))
        } else {
            path.append(.lesson(.oneClue))
        }
    }
}
