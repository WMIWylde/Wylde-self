import Foundation
import StoreKit

// ════════════════════════════════════════════════════════════════════
//  PurchaseManager — RevenueCat-backed wrapper for in-app purchases.
//
//  This file uses the RevenueCat SDK (`Purchases`) but is written so it
//  compiles and runs in two modes:
//
//    1. With RevenueCat installed (recommended):
//       - Add `RevenueCat` via Xcode → File → Add Package Dependencies
//         and paste:  https://github.com/RevenueCat/purchases-ios
//       - Set `useRealRevenueCat = true` below
//       - Set the API key in Info.plist (key: WyldeRevenueCatAPIKey)
//
//    2. Stub mode (for now, while RevenueCat is being set up):
//       - useRealRevenueCat = false
//       - Purchases will simulate success after a 1.2s delay so the
//         UI can be developed against this without the SDK installed.
//
//  When you're ready to switch to real:
//    1. Add the RevenueCat package
//    2. Uncomment the `import RevenueCat` line
//    3. Uncomment the // REAL: blocks
//    4. Comment out the // STUB: blocks
//    5. Set useRealRevenueCat = true
//
//  The PaywallView + AppState do not need to change.
// ════════════════════════════════════════════════════════════════════

// import RevenueCat   // ← uncomment after adding the SwiftPM dependency

/// Product IDs as configured in App Store Connect + RevenueCat.
/// These must match exactly. Standard tier is shipped at v1.0; founder
/// tier is shipped now and disappears after the first 1,000 purchases.
enum WyldeProduct: String, CaseIterable {
    case lifetimeFounder = "com.wylde.self.lifetime.founder"
    case annualFounder   = "com.wylde.self.annual.founder"
    case monthlyFounder  = "com.wylde.self.monthly.founder"
    // Standard pricing (post-founder) — uncomment when you ship 1.0:
    // case lifetime  = "com.wylde.self.lifetime"
    // case annual    = "com.wylde.self.annual"
    // case monthly   = "com.wylde.self.monthly"

    /// The display price hard-coded as a fallback (RevenueCat returns
    /// localized prices, but we want UI to render even before fetch).
    var fallbackPriceString: String {
        switch self {
        case .lifetimeFounder: return "$149"
        case .annualFounder:   return "$79"
        case .monthlyFounder:  return "$9.99"
        }
    }
    var displayName: String {
        switch self {
        case .lifetimeFounder: return "Lifetime"
        case .annualFounder:   return "Annual"
        case .monthlyFounder:  return "Monthly"
        }
    }
    var billingNote: String {
        switch self {
        case .lifetimeFounder: return "one-time, yours forever"
        case .annualFounder:   return "billed yearly · founder price locked"
        case .monthlyFounder:  return "billed monthly · founder price locked"
        }
    }
}

/// The single source of truth for whether the user is Pro.
struct ProEntitlement {
    enum Status: String { case free, lifetime, annual, monthly, expired, refunded }

    let status: Status
    let productID: String?
    let expiresAt: Date?
    let purchasedAt: Date?
    let provider: String   // 'apple' | 'stripe' | 'google'

    var isActive: Bool {
        switch status {
        case .free, .expired, .refunded: return false
        case .lifetime: return true
        case .annual, .monthly:
            guard let exp = expiresAt else { return false }
            return exp > Date()
        }
    }

    static let free = ProEntitlement(
        status: .free, productID: nil, expiresAt: nil,
        purchasedAt: nil, provider: ""
    )
}

@MainActor
final class PurchaseManager: ObservableObject {

    // MARK: - Singleton
    static let shared = PurchaseManager()
    private init() {}

    // MARK: - Mode toggle
    /// Flip to true once RevenueCat SDK is added + API key is in Info.plist.
    /// Until then, runs in STUB mode (simulated purchase, dev-friendly).
    private let useRealRevenueCat = false

    // MARK: - Published state (Views observe these)
    @Published var entitlement: ProEntitlement = .free
    @Published var isLoadingProducts: Bool = false
    @Published var isPurchasing: Bool = false
    @Published var lastError: String? = nil

    // Localized prices, populated after fetchProducts(). Keys are product IDs.
    @Published var localizedPrices: [String: String] = [:]

    // MARK: - Lifecycle

    /// Called from WyldeSelfApp.onAppear so the SDK is configured early.
    /// Safe to call multiple times — internal init is idempotent.
    func configure(supabaseUserID: String?) {
        if useRealRevenueCat {
            // REAL: configure RevenueCat with API key + log in user
            // guard let apiKey = Bundle.main.object(forInfoDictionaryKey: "WyldeRevenueCatAPIKey") as? String,
            //       !apiKey.isEmpty else {
            //     print("[Purchases] Missing WyldeRevenueCatAPIKey in Info.plist")
            //     return
            // }
            // Purchases.logLevel = .info
            // Purchases.configure(withAPIKey: apiKey, appUserID: supabaseUserID)
            // refreshEntitlement()
        } else {
            // STUB: pretend everyone is free until they "buy"
            self.entitlement = .free
            print("[Purchases] STUB mode — RevenueCat not yet wired")
        }
    }

