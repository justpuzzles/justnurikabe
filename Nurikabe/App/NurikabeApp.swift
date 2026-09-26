//
//  NurikabeApp.swift
//  Nurikabe
//

import SwiftUI

@main
struct NurikabeApp: App {
    @State private var progress: ProgressStore
    @State private var entitlements: EntitlementStore
    @State private var paywall: PaywallPresenter
    @State private var cache: PuzzleCache

    init() {
        #if DEBUG
        // UI tests launch with -uiTestResetState for a clean slate. DEBUG-only:
        // a release build must not carry a switch that wipes a player's data.
        if ProcessInfo.processInfo.arguments.contains("-uiTestResetState") {
            UserDefaults.standard.removePersistentDomain(
                forName: Bundle.main.bundleIdentifier ?? "de.kaikunze.nurikabe")
        }
        #endif
        let progress = ProgressStore()
        _progress = State(initialValue: progress)
        _entitlements = State(initialValue: Self.makeEntitlementStore())
        _paywall = State(initialValue: PaywallPresenter())
        _cache = State(initialValue: PuzzleCache())
        Haptics.enabled = progress.settings.hapticsEnabled
    }

    /// Screenshot runs need the paid screens. `#if DEBUG` on purpose: a launch
    /// argument that grants the unlock must not exist in the shipped binary
    /// (ReleaseBuildTests checks the flag is read inside the guard).
    private static func makeEntitlementStore() -> EntitlementStore {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains(Self.screenshotUnlockFlag) {
            return EntitlementStore(source: PreviewEntitlementSource(owned: true))
        }
        #endif
        return EntitlementStore()
    }

    /// Outside the `#if` on purpose — the test has to be able to name it.
    static let screenshotUnlockFlag = "-NurikabeScreenshotUnlock"

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(progress)
                .environment(entitlements)
                .environment(paywall)
                .environment(cache)
                .tint(Theme.accent)
        }
    }
}
