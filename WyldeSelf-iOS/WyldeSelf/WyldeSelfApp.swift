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
                .preferredColorScheme(appState.preferredColorScheme)
                .onAppear {
                    configureAppearance()
                    scheduleDailyReminders()
                    // Purchase SDK — stub mode until RevenueCat is wired.
                    PurchaseManager.shared.configure(supabaseUserID: nil as String?)
                    // CheckinSync — observes AppState toggles, posts to
                    // /api/consumer/checkin (debounced).
                    CheckinSync.shared.start(appState: appState)
                    // WatchSync — sends daily state to Apple Watch companion
                    WatchSync.shared.start(appState: appState)
                }
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
                    // Refresh daily state, then recompute the day counter.
                    // Order matters: loadFromDefaults() reads the persisted
                    // "wylde_day" value, so it must run BEFORE
                    // refreshCurrentDay() overwrites it with the fresh
                    // calendar-math result. Reversing this order (the
                    // previous bug) meant every foreground return
                    // clobbered today's day back to yesterday's.
                    appState.loadFromDefaults()
                    appState.refreshCurrentDay()
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