    /// Refreshes the cached entitlement from RevenueCat. Call after app
    /// becomes active or after a purchase.
    func refreshEntitlement() {
        if useRealRevenueCat {
            // REAL:
            // Purchases.shared.getCustomerInfo { [weak self] info, error in
            //     guard let self = self, let info = info else { return }
            //     Task { @MainActor in
            //         self.entitlement = self.entitlementFrom(info)
            //         self.notifyChange()
            //     }
            // }
        }
    }

    /// Fetch product metadata + localized prices from the App Store.
    func fetchProducts() async {
        isLoadingProducts = true
        defer { isLoadingProducts = false }

        if useRealRevenueCat {
            // REAL:
            // do {
            //     let offerings = try await Purchases.shared.offerings()
            //     guard let current = offerings.current else { return }
            //     for package in current.availablePackages {
            //         localizedPrices[package.storeProduct.productIdentifier] = package.storeProduct.localizedPriceString
            //     }
            // } catch {
            //     lastError = "Couldn't load products: \(error.localizedDescription)"
            // }
        } else {
            // STUB: populate fallback prices immediately
            try? await Task.sleep(nanoseconds: 300_000_000)
            for p in WyldeProduct.allCases {
                localizedPrices[p.rawValue] = p.fallbackPriceString
            }
        }
    }

    /// Initiate a purchase for the given product. Returns true on success.
    func purchase(_ product: WyldeProduct) async -> Bool {
        isPurchasing = true
        defer { isPurchasing = false }
        lastError = nil

        if useRealRevenueCat {
            // REAL:
            // do {
            //     let offerings = try await Purchases.shared.offerings()
            //     guard let pkg = offerings.current?.availablePackages.first(where: {
            //         $0.storeProduct.productIdentifier == product.rawValue
            //     }) else {
            //         lastError = "Product unavailable"
            //         return false
            //     }
            //     let result = try await Purchases.shared.purchase(package: pkg)
            //     if !result.userCancelled {
            //         self.entitlement = self.entitlementFrom(result.customerInfo)
            //         await assignFoundingMemberNumberIfEligible()
            //         self.notifyChange()
            //         return true
            //     }
            //     return false
            // } catch {
            //     lastError = "Purchase failed: \(error.localizedDescription)"
            //     return false
            // }
            return false
        } else {
            // STUB: simulate a 1.2s purchase, then mark as Pro
            try? await Task.sleep(nanoseconds: 1_200_000_000)
            let status: ProEntitlement.Status = {
                switch product {
                case .lifetimeFounder: return .lifetime
                case .annualFounder:   return .annual
                case .monthlyFounder:  return .monthly
                }
            }()
            let now = Date()
            let exp: Date? = {
                switch product {
                case .lifetimeFounder: return nil
                case .annualFounder:   return Calendar.current.date(byAdding: .year, value: 1, to: now)
                case .monthlyFounder:  return Calendar.current.date(byAdding: .month, value: 1, to: now)
                }
            }()
            self.entitlement = ProEntitlement(
                status: status,
                productID: product.rawValue,
                expiresAt: exp,
                purchasedAt: now,
                provider: "apple"
            )
            notifyChange()
            return true
        }
    }

    /// Restore previous purchases — required by App Store guidelines.
    func restorePurchases() async -> Bool {
        if useRealRevenueCat {
            // REAL:
            // do {
            //     let info = try await Purchases.shared.restorePurchases()
            //     self.entitlement = self.entitlementFrom(info)
            //     self.notifyChange()
            //     return self.entitlement.isActive
            // } catch {
            //     lastError = "Restore failed: \(error.localizedDescription)"
            //     return false
            // }
            return false
        } else {
            // STUB: no-op
            return entitlement.isActive
        }
    }

    // MARK: - Internal helpers

    /// Translates a RevenueCat CustomerInfo into our ProEntitlement.
    /// Uncomment when RevenueCat is wired.
    /*
    private func entitlementFrom(_ info: CustomerInfo) -> ProEntitlement {
        guard let entitlement = info.entitlements["wylde_pro"], entitlement.isActive else {
            return .free
        }
        let status: ProEntitlement.Status = {
            switch entitlement.productIdentifier {
            case let id where id.contains("lifetime"): return .lifetime
            case let id where id.contains("annual"):   return .annual
            case let id where id.contains("monthly"):  return .monthly
            default: return .free
            }
        }()
        return ProEntitlement(
            status: status,
            productID: entitlement.productIdentifier,
            expiresAt: entitlement.expirationDate,
            purchasedAt: entitlement.originalPurchaseDate,
            provider: "apple"
        )
    }
    */

    /// After a successful purchase, ask Supabase to assign this user a
    /// founding_member_number atomically. Webhook does this server-side
    /// too, but this gives instant UI feedback.
    private func assignFoundingMemberNumberIfEligible() async {
        // Implemented via Supabase RPC: assign_founding_member_number(p_user_id)
        // The migration file (20260427_pro_entitlements.sql) creates this function.
        // The actual call lives in AppState.didReceiveProEntitlementChange — keeps
        // the Supabase client centralized in one place.
    }

    /// Broadcasts so AppState + any listening views update.
    private func notifyChange() {
        NotificationCenter.default.post(
            name: .wyldeProEntitlementChanged,
            object: nil,
            userInfo: ["status": entitlement.status.rawValue]
        )
    }
}

extension Notification.Name {
    static let wyldeProEntitlementChanged = Notification.Name("wyldeProEntitlementChanged")
}
