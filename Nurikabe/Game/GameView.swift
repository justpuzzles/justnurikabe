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

    var body: some View {
        VStack(spacing: 14) {
            header
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

            if game.isSolved {
                finishCard
            } else if let hint = game.hint {
                hintCard(hint)
            } else if let breakNote = ruleBreakNote {
                note(breakNote, colour: Theme.error)
            }
            Spacer(minLength: 0)
            if !game.isSolved { toolbar }
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
        .onAppear { game.resumeClock() }
        .onDisappear { game.pauseClock(); save() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { game.resumeClock() } else { game.pauseClock(); save() }
        }
        .onChange(of: game.isSolved) { _, solved in
            if solved { finish() }
        }
    }

    // MARK: Pieces

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
        VStack(spacing: 10) {
            Text("Solved").font(Theme.heading).foregroundStyle(Theme.text)
            Text("\(Self.clock(game.elapsed(at: Date()))) · \(game.hintsUsed == 0 ? "no hints" : "\(game.hintsUsed) hint\(game.hintsUsed == 1 ? "" : "s")")")
                .font(Theme.numberFont(size: 16))
                .foregroundStyle(Theme.textSoft)
            HStack(spacing: 12) {
                if let onNext {
                    Button("Next board", action: onNext).buttonStyle(.borderedProminent)
                }
                Button("Done") { dismiss() }.buttonStyle(.bordered)
            }
            .tint(Theme.sea)
        }
        .frame(maxWidth: .infinity)
        .padding(18)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 14))
        .padding(.horizontal, 16)
        .accessibilityIdentifier("solvedCard")
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

    private var satisfiedClues: Set<Int> {
        Set(game.puzzle.clues.indices.filter { game.isClueSatisfied($0) })
    }

    // MARK: Persistence

    private func save() {
        guard !game.isSolved else { return }
        progress.saveGame(game.snapshot)
    }

    private func finish() {
        guard !recorded else { return }
        recorded = true
        Haptics.success()
        progress.recordSolve(kind: game.kind, grade: game.grade, size: game.size,
                             seconds: game.elapsed(at: Date()), hintsUsed: game.hintsUsed)
    }

    static func clock(_ seconds: TimeInterval) -> String {
        let s = Int(seconds)
        return s >= 3600
            ? String(format: "%d:%02d:%02d", s / 3600, (s / 60) % 60, s % 60)
            : String(format: "%d:%02d", s / 60, s % 60)
    }
}
