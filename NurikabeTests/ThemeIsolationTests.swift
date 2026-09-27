import Foundation
import SwiftUI
import Testing
import UIKit
@testable import Nurikabe

// Guards the crash Just Kakuro shipped: under default MainActor isolation a
// UIColor dynamic provider closure traps when UIKit resolves it off the main
// thread (SwiftUI's async renderer). Theme and Motion must stay nonisolated.

private nonisolated func themeColors() -> [(String, Color)] {
    [("ground", Theme.ground), ("card", Theme.card), ("text", Theme.text), ("textSoft", Theme.textSoft),
     ("hairline", Theme.hairline), ("accent", Theme.accent), ("bandText", Theme.bandText), ("bandSoft", Theme.bandSoft), ("land", Theme.land), ("sea", Theme.sea), ("grid", Theme.grid),
     ("numeral", Theme.numeral), ("numeralDone", Theme.numeralDone), ("ochre", Theme.ochre),
     ("ochreWash", Theme.ochreWash), ("error", Theme.error), ("errorWash", Theme.errorWash)]
}

private nonisolated func motionTokens() -> [Animation] {
    [Motion.mark, Motion.hintWash, Motion.feedback, Motion.win, Motion.chrome]
}

private nonisolated let mainQueueKey: DispatchSpecificKey<Bool> = {
    let key = DispatchSpecificKey<Bool>()
    DispatchQueue.main.setSpecific(key: key, value: true)
    return key
}()

private nonisolated func rgba(_ color: UIColor) -> [CGFloat] {
    var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
    color.getRed(&r, green: &g, blue: &b, alpha: &a)
    return [r, g, b, a]
}

@Suite struct ThemeIsolationTests {

    @Test func tokensAreReachableFromANonisolatedContext() {
        #expect(themeColors().count == 17)
        #expect(motionTokens().count == 5)
    }

    @Test func dynamicColorsResolveOffTheMainThread() async {
        let tokens = themeColors()
        let result = await Task.detached { () -> (onMain: Bool, differing: [String]) in
            let light = UITraitCollection(userInterfaceStyle: .light)
            let dark = UITraitCollection(userInterfaceStyle: .dark)
            var differing: [String] = []
            for (name, color) in tokens {
                let ui = UIColor(color)
                if rgba(ui.resolvedColor(with: light)) != rgba(ui.resolvedColor(with: dark)) {
                    differing.append(name)
                }
            }
            return (DispatchQueue.getSpecific(key: mainQueueKey) != nil, differing)
        }.value
        #expect(!result.onMain, "the guard is meaningless if this ran on the main thread")
        let inert = Set(tokens.map(\.0)).subtracting(result.differing).sorted()
        #expect(inert.isEmpty, "these tokens never exercised the dynamic provider: \(inert)")
    }

    @Test func dynamicProvidersLiveOnlyInTheme() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Nurikabe")
        var offenders: [String] = []
        let files = FileManager.default.enumerator(at: root, includingPropertiesForKeys: nil)
        while let url = files?.nextObject() as? URL {
            guard url.pathExtension == "swift", url.lastPathComponent != "Theme.swift" else { continue }
            let text = try String(contentsOf: url, encoding: .utf8)
            if text.contains("dynamicProvider") { offenders.append(url.lastPathComponent) }
        }
        #expect(offenders.isEmpty, "dynamic colour providers outside Theme.swift: \(offenders)")
        let theme = try String(contentsOf: root.appendingPathComponent("Design/Theme.swift"), encoding: .utf8)
        #expect(theme.contains("nonisolated enum Theme"))
        #expect(theme.contains("@Sendable trait in"))
    }
}
