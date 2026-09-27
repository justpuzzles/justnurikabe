import SwiftUI

struct HomeView: View {
    @Binding var path: [Route]

    @Environment(ProgressStore.self) private var progress
    @Environment(EntitlementStore.self) private var entitlements
    @Environment(PaywallPresenter.self) private var paywall
    @Environment(PuzzleCache.self) private var cache
    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var showingNewBoard = false
    /// A new board waiting for the player to agree to replace the game in
    /// progress.
    @State private var pendingBoard: PendingBoard?

    private struct PendingBoard: Identifiable {
        let size: BoardSize
        let tier: Difficulty
        var id: String { "\(size.rawValue)-\(tier.rawValue)" }
    }

    private var today: DayKey { .today() }
    private var pathDone: Bool { progress.nextPathStep == nil }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                header
                VStack(spacing: 16) {
                    primary
                    tiles
                    slimRows
                }
                .padding(.horizontal, 20)
                // The first card rides up over the band's lower edge by a set
                // amount, so the band always ends at a deliberate place.
                .padding(.top, -Self.cardOverlap)
                .padding(.bottom, 32)
            }
        }
        .scrollBounceBehavior(.basedOnSize)
        .background(Theme.ground.ignoresSafeArea())
        // The bar is part of the band: the same fixed indigo (see Theme.band)
        // and the dark scheme, so the status bar is light over it.
        .toolbarBackground(Theme.band, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button { path.append(.stats) } label: { Image(systemName: "chart.bar") }
                    .accessibilityLabel("Statistics")
                Button { path.append(.settings) } label: { Image(systemName: "gearshape") }
                    .accessibilityLabel("Settings")
            }
        }
        .tint(Theme.bandText)
        .sheet(isPresented: $showingNewBoard) {
            NewBoardSheet { size, tier in
                showingNewBoard = false
                if progress.savedGame == nil {
                    path.append(.play(.random(size, tier)))
                } else {
                    pendingBoard = PendingBoard(size: size, tier: tier)
                }
            }
            .presentationDetents([.medium, .large])
            .tint(Theme.accent)
        }
        .confirmationDialog("Replace the game in progress?", isPresented: Binding(
            get: { pendingBoard != nil }, set: { if !$0 { pendingBoard = nil } }),
            titleVisibility: .visible, presenting: pendingBoard) { board in
            Button("Start the new board", role: .destructive) {
                progress.clearGame(kind: .random(size: board.size, tier: board.tier))
                path.append(.play(.random(board.size, board.tier)))
            }
            Button("Keep playing mine", role: .cancel) {}
        } message: { _ in
            Text("Your unfinished board will be lost.")
        }
        .onAppear { cache.prefetch(size: .seven, tier: .steady) }
    }

    // MARK: Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 14) {
            Wordmark()
            Text("Paint the sea. Find the islands.")
                .font(.subheadline)
                .foregroundStyle(Theme.bandSoft)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 24)
        .padding(.top, 20)
        .padding(.bottom, 36 + Self.cardOverlap)
        .background(alignment: .bottom) {
            // Tall enough to reach past the top of any overscroll.
            SeaBand().frame(height: 1200).ignoresSafeArea(edges: .top)
        }
    }

    /// How far the first card overlaps the band.
    private static let cardOverlap: CGFloat = 40

    // MARK: Primary

    @ViewBuilder
    private var primary: some View {
        if !pathDone {
            learnCard
        } else if let saved = progress.savedGame {
            continueCard(saved)
        }
    }

    private var learnCard: some View {
        let done = progress.completedRules.count + progress.completedLessons.count
        let total = RuleStep.allCases.count + Technique.allCases.count
        return Button { path.append(.learn) } label: {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .firstTextBaseline) {
                    Text(done == 0 ? "Learn to play" : "Keep learning")
                        .font(Theme.heading)
                        .foregroundStyle(Theme.text)
                    Spacer()
                    Image(systemName: "arrow.right")
                        .font(.headline)
                        .foregroundStyle(Theme.accent)
                }
                Text(learnSubtitle)
                    .font(.subheadline)
                    .foregroundStyle(Theme.textSoft)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                ProgressView(value: Double(done), total: Double(total))
                    .tint(Theme.ochre)
                Text("\(done) of \(total) steps")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(Theme.textSoft)
            }
            .padding(20)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("learnCard")
    }

    private var learnSubtitle: String {
        switch progress.nextPathStep {
        case .rule(let r)?:
            progress.completedRules.isEmpty
                ? "The rules in five short steps, then nine lessons that teach you to think like a solver."
                : "Next: \(TechniqueContent.title(r))"
        case .lesson(let t)?: "Next lesson: \(TechniqueContent.name(t))"
        case nil: "All nine techniques learned."
        }
    }

    private func continueCard(_ saved: SavedGame) -> some View {
        Button { path.append(.play(.resume)) } label: {
            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Continue").font(Theme.heading).foregroundStyle(Theme.text)
                    Text(savedLine(saved)).font(.subheadline).foregroundStyle(Theme.textSoft)
                }
                Spacer()
                Image(systemName: "play.fill").font(.title3).foregroundStyle(Theme.accent)
            }
            .padding(20)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("continueCard")
    }

    // MARK: Tiles

    private var tiles: some View {
        let layout = typeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(spacing: 12)) : AnyLayout(HStackLayout(spacing: 12))
        return layout {
            dailyTile
            newBoardTile
        }
    }

    private var dailyTile: some View {
        let solved = progress.isDailySolved(today)
        let streak = progress.dailyStreak(today: today)
        return tile(symbol: solved ? "checkmark.circle.fill" : "calendar",
                    title: "Today's chart",
                    detail: "7×7 · \(TechniqueContent.name(DailySeed.tier(for: today)))",
                    note: solved ? "Solved" : streak > 1 ? "\(streak)-day streak" : nil) {
            path.append(.play(.daily(today)))
        }
        .accessibilityIdentifier("dailyCard")
    }

    private var newBoardTile: some View {
        tile(symbol: "plus.square", title: "New board", detail: "Pick size and difficulty", note: nil) {
            showingNewBoard = true
        }
        .accessibilityIdentifier("newBoardCard")
    }

    private func tile(symbol: String, title: String, detail: String, note: String?,
                      action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 6) {
                Image(systemName: symbol)
                    .font(.title3)
                    .foregroundStyle(Theme.accent)
                    .padding(.bottom, 6)
                Text(title).font(.headline).foregroundStyle(Theme.text)
                Text(detail).font(.subheadline).foregroundStyle(Theme.textSoft)
                    .fixedSize(horizontal: false, vertical: true)
                if let note {
                    Text(note).font(.caption.weight(.semibold)).foregroundStyle(Theme.ochre)
                }
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, minHeight: 124, alignment: .topLeading)
            .padding(16)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    // MARK: Slim rows

    @ViewBuilder
    private var slimRows: some View {
        if !pathDone, let saved = progress.savedGame {
            slimRow(symbol: "play.fill", title: "Continue", detail: savedLine(saved)) {
                path.append(.play(.resume))
            }
            .accessibilityIdentifier("continueCard")
        }
        if pathDone {
            slimRow(symbol: "map", title: "Lessons", detail: "Revisit any technique") {
                path.append(.learn)
            }
            .accessibilityIdentifier("learnCard")
        }
    }

    private func slimRow(symbol: String, title: String, detail: String,
                         action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: symbol).foregroundStyle(Theme.accent).frame(width: 24)
                Text(title).font(.subheadline.weight(.semibold)).foregroundStyle(Theme.text)
                Text(detail).font(.subheadline).foregroundStyle(Theme.textSoft).lineLimit(1)
                Spacer(minLength: 0)
                Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(Theme.textSoft)
            }
            .padding(.horizontal, 16)
            .frame(minHeight: 52)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func savedLine(_ saved: SavedGame) -> String {
        "\(TechniqueContent.name(BoardSize(rawValue: saved.puzzle.size) ?? .seven)) · \(TechniqueContent.name(saved.grade)) · \(GameView.clock(saved.elapsed))"
    }
}

