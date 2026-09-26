import SwiftUI

/// Scroll anchors shared by the lesson screens.
enum LessonAnchor: Hashable { case board, feedback }

/// A lesson board: BoardView driven by a LessonSession, with the task line,
/// feedback, and an optional drawn argument.
struct LessonBoardView: View {
    @Bindable var session: LessonSession
    let task: String
    /// Show the argument's region and text from the start (worked example).
    var showArgument: Bool
    var successText: String
    var onContinue: () -> Void

    @State private var hintShown = false
    @State private var strokeMark: Mark?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(task)
                .font(.callout.weight(.medium))
                .foregroundStyle(Theme.text)
                .fixedSize(horizontal: false, vertical: true)

            BoardView(puzzle: session.position.puzzle, marks: session.marks, overlay: overlay,
                      interactive: !session.isDone) { event in
                switch event {
                case .begin(let i):
                    if session.targets.contains(i) {
                        session.tap(i)
                        strokeMark = session.marks[i]
                    } else {
                        session.tap(i)
                        strokeMark = nil
                    }
                    Haptics.mark()
                case .extend(let i):
                    if let m = strokeMark, session.targets.contains(i) { session.paint(i, m) }
                case .end:
                    strokeMark = nil
                    if case .wrong = session.feedback { Haptics.warn() }
                    if session.isDone { Haptics.success() }
                }
            }
            .frame(maxWidth: 330)
            .frame(maxWidth: .infinity)
            .animation(Motion.mark, value: session.marks)
            .id(LessonAnchor.board)

            if showArgument || hintShown || session.isDone, let step = session.position.step {
                Text(TechniqueContent.argument(step, puzzle: session.position.puzzle))
                    .font(.callout)
                    .foregroundStyle(Theme.text)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Theme.ochreWash, in: RoundedRectangle(cornerRadius: 10))
                    .fixedSize(horizontal: false, vertical: true)
            }

            feedbackView
                .animation(Motion.feedback, value: session.feedback)
                .id(LessonAnchor.feedback)
        }
    }

    @ViewBuilder
    private var feedbackView: some View {
        switch session.feedback {
        case .done:
            VStack(alignment: .leading, spacing: 10) {
                Label(session.revealed ? "Here's the answer." : successText, systemImage: "checkmark.circle.fill")
                    .foregroundStyle(Theme.text)
                Button("Continue", action: onContinue)
                    .buttonStyle(.borderedProminent)
                    .tint(Theme.sea)
                    .accessibilityIdentifier("lessonContinue")
            }
        case .wrong(let text):
            VStack(alignment: .leading, spacing: 10) {
                Label(text, systemImage: "xmark.circle")
                    .foregroundStyle(Theme.error)
                    .fixedSize(horizontal: false, vertical: true)
                helpButtons
            }
        case .offTarget:
            VStack(alignment: .leading, spacing: 10) {
                Label(TechniqueContent.offTarget, systemImage: "hand.point.up.left")
                    .foregroundStyle(Theme.textSoft)
                helpButtons
            }
        case .none:
            helpButtons
        }
    }

    private var helpButtons: some View {
        HStack(spacing: 16) {
            if !showArgument && !hintShown {
                Button("Hint") { hintShown = true }
            }
            Button("Show me") { session.reveal() }
        }
        .font(.callout)
        .tint(Theme.sea)
    }

    private var overlay: BoardOverlay {
        var o = BoardOverlay()
        o.targets = session.isDone ? [] : session.targets
        if showArgument || hintShown, let step = session.position.step {
            let g = session.position.puzzle.grid
            o.region = Set(step.explanation.region.map { g.index($0) })
            if step.technique == .whatIf {
                o.errors = Set(step.explanation.contradiction.map { g.index($0) })
            }
        }
        return o
    }
}
