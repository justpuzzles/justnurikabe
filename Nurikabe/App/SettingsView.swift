import SwiftUI

struct SettingsView: View {
    @Environment(ProgressStore.self) private var progress
    @Environment(EntitlementStore.self) private var entitlements
    @Environment(PaywallPresenter.self) private var paywall

    var body: some View {
        @Bindable var progress = progress
        Form {
            Section {
                Toggle("Show broken rules", isOn: $progress.settings.showRuleBreaks)
                Toggle("Show timer", isOn: $progress.settings.showTimer)
                Toggle("Haptics", isOn: $progress.settings.hapticsEnabled)
                    .onChange(of: progress.settings.hapticsEnabled) { _, on in Haptics.enabled = on }
            } footer: {
                Text("Broken rules are pools, islands with two numbers, and sea that has been cut off. They're marked in red as soon as they happen.")
            }
            Section("Full game") {
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
                        Text(text).font(.footnote).foregroundStyle(Theme.error)
                    case .awaitingApproval:
                        Text("Waiting for approval.").font(.footnote).foregroundStyle(Theme.textSoft)
                    case .idle:
                        EmptyView()
                    }
                }
            }
            Section("About") {
                Text("Nurikabe is a logic puzzle first published by Nikoli. Every board here has exactly one solution, and every board can be solved by reasoning alone, without guessing.")
                    .font(.footnote)
                    .foregroundStyle(Theme.textSoft)
                LabeledContent("Version", value: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0")
            }
        }
        .scrollContentBackground(.hidden)
        .background(Theme.ground.ignoresSafeArea())
        .navigationTitle("Settings")
        .onAppear { entitlements.clearTransientState() }
    }
}
