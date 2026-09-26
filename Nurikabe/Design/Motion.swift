import SwiftUI

/// Named animation tokens. Views never write inline animation values: every
/// animated moment has a name here, which keeps motion coherent and lets
/// Reduce Motion be honoured in one place.
///
/// `nonisolated` for the same load-bearing reason as `Theme`.
nonisolated enum Motion {

    /// A cell taking ink or paper.
    static let mark = Animation.easeOut(duration: 0.12)

    /// A hint's region washing in.
    static let hintWash = Animation.easeInOut(duration: 0.25)

    /// Lesson feedback cards sliding in.
    static let feedback = Animation.spring(response: 0.32, dampingFraction: 0.82)

    /// The finished board's sea settling into one colour.
    static let win = Animation.easeInOut(duration: 0.8)

    /// Chrome transitions (sheets, banners).
    static let chrome = Animation.easeInOut(duration: 0.22)
}
