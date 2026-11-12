import SwiftUI

struct SettingsView: View {
    static let support = "https://kaikunze.de/justnurikabe/"
    static let privacyPolicy = "https://kaikunze.de/justnurikabe/justnurikabe-privacy.html"

    @Environment(ProgressStore.self) private var progress
    @Environment(EntitlementStore.self) private var entitlements
    @Environment(PaywallPresenter.self) private var paywall

    var body: some View {
        @Bindable var progress = progress
        Form {
            Section {
                Toggle("Show broken rules", isOn: $progress.settings.showRuleBreaks)
                Toggle("Show timer", isOn: $progress.settings.showTimer)
                #if os(iOS)
                Toggle("Haptics", isOn: $progress.settings.hapticsEnabled)
                    .onChange(of: progress.settings.hapticsEnabled) { _, on in Haptics.enabled = on }
                #endif
            } footer: {
                Text("Broken rules are pools, islands with two numbers, and sea that has been cut off. They're marked in red as soon as they happen.").listHeaderText()
            }
            Section {
                if entitlements.isUnlocked {
                    Label("Unlocked. Thank you.", systemImage: "checkmark.seal")
                } else {
                    Button("Unlock the full game") { paywall.present(.advancedLessons) }
                    Button("Restore purchase") { Task { await entitlements.restore() } }
                        .disabled(entitlements.purchaseState.isBusy)
                    switch entitlements.purchaseState {
                    case .restoring, .loadingProduct, .purchasing:
                        ProgressView()
                    case .note(let text):
                        Text(text).font(.footnote).foregroundStyle(Theme.textSoft)
                    case .failed(let text):
                        Text(text).font(.footnote).foregroundStyle(Theme.errorText)
                    case .awaitingApproval:
                        Text("Waiting for approval.").font(.footnote).foregroundStyle(Theme.textSoft)
                    case .idle:
                        EmptyView()
                    }
                }
            } header: {
                Text("Full game").listHeaderText()
}
            Section {
                Text("Every board has exactly one solution, and you can reach it by reasoning alone.")
                    .font(.footnote)
                    .foregroundStyle(Theme.textSoft)
                // Guideline 5.1.1(i): the privacy policy must be reachable
                // inside the app, not only from the store listing.
                if let url = URL(string: Self.privacyPolicy) {
                    Link("Privacy policy", destination: url)
                }
                if let url = URL(string: Self.support) {
                    Link("Help and contact", destination: url)
                }
                LabeledContent("Version", value: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0")
            } header: {
                Text("About").listHeaderText()
}
        }
        .groundListBackground()
        .background(Theme.ground.ignoresSafeArea())
        .navigationTitle("Settings")
        .onAppear { entitlements.clearTransientState() }
    }
}
