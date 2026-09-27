import SwiftUI

/// The play screen: header, chart, hint card, toolbar, finish card.
struct GameView: View {
    @Bindable var game: NurikabeGame
    var title: String
    /// Called when the player asks for another board of the same kind.
    var onNext: (() -> Void)? = nil

    @Environment(ProgressStore.self) private var progress
    @Environment(EntitlementStore.self) private var entitlements
    @Environment(PaywallPresenter.self) private var paywall
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.dismiss) private var dismiss
    @State private var recorded = false
    @State private var solveRecord: ProgressStore.SolveRecord?
    /// The techniques the puzzle's solve uses, in ladder order (found once,
    /// off the main actor, when the board is finished).
    @State private var techniquesUsed: [Technique] = []

    @Environment(\.horizontalSizeClass) private var sizeClass

    var body: some View {
        GeometryReader { geo in
            if sizeClass == .regular && geo.size.width > geo.size.height {
                // iPad landscape: the board on the left, sized by height; the
                // talk (hints, finish) and the tools in a column beside it.
                HStack(alignment: .top, spacing: 28) {
                    VStack(spacing: 14) {
                        header
                        board
                    }
                    .frame(width: min(geo.size.height - 24, geo.size.width * 0.6))
                    VStack(spacing: 14) {
                        panel
                        Spacer(minLength: 0)
                        if !game.isSolved { toolbar }
                    }
                    .frame(maxWidth: 420)
                    .padding(.top, 40)
                }
                .padding(.horizontal, 24)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                VStack(spacing: 14) {
                    header
                    board
                    panel
                    Spacer(minLength: 0)
                    if !game.isSolved { toolbar }
                }
                .readableColumn(sizeClass == .regular ? 760 : .infinity)
            }
        }
        .padding(.vertical, 10)
        .background(Theme.ground.ignoresSafeArea())
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button("Clear board", systemImage: "arrow.counterclockwise") { game.restart(); save() }
                        .disabled(game.isSolved)
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .accessibilityLabel("More")
            }
        }
        .onAppear {
            game.resumeClock()
            game.onCredit = { progress.credit($0) }
        }
        .onDisappear { game.pauseClock(); save() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { game.resumeClock() } else { game.pauseClock(); save() }
        }
        .onChange(of: game.isSolved) { _, solved in
            if solved { finish() }
        }
    }

    // MARK: Pieces

    private var board: some View {
        BoardView(puzzle: game.puzzle, marks: game.marks, overlay: overlay,
                  satisfiedClues: satisfiedClues, interactive: !game.isSolved) { event in
            switch event {
            case .begin(let i):
                game.beginStroke(at: i)
                Haptics.mark()
            case .extend(let i):
                game.extendStroke(to: i)
            case .end:
                game.endStroke()
                save()
            }
        }
        .padding(.horizontal, 12)
        .animation(Motion.mark, value: game.marks)
    }

    /// What the game has to say: the finish card, a hint, or a broken rule.
    @ViewBuilder
    private var panel: some View {
        if game.isSolved {
            finishCard
        } else if let hint = game.hint {
            hintCard(hint)
        } else if let breakNote = ruleBreakNote {
            note(breakNote, colour: Theme.error)
        }
    }

    private var header: some View {
        HStack {
            Text(TechniqueContent.name(game.grade))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.textSoft)
            Spacer()
            if progress.settings.showTimer {
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    Text(Self.clock(game.elapsed(at: context.date)))
                        .font(Theme.numberFont(size: 17))
                        .foregroundStyle(Theme.textSoft)
                }
            }
        }
        .padding(.horizontal, 20)
    }

    private var toolbar: some View {
        HStack(spacing: 28) {
            toolButton("Undo", "arrow.uturn.backward", enabled: game.canUndo) { game.undo(); save() }
            toolButton("Redo", "arrow.uturn.forward", enabled: game.canRedo) { game.redo(); save() }
            toolButton("Hint", "lightbulb", enabled: true) {
                game.advanceHint(policy: FeatureGate.hintPolicy(unlocked: entitlements.isUnlocked))
                save()
            }
            .accessibilityIdentifier("hintButton")
        }
        .padding(.bottom, 8)
    }

    private func toolButton(_ label: String, _ symbol: String, enabled: Bool,
                            action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: symbol).font(.title3)
                Text(label).font(.caption)
            }
            .frame(minWidth: 56, minHeight: 44)
        }
        .disabled(!enabled)
        .foregroundStyle(enabled ? Theme.text : Theme.textSoft.opacity(0.5))
    }

    private func hintCard(_ hint: HintState) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            switch hint {
            case .mistakes(let cells):
                Text(TechniqueContent.mistakes(cells.count))
                Button("Clear them") { game.clearWrongCells(); save() }
                    .font(.subheadline.weight(.semibold))
            case .noMistakes:
                Text(TechniqueContent.noMistakes)
                Button("See the full game") { paywall.present(.teachingHints) }
                    .font(.subheadline.weight(.semibold))
            case .nudge:
                Text(TechniqueContent.nudge)
                ladderFooter("Tap Hint again to name the argument.")
            case .technique(let step):
                Text(TechniqueContent.name(step.technique)).font(.headline)
                Text(TechniqueContent.rule(step.technique))
                ladderFooter("Tap Hint again to see it on the board.")
            case .argument(let step):
                Text(TechniqueContent.name(step.technique)).font(.headline)
                Text(TechniqueContent.argument(step, puzzle: game.puzzle))
                ladderFooter("Tap Hint again to fill it in.")
            case .apply, .stuck:
                Text(TechniqueContent.stuck)
            }
        }
        .font(.callout)
        .foregroundStyle(Theme.text)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 12))
        .overlay(alignment: .topTrailing) {
            Button { game.dismissHint() } label: {
                Image(systemName: "xmark").font(.caption.weight(.bold)).padding(10)
            }
            .foregroundStyle(Theme.textSoft)
            .accessibilityLabel("Close hint")
        }
        .padding(.horizontal, 16)
        .transition(.opacity)
    }

    private func ladderFooter(_ text: String) -> some View {
        Text(text).font(.caption).foregroundStyle(Theme.textSoft)
    }

    private func note(_ text: String, colour: Color) -> some View {
        Label(text, systemImage: "exclamationmark.triangle")
            .font(.callout)
            .foregroundStyle(colour)
            .padding(.horizontal, 20)
    }

    private var finishCard: some View {
        VStack(spacing: 12) {
            Text("Solved").font(Theme.heading).foregroundStyle(Theme.text)
            Text("\(Self.clock(game.elapsed(at: Date()))) · \(game.hintsUsed == 0 ? "no hints" : "\(game.hintsUsed) hint\(game.hintsUsed == 1 ? "" : "s")")")
                .font(Theme.numberFont(size: 16))
                .foregroundStyle(Theme.textSoft)
            if let line = recordLine {
                Label(line, systemImage: "rosette")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.ochre)
            }
            if !techniquesUsed.isEmpty {
                VStack(spacing: 8) {
                    Text("This board used").font(.caption).foregroundStyle(Theme.textSoft)
                    ChipFlow(spacing: 6) {
                        ForEach(techniquesUsed) { t in techniqueChip(t) }
                    }
                }
                .padding(.top, 2)
            }
            HStack(spacing: 12) {
                if let onNext {
                    Button("Next board", action: onNext).buttonStyle(.borderedProminent).tint(Theme.sea)
                }
                Button("Done") { dismiss() }.buttonStyle(.bordered).tint(Theme.accent)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(18)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 14))
        .padding(.horizontal, 16)
        .accessibilityIdentifier("solvedCard")
    }

    private var recordLine: String? {
        guard let solveRecord else { return nil }
        let where_ = "\(TechniqueContent.name(game.size)) \(TechniqueContent.name(game.grade))"
        if solveRecord.isNewBest { return "New best for \(where_)" }
        if solveRecord.isFirst { return "Your first \(where_) board" }
        return nil
    }

    /// A technique the board used. Mastered in this very game → ochre with a
    /// seal. Opens the lesson, or the paywall when the lesson is locked.
    @ViewBuilder
    private func techniqueChip(_ t: Technique) -> some View {
        let justMastered = (game.creditsThisGame[t] ?? 0) > 0 && progress.isMastered(t)
            && progress.masteryCount(t) - (game.creditsThisGame[t] ?? 0) < MasteryRules.threshold
        let label = HStack(spacing: 4) {
            if justMastered { Image(systemName: "seal.fill") }
            Text(TechniqueContent.name(t))
        }
        .font(.caption.weight(.medium))
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .foregroundStyle(justMastered ? Theme.land : Theme.text)
        .background(justMastered ? Theme.ochre : Theme.ground, in: Capsule())
        if FeatureGate.isLessonAvailable(t, unlocked: entitlements.isUnlocked) {
            NavigationLink(value: Route.lesson(t)) { label }
                .buttonStyle(.plain)
                .accessibilityHint("Opens the lesson")
        } else {
            Button { paywall.present(.advancedLessons) } label: { label }
                .buttonStyle(.plain)
        }
    }

    // MARK: Derived

    private var overlay: BoardOverlay {
        var o = BoardOverlay()
        if progress.settings.showRuleBreaks { o.broken = brokenCells }
        switch game.hint {
        case .mistakes(let cells)?: o.errors = Set(cells)
        case .nudge(let step)?: o.region = cellSet(step.explanation.region)
        case .technique(let step)?: o.region = cellSet(step.explanation.region)
        case .argument(let step)?:
            o.region = cellSet(step.explanation.region)
            o.targets = cellSet(step.sea + step.land)
            if step.technique == .whatIf {
                o.errors = cellSet(step.explanation.contradiction)
                o.trial = step.explanation.trialCell.map { game.grid.index($0) }
            }
        default: break
        }
        return o
    }

    private func cellSet(_ cells: [Cell]) -> Set<Int> { Set(cells.map { game.grid.index($0) }) }

    private var brokenCells: Set<Int> {
        var out = Set<Int>()
        for v in game.ruleBreaks {
            switch v {
            case .twoClues(let g), .oversized(let g), .undersized(let g), .unnumbered(let g):
                out.formUnion(g)
            case .pool(let corner):
                out.formUnion(game.grid.pool(at: corner))
            case .clueShaded(let cell):
                out.insert(cell)
            case .seaSplit:
                break
            }
        }
        return out
    }

    private var ruleBreakNote: String? {
        guard progress.settings.showRuleBreaks, let first = game.ruleBreaks.first else { return nil }
        return TechniqueContent.ruleBreak(first)
    }

    private var satisfiedClues: Set<Int> { game.satisfiedClues }

    // MARK: Persistence

    private func save() {
        guard !game.isSolved else { return }
        progress.saveGame(game.snapshot)
    }

    private func finish() {
        guard !recorded else { return }
        recorded = true
        Haptics.success()
        solveRecord = progress.recordSolve(kind: game.kind, grade: game.grade, size: game.size,
                                           seconds: game.elapsed(at: Date()), hintsUsed: game.hintsUsed)
        let puzzle = game.puzzle
        Task {
            let used = await Task.detached(priority: .utility) { () -> [Technique] in
                var budget = 200_000
                let trace = LogicalSolver.solve(puzzle: puzzle, budget: &budget).trace
                return Set(trace.map(\.technique)).sorted()
            }.value
            techniquesUsed = used
        }
    }

    static func clock(_ seconds: TimeInterval) -> String {
        let s = Int(seconds)
        return s >= 3600
            ? String(format: "%d:%02d:%02d", s / 3600, (s / 60) % 60, s % 60)
            : String(format: "%d:%02d", s / 60, s % 60)
    }
}
