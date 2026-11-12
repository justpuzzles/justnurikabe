import SwiftUI
#if canImport(UIKit)
import UIKit
#endif
#if os(macOS)
import AppKit
#endif

// Where iPhone, iPad, Mac, Apple TV and Vision Pro differ. Each seam says why
// the platform needs something else; the views call the seam, never `#if`.

extension View {
    /// `navigationBarTitleDisplayMode(.inline)`, which neither tvOS nor the Mac
    /// has: a television shows the system's title, a Mac window its title bar.
    @ViewBuilder
    func inlineNavigationTitle() -> some View {
        #if os(tvOS) || os(macOS)
        self
        #else
        navigationBarTitleDisplayMode(.inline)
        #endif
    }

    /// Hides a list's scroll background so the chart's ground shows. tvOS has
    /// no hideable background; there the list keeps the system's grouped look.
    @ViewBuilder
    func groundListBackground() -> some View {
        #if os(tvOS)
        self
        #else
        scrollContentBackground(.hidden)
        #endif
    }

    /// Makes focus (tvOS) or gaze (visionOS) visible on buttons that draw
    /// themselves. A custom style or `.plain` gets no focus effect on a
    /// television, and with a remote focus is the only cursor there is.
    func focusLift() -> some View {
        modifier(FocusLift())
    }

    /// A button drawn as a bare icon or label (the game's tools, a card's
    /// close cross). The Mac's default style would box it in a grey bezel,
    /// Vision Pro's in a tinted pill; borderless keeps the gaze highlight.
    @ViewBuilder
    func bareButton() -> some View {
        #if os(macOS) || os(visionOS)
        buttonStyle(.borderless)
        #else
        self
        #endif
    }

    /// A button in a list. tvOS lifts a focused row onto a white plate, and
    /// the chart's own text colours (pale by night) vanish on it; there the
    /// row draws its own focus instead. Elsewhere the system row is right.
    @ViewBuilder
    func listRowButton() -> some View {
        #if os(tvOS)
        buttonStyle(.tile)
        #else
        self
        #endif
    }
}

/// The trailing toolbar slot: the navigation bar's on iPhone, iPad and
/// Vision Pro; the window toolbar's on the Mac.
extension ToolbarItemPlacement {
    static var barTrailing: ToolbarItemPlacement {
        #if os(macOS)
        .primaryAction
        #elseif os(tvOS)
        .automatic
        #else
        .topBarTrailing
        #endif
    }
}

private struct FocusLift: ViewModifier {
    func body(content: Content) -> some View {
        #if os(tvOS)
        Lifted(content: content)
        #elseif os(visionOS)
        content
            .contentShape(.hoverEffect, RoundedRectangle(cornerRadius: 12, style: .continuous))
            .hoverEffect(.highlight)
        #else
        content
        #endif
    }

    #if os(tvOS)
    private struct Lifted: View {
        let content: Content
        @Environment(\.isFocused) private var isFocused

        var body: some View {
            content
                // A plate behind, for text-only rows: brightening paper text
                // on paper changes nothing.
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Theme.sea.opacity(isFocused ? 0.14 : 0))
                        .padding(-8)
                )
                .brightness(isFocused ? 0.06 : 0)
                .shadow(color: .black.opacity(isFocused ? 0.35 : 0),
                        radius: isFocused ? 16 : 0, y: isFocused ? 8 : 0)
                .scaleEffect(isFocused ? 1.03 : 1)
                .animation(.easeOut(duration: 0.15), value: isFocused)
        }
    }
    #endif
}

/// `.plain` with a focus effect on tvOS and a gaze highlight on visionOS. Use
/// it where `.plain` was: cards and rows that draw their own background.
struct TileButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(isEnabled ? (configuration.isPressed ? 0.75 : 1) : 0.5)
            .focusLift()
    }
}

extension ButtonStyle where Self == TileButtonStyle {
    static var tile: TileButtonStyle { TileButtonStyle() }
}

/// Sizes that change with the distance to the screen.
nonisolated enum Metrics {
    #if os(tvOS)
    /// Clock and counts in the game header, read from the sofa.
    static let headerNumber: CGFloat = 34
    static let isTelevision = true
    #elseif os(visionOS)
    static let headerNumber: CGFloat = 22
    static let isTelevision = false
    #else
    static let headerNumber: CGFloat = 17
    static let isTelevision = false
    #endif
}

/// The verb for pressing a control, in the hint card's instructions: there
/// is nothing to tap on a television, and on a Mac you click.
nonisolated enum InputVerb {
    #if os(tvOS)
    static let press = "Press"
    #elseif os(macOS)
    static let press = "Click"
    #else
    static let press = "Tap"
    #endif
}

/// Whether VoiceOver is speaking, on every platform (UIKit and AppKit ask
/// differently).
@MainActor
enum VoiceOver {
    static var isRunning: Bool {
        #if os(macOS)
        NSWorkspace.shared.isVoiceOverEnabled
        #else
        UIAccessibility.isVoiceOverRunning
        #endif
    }
}
