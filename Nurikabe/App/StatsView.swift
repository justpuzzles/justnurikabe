import SwiftUI

struct StatsView: View {
    @Environment(ProgressStore.self) private var progress

    var body: some View {
        List {
            Section {
                row("Boards solved", "\(progress.totalSolved)")
                row("Daily streak", "\(progress.dailyStreak())")
                row("Lessons finished", "\(progress.completedLessons.count) of \(Technique.allCases.count)")
            }
            Section {
                ForEach(Technique.allCases) { t in
                    let count = progress.masteryCount(t)
                    HStack {
                        Text(TechniqueContent.name(t)).foregroundStyle(Theme.text)
                        Spacer()
                        if count >= MasteryRules.threshold {
                            Label("Mastered", systemImage: "seal.fill")
                                .foregroundStyle(Theme.ochreText)
                                .font(.subheadline.weight(.semibold))
                        } else {
                            Text("\(count) of \(MasteryRules.threshold)")
                                .numberFont(15)
                                .foregroundStyle(Theme.textSoft)
                        }
                    }
                }
            } header: {
                Text("Mastery").listHeaderText()
            } footer: {
                Text("A deduction counts when you make it yourself, without a hint, and the solver agrees it follows from the board.").listHeaderText()
            }
            ForEach(BoardSize.allCases) { size in
                Section(TechniqueContent.name(size)) {
                    ForEach(Difficulty.allCases) { tier in
                        let e = progress.entry(size: size, grade: tier)
                        if e.solved > 0 {
                            HStack {
                                Text(TechniqueContent.name(tier)).foregroundStyle(Theme.text)
                                Spacer()
                                Text("\(e.solved) solved").foregroundStyle(Theme.textSoft)
                                if let best = e.bestSeconds {
                                    Text("best \(GameView.clock(best))")
                                        .numberFont(15)
                                        .foregroundStyle(Theme.text)
                                }
                            }
                        }
                    }
                    if Difficulty.allCases.allSatisfy({ progress.entry(size: size, grade: $0).solved == 0 }) {
                        Text("Nothing solved yet.").foregroundStyle(Theme.textSoft)
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Theme.ground.ignoresSafeArea())
        .navigationTitle("Statistics")
    }

    private func row(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).foregroundStyle(Theme.text)
            Spacer()
            Text(value).numberFont(17).foregroundStyle(Theme.text)
        }
    }
}
