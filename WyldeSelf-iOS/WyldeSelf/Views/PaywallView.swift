import SwiftUI

// ════════════════════════════════════════════════════════════════════
//  PaywallView — Founding Member offer (iOS native)
//
//  Brand brief: this is NOT a subscription wall. It's an early-supporter
//  offer. Free users keep using the full app. Founders pay to lock in
//  lifetime access + founder pricing forever + signal belief in the
//  practice.
//
//  Three tiers:
//    Lifetime $149 (one-time)         ← hero offer, recommended
//    Annual   $79  (yearly, locked)
//    Monthly  $9.99 (monthly, locked)
//
//  Only the first 1,000 founders get founder pricing. After that, the
//  standard tier kicks in at $249 / $99 / $14.99.
// ════════════════════════════════════════════════════════════════════

struct PaywallView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var purchases = PurchaseManager.shared
    @Environment(\.dismiss) private var dismiss

    @State private var selectedProduct: WyldeProduct = .lifetimeFounder
    @State private var founderCount: Int = 0
    @State private var founderCap: Int = 1000
    @State private var isLoadingCount = true
    @State private var showThankYou = false
    @State private var purchasedNumber: Int? = nil

    var body: some View {
        ZStack {
            // Strict dark — matches the rest of the brand
            Color(hex: "070707").ignoresSafeArea()

            // Subtle gold radial glow at top — sets a "ritual" tone
            RadialGradient(
                colors: [
                    Color(hex: "C8A96E").opacity(0.08),
                    Color.clear
                ],
                center: .top,
                startRadius: 0,
                endRadius: 400
            )
            .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    closeButton
                    founderCounter
                    headline
                    pitch
                    priceTiles
                    primaryCTA
                    restoreLink
                    finePrint
                }
                .padding(.horizontal, 22)
                .padding(.top, 16)
                .padding(.bottom, 40)
            }
        }
        .task {
            await loadFounderCount()
            await purchases.fetchProducts()
        }
        .sheet(isPresented: $showThankYou) {
            FounderThankYouView(memberNumber: purchasedNumber ?? 0)
                .environmentObject(appState)
        }
    }

    // MARK: - Top close

    private var closeButton: some View {
        HStack {
            Spacer()
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(Color(hex: "A6A29A"))
                    .frame(width: 36, height: 36)
                    .background(Color(hex: "111111"))
                    .clipShape(Circle())
            }
            .padding(.bottom, 24)
        }
    }

    // MARK: - Founder counter

    private var founderCounter: some View {
        VStack(spacing: 6) {
            HStack(spacing: 6) {
                Circle()
                    .fill(Color(hex: "C8A96E"))
                    .frame(width: 6, height: 6)
                Text("FOUNDING MEMBER OFFER")
                    .font(.system(size: 10, weight: .semibold))
                    .tracking(2.5)
                    .foregroundColor(Color(hex: "C8A96E"))
            }
            if isLoadingCount {
                Text("Reserving your spot…")
                    .font(.system(size: 13))
                    .foregroundColor(Color(hex: "A6A29A"))
            } else {
                Text("Founding member \(founderCount + 1) of \(founderCap)")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(Color(hex: "F4F1E8"))
            }
        }
        .padding(.bottom, 28)
    }

    // MARK: - Headline + pitch

    private var headline: some View {
        Text("Sponsor the work.\nLock in lifetime.")
            .font(.system(size: 34, weight: .bold))
            .foregroundColor(Color(hex: "F4F1E8"))
            .multilineTextAlignment(.leading)
            .lineSpacing(2)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.bottom, 16)
    }

    private var pitch: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Wylde Self is in active beta. We're building toward something that doesn't exist yet — a system that helps you become who you said you'd be.")
                .font(.system(size: 15))
                .foregroundColor(Color(hex: "A6A29A"))
                .lineSpacing(4)
            Text("The first 1,000 people who fund this work get lifetime access, founder pricing forever, and a direct line to the build.")
                .font(.system(size: 15))
                .foregroundColor(Color(hex: "A6A29A"))
                .lineSpacing(4)
        }
        .padding(.bottom, 28)
    }

    // MARK: - Price tiles

    private var priceTiles: some View {
        VStack(spacing: 10) {
            ForEach([WyldeProduct.lifetimeFounder, .annualFounder, .monthlyFounder], id: \.rawValue) { product in
                priceTile(for: product)
            }
        }
        .padding(.bottom, 24)
    }

    private func priceTile(for product: WyldeProduct) -> some View {
        let isSelected = selectedProduct == product
        let isLifetime = product == .lifetimeFounder
        let priceText = purchases.localizedPrices[product.rawValue] ?? product.fallbackPriceString

        return Button {
            selectedProduct = product
            HapticManager.shared.impact(.light)
        } label: {
            HStack(alignment: .center, spacing: 14) {
                // Selection indicator
                ZStack {
                    Circle()
                        .stroke(isSelected ? Color(hex: "C8A96E") : Color(hex: "A6A29A").opacity(0.4), lineWidth: 1.5)
                        .frame(width: 22, height: 22)
                    if isSelected {
                        Circle()
                            .fill(Color(hex: "C8A96E"))
                            .frame(width: 12, height: 12)
                    }
                }

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 8) {
                        Text(product.displayName)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(Color(hex: "F4F1E8"))
                        if isLifetime {
                            Text("BEST VALUE")
                                .font(.system(size: 9, weight: .bold))
                                .tracking(1.2)
                                .foregroundColor(Color(hex: "070707"))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                                .background(Color(hex: "C8A96E"))
                                .cornerRadius(4)
                        }
                    }
                    Text(product.billingNote)
                        .font(.system(size: 12))
                        .foregroundColor(Color(hex: "A6A29A"))
                }

                Spacer()

                Text(priceText)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(Color(hex: "F4F1E8"))
            }
            .padding(16)
            .background(isSelected ? Color(hex: "1A1A1A") : Color(hex: "111111"))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(isSelected ? Color(hex: "C8A96E") : Color(hex: "F4F1E8").opacity(0.06), lineWidth: 1)
            )
            .cornerRadius(14)
        }
        .buttonStyle(.plain)
    }

    // MARK: - CTA

    private var primaryCTA: some View {
        Button(action: handlePurchase) {
            HStack(spacing: 8) {
                if purchases.isPurchasing {
                    ProgressView()
                        .tint(Color(hex: "070707"))
                        .scaleEffect(0.85)
                }
                Text(purchases.isPurchasing ? "Processing…" : "Become a Founding Member")
                    .font(.system(size: 14, weight: .bold))
                    .tracking(1.5)
                    .textCase(.uppercase)
            }
            .foregroundColor(Color(hex: "070707"))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 17)
            .background(Color(hex: "C8A96E"))
            .cornerRadius(14)
            .shadow(color: Color(hex: "C8A96E").opacity(0.18), radius: 24, x: 0, y: 8)
        }
        .buttonStyle(.plain)
        .disabled(purchases.isPurchasing)
        .padding(.bottom, 12)
    }

    private var restoreLink: some View {
        Button {
            Task { _ = await purchases.restorePurchases() }
        } label: {
            Text("Restore purchases")
                .font(.system(size: 13))
                .foregroundColor(Color(hex: "A6A29A"))
        }
        .buttonStyle(.plain)
        .padding(.bottom, 24)
    }

    private var finePrint: some View {
        VStack(spacing: 8) {
            if let err = purchases.lastError {
                Text(err)
                    .font(.system(size: 12))
                    .foregroundColor(.red.opacity(0.85))
                    .multilineTextAlignment(.center)
                    .padding(.bottom, 8)
            }
            Text("Annual & monthly auto-renew. Cancel anytime in Settings → Apple ID → Subscriptions. Lifetime is a one-time payment, yours forever.")
                .font(.system(size: 11))
                .foregroundColor(Color(hex: "6E6B65"))
                .multilineTextAlignment(.center)
                .lineSpacing(3)
        }
    }

    // MARK: - Actions

    private func handlePurchase() {
        Task {
            HapticManager.shared.impact(.medium)
            let success = await purchases.purchase(selectedProduct)
            if success {
                HapticManager.shared.notification(.success)
                // The number gets assigned by the webhook + by AppState's
                // proEntitlementChanged listener. For instant UI feedback,
                // optimistic = current count + 1.
                purchasedNumber = founderCount + 1
                showThankYou = true
            }
        }
    }

    private func loadFounderCount() async {
        defer { isLoadingCount = false }
        guard let url = URL(string: "https://wyldeself.com/api/founder-count") else { return }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                self.founderCount = (json["total_founders"] as? Int) ?? 0
                self.founderCap   = (json["founder_cap"] as? Int) ?? 1000
            }
        } catch {
            // Silent fallback — counter still renders with default values
            print("[Paywall] Couldn't load founder count: \(error.localizedDescription)")
        }
    }
}

