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
        // Status bar
        UIApplication.shared.statusBarStyle = .darkContent

        // Tab bar appearance
        let tabAppearance = UITabBarAppearance()
        tabAppearance.configureWithOpaqueBackground()
        tabAppearance.backgroundColor = .white
        tabAppearance.shadowColor = UIColor.black.withAlphaComponent(0.06)
        UITabBar.appearance().standardAppearance = tabAppearance
        UITabBar.appearance().scrollEdgeAppearance = tabAppearance

        // Navigation bar
        let navAppearance = UINavigationBarAppearance()
        navAppearance.configureWithTransparentBackground()
        UINavigationBar.appearance().standardAppearance = navAppearance
        UINavigationBar.appearance().scrollEdgeAppearance = navAppearance
    }
}
