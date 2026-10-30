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

    /// The win, "the sea floods in" (`SeaFlood`, drawn by `BoardView` on a
    /// TimelineView clock, so these are seconds rather than Animations):
    /// sea cells start filling from the border over `winStagger`, each takes
    /// `winCellFill`, then the islands lift over `winLift`. ≈0.9 s in all.
    static let winStagger: TimeInterval = 0.4
    static let winCellFill: TimeInterval = 0.25
    static let winLift: TimeInterval = 0.25
    /// Reduce Motion: the solved look crossfades in, nothing travels.
    static let winCrossfade: TimeInterval = 0.3

    /// Chrome transitions (sheets, banners).
    static let chrome = Animation.easeInOut(duration: 0.22)
}