// MARK: - Thank You sheet shown after a successful founder purchase

struct FounderThankYouView: View {
    let memberNumber: Int
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Color(hex: "070707").ignoresSafeArea()

            // Soft gold halo behind the number
            RadialGradient(
                colors: [Color(hex: "C8A96E").opacity(0.18), .clear],
                center: .center, startRadius: 0, endRadius: 280
            )
            .ignoresSafeArea()

            VStack(spacing: 28) {
                Spacer()

                Text("FOUNDING MEMBER")
                    .font(.system(size: 11, weight: .bold))
                    .tracking(3)
                    .foregroundColor(Color(hex: "C8A96E"))

                Text("#\(memberNumber)")
                    .font(.system(size: 84, weight: .bold))
                    .foregroundColor(Color(hex: "F4F1E8"))
                    .tracking(-2)

                VStack(spacing: 10) {
                    Text("You're in.")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundColor(Color(hex: "F4F1E8"))
                    Text("Founder pricing locked. Lifetime access. A direct line to the build.")
                        .font(.system(size: 14))
                        .foregroundColor(Color(hex: "A6A29A"))
                        .multilineTextAlignment(.center)
                        .lineSpacing(3)
                        .padding(.horizontal, 36)
                }

                Spacer()

                Button {
                    dismiss()
                } label: {
                    Text("Continue")
                        .font(.system(size: 13, weight: .bold))
                        .tracking(1.5)
                        .textCase(.uppercase)
                        .foregroundColor(Color(hex: "070707"))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 17)
                        .background(Color(hex: "C8A96E"))
                        .cornerRadius(14)
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 22)
                .padding(.bottom, 32)
            }
        }
    }
}
