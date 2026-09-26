import StoreKit
import SwiftUI

/// The one-time unlock. Opens on the feature that brought the player here,
/// and lists the rest below it.
struct PaywallView: View {
    let feature: PaidFeature

    @Environment(EntitlementStore.self) private var entitlements
    @Environment(PaywallPresenter.self) private var paywall

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text(feature.headline).font(Theme.title).foregroundStyle(Theme.text)
                    Text(feature.pitch).foregroundStyle(Theme.text)
                        .fixedSize(horizontal: false, vertical: true)
                    Divider()
                    Text("Also in the full game").font(.headline).foregroundStyle(Theme.text)
                    ForEach(PaidFeature.allCases.filter { $0 != feature }) { other in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(other.headline).font(.subheadline.weight(.semibold))
                            Text(other.pitch).font(.subheadline).foregroundStyle(Theme.textSoft)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    Text("One purchase, no subscription. Rules, the first five lessons, 5×5 and 7×7 boards and the daily stay free.")
                        .font(.footnote)
                        .foregroundStyle(Theme.textSoft)
                    purchaseArea
                }
                .padding(20)
            }
            .background(Theme.ground.ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Not now") { paywall.dismiss() }
                }
            }
            .task { await entitlements.loadProduct() }
            .onChange(of: entitlements.isUnlocked) { _, unlocked in if unlocked { paywall.dismiss() } }
            .onAppear { entitlements.clearTransientState() }
        }
    }

    @ViewBuilder
    private var purchaseArea: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button {
                Task { await entitlements.purchase() }
            } label: {
                Text(entitlements.product.map { "Unlock for \($0.displayPrice)" } ?? "Unlock")
                    .font(.headline)
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(.borderedProminent)
            .tint(Theme.sea)
            .disabled(entitlements.purchaseState.isBusy)

            Button("Restore purchase") { Task { await entitlements.restore() } }
                .disabled(entitlements.purchaseState.isBusy)
                .tint(Theme.accent)

            switch entitlements.purchaseState {
            case .loadingProduct, .purchasing, .restoring:
                ProgressView()
            case .awaitingApproval:
                Text("Waiting for approval. The game unlocks as soon as it comes through.")
                    .font(.footnote).foregroundStyle(Theme.textSoft)
            case .note(let text):
                Text(text).font(.footnote).foregroundStyle(Theme.textSoft)
            case .failed(let text):
                Text(text).font(.footnote).foregroundStyle(Theme.error)
            case .idle:
                EmptyView()
            }
        }
    }
}
