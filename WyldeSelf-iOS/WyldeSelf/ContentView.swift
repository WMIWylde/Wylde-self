import SwiftUI

struct ContentView: View {
    @EnvironmentObject var appState: AppState
    @State private var showIntroAnimation = false

    var body: some View {
        ZStack {
            Group {
                if !appState.isAuthenticated || !AuthService.shared.isSignedIn {
                    SignInView()
                } else if !appState.onboardingComplete {
                    OnboardingView()
                        .onDisappear {
                            // Trigger intro animation when onboarding completes
                            if appState.onboardingComplete && !UserDefaults.standard.bool(forKey: "wylde_intro_seen") {
                                showIntroAnimation = true
                            }
                        }
                } else {
                    MainTabView()
                }
            }

            if showIntroAnimation {
                IntroAnimationView(isShowing: $showIntroAnimation)
                    .zIndex(999)
                    .onDisappear {
                        UserDefaults.standard.set(true, forKey: "wylde_intro_seen")
                    }
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
