import Foundation
import Observation

/// Owns paywall presentation for the whole app. One sheet at the root beats
/// five copies scattered through the view tree, and gives one place to hang a
/// purchase celebration later. A service, like `PuzzleCache` — not a ViewModel.
///
/// Presents the `PaidFeature` directly: it is `Identifiable`, so it drives
/// `.sheet(item:)` as-is.
@Observable @MainActor
final class PaywallPresenter {
    private(set) var presented: PaidFeature?

    func present(_ feature: PaidFeature) {
        presented = feature
    }

    func dismiss() {
        presented = nil
    }
}
