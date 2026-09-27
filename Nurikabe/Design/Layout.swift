import SwiftUI

extension View {
    /// Caps reading content at a comfortable column on iPad and centres it;
    /// a no-op on iPhone widths.
    func readableColumn(_ maxWidth: CGFloat = 640) -> some View {
        frame(maxWidth: maxWidth).frame(maxWidth: .infinity)
    }
}