// MARK: - Previews (lived-in states)

@MainActor
private func previewEnvironment(_ configure: (ProgressStore) -> Void) -> some View {
    let defaults = UserDefaults(suiteName: "preview.\(UUID().uuidString)")!
    let progress = ProgressStore(userDefaults: defaults)
    configure(progress)
    return NavigationStack { HomeView(path: .constant([])) }
        .environment(progress)
        .environment(EntitlementStore(userDefaults: defaults, source: PreviewEntitlementSource(owned: false)))
        .environment(PaywallPresenter())
        .environment(PuzzleCache())
}

#Preview("New player") { previewEnvironment { _ in } }

#Preview("Mid-path, game saved") {
    previewEnvironment { p in
        for r in RuleStep.allCases { p.completeRule(r) }
        p.completeLesson(.oneClue)
        let puzzle = BakedPuzzles.puzzle(size: .seven)
        p.saveGame(SavedGame(kind: .random(size: .seven, tier: .sharp), puzzle: puzzle, grade: .sharp,
                             marks: puzzle.initialMarks, elapsed: 312, hintsUsed: 1))
    }
}

#Preview("Path done, streak") {
    previewEnvironment { p in
        for r in RuleStep.allCases { p.completeRule(r) }
        for t in Technique.allCases { p.completeLesson(t) }
        var day = DayKey.today()
        for _ in 0..<4 {
            p.recordSolve(kind: .daily(day), grade: .steady, size: .seven, seconds: 200, hintsUsed: 0)
            day = day.previous
        }
    }
}

