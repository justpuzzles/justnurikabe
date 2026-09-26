import SwiftUI

struct HomeView: View {
    @Binding var path: [Route]

    @Environment(ProgressStore.self) private var progress
    @Environment(EntitlementStore.self) private var entitlements
    @Environment(PaywallPresenter.self) private var paywall
    @Environment(PuzzleCache.self) private var cache
    @State private var showingNewBoard = false

    private var today: DayKey { .today() }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                wordmark
                if progress.nextPathStep != nil { learnCard(primary: true) }
                if let saved = progress.savedGame, !isDailyToday(saved) { continueCard(saved) }
                dailyCard
                newBoardCard
                if progress.nextPathStep == nil { learnCard(primary: false) }
                HStack(spacing: 12) {
                    smallCard("Statistics", "chart.bar") { path.append(.stats) }
                    smallCard("Settings", "gearshape") { path.append(.settings) }
                }
            }
            .padding(20)
        }
        .background(Theme.ground.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $showingNewBoard) {
            NewBoardSheet { size, tier in
                showingNewBoard = false
                path.append(.play(.random(size, tier)))
            }
            .presentationDetents([.medium, .large])
        }
        .onAppear { cache.prefetch(size: .seven, tier: .steady) }
    }

    // MARK: Cards

    private var wordmark: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Just").font(.title3.weight(.medium)).foregroundStyle(Theme.textSoft)
            Text("Nurikabe").font(Theme.title).foregroundStyle(Theme.text)
            Text("Paint the sea. Find the islands.").font(.subheadline).foregroundStyle(Theme.textSoft)
        }
        .padding(.top, 12)
        .accessibilityElement(children: .combine)
    }

    private func learnCard(primary: Bool) -> some View {
        let done = progress.completedRules.count + progress.completedLessons.count
        let total = RuleStep.allCases.count + Technique.allCases.count
        return card(primary: primary) {
            path.append(.learn)
        } content: {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(done == 0 ? "Learn to play" : "Learning path").font(.headline)
                    Text(learnSubtitle).font(.subheadline).opacity(0.85)
                        .fixedSize(horizontal: false, vertical: true)
                    ProgressView(value: Double(done), total: Double(total))
                        .tint(primary ? Theme.ochre : Theme.sea)
                        .padding(.top, 4)
                }
                Spacer()
                Image(systemName: "map").font(.title2)
            }
        }
        .accessibilityIdentifier("learnCard")
    }

    private var learnSubtitle: String {
        switch progress.nextPathStep {
        case .rule(let r)?:
            progress.completedRules.isEmpty
                ? "Start here: the rules in five short steps, then nine lessons."
                : "Next: \(TechniqueContent.title(r))"
        case .lesson(let t)?: "Next lesson: \(TechniqueContent.name(t))"
        case nil: "All nine techniques learned. Revisit any lesson."
        }
    }

    private func continueCard(_ saved: SavedGame) -> some View {
        card(primary: progress.nextPathStep == nil) {
            path.append(.play(.resume))
        } content: {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Continue").font(.headline)
                    Text("\(TechniqueContent.name(BoardSize(rawValue: saved.puzzle.size) ?? .seven)) · \(TechniqueContent.name(saved.grade)) · \(GameView.clock(saved.elapsed))")
                        .font(.subheadline).opacity(0.85)
                }
                Spacer()
                Image(systemName: "play.fill").font(.title3)
            }
        }
        .accessibilityIdentifier("continueCard")
    }

    private var dailyCard: some View {
        let solved = progress.isDailySolved(today)
        let streak = progress.dailyStreak(today: today)
        return card(primary: false) {
            path.append(.play(.daily(today)))
        } content: {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Today's chart").font(.headline)
                    Text("7×7 · \(TechniqueContent.name(DailySeed.tier(for: today)))\(solved ? " · solved" : "")")
                        .font(.subheadline).opacity(0.85)
                    if streak > 1 {
                        Text("\(streak)-day streak").font(.caption.weight(.semibold)).foregroundStyle(Theme.ochre)
                    }
                }
                Spacer()
                Image(systemName: solved ? "checkmark.circle.fill" : "calendar").font(.title3)
            }
        }
        .accessibilityIdentifier("dailyCard")
    }

    private var newBoardCard: some View {
        card(primary: false) {
            showingNewBoard = true
        } content: {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("New board").font(.headline)
                    Text("Choose a size and how hard.").font(.subheadline).opacity(0.85)
                }
                Spacer()
                Image(systemName: "plus.square").font(.title3)
            }
        }
        .accessibilityIdentifier("newBoardCard")
    }

    private func smallCard(_ title: String, _ symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: symbol)
                .font(.subheadline.weight(.medium))
                .frame(maxWidth: .infinity, minHeight: 44)
                .foregroundStyle(Theme.text)
                .background(Theme.card, in: RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }

    private func card(primary: Bool, action: @escaping () -> Void,
                      @ViewBuilder content: () -> some View) -> some View {
        Button(action: action) {
            content()
                .foregroundStyle(primary ? Theme.land : Theme.text)
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(primary ? Theme.sea : Theme.card, in: RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
    }

    private func isDailyToday(_ saved: SavedGame) -> Bool {
        if case .daily(let day) = saved.kind { return day == today }
        return false
    }
}

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
