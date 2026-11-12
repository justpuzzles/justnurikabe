import SwiftUI
#if os(iOS)
import UIKit
#endif

/// Haptic vocabulary; intensity scales with rarity. `@MainActor`, and it must
/// stay so: UIFeedbackGenerator is NS_SWIFT_UI_ACTOR and `enabled` is mutable
/// global state.
@MainActor
enum Haptics {

    /// Applied from settings at launch AND when the toggle changes.
    static var enabled = true

    #if os(iOS)
    private static let light = UIImpactFeedbackGenerator(style: .light)
    private static let soft = UIImpactFeedbackGenerator(style: .soft)
    private static let notification = UINotificationFeedbackGenerator()
    #endif

    /// A cell marked.
    static func mark() {
        #if os(iOS)
        guard enabled else { return }
        light.impactOccurred(intensity: 0.5)
        #endif
    }

    /// An island closed during play.
    static func islandClosed() {
        #if os(iOS)
        guard enabled else { return }
        soft.impactOccurred()
        #endif
    }

    /// A move the lesson did not want, or a broken rule.
    static func warn() {
        #if os(iOS)
        guard enabled else { return }
        notification.notificationOccurred(.warning)
        #endif
    }

    /// A board solved, a lesson finished.
    static func success() {
        #if os(iOS)
        guard enabled else { return }
        notification.notificationOccurred(.success)
        #endif
    }
}
