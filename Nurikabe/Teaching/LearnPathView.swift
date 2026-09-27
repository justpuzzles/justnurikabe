import SwiftUI

/// The learning path: the rules chapter, then the nine techniques in order.
/// Steps unlock one after another; paid lessons stay tappable and open the
/// paywall (never `.disabled` — only order-locked steps are).
struct LearnPathView: View {
    @Binding var path: [Route]

    @Environment(ProgressStore.self) private var progress
    @Environment(EntitlementStore.self) private var entitlements
    @Environment(PaywallPresenter.self) private var paywall

    var body: some View {
        List {
            Section {
                summary
            }
            .listRowBackground(Theme.card)

            Section("Chapter 1 · The rules") {
                ForEach(RuleStep.allCases) { rule in
                    let unlocked = progress.isRuleUnlocked(rule)
                    Button { path.append(.rule(rule)) } label: {
                        row(title: TechniqueContent.title(rule),
                            subtitle: ruleSubtitle(rule),
                            state: progress.completedRules.contains(rule) ? .done : unlocked ? .open : .locked)
                    }
                    .disabled(!unlocked)
                    .accessibilityIdentifier("rule-\(rule.rawValue)")
                }
            }
            .listRowBackground(Theme.card)

            Section {
                ForEach(Technique.allCases) { technique in
                    let unlocked = progress.isLessonUnlocked(technique)
                    let paid = !FeatureGate.isLessonAvailable(technique, unlocked: entitlements.isUnlocked)
                    Button {
                        if paid { paywall.present(.advancedLessons) } else { path.append(.lesson(technique)) }
                    } label: {
                        row(title: "\(technique.rawValue + 1). \(TechniqueContent.name(technique))",
                            subtitle: TechniqueContent.rule(technique),
                            state: progress.completedLessons.contains(technique) ? .done
                                : !unlocked ? .locked : paid ? .paid : .open,
                            mastery: progress.masteryCount(technique))
                    }
                    .disabled(!unlocked)
                    .accessibilityIdentifier("lesson-\(technique.rawValue)")
                }
            } header: {
                Text("Chapter 2 · The techniques")
            } footer: {
                Text("Each lesson explains one argument, works an example on a real board, then gives you two to try. Lessons open in order. A seal appears once you've used a technique on your own \(MasteryRules.threshold) times in games.")
            }
            .listRowBackground(Theme.card)
        }
        .scrollContentBackground(.hidden)
        .readableColumn(720)
        .background(Theme.ground.ignoresSafeArea())
        .navigationTitle("Learn")
    }

    private var done: Int { progress.completedRules.count + progress.completedLessons.count }
    private var total: Int { RuleStep.allCases.count + Technique.allCases.count }

    private var summary: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("\(done) of \(total) steps")
                .font(.headline)
                .foregroundStyle(Theme.text)
            ProgressView(value: Double(done), total: Double(total))
                .tint(Theme.ochre)
            if let next = progress.nextPathStep {
                Button {
                    switch next {
                    case .rule(let r): path.append(.rule(r))
                    case .lesson(let t):
                        if FeatureGate.isLessonAvailable(t, unlocked: entitlements.isUnlocked) {
                            path.append(.lesson(t))
                        } else {
                            paywall.present(.advancedLessons)
                        }
                    }
                } label: {
                    Text("Continue: \(title(next))").font(.subheadline.weight(.semibold))
                }
                .tint(Theme.accent)
                .accessibilityIdentifier("continueLearning")
            } else {
                Text("You've finished the path. Every board is within reach.")
                    .font(.subheadline)
                    .foregroundStyle(Theme.textSoft)
            }
        }
        .padding(.vertical, 4)
    }

    private func title(_ step: PathStep) -> String {
        switch step {
        case .rule(let r): TechniqueContent.title(r)
        case .lesson(let t): TechniqueContent.name(t)
        }
    }

    private func ruleSubtitle(_ rule: RuleStep) -> String {
        TechniqueContent.cards(rule).first ?? ""
    }

    private enum RowState { case open, done, locked, paid }

    private func row(title: String, subtitle: String, state: RowState,
                     mastery: Int? = nil) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: symbol(state))
                .font(.title3)
                .foregroundStyle(state == .done ? Theme.ochre : Theme.textSoft)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.body.weight(.medium)).foregroundStyle(Theme.text)
                Text(subtitle).font(.footnote).foregroundStyle(Theme.textSoft).lineLimit(2)
            }
            Spacer(minLength: 4)
            if let mastery, mastery > 0 { masteryBadge(mastery) }
        }
        .opacity(state == .locked ? 0.55 : 1)
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
        .accessibilityValue(accessibilityState(state))
    }

    /// A seal once mastered; progress toward it before.
    @ViewBuilder
    private func masteryBadge(_ count: Int) -> some View {
        if count >= MasteryRules.threshold {
            Image(systemName: "seal.fill")
                .foregroundStyle(Theme.ochre)
                .accessibilityLabel("Mastered")
        } else {
            Text("\(count)/\(MasteryRules.threshold)")
                .font(.caption.weight(.semibold).monospacedDigit())
                .foregroundStyle(Theme.textSoft)
                .accessibilityLabel("\(count) of \(MasteryRules.threshold) toward mastery")
        }
    }

    private func symbol(_ state: RowState) -> String {
        switch state {
        case .open: "circle"
        case .done: "checkmark.circle.fill"
        case .locked: "lock"
        case .paid: "lock.circle"
        }
    }

    private func accessibilityState(_ state: RowState) -> String {
        switch state {
        case .open: "Not done"
        case .done: "Done"
        case .locked: "Opens after the previous step"
        case .paid: "Part of the full game"
        }
    }
}
