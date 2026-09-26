import SwiftUI

struct ContentView: View {
    @State private var path: [Route] = []
    @Environment(PaywallPresenter.self) private var paywall

    var body: some View {
        NavigationStack(path: $path) {
            HomeView(path: $path)
                .navigationDestination(for: Route.self) { route in
                    destination(for: route)
                }
        }
        .sheet(item: paywallBinding) { feature in
            PaywallView(feature: feature)
        }
    }

    /// Dismissal goes through `dismiss()`, so there is one way the sheet closes.
    private var paywallBinding: Binding<PaidFeature?> {
        Binding(get: { paywall.presented },
                set: { if $0 == nil { paywall.dismiss() } })
    }

    @ViewBuilder
    private func destination(for route: Route) -> some View {
        switch route {
        case .play(let source): PlayHostView(source: source)
        case .learn: LearnPathView(path: $path)
        // Explicit identity: finishing a step replaces the top of the path
        // with the next step's view of the same type, and without an id
        // SwiftUI keeps the old step's @State (card, session) alive.
        case .rule(let rule): RuleLessonView(rule: rule, path: $path).id(rule)
        case .lesson(let technique): TechniqueLessonView(technique: technique, path: $path).id(technique)
        case .stats: StatsView()
        case .settings: SettingsView()
        }
    }
}
