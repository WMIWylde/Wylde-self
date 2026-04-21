import SwiftUI

struct MainTabView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        ZStack(alignment: .bottom) {
            // Screen content
            Group {
                switch appState.selectedTab {
                case .today:
                    TodayView()
                case .future:
                    WebViewScreen(path: "#future")
                case .coach:
                    WebViewScreen(path: "#coach")
                case .optimize:
                    WebViewScreen(path: "#optimize")
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            // Custom tab bar
            BottomTabBar()
        }
        .background(Theme.background)
        .ignoresSafeArea(.keyboard)
    }
}

// MARK: - Bottom Tab Bar

struct BottomTabBar: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        HStack(spacing: 0) {
            ForEach(AppState.Tab.allCases, id: \.self) { tab in
                TabButton(tab: tab, isActive: appState.selectedTab == tab) {
                    HapticManager.shared.impact(.light)
                    withAnimation(.easeInOut(duration: 0.15)) {
                        appState.selectedTab = tab
                    }
                }
            }
        }
        .frame(height: 72)
        .padding(.bottom, safeAreaBottom)
        .background(
            Rectangle()
                .fill(.white)
                .shadow(color: .black.opacity(0.06), radius: 12, y: -4)
                .ignoresSafeArea(edges: .bottom)
        )
    }

    private var safeAreaBottom: CGFloat {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first?.windows.first?.safeAreaInsets.bottom ?? 0
    }
}

struct TabButton: View {
    let tab: AppState.Tab
    let isActive: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                // Active indicator pill
                Capsule()
                    .fill(isActive ? Theme.sage : .clear)
                    .frame(width: 20, height: 2)

                Image(systemName: tab.icon)
                    .font(.system(size: 20, weight: isActive ? .semibold : .regular))
                    .foregroundColor(isActive ? Theme.sage : Color(hex: "999999"))

                Text(tab.rawValue)
                    .font(.system(size: 10, weight: isActive ? .semibold : .medium))
                    .foregroundColor(isActive ? Theme.sage : Color(hex: "999999"))
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }
}
