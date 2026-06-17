import SwiftUI

@main
struct WyldeSelfApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var appState = AppState()
    @State private var showSplash = true

    var body: some Scene {
        WindowGroup {
            ZStack {
                ContentView()
                    .environmentObject(appState)

                if showSplash {
                    SplashView()
                        .transition(.opacity)
                        .zIndex(1)
                        .onReceive(
                            NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)
                                .first()
                                .delay(for: .seconds(2.4), scheduler: RunLoop.main)
                        ) { _ in
                            withAnimation { showSplash = false }
                        }
                }
            }
                .preferredColorScheme(.light)
                .onAppear {
                    configureAppearance()
                    scheduleDailyReminders()
                    // Initialize the in-app purchase SDK. Stub mode until
                    // RevenueCat package + API key are added (see PAYWALL_SETUP.md).
                    PurchaseManager.shared.configure(supabaseUserID: nil as String?)
                    Task { await PurchaseManager.shared.fetchProducts() }
                    // Restore Supabase session if one exists, so returning users
                    // skip the sign-in screen.
                    Task { await AuthService.shared.restore() }
                    // Start background CheckinSync — observes AppState daily
                    // toggles and posts to /api/consumer/checkin (debounced).
                    CheckinSync.shared.start(appState: appState)
                }
                .onReceive(NotificationCenter.default.publisher(for: .wyldeAuthChanged)) { note in
                    let signedIn = (note.userInfo?["isSignedIn"] as? Bool) ?? false
                    appState.isAuthenticated = signedIn
                }
                .onOpenURL { url in
                    // Magic-link callback from Supabase email — finalize the session.
                    if url.scheme == "wyldeself" && url.host == "auth" {
                        Task { await AuthService.shared.handleCallback(url) }
                    }
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
