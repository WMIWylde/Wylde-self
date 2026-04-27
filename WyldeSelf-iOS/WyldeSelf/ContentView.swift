import SwiftUI

struct ContentView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        MainTabView()
            .onReceive(NotificationCenter.default.publisher(for: .navigateToScreen)) { notification in
                if let screen = notification.userInfo?["screen"] as? String {
                    switch screen {
                    case "today", "overview":
                        appState.selectedTab = .today
                    case "future":
                        appState.selectedTab = .future
                    case "coach":
                        appState.selectedTab = .coach
                    case "settings", "optimize", "progress":
                        appState.selectedTab = .settings
                    default:
                        break
                    }
                }
            }
    }
}
