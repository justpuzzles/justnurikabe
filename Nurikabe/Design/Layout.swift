import SwiftUI

extension View {
    /// Caps reading content at a comfortable column on iPad and centres it;
    /// a no-op on iPhone widths.
    func readableColumn(_ maxWidth: CGFloat = 640) -> some View {
        // A television is read from across the room in bigger type: the
        // phone/iPad column there is a strip down the middle of the screen.
        frame(maxWidth: Metrics.isTelevision ? maxWidth * 1.5 : maxWidth).frame(maxWidth: .infinity)
    }

    /// A lesson board, centred: 330 pt on iPhone, larger on iPad where the
    /// phone cap left the board a small island in a wide column.
    func lessonBoardFrame() -> some View {
        modifier(LessonBoardFrame())
    }
}

private struct LessonBoardFrame: ViewModifier {
    @Environment(\.horizontalSizeClass) private var sizeClass

    func body(content: Content) -> some View {
        content
            .frame(maxWidth: Metrics.isTelevision ? 640 : sizeClass == .regular ? 480 : 330)
            .frame(maxWidth: .infinity)
    }
}
