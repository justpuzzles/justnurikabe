import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// Haptic vocabulary; intensity scales with rarity. `@MainActor`, and it must
/// stay so: UIFeedbackGenerator is NS_SWIFT_UI_ACTOR and `enabled` is mutable
/// global state.
@MainActor
enum Haptics {

    /// Applied from settings at launch AND when the toggle changes.
    static var enabled = true

    #if canImport(UIKit)
    private static let light = UIImpactFeedbackGenerator(style: .light)
    private static let notification = UINotificationFeedbackGenerator()
    #endif

    /// A cell marked.
    static func mark() {
        #if canImport(UIKit)
        guard enabled else { return }
        light.impactOccurred(intensity: 0.5)
        #endif
    }

    /// A move the lesson did not want, or a broken rule.
    static func warn() {
        #if canImport(UIKit)
        guard enabled else { return }
        notification.notificationOccurred(.warning)
        #endif
    }

    /// A board solved, a lesson finished.
    static func success() {
        #if canImport(UIKit)
        guard enabled else { return }
        notification.notificationOccurred(.success)
        #endif
    }
}
