import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// A light/dark colour value, held as plain components rather than a
/// `UIColor`, so the provider closure in `Theme.dynamic(light:dark:)` captures
/// only `Sendable` values. See the note on `Theme`.
nonisolated struct ThemeRGBA: Sendable {
    let red, green, blue, alpha: CGFloat

    init(_ hex: UInt32, alpha: CGFloat = 1) {
        red = CGFloat((hex >> 16) & 0xFF) / 255
        green = CGFloat((hex >> 8) & 0xFF) / 255
        blue = CGFloat(hex & 0xFF) / 255
        self.alpha = alpha
    }
}

// `nonisolated` for the same load-bearing reason as `Theme` below.
#if canImport(UIKit)
private nonisolated extension UIColor {
    convenience init(_ c: ThemeRGBA) {
        self.init(red: c.red, green: c.green, blue: c.blue, alpha: c.alpha)
    }
}
#endif

/// Semantic colour and type tokens. **The chart**: Nurikabe is islands in a
/// sea, so the board is drawn like a printed nautical chart — paper islands,
/// an aizome-indigo sea, and one ochre for the lighthouse (teaching).
///
/// Three rules hold this together:
///
/// 1. **The board is the same in light and dark.** It is a printed chart, not
///    interface; only the room around it (`ground`, text) follows the system
///    appearance. The sea/land tokens therefore carry near-identical pairs.
/// 2. **Ochre means teaching**, vermilion means a broken rule. They never
///    stand in for each other.
/// 3. **Opaque, always.** No blur or translucency on the board.
///
/// `nonisolated` is load-bearing, not tidiness. The project builds with
/// `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`, so without it the provider
/// closure in `dynamic(light:dark:)` would be implicitly `@MainActor`. UIKit
/// resolves dynamic colours from SwiftUI's async render thread, where Swift 6's
/// executor assertion traps (EXC_BREAKPOINT) — it shipped in Just Kakuro once.
/// Guarded by ThemeIsolationTests.
nonisolated enum Theme {

    // MARK: - Room (follows the appearance)

    /// The ground everything sits on.
    static let ground = dynamic(light: ThemeRGBA(0xEFEAE0), dark: ThemeRGBA(0x14171C))
    /// Cards and sheets, a step off `ground`.
    static let card = dynamic(light: ThemeRGBA(0xF8F5EE), dark: ThemeRGBA(0x1E232A))
    /// Primary text.
    static let text = dynamic(light: ThemeRGBA(0x1C2433), dark: ThemeRGBA(0xECE6DA))
    /// Secondary text. Kept at 0.78 alpha — a sibling's contrast audit failed
    /// at 0.55.
    static let textSoft = dynamic(light: ThemeRGBA(0x1C2433, alpha: 0.78),
                                  dark: ThemeRGBA(0xECE6DA, alpha: 0.76))
    /// Interactive text and icons (navigation, plain buttons). Indigo by
    /// day; by night a pale indigo, because the sea's own indigo all but
    /// vanishes on the dark ground.
    static let accent = dynamic(light: ThemeRGBA(0x233A5E), dark: ThemeRGBA(0xA9C1EC))
    /// Hairlines and separators.
    static let hairline = dynamic(light: ThemeRGBA(0x1C2433, alpha: 0.14),
                                  dark: ThemeRGBA(0xECE6DA, alpha: 0.14))

    // MARK: - The chart (near-identical in both appearances)

    /// Land: chart paper. Blank cells and dotted cells both show paper.
    static let land = dynamic(light: ThemeRGBA(0xFBF8F1), dark: ThemeRGBA(0xF3EEE3))
    /// Sea: aizome indigo, the dominant colour of the app.
    static let sea = dynamic(light: ThemeRGBA(0x233A5E), dark: ThemeRGBA(0x2A4470))
    /// The chart's grid lines.
    static let grid = dynamic(light: ThemeRGBA(0x233A5E, alpha: 0.28),
                              dark: ThemeRGBA(0x2A4470, alpha: 0.34))
    /// Clue numerals and the land dot.
    static let numeral = dynamic(light: ThemeRGBA(0x1B2C49), dark: ThemeRGBA(0x1F3357))
    /// A finished island's numeral relaxes to this.
    static let numeralDone = dynamic(light: ThemeRGBA(0x1B2C49, alpha: 0.42),
                                     dark: ThemeRGBA(0x1F3357, alpha: 0.46))

    // MARK: - Accents

    /// Lighthouse ochre — **teaching only**: hint regions, lesson targets,
    /// the path's progress, the win mark.
    static let ochre = dynamic(light: ThemeRGBA(0xC98A1B), dark: ThemeRGBA(0xE0A23A))
    /// Ochre at wash strength, for the region an argument is about.
    static let ochreWash = dynamic(light: ThemeRGBA(0xC98A1B, alpha: 0.30),
                                   dark: ThemeRGBA(0xE0A23A, alpha: 0.34))
    /// Vermilion — a broken rule (pool, merged islands, wrong cell).
    static let error = dynamic(light: ThemeRGBA(0xC4432B), dark: ThemeRGBA(0xE0573C))
    static let errorWash = dynamic(light: ThemeRGBA(0xC4432B, alpha: 0.30),
                                   dark: ThemeRGBA(0xE0573C, alpha: 0.36))

    /// The closure is *also* explicitly `@Sendable` — redundant while `Theme`
    /// is `nonisolated`, deliberately, so losing one annotation does not bring
    /// the trap back. `dynamicProvider:` is spelled out so the dangerous API
    /// stays greppable (ThemeIsolationTests scans for it).
    private static func dynamic(light: ThemeRGBA, dark: ThemeRGBA) -> Color {
        #if canImport(UIKit)
        Color(UIColor(dynamicProvider: { @Sendable trait in
            UIColor(trait.userInterfaceStyle == .dark ? dark : light)
        }))
        #else
        Color(red: light.red, green: light.green, blue: light.blue, opacity: light.alpha)
        #endif
    }

    // MARK: - Type

    /// Clue numerals: New York, the serif of printed charts.
    static func clueFont(size: CGFloat) -> Font {
        .system(size: size, weight: .semibold, design: .serif)
    }

    /// Timers and counts.
    static func numberFont(size: CGFloat) -> Font {
        .system(size: size, weight: .medium, design: .rounded).monospacedDigit()
    }

    static let title = Font.system(.largeTitle, design: .serif, weight: .semibold)
    static let heading = Font.system(.title2, design: .serif, weight: .semibold)
    static let body = Font.system(.body)
}
