import SwiftUI

@main
struct WyldeSelfApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .preferredColorScheme(.light)
                .onAppear {
                    configureAppearance()
                    scheduleDailyReminders()
                    // Initialize the in-app purchase SDK. Stub mode until
                    // RevenueCat package + API key are added (see PAYWALL_SETUP.md).
                    PurchaseManager.shared.configure(supabaseUserID: nil as String?)
                    Task { await PurchaseManager.shared.fetchProducts() }
                }
        }
    }

    /// Set up the daily walk reminder once per launch. iOS de-dupes by
    /// identifier (`daily_13_0`), so re-registering is idempotent.
    private func scheduleDailyReminders() {
        NotificationManager.shared.scheduleDailyReminder(
            hour: 13, minute: 0,
            title: "Time for your walk",
            body: "30+ minutes outside. Phone in your pocket. Your body needs the reset."
        )
    }

    private func configureAppearance() {
        // Status bar icons follow light trait + UIViewController hierarchy (avoid deprecated globals).

        // Tab bar appearance — match paper chrome from DESIGN tokens
        let tabAppearance = UITabBarAppearance()
        tabAppearance.configureWithOpaqueBackground()
        tabAppearance.backgroundColor = Theme.paperUIColor
        tabAppearance.shadowColor = Theme.hairlineShadowUIColor
        UITabBar.appearance().standardAppearance = tabAppearance
        UITabBar.appearance().scrollEdgeAppearance = tabAppearance

        // Navigation bar
        let navAppearance = UINavigationBarAppearance()
        navAppearance.configureWithTransparentBackground()
        UINavigationBar.appearance().standardAppearance = navAppearance
        UINavigationBar.appearance().scrollEdgeAppearance = navAppearance
    }
}
