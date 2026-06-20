import SwiftUI

struct ContentView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        Group {
            if !appState.isAuthenticated || !AuthService.shared.isSignedIn {
                SignInView()
            } else if !appState.onboardingComplete {
                OnboardingView()
            } else {
                MainTabView()
            }
        }
            .onReceive(NotificationCenter.default.publisher(for: .navigateToScreen)) { notification in
                if let screen = notification.userInfo?["screen"] as? String {
                    switch screen {
                    case "today", "overview":
                        appState.selectedTab = .today
                    case "future":
                        appState.selectedTab = .future
                    case "coach":
                        // Phase 1c migration: Coach tab removed; route to Today until Phase 5
                        // builds in-Today CoachSheet. Stale "coach" payloads land here gracefully.
                        appState.selectedTab = .today
                    case "settings", "optimize", "progress":
                        appState.selectedTab = .settings
                    default:
                        break
                    }
                }
            }
    }
}