#Preview("Dark") { previewEnvironment { _ in }.preferredColorScheme(.dark) }

#Preview("AX3 type") { previewEnvironment { _ in }.dynamicTypeSize(.accessibility3) }

/// Size and difficulty for a new random board.
struct NewBoardSheet: View {
    var onStart: (BoardSize, Difficulty) -> Void

    @Environment(EntitlementStore.self) private var entitlements
    @Environment(PaywallPresenter.self) private var paywall
    @Environment(\.dismiss) private var dismiss
    @State private var size: BoardSize = .seven
    @State private var tier: Difficulty = .steady

    var body: some View {
        NavigationStack {
            Form {
                Section("Size") {
                    Picker("Size", selection: $size) {
                        ForEach(BoardSize.allCases) { s in
                            Text(TechniqueContent.name(s) + (FeatureGate.isBoardSizeAvailable(s, unlocked: entitlements.isUnlocked) ? "" : " 🔒"))
                                .tag(s)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                Section {
                    ForEach(size.tiers) { t in
                        Button { tier = t } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(TechniqueContent.name(t)).foregroundStyle(Theme.text)
                                    Text(TechniqueContent.blurb(t)).font(.caption).foregroundStyle(Theme.textSoft)
                                }
                                Spacer()
                                if tier == t { Image(systemName: "checkmark").foregroundStyle(Theme.accent) }
                            }
                        }
                    }
                } header: {
                    Text("Difficulty")
                } footer: {
                    if size == .ten { Text("10×10 boards start at Sharp: at this size, easier boards are rare.") }
                }
            }
            .navigationTitle("New board")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                // In the toolbar, not the form: at the sheet's medium height
                // a form button sits below the fold.
                ToolbarItem(placement: .confirmationAction) {
                    Button("Start") {
                        if FeatureGate.isBoardSizeAvailable(size, unlocked: entitlements.isUnlocked) {
                            onStart(size, tier)
                        } else {
                            dismiss()
                            paywall.present(.largeBoards)
                        }
                    }
                    .fontWeight(.semibold)
                    .accessibilityIdentifier("startBoard")
                }
            }
            .onChange(of: size) { _, s in if !s.tiers.contains(tier) { tier = s.tiers[0] } }
        }
    }
}
