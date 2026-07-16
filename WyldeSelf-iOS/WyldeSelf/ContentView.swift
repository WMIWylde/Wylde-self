import SwiftUI

struct ContentView: View {
    @EnvironmentObject var appState: AppState
    @ObservedObject private var auth = AuthService.shared
    @State private var showIntroAnimation = false
    @State private var isRestoringSession = true

    var body: some View {
        ZStack {
            Group {
                if isRestoringSession {
                    // Loading state while Supabase checks session validity
                    ZStack {
                        Theme.appBG.ignoresSafeArea()
                        ProgressView()
                            .tint(Color(hex: "C8A96E"))
                            .scaleEffect(1.2)
                    }
                } else if !auth.isSignedIn {
                    // Supabase is the single source of truth for auth
                    SignInView()
                } else if !appState.onboardingComplete {
                    OnboardingView()
                        .onDisappear {
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
        .task {
            // Restore Supabase session on launch
            await auth.restore()
            // Sync local auth flag with Supabase truth
            appState.isAuthenticated = auth.isSignedIn
            isRestoringSession = false
        }
        .onReceive(NotificationCenter.default.publisher(for: .wyldeAuthChanged)) { note in
            let signedIn = (note.userInfo?["isSignedIn"] as? Bool) ?? false
            appState.isAuthenticated = signedIn
        }
        .onReceive(NotificationCenter.default.publisher(for: .navigateToScreen)) { notification in
            if let screen = notification.userInfo?["screen"] as? String {
                switch screen {
                case "today", "overview":
                    appState.selectedTab = .today
                case "future":
                    appState.selectedTab = .future
                case "coach":
                    appState.selectedTab = .today
                case "settings", "optimize", "progress":
                    appState.selectedTab = .settings
                default:
                    break
                }
            }
        }
        .onOpenURL { url in
            if url.scheme == "wyldeself" && url.host == "auth" {
                Task { await auth.handleCallback(url) }
            }
        }
    }
}
