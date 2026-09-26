import SwiftUI

/// One technique's lesson: explanation, a worked example with the argument
/// drawn, two positions for the player, then practice.
struct TechniqueLessonView: View {
    let technique: Technique
    @Binding var path: [Route]

    @Environment(ProgressStore.self) private var progress
    @Environment(EntitlementStore.self) private var entitlements
    @Environment(PaywallPresenter.self) private var paywall

    private enum Page: Equatable { case intro, example, turn(Int), done }
    @State private var page: Page = .intro
    @State private var sessions: [LessonSession] = []

    var body: some View {
        ScrollViewReader { proxy in
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                progressDots
                switch page {
                case .intro: intro
                case .example: board(0, showArgument: true)
                case .turn(let k): board(k, showArgument: false)
                case .done: done
                }
            }
            .padding(20)
        }
        .onChange(of: page) { _, _ in
            withAnimation(Motion.chrome) { proxy.scrollTo(page == .done ? LessonAnchor.feedback : LessonAnchor.board, anchor: .top) }
        }
        .onChange(of: currentFeedback) { _, feedback in
            // The last position solved finishes the lesson, even if the
            // player leaves before tapping Continue.
            if feedback == .done, page == .turn(2) { progress.completeLesson(technique) }
            withAnimation(Motion.chrome) { proxy.scrollTo(LessonAnchor.feedback, anchor: .bottom) }
        }
        }
        .background(Theme.ground.ignoresSafeArea())
        .navigationTitle(TechniqueContent.name(technique))
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if sessions.isEmpty {
                sessions = (LessonBoards.techniques[technique] ?? []).map { LessonSession(position: $0) }
            }
        }
    }

    private var currentFeedback: LessonSession.Feedback? {
        switch page {
        case .example: sessions.first?.feedback
        case .turn(let k): k < sessions.count ? sessions[k].feedback : nil
        default: nil
        }
    }

    private var pageIndex: Int {
        switch page {
        case .intro: 0
        case .example: 1
        case .turn(let k): 1 + k
        case .done: 4
        }
    }

    private var progressDots: some View {
        HStack(spacing: 6) {
            ForEach(0..<5, id: \.self) { i in
                Capsule()
                    .fill(i <= pageIndex ? Theme.ochre : Theme.hairline)
                    .frame(height: 4)
            }
        }
        .accessibilityElement()
        .accessibilityLabel("Step \(pageIndex + 1) of 5")
    }

    private var intro: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(TechniqueContent.name(technique)).font(Theme.title).foregroundStyle(Theme.text)
            Text(TechniqueContent.rule(technique))
                .font(.title3.weight(.medium))
                .foregroundStyle(Theme.text)
            ForEach(TechniqueContent.explanation(technique), id: \.self) { paragraph in
                Text(paragraph).font(.body).foregroundStyle(Theme.textSoft)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Button("Show me on a board") { page = .example }
                .buttonStyle(.borderedProminent)
                .tint(Theme.sea)
                .padding(.top, 6)
                .accessibilityIdentifier("lessonStart")
        }
    }

    @ViewBuilder
    private func board(_ k: Int, showArgument: Bool) -> some View {
        if k < sessions.count {
            let session = sessions[k]
            VStack(alignment: .leading, spacing: 8) {
                Text(showArgument ? "Worked example" : "Your turn (\(k) of 2)")
                    .font(.headline)
                    .foregroundStyle(Theme.ochre)
                LessonBoardView(session: session,
                                task: TechniqueContent.lessonTask(technique, count: session.targets.count),
                                showArgument: showArgument,
                                successText: TechniqueContent.lessonSuccess(technique)) {
                    advance(from: k)
                }
                .id(k)
            }
        }
    }

    private func advance(from k: Int) {
        if k < 2 { page = .turn(k + 1) } else {
            progress.completeLesson(technique)
            page = .done
        }
    }

    private var done: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("Lesson complete", systemImage: "checkmark.seal.fill")
                .font(Theme.heading)
                .foregroundStyle(Theme.ochre)
                .id(LessonAnchor.feedback)
            Text("\(TechniqueContent.name(technique)): \(TechniqueContent.rule(technique))")
                .foregroundStyle(Theme.text)
            Button("Practice on a whole board") {
                if FeatureGate.isPracticeAvailable(technique, unlocked: entitlements.isUnlocked) {
                    path.append(.play(.practice(technique)))
                } else {
                    paywall.present(.advancedLessons)
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(Theme.sea)
            if let next = Technique(rawValue: technique.rawValue + 1) {
                Button("Next lesson: \(TechniqueContent.name(next))") {
                    if FeatureGate.isLessonAvailable(next, unlocked: entitlements.isUnlocked) {
                        path.removeLast()
                        path.append(.lesson(next))
                    } else {
                        paywall.present(.advancedLessons)
                    }
                }
                .buttonStyle(.bordered)
                .tint(Theme.sea)
            } else {
                Text("That's the whole ladder. Every board in the game can be solved with these nine arguments.")
                    .foregroundStyle(Theme.textSoft)
            }
        }
    }
}
