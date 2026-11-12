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
    /// The cell a stroke began on, for speaking what a VoiceOver double-tap
    /// did (it arrives as a one-cell stroke).
    @State private var strokeCell: Int?
    /// Closed islands and rule breaks when the stroke began, so its end can
    /// tell what the stroke changed (haptic, spoken result).
    @State private var strokeBefore: (Set<Int>, [Rules.Violation])?
    /// The win moment, started by the solving move. Nil on a board that was
    /// already solved when it opened: that one draws the settled look.
    @State private var flood: SeaFlood?
    /// The finish card waits for the flood (or a tap that skips it).
    @State private var cardShown = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @Environment(\.horizontalSizeClass) private var sizeClass
    @Environment(\.dynamicTypeSize) private var typeSize

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
                    .frame(maxWidth: Metrics.isTelevision ? 640 : 420)
                    .padding(.top, 40)
                }
                .padding(.horizontal, 24)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                VStack(spacing: 14) {
                    header
                    board
                    // At accessibility sizes the hint and finish cards can be
                    // taller than the screen; scrolling them keeps the board
                    // and the tools in view.
                    if typeSize.isAccessibilitySize {
                        ScrollView { panel }
                            .scrollBounceBehavior(.basedOnSize)
                            .frame(maxHeight: geo.size.height * 0.4)
                    } else {
                        panel
                    }
                    Spacer(minLength: 0)
                    if !game.isSolved { toolbar }
                }
                .readableColumn(sizeClass == .regular ? 760 : .infinity)
            }
        }
        .padding(.vertical, 10)
        .background(Theme.ground.ignoresSafeArea())
        .navigationTitle(title)
        .inlineNavigationTitle()
        #if !os(tvOS)
        .toolbar {
            ToolbarItem(placement: .barTrailing) {
                Menu {
                    Button("Clear board", systemImage: "arrow.counterclockwise") { game.restart(); save() }
                        .disabled(game.isSolved)
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .accessibilityLabel("More")
            }
        }
        #endif
        #if os(macOS)
        // The menu bar's Undo, Redo and Hint act on this game.
        .focusedSceneValue(\.boardActions, BoardActions(
            canUndo: game.canUndo, undo: { game.undo(); save() },
            canRedo: game.canRedo, redo: { game.redo(); save() },
            canHint: !game.isSolved, hint: askHint))
        #endif
        .onAppear {
            game.resumeClock()
            game.onCredit = { progress.credit($0) }
            stageScreenshot()
        }
        .onDisappear { game.pauseClock(); save() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { game.resumeClock() } else { game.pauseClock(); save() }
        }
        .onChange(of: game.isSolved) { _, solved in
            if solved { finish() }
        }
        // While the sea floods in, a tap anywhere skips to the card.
        .overlay {
            if flood != nil && !cardShown {
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture { showCard() }
                    .accessibilityHidden(true)
            }
        }
    }

    // MARK: Pieces

    private var board: some View {
        BoardView(puzzle: game.puzzle, marks: game.marks, overlay: overlay,
                  satisfiedClues: satisfiedClues, interactive: !game.isSolved,
                  flood: flood ?? (game.isSolved ? .settled(marks: game.marks, size: game.puzzle.size) : nil),
                  onStroke: { event in
            switch event {
            case .begin(let i):
                strokeCell = i
                strokeBefore = (game.satisfiedClues, game.ruleBreaks)
                game.beginStroke(at: i)
                Haptics.mark()
            case .extend(let i):
                strokeCell = nil
                game.extendStroke(to: i)
            case .end:
                // The board before the stroke began. Read here, it already
                // held the stroke's marks, so no island ever "newly" closed.
                let before = strokeBefore ?? (game.satisfiedClues, game.ruleBreaks)
                strokeBefore = nil
                game.endStroke()
                save()
                moveHaptic(satisfiedBefore: before.0, breaksBefore: before.1)
                if let i = strokeCell, VoiceOver.isRunning {
                    announceMove(i, satisfiedBefore: before.0, breaksBefore: before.1)
                }
                strokeCell = nil
            }
        }, onSet: { i, mark in assistiveSet(i, to: mark) })
        .padding(.horizontal, 12)
        .animation(Motion.mark, value: game.marks)
        // Every rung: each tap of Hint swaps the card's words in place.
        .onChange(of: game.hint) { _, hint in
            guard let hint, let text = spokenHintText(hint) else { return }
            BoardSpeech.announce(BoardSpeech.spokenHint(hint, text: text))
        }
    }

    /// A cell's accessibility action: set it directly, then say what changed.
    private func assistiveSet(_ i: Int, to mark: Mark) {
        let before = (game.satisfiedClues, game.ruleBreaks)
        game.set(i, to: mark)
        Haptics.mark()
        save()
        moveHaptic(satisfiedBefore: before.0, breaksBefore: before.1)
        announceMove(i, satisfiedBefore: before.0, breaksBefore: before.1)
    }

    /// After a move: a soft bump when an island closes, a warning when a rule
    /// newly breaks (only if rule breaks are shown). The win has its own.
    private func moveHaptic(satisfiedBefore: Set<Int>, breaksBefore: [Rules.Violation]) {
        guard !game.isSolved else { return }
        if progress.settings.showRuleBreaks, game.ruleBreaks.contains(where: { !breaksBefore.contains($0) }) {
            Haptics.warn()
        } else if !game.satisfiedClues.subtracting(satisfiedBefore).isEmpty {
            Haptics.islandClosed()
        }
    }

    private func announceMove(_ i: Int, satisfiedBefore: Set<Int>, breaksBefore: [Rules.Violation]) {
        let newBreak = progress.settings.showRuleBreaks
            ? game.ruleBreaks.first { !breaksBefore.contains($0) }.map(TechniqueContent.ruleBreak)
            : nil
        BoardSpeech.announce(BoardSpeech.moveResult(
            index: i, mark: game.marks[i], puzzle: game.puzzle,
            newlySatisfied: game.satisfiedClues.subtracting(satisfiedBefore), newBreak: newBreak))
    }

    /// The words the hint card shows, for speech.
    private func spokenHintText(_ hint: HintState) -> String? {
        switch hint {
        case .mistakes(let cells):
            let wrong = BoardSpeech.cells(cells.map { Cell(row: $0 / game.puzzle.size, col: $0 % game.puzzle.size) })
            return "\(TechniqueContent.mistakes(cells.count)) \(wrong)."
        case .noMistakes: return TechniqueContent.noMistakes
        case .nudge: return TechniqueContent.nudge
        case .technique(let step):
            return "\(TechniqueContent.name(step.technique)). \(TechniqueContent.rule(step.technique))"
        case .argument(let step):
            return "\(TechniqueContent.name(step.technique)). \(TechniqueContent.argument(step, puzzle: game.puzzle))"
        case .apply, .stuck: return TechniqueContent.stuck
        }
    }

    /// What the game has to say: the finish card, a hint, or a broken rule.
    @ViewBuilder
    private var panel: some View {
        if game.isSolved {
            // A board opened already solved shows its card at once.
            if cardShown || flood == nil { finishCard.transition(.opacity) }
        } else if let hint = game.hint {
            hintCard(hint)
        } else if let breakNote = ruleBreakNote {
            note(breakNote, colour: Theme.errorText)
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
                        .numberFont(Metrics.headerNumber)
                        .foregroundStyle(Theme.textSoft)
                        .accessibilityLabel("Time \(Self.spoken(game.elapsed(at: context.date)))")
                }
            }
        }
        .padding(.horizontal, 20)
    }

    private var toolbar: some View {
        #if os(tvOS)
        // Two by two, labels beside the icons: four system buttons in a row
        // were wider than the column and wrapped their words.
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 24), GridItem(.flexible(), spacing: 24)],
                  spacing: 24) { tools }
        #else
        HStack(spacing: 28) { tools }
            .padding(.bottom, 8)
        #endif
    }

    @ViewBuilder
    private var tools: some View {
        Group {
            toolButton("Undo", "arrow.uturn.backward", enabled: game.canUndo) { game.undo(); save() }
            toolButton("Redo", "arrow.uturn.forward", enabled: game.canRedo) { game.redo(); save() }
            toolButton("Hint", "lightbulb", enabled: true, action: askHint)
                .accessibilityIdentifier("hintButton")
            #if os(tvOS)
            // The toolbar's More menu is not on a television (a toolbar is a
            // focus trap there), so Clear sits with the other tools.
            toolButton("Clear", "arrow.counterclockwise", enabled: !game.isSolved) {
                game.restart(); save()
            }
            #endif
        }
    }

    private func askHint() {
        game.advanceHint(policy: FeatureGate.hintPolicy(unlocked: entitlements.isUnlocked))
        save()
    }

    private func toolButton(_ label: String, _ symbol: String, enabled: Bool,
                            action: @escaping () -> Void) -> some View {
        Button(action: action) {
            #if os(tvOS)
            Label(label, systemImage: symbol)
                .frame(maxWidth: .infinity)
            #else
            VStack(spacing: 4) {
                Image(systemName: symbol).font(.title3)
                Text(label).font(.caption)
            }
            .frame(minWidth: 56, minHeight: 44)
            #endif
        }
        .bareButton()
        .disabled(!enabled)
        // textSoft, not faded further: a disabled tool still has to be
        // readable (the audit measured 0.5 × textSoft at 2.3–3.1:1).
        .foregroundStyle(enabled ? Theme.text : Theme.textSoft)
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
        // Grow rather than truncate at large text sizes.
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 12))
        .overlay(alignment: .topTrailing) {
            Button { game.dismissHint() } label: {
                Image(systemName: "xmark").font(.caption.weight(.bold))
                    .frame(minWidth: 44, minHeight: 44)
                    .contentShape(Rectangle())
            }
            .bareButton()
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
                .numberFont(16)
                .foregroundStyle(Theme.textSoft)
            if let line = recordLine {
                Label(line, systemImage: "rosette")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.ochreText)
            }
            // No share sheet on Apple TV.
            #if !os(tvOS)
            if case .daily(let day) = game.kind {
                ShareLink(item: shareText(day)) {
                    Label("Share", systemImage: "square.and.arrow.up")
                }
                .font(.subheadline.weight(.semibold))
                .tint(Theme.accent)
                .accessibilityLabel("Share result")
            }
            #endif
            if !techniquesUsed.isEmpty {
                VStack(spacing: 8) {
                    Text("This board used").font(.caption).foregroundStyle(Theme.textSoft)
                    ChipFlow(spacing: 6) {
                        ForEach(techniquesUsed) { t in techniqueChip(t) }
                    }
                }
                .padding(.top, 2)
            }
            // Side by side normally; stacked at accessibility sizes, where
            // "Next board" was cut off.
            (typeSize.isAccessibilitySize ? AnyLayout(VStackLayout(spacing: 12)) : AnyLayout(HStackLayout(spacing: 12))) {
                if let onNext {
                    Button("Next board", action: onNext).buttonStyle(.borderedProminent).tint(Theme.sea)
                }
                Button("Done") { dismiss() }.buttonStyle(.bordered).tint(Theme.accent)
            }
        }
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: .infinity)
        .padding(18)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 14))
        .padding(.horizontal, 16)
        .accessibilityIdentifier("solvedCard")
    }

    /// PuzzleKit's family text: the day, the time on record (a replay
    /// shares the first solve's), the streak, the link. Nothing about the
    /// board itself, so it spoils nothing.
    private func shareText(_ day: DayKey) -> String {
        let time = progress.daily.time(for: day) ?? game.elapsed(at: Date())
        let streak = progress.daily.lastCompleted == day ? progress.daily.currentStreak : 0
        return DailyShare(game: "Just Nurikabe", day: day, timeText: Self.clock(time),
                          streak: streak, detail: "\(TechniqueContent.name(game.size)) \(TechniqueContent.name(game.grade))",
                          url: URL(string: "https://kaikunze.de/justnurikabe/"))
            .text()
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
        .foregroundStyle(Theme.text)
        .background(justMastered ? Theme.ochre : Theme.ground, in: Capsule())
        .frame(minHeight: 44)
        .contentShape(Rectangle())
        if FeatureGate.isLessonAvailable(t, unlocked: entitlements.isUnlocked) {
            NavigationLink(value: Route.lesson(t)) { label }
                .buttonStyle(.tile)
                .accessibilityHint("Opens the lesson")
        } else {
            Button { paywall.present(.advancedLessons) } label: { label }
                .buttonStyle(.tile)
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

    /// DEBUG screenshot scenes: climb the hint ladder to the drawn argument,
    /// or place the last cell to reach the finish card.
    private func stageScreenshot() {
        switch ScreenshotScene.current {
        case .hint?:
            for _ in 0..<3 { game.advanceHint(policy: .full) }
        case .win?:
            // A beat after the screen settles, so the flood can be watched
            // (and recorded) before the card.
            Task {
                try? await Task.sleep(for: .seconds(1.5))
                if let last = game.marks.indices.first(where: { game.marks[$0] == .unknown }) {
                    game.set(last, to: game.puzzle.solution[last] ? .land : .sea)
                }
            }
        default:
            break
        }
    }

    // MARK: Persistence

    private func save() {
        guard !game.isSolved else { return }
        progress.saveGame(game.snapshot)
    }

    private func finish() {
        guard !recorded else { return }
        recorded = true
        let sea = SeaFlood(marks: game.marks, size: game.puzzle.size, start: .now, reduceMotion: reduceMotion)
        flood = sea
        Task {
            try? await Task.sleep(for: .seconds(sea.duration))
            showCard()
        }
        solveRecord = progress.recordSolve(kind: game.kind, grade: game.grade, size: game.size,
                                           seconds: game.elapsed(at: Date()), hintsUsed: game.hintsUsed)
        let hints = game.hintsUsed == 0 ? "no hints" : "\(game.hintsUsed) hint\(game.hintsUsed == 1 ? "" : "s")"
        let spoken = "Solved in \(Self.spoken(game.elapsed(at: Date()))), \(hints)."
            + (recordLine.map { " \($0)." } ?? "")
        Task {
            // After the finish card appears, or its arrival cuts this off.
            try? await Task.sleep(for: .seconds(sea.duration + 0.8))
            BoardSpeech.announce(spoken)
        }
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

    /// The end of the win moment, by the clock or by a tap: the haptic, then
    /// the card. Runs once.
    private func showCard() {
        guard flood != nil, !cardShown else { return }
        Haptics.success()
        // A skip jumps the board to its settled look.
        flood?.start = .distantPast
        withAnimation(Motion.chrome) { cardShown = true }
    }

    /// "4 minutes 7 seconds". VoiceOver reads "4:07" as a time of day.
    static func spoken(_ seconds: TimeInterval) -> String {
        let total = max(0, Int(seconds))
        let (h, m, s) = (total / 3600, (total % 3600) / 60, total % 60)
        func unit(_ n: Int, _ name: String) -> String { "\(n) \(name)\(n == 1 ? "" : "s")" }
        if h > 0 { return [unit(h, "hour"), m > 0 ? unit(m, "minute") : nil].compactMap { $0 }.joined(separator: " ") }
        if m > 0 { return [unit(m, "minute"), s > 0 ? unit(s, "second") : nil].compactMap { $0 }.joined(separator: " ") }
        return unit(s, "second")
    }

    static func clock(_ seconds: TimeInterval) -> String {
        let s = Int(seconds)
        return s >= 3600
            ? String(format: "%d:%02d:%02d", s / 3600, (s / 60) % 60, s % 60)
            : String(format: "%d:%02d", s / 60, s % 60)
    }
}
